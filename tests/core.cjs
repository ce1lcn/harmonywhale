const fs=require('fs'),vm=require('vm'),path=require('path'),assert=require('assert/strict');
const ts=require(process.env.HVIGOR_TS||'typescript');
const cache=new Map();let response={choices:[{finish_reason:'stop',message:{content:'完成',tool_calls:[]}}]},payload;let leaseCallback;let leaseDelay=180000;const crypto=require('crypto');
const kit={
 '@kit.BackgroundTasksKit':{backgroundTaskManager:{requestSuspendDelay:(r,cb)=>{leaseCallback=cb;return {requestId:1,actualDelayTime:leaseDelay};},cancelSuspendDelay(){}}},
 '@kit.NetworkKit':{http:{RequestMethod:{POST:'POST'},HttpDataType:{STRING:1},createHttp:()=>({destroy(){},request:async(url,opt)=>{payload=JSON.parse(opt.extraData);return {responseCode:200,result:JSON.stringify(response),header:{}};}})}},
 '@kit.CoreFileKit':{fileIo:{},picker:{}},'@kit.BasicServicesKit':{zlib:{}},'@kit.ImageKit':{},'@kit.AbilityKit':{},'@kit.UniversalKeystoreKit':{},'@kit.CryptoArchitectureKit':{},'@kit.ArkTS':{buffer:{from:(x,e)=>Buffer.from(x,e)},util:{}}
};
function load(file){file=path.resolve(file);if(cache.has(file))return cache.get(file);const module={exports:{}};const source=fs.readFileSync(file,'utf8');const js=ts.transpileModule(source,{compilerOptions:{module:ts.ModuleKind.CommonJS,target:ts.ScriptTarget.ES2020}}).outputText;vm.runInNewContext(js,{module,exports:module.exports,require:n=>n.startsWith('.')?load(path.resolve(path.dirname(file),n+'.ets')):kit[n],setTimeout:(cb,ms)=>ms>5000?0:setTimeout(cb,0),clearTimeout,Uint8Array,ArrayBuffer,Map,Buffer});cache.set(file,module.exports);return module.exports;}
const root='entry/src/main/ets/agent/';
(async()=>{
 const {rpcBody,Mcp}=load(root+'Mcp.ets');assert.equal(rpcBody('event: message\ndata: {"id":2,"result":{"tools":[]}}\n\n',2).id,2);assert.throws(()=>rpcBody('data: bad\n\n',2));
 const {safePath,inspectZip}=load(root+'Skills.ets');for(const p of ['../x','/x','a/../x','a\\b','C:x'])assert.equal(safePath(p),false);assert.equal(safePath('references/guide.md'),true);assert.throws(()=>inspectZip(new Uint8Array([80,75])));
 const {Model}=load(root+'Model.ets');const {defaults}=load(root+'Types.ets');const profile=defaults().profiles[0];const model=new Model();await model.request(profile,'fixture',[{role:'user',content:'test'}]);assert.equal(payload.thinking.type,'enabled');assert.equal(payload.reasoning_effort,'high');assert.equal(payload.max_tokens,256000);/* 0.8.0.2：思考默认开、强度 high、输出 256000（DSH） */
 response={choices:[{finish_reason:'length',message:{content:'{"unfinished"'}}]};const partial=await model.request(profile,'fixture',[]);assert.equal(partial.incomplete,true);assert.equal(partial.calls.length,0);response={choices:[{finish_reason:'stop',message:{content:''}}]};await assert.rejects(()=>model.request(profile,'fixture',[]),/空回复/);
 response={choices:[{finish_reason:'tool_calls',message:{content:'点击',tool_calls:[{id:'a',type:'function',function:{name:'click',arguments:'{"x":500,"y":500}'}}]}}]};const decision=await model.request(profile,'fixture',[]);assert.equal(decision.calls[0].name,'click');assert.equal(decision.text,'点击');
 const {Engine}=load(root+'Engine.ets');function fixture(){let writes=0,actions=[];const state=defaults(),store={save(){writes++;},secret:async()=> 'fixture'},device={sensitive:()=>false,invalidate(){},stable:async()=>{},mutationCount:0,hdc:{ready:true},observe:async()=>({layout:'screen',fingerprint:'fixed',image:'',width:2800,height:1840}),execute:async(name,a)=>{actions.push(name);return 'No Error';},reconnect:async()=>{throw new Error('模拟断线');}};const engine=new Engine(state,store,device,()=>{});const start=engine.start.bind(engine);engine.start=(goal,mode)=>start(goal,mode??'device');return {engine,state,actions,get writes(){return writes;}};}
 const {ProgressGuard,stableFingerprint}=load(root+'Progress.ets');
 assert.equal(stableFingerprint('{"text":"19:15"}\n{"text":"7"}'),stableFingerprint('{"text":"19:16"}\n{"text":"7"}'));
 assert.notEqual(stableFingerprint('{"text":"7"}'),stableFingerprint('{"text":"8"}'));
 assert.equal(stableFingerprint('{"text":"19","normalizedCenter":[10,12]}\n{"text":"32","normalizedCenter":[20,12]}\n{"text":"7","normalizedCenter":[500,500]}'),stableFingerprint('{"text":"19","normalizedCenter":[10,12]}\n{"text":"33","normalizedCenter":[20,12]}\n{"text":"7","normalizedCenter":[500,500]}'));
 const cyclic=new ProgressGuard();for(const step of ['clear|7','seven|empty','clear|7','seven|empty','clear|7'])cyclic.check(step);assert.throws(()=>cyclic.check('seven|empty'),/循环/);
 const progressing=new ProgressGuard();for(let j=0;j<30;j++)progressing.check('click|screen-'+j);
 const {SYSTEM_PROMPT}=load(root+'Prompt.ets');assert.match(SYSTEM_PROMPT,/No Error 只证明命令已发出/);assert.match(SYSTEM_PROMPT,/不把表达式输入到不可编辑显示区域/);
 let f=fixture(),n=0;f.engine.model.next=async()=>++n===1?{text:'',calls:[{id:'1',name:'home',arguments:'{}'}]}:{text:'完成',calls:[]};await f.engine.start('返回桌面');assert.deepEqual(f.actions,['home']);assert.equal(f.engine.current.status,'completed');assert.equal(f.engine.current.outcome,'done');assert.ok(f.writes>3);assert.equal(f.engine.current.records[0].status,'success');
 f=fixture();f.engine.model.next=async()=>{f.engine.pause();return {text:'',calls:[{id:'2',name:'home',arguments:'{}'}]};};await f.engine.start('任务');assert.equal(f.actions.length,0);assert.equal(f.engine.current.status,'paused');
 f=fixture();f.engine.model.next=async()=>{leaseCallback();return {text:'',calls:[{id:'3',name:'home',arguments:'{}'}]};};await f.engine.start('任务');assert.equal(f.actions.length,0);assert.equal(f.engine.current.status,'paused');
 f=fixture();let i=0;f.engine.model.next=async()=>({text:'',calls:[{id:String(++i),name:'click',arguments:'{"x":50,"y":50}'}]});await f.engine.start('重复任务');assert.equal(f.actions.length,2);assert.match(f.engine.current.reason,/没有进展/);
 f=fixture();let cycleRound=0;f.engine.device.observe=async()=>({layout:'screen',fingerprint:cycleRound%2?'digit7':'empty',image:'',width:2800,height:1840});f.engine.model.next=async()=>({text:'',calls:[{id:String(++cycleRound),name:'click',arguments:cycleRound%2?'{"x":50,"y":50}':'{"x":60,"y":60}'}]});await f.engine.start('交替清空输入');assert.equal(f.actions.length,5);assert.match(f.engine.current.reason,/循环/);
 f=fixture();let supplemented=false;f.engine.model.next=async()=>{if(!supplemented){supplemented=true;f.engine.supplement('改为返回桌面');return {text:'旧要求',calls:[{id:'old',name:'home',arguments:'{}'}]};}return {text:'已采纳',calls:[]};};await f.engine.start('原任务');assert.equal(f.engine.current.constraints[0],'改为返回桌面');assert.equal(f.actions.length,0);
 f=fixture();f.engine.device.hdc.ready=false;await f.engine.start('任务');assert.equal(f.engine.current.status,'paused');assert.equal(f.actions.length,0);

 // Exercise the real device wrapper, including pause between replace-text commands.
 const {Device}=load(root+'Device.ets');let issued=[];const device=new Device({execute:async command=>{issued.push(command);if(issued.length===1)device.active=()=>false;return 'No Error';}},{});
 await assert.rejects(()=>device.execute('click',{x:1001,y:20}),/坐标/);assert.equal(issued.length,0);
 await assert.rejects(()=>device.execute('replace_text',{x:50,y:50,text:'fixture'}),/暂停/);assert.equal(issued.length,1);
 // Real calculator layout: verbose native attributes used to consume the entire
 // observation budget before digit and operator labels were reached.
 const calculator=JSON.parse(fs.readFileSync('artifacts/unplug045-observed.json','utf8'));
 const nodes=[];device.walk(calculator,nodes);const compactLayout=nodes.join('\n');
 assert.ok(compactLayout.length<16000);for(const label of ['7','8','9'])assert.ok(nodes.some(line=>JSON.parse(line).text===label), 'missing calculator label '+label);
 assert.ok(nodes.every(line=>!line.includes('hierarchy')));
 const seven=nodes.map(line=>JSON.parse(line)).find(item=>item.text==='7');assert.equal(seven.normalizedCenter.length,2);
 // Retain constraints through compression and stop on a failed summary.
 f=fixture();let rounds=0;f.engine.state.profiles[0].contextWindow=32768;f.engine.model.compact=async(p,k,t)=>{assert.equal(t.constraints[0],'保留重要约束');return '已压缩，保留重要约束';};
 f.engine.model.next=async()=>{if(rounds++===0)f.engine.supplement('保留重要约束');if(rounds>25)return {text:'完成',calls:[]};return {text:'',calls:[{id:'ctx'+rounds,name:'home',arguments:'{}'}]};};
 f.engine.device.observe=async()=>({layout:'screen',fingerprint:String(rounds),image:'latest',width:2800,height:1840});f.engine.device.execute=async()=> 'x'.repeat(6000);await f.engine.start('任务');assert.match(f.engine.current.summary,/重要约束/);assert.equal(f.engine.current.constraints[0],'保留重要约束');
 f=fixture();rounds=0;f.engine.device.observe=async()=>({layout:'screen',fingerprint:String(rounds),image:'',width:2800,height:1840});f.engine.model.next=async()=>({text:'',calls:[{id:String(++rounds),name:'home',arguments:'{}'}]});await f.engine.start('任务');assert.equal(f.actions.length,200);assert.equal(f.engine.current.status,'paused');assert.match(f.engine.current.reason,/200/);f.engine.model.next=async()=>({text:'',calls:[{id:'finish-resumed',name:'finish_task',arguments:'{"outcome":"blocked","reply":"验证恢复预算"}'}]});await f.engine.start();assert.equal(f.engine.current.calls,201);assert.equal(f.engine.current.segmentCalls,1);
 f=fixture();f.engine.model.next=async()=>({text:'',calls:[{id:'bad',name:'click',arguments:'{}'}]});await f.engine.start('任务');assert.equal(f.actions.length,0);assert.match(f.engine.current.reason,/连续六次/);assert.equal(f.engine.current.records.length,6);
 // A pending action remains uncertain when cancellation arrives before its result.
 f=fixture();f.engine.model.next=async()=>({text:'',calls:[{id:'cancel',name:'home',arguments:'{}'}]});f.engine.device.execute=async()=>{f.engine.pause('用户取消',true);return 'No Error';};await f.engine.start('任务');assert.equal(f.engine.current.status,'cancelled');assert.equal(f.engine.current.records[0].status,'uncertain');

 const state=defaults(),task={id:'ctx',goal:'目标',constraints:['保留约束'],summary:'摘要',records:Array.from({length:12},(_,i)=>({id:'tool'+i,name:'home',args:'{}',result:'No Error',status:'success',time:i,observation:'old',providerReasoning:'opaque-'+i})),calls:12,reason:'',status:'paused'};
 state.sessions[0].messages.push({role:'assistant',text:'STALE_STEP_DO_NOT_RESEND',time:1});
 const thinkProfile={...profile,thinking:'enabled'};await model.next(thinkProfile,'fixture',state.sessions[0],task,{layout:'最新布局',image:'LATEST_ONLY',width:2800,height:1840},[],'');
 assert.ok(!JSON.stringify(payload).includes('STALE_STEP_DO_NOT_RESEND'));const assistants=payload.messages.filter(m=>m.role==='assistant');assert.equal(assistants.length,12);assert.equal(assistants[0].reasoning_content,'opaque-0');assert.equal(JSON.stringify(payload).split('data:image/jpeg;base64,').length-1,1);assert.match(JSON.stringify(payload),/保留约束/);

 f=fixture();f.engine.device.hdc.ready=false;let connected=0;f.engine.device.reconnect=async()=>{connected++;f.engine.device.hdc.ready=true;};f.engine.model.next=async()=>({text:'重新观察后完成',calls:[]});await f.engine.start('任务');assert.equal(connected,1);assert.equal(f.engine.current.status,'completed');assert.equal(f.actions.length,0);

 f=fixture();let order=0;f.engine.model.next=async()=>({text:'',calls:[{id:String(++order),name:'click',arguments:order%2?'{"x":50,"y":50}':'{"y":50,"x":50}'}]});await f.engine.start('任务');assert.equal(f.actions.length,2);assert.match(f.engine.current.reason,/没有进展/);
 f=fixture();f.engine.confirm=async()=>false;f.engine.model.next=async()=>({text:'',calls:[{id:'deny',name:'request_confirmation',arguments:'{"text":"发送一条消息"}'}]});await f.engine.start('任务');assert.equal(f.actions.length,0);assert.equal(f.engine.current.status,'paused');assert.match(f.engine.current.reason,/拒绝/);

 leaseDelay=0;f=fixture();let asked=false;f.engine.model.next=async()=>{asked=true;return {text:'不应执行',calls:[]};};await f.engine.start('任务');assert.equal(asked,false);assert.equal(f.engine.current.status,'paused');assert.match(f.engine.current.reason,/后台额度/);assert.equal(f.actions.length,0);leaseDelay=180000;
 console.log('PASS: real model boundary, SSE JSON-RPC, path limits, durable action records, pause, background expiry, steering, no-progress and disconnect guards');
})().catch(e=>{console.error(e);process.exitCode=1;});

