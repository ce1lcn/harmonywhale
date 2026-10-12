const fs=require('fs'),path=require('path'),vm=require('vm'),assert=require('assert/strict');
const ts=require(process.env.HVIGOR_TS||'typescript');
let leaseRequests=0,leaseExpiry;
const kit={'@kit.BackgroundTasksKit':{backgroundTaskManager:{requestSuspendDelay:(reason,cb)=>{leaseRequests++;leaseExpiry=cb;return {requestId:1,actualDelayTime:180000};},cancelSuspendDelay(){}}},'@kit.ArkTS':{buffer:Buffer}};
const cache=new Map();function load(file){file=path.resolve(file);if(cache.has(file))return cache.get(file);const module={exports:{}};vm.runInNewContext(ts.transpileModule(fs.readFileSync(file,'utf8'),{compilerOptions:{module:ts.ModuleKind.CommonJS,target:ts.ScriptTarget.ES2020}}).outputText,{module,exports:module.exports,require:n=>n.startsWith('.')?load(path.resolve(path.dirname(file),n+'.ets')):kit[n]??{},setTimeout:(f,ms)=>ms>5000?0:setTimeout(f,0),clearTimeout,Uint8Array,ArrayBuffer,Map,Set,Buffer});cache.set(file,module.exports);return module.exports;}
const root='entry/src/main/ets/agent/',T=load(root+'Types.ets'),{Engine}=load(root+'Engine.ets'),{conversation,CHAT_RULES}=load(root+'Conversation.ets');
assert.ok(CHAT_RULES.includes('按本任务、危险类别和应用隔离授权'));
assert.ok(CHAT_RULES.includes('不要重复调用 request_confirmation'));
assert.ok(!CHAT_RULES.includes('执行前用 request_confirmation'));
function fixture(){const state=T.defaults(),actions=[];let screen=0;const device={mutationCount:0,hdc:{ready:true},active:()=>true,invalidate(){},sensitive:()=>false,stable:async()=>{},observe:async()=>({path:'/sandbox/screen.jpeg',snapshotId:'screen-'+screen,layout:'page-'+screen,fingerprint:'page-'+screen,image:'',width:1000,height:1000}),execute:async(n)=>{device.mutationCount++;screen++;actions.push(n);return 'No Error';},actionTarget:async()=>({label:'7',app:'calculator'})};const engine=new Engine(state,{save(){},secret:async()=> 'fixture'},device,()=>{});return {engine,state,device,actions};}
const call=(id,name,args={})=>({id,name,arguments:JSON.stringify(args)});
(async()=>{
 const {riskOf,ActionGrants}=load(root+'Risk.ets');for(const label of ['确认支付','立即购买','发送','永久删除','清空','安装','卸载','恢复出厂','格式化','转账'])assert.ok(riskOf(label,'app'),label);for(const label of ['7','播放','搜索','取消'])assert.equal(riskOf(label,'app'),null);
 const g=new ActionGrants();g.add('task','删除数据','notes');assert.ok(g.allows('task','删除数据','notes'));assert.ok(!g.allows('other','删除数据','notes'));assert.ok(!g.allows('task','发送消息','notes'));assert.ok(!g.allows('task','删除数据','photos'));
 assert.equal(riskOf('最近删除, 1 最近删除 1','notes'),null);assert.equal(riskOf('回收站','notes'),null);assert.equal(riskOf('永久删除','notes'),'删除数据');assert.equal(riskOf('删除最近删除中的全部内容','notes'),'删除数据');
 assert.equal(riskOf('id_history_record_delete','calculator'),'删除数据');assert.equal(riskOf('id_delete_button','app'),'删除数据');assert.equal(riskOf('id_history_record','calculator'),null);assert.equal(riskOf('clear_all','app'),'删除数据');
 const {ScreenProgress,budgetState,callLimit,tokenLimit,isResume}=load(root+'ExecutionPolicy.ets');const p=new ScreenProgress();for(let i=1;i<=10;i++)assert.equal(p.sample('same','same'),i===3||i===5?'warning':i>=8?'stop':'');assert.equal(p.sample('a','b'),'');assert.equal(p.unchanged,0);assert.equal(callLimit(),200);assert.equal(callLimit(999),500);assert.equal(tokenLimit(),20000000);/* 0.8.0.2 默认 2000 万等效 */assert.equal(tokenLimit(0),0);assert.equal(budgetState(4100000,100000,5000000),'warning');assert.equal(budgetState(5100000,100000,5000000),'exhausted');assert.equal(budgetState(99999999,0,0),'');assert.ok(isResume('继续'));assert.ok(isResume('go on'));assert.ok(!isResume('继续画一只猫'));
 let f=fixture(),round=0;f.engine.model.next=async()=>++round===1?{text:'',calls:[call('read1','observe'),call('read2','skill_load',{name:'原生计算器操作要点'}),call('write','home'),call('skipped','back')]}:{text:'做好了',calls:[]};await f.engine.start('返回桌面');assert.equal(f.engine.current.status,'completed');assert.equal(f.engine.current.outcome,'done');assert.deepEqual(f.actions,['home']);const records=f.engine.current.records;assert.equal(records.length,4);assert.equal(records[3].status,'skipped');assert.match(records[3].result,/逐个/);assert.equal(f.engine.current.finalObservation.path,'/sandbox/screen.jpeg');
 const c=conversation(f.state.profiles[0],f.engine.session(),f.engine.current,{layout:'files',image:'',width:0,height:0},f.engine.definitions,'');const assistant=c.messages.find(m=>m.tool_calls?.length===4);assert.ok(assistant);const ai=c.messages.indexOf(assistant);assert.equal(JSON.stringify(Array.from(c.messages.slice(ai+1,ai+5),m=>m.tool_call_id)),JSON.stringify(records.map(r=>r.id)));
 f=fixture();round=0;f.engine.model.next=async()=>++round===1?{text:'',calls:Array.from({length:6},(_,i)=>call('r'+i,'skill_load',{name:'原生计算器操作要点'}))}:{text:'好了',calls:[]};await f.engine.start('看指引');assert.equal(f.engine.current.records.filter(r=>r.status==='success').length,4);assert.equal(f.engine.current.records.filter(r=>r.status==='skipped').length,2);
 // Engine guards risky clicks even when the model omits request_confirmation.
 f=fixture();f.device.actionTarget=async()=>({label:'删除',app:'notes'});f.engine.confirm=async(text,scope)=>{assert.match(text,/删除/);assert.match(text,/备忘录/);assert.match(scope,/本任务/);return false;};f.engine.model.next=async()=>({text:'',calls:[call('danger','click',{x:10,y:10})]});await f.engine.start('删测试内容');assert.equal(f.actions.length,0);assert.equal(f.engine.current.status,'paused');assert.equal(f.engine.current.records[0].errorCode,'DENIED');
 f=fixture();round=0;let asks=0;f.device.actionTarget=async()=>({label:'删除',app:'notes'});f.engine.confirm=async(text,scope,key)=>{asks++;f.engine.actionGrants.keys.add(key);return true;};f.engine.model.next=async()=>++round<=2?{text:'',calls:[call('delete'+round,'click',{x:round*10,y:10})]}:{text:'删除了两项测试内容',calls:[]};await f.engine.start('删两项');assert.equal(asks,1);assert.equal(f.actions.length,2);assert.equal(f.engine.actionGrants.keys.size,0);
 // A cancellation during the first member prevents all subsequent members.
 f=fixture();f.engine.skills.load=()=>{f.engine.pause('取消',true);return 'read';};f.engine.model.next=async()=>({text:'',calls:[call('read','skill_load',{name:'原生计算器操作要点'}),call('never','home')]});await f.engine.start('取消批次');assert.equal(f.actions.length,0);assert.equal(f.engine.current.records[1].status,'skipped');assert.equal(f.engine.current.status,'cancelled');
 // First uncertain mutation is fed back. Read-only recovery does not clear its count.
 f=fixture();round=0;f.device.execute=async()=>{f.device.mutationCount++;throw Error('结果未知');};f.engine.model.next=async()=>{round++;return {text:'',calls:[call('u'+round,round===2?'observe':'home')]};};await f.engine.start('不确定动作');assert.equal(f.engine.current.status,'paused');assert.match(f.engine.current.reason,/连续两次/);assert.equal(f.engine.current.records.filter(r=>r.status==='uncertain').length,2);
 f=fixture();f.engine.model.next=async()=>({text:'',calls:[call('finish','finish_task',{outcome:'success',reply:'完成'})]});await f.engine.start('结束');assert.equal(f.engine.current.status,'completed');assert.equal(f.engine.current.outcome,'success');
 // Budget is cumulative across model rounds, including cache hits, and renewed on resume.
 f=fixture();f.state.tokenBudget=1000000;round=0;f.engine.model.next=async()=>{f.engine.model.onUsage({input:1000000,cacheRead:0,cacheWrite:0,output:0,total:1000000,calls:1,model:'fixture'});return {text:'',calls:[call('over','home')]};};await f.engine.start('预算测试');/* 0.8.0：等效用量口径，未缓存输入全价计 */assert.equal(f.actions.length,0);assert.equal(f.engine.current.records[0].status,'skipped');assert.match(f.engine.current.reason,/用量预算/);f.engine.model.next=async()=>({text:'接着结束',calls:[]});await f.engine.start();assert.equal(f.engine.current.status,'completed');assert.equal(f.engine.current.budgetBase,1000000);
 f=fixture();f.engine.session().plan={id:'old',text:'EXPIRED_PLAN',status:'completed',steps:[]};const chat=conversation(f.state.profiles[0],f.engine.session(),{id:'q',mode:'auto',goal:'聊聊',constraints:[],summary:'',records:[],calls:0,status:'running',reason:''},{layout:'[]',image:'',width:0,height:0},[], '');assert.ok(!JSON.stringify(chat).includes('EXPIRED_PLAN'));assert.ok(!JSON.stringify(chat).includes('未观察屏幕时不能猜'));
 console.log('PASS: risk grants, screen progress, token renewal, batch pairing/limits, cancellation, uncertain recovery, optional completion and chat context');
 // Trust must distinguish servers even when their display titles are identical.
 const {mcpGrantKey}=load(root+'Risk.ets');
 assert.notEqual(mcpGrantKey('s','a','https://one.example/mcp'),mcpGrantKey('s','b','https://two.example/mcp'));
 assert.notEqual(mcpGrantKey('s','a','https://one.example/mcp'),mcpGrantKey('s','a','https://two.example/mcp'));
 assert.notEqual(mcpGrantKey('s','a','https://one.example/mcp'),mcpGrantKey('other','a','https://one.example/mcp'));
 f=fixture();let shown=0;f.device.showApproval=async()=>{shown++;};f.engine.current={status:'running'};
 const pending=f.engine.confirm('具体动作','此任务范围','key');await new Promise(resolve=>setTimeout(resolve,0));
 assert.equal(shown,1);assert.equal(f.engine.current.status,'approval');f.engine.approve(false);assert.equal(await pending,false);
 // Consent restores the target before relocalization; cancellation never restores or clicks.
 f=fixture();round=0;let restored=0;f.device.actionTarget=async()=>({label:'删除',app:'notes'});
 f.device.restoreApproval=async(target,args)=>{restored++;args.x=55;};f.engine.confirm=async()=>true;
 f.engine.model.next=async()=>++round===1?{text:'',calls:[call('approved','click',{x:10,y:10})]}:{text:'完成',calls:[]};
 await f.engine.start('删除测试项');assert.equal(restored,1);assert.equal(f.actions.length,1);
 f=fixture();f.device.actionTarget=async()=>({label:'删除',app:'notes'});f.device.restoreApproval=async()=>{throw Error('MUST NOT RESTORE');};
 f.engine.confirm=async()=>{f.engine.pause('用户取消',true);return true;};f.engine.model.next=async()=>({text:'',calls:[call('cancel-risk','click',{x:10,y:10})]});
 await f.engine.start('取消确认');assert.equal(f.actions.length,0);assert.equal(f.engine.current.status,'cancelled');
 const {Device}=load(root+'Device.ets'),{snapshot}=load(root+'Elements.ets');
 const node=(x,text='删除测试数据')=>({attributes:{id:'delete',type:'Button',text,bounds:`[${x},100][${x+100},200]`,clickable:'true',hostWindowId:'window'}});
 const original=snapshot({children:[node(100)]},1000,1000),moved=snapshot({children:[node(300)]},1000,1000);
 const realDevice=new Device({ready:true},{});realDevice.readLayout=async()=>moved;
 const iconDevice=new Device({ready:true},{});iconDevice.width=1000;iconDevice.height=1000;
 iconDevice.readLayout=async()=>snapshot({children:[{attributes:{id:'id_history_record_delete',type:'Button',text:'',description:' ',bounds:'[900,50][1000,150]',clickable:'true'}}]},1000,1000);
 iconDevice.command=async()=> 'AbilityRecord ID: 1\nstate #FOREGROUND\nbundle name [com.huawei.hmos.calculator]\nmain name [CalculatorAbility]';
 const iconTarget=await iconDevice.actionTarget('click',{x:950,y:100});assert.equal(iconTarget.label,'id_history_record_delete');assert.equal(riskOf(iconTarget.label,iconTarget.app),'删除数据');
 const args={x:150,y:150};await realDevice.restoreApproval({label:'删除测试数据',app:'com.harmonyloom.selfhdcprobe',ability:'ProbeAbility',snapshot:original,elementId:original.elements[0].elementId},args);
 assert.equal(args.x,350);assert.equal(args.y,150);
 realDevice.readLayout=async()=>snapshot({children:[node(300,'删除另一份数据')]},1000,1000);
 await assert.rejects(()=>realDevice.restoreApproval({label:'删除测试数据',app:'com.harmonyloom.selfhdcprobe',ability:'ProbeAbility',snapshot:original,elementId:original.elements[0].elementId},args),/页面内容变化/);
 f=fixture();round=0;f.device.observe=async()=>({path:'/sandbox/screen.jpeg',snapshotId:'unchanged',layout:'same',fingerprint:'same',image:'',width:1000,height:1000});
 f.engine.model.next=async()=>({text:'',calls:[round++===0?call('initial','observe'):call('noop'+round,'click',{x:round*10,y:100})]});
 await f.engine.start('无进展验收');assert.match(f.engine.current.reason,/连续八次/);
 assert.equal(f.engine.current.records.at(-1).status,'success');assert.match(f.engine.current.records.at(-1).result,/动作已执行/);
 f.engine.model.next=async()=>{const ctx=conversation(f.state.profiles[0],f.engine.session(),f.engine.current,{layout:'same',image:'',width:1000,height:1000},f.engine.definitions,'');assert.match(JSON.stringify(ctx),/恢复前暂停原因/);return {text:'八次已执行，不补发',calls:[]};};
 await f.engine.start();assert.equal(f.engine.current.status,'completed');assert.equal(f.actions.length,8);
 f=fixture();f.engine.setForeground(true);leaseRequests=0;
 f.engine.model.next=async()=>{assert.equal(leaseRequests,0);f.engine.setForeground(false);assert.equal(leaseRequests,1);const stale=leaseExpiry;f.engine.setForeground(true);stale();assert.notEqual(f.engine.current.status,'paused');assert.equal(f.engine.leaseDeadline,0);return {text:'前台正常完成',calls:[]};};
 await f.engine.start('前台准备与后台额度');assert.equal(f.engine.current.status,'completed');
 f=fixture();f.engine.setForeground(true);f.engine.model.next=async()=>{f.engine.setForeground(false);leaseExpiry();return {text:'',calls:[call('too-late','home')]};};
 await f.engine.start('后台到期');assert.equal(f.engine.current.status,'paused');assert.equal(f.actions.length,0);assert.match(f.engine.current.reason,/后台额度/);
 const {calculatorLabels}=load(root+'CalculatorLabels.ets');
 f=fixture();let networkCalls=0;f.engine.network.execute=async()=>{networkCalls++;return '没能联网核实：断网';};f.engine.network.sources=[];
 f.device.observe=async()=>{throw new Error('Network chat must not observe tablet');};round=0;
 f.engine.model.next=async()=>++round===1?{text:'',calls:[call('web','web_search',{query:'天气'})]}:{text:'这次没能联网核实。',calls:[]};
 await f.engine.start('联网问答');assert.equal(networkCalls,1);assert.equal(f.actions.length,0);assert.equal(f.engine.current.status,'completed');assert.equal(f.engine.current.records[0].status,'error');assert.equal(f.engine.current.records[0].errorCode,'WEB_UNAVAILABLE');
 f=fixture();let cancelledNetwork=0;f.engine.network.cancel=()=>{cancelledNetwork++;};f.engine.pause();assert.equal(cancelledNetwork,1);
 f.state.disabledTools=['web_search'];f.engine.register();assert.equal(f.engine.definitions.find(d=>d.name==='web_search').enabled,false);
 const buttons=['id_global_exp',...Array.from({length:10},(_,i)=>'keyCode_'+i),'keyCode_12','keyCode_16','keyCode_19','keyCode_20','keyCode_21','keyCode_22'];
 const calc=()=>snapshot({children:buttons.map((id,i)=>({attributes:{id,type:'Button',bounds:`[${i*10},100][${i*10+5},200]`,clickable:'true',description:' '}}))},1000,1000);
 let labeled=calc();calculatorLabels(labeled,'com.huawei.hmos.calculator',160100115);assert.equal(labeled.elements.find(e=>e.id==='keyCode_16').text,'C');assert.equal(labeled.elements.find(e=>e.id==='keyCode_12').text,'+');assert.equal(labeled.elements.find(e=>e.id==='keyCode_22').text,'MR');
 labeled=calc();calculatorLabels(labeled,'other.app',160100115);assert.ok(labeled.elements.every(e=>!e.text));
 labeled=calc();calculatorLabels(labeled,'com.huawei.hmos.calculator',999);assert.ok(labeled.elements.every(e=>!e.text));
 labeled=calc();labeled.elements.find(e=>e.id==='keyCode_16').text='原生标签';calculatorLabels(labeled,'com.huawei.hmos.calculator',160100115);assert.equal(labeled.elements.find(e=>e.id==='keyCode_16').text,'原生标签');
})().catch(e=>{console.error(e);process.exitCode=1});
