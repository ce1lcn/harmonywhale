// 0.8.1 小窗回归：紧凑模式判定与时间线、对模型隐形（剔除自身节点、截图隐形策略、灰块遮盖与 SELF_OVERLAP 守卫、注入期间点击穿透且异常也恢复）、
// 小窗内确认（不切回全屏、通知按钮序号）、通知进度、上下文显示（DSH 口径：服务端用量锚点 + 增量估算，不计输出预留）。
const fs=require('fs'),path=require('path'),vm=require('vm'),assert=require('assert/strict');
const ts=require(process.env.HVIGOR_TS||'typescript');
let leaseDelay=180000;
const imageStub={createImageSource:()=>({getImageInfo:async()=>({size:{width:2800,height:1840}}),createPixelMap:async()=>{throw new Error('无图像解码');},release(){}}),createImagePacker:()=>({release(){}})};
const kit={'@kit.NetworkKit':{http:{RequestMethod:{POST:'POST'},HttpDataType:{STRING:1},createHttp:()=>({on(){},off(){},destroy(){}})}},'@kit.BackgroundTasksKit':{backgroundTaskManager:{requestSuspendDelay:()=>({requestId:1,actualDelayTime:leaseDelay}),cancelSuspendDelay(){}}},'@kit.ArkTS':{buffer:{from:(x,e)=>Buffer.from(x,e)},util:{Base64Helper:class{decodeSync(s){return new Uint8Array(Buffer.from(s,'base64'));}encodeToStringSync(b){return Buffer.from(b).toString('base64');}}}},'@kit.CoreFileKit':{fileIo:{OpenMode:{CREATE:1,READ_WRITE:2},openSync:()=>({fd:1}),writeSync(){},closeSync(){}},picker:{}},'@kit.BasicServicesKit':{zlib:{}},'@kit.ImageKit':{image:imageStub},'@kit.AbilityKit':{},'@kit.UniversalKeystoreKit':{},'@kit.CryptoArchitectureKit':{}};
const cache=new Map();function load(file){file=path.resolve(file);if(cache.has(file))return cache.get(file);const module={exports:{}};vm.runInNewContext(ts.transpileModule(fs.readFileSync(file,'utf8'),{compilerOptions:{module:ts.ModuleKind.CommonJS,target:ts.ScriptTarget.ES2020}}).outputText,{module,exports:module.exports,require:n=>n.startsWith('.')?load(path.resolve(path.dirname(file),n+'.ets')):kit[n]??{},setTimeout:(cb,ms)=>(ms??0)>=60000?0:setTimeout(cb,Math.min(ms??0,5)),clearTimeout,queueMicrotask,Uint8Array,ArrayBuffer,Map,Set,Buffer,Date,JSON,Math,Number,Object,Array,String,RegExp,Error,Promise});cache.set(file,module.exports);return module.exports;}
const root='entry/src/main/ets/agent/';
const F=load(root+'FloatPolicy.ets'),T=load(root+'Types.ets'),S=load(root+'Stats.ets'),C=load(root+'CompactTimeline.ets'),{Device,SELF_BUNDLE}=load(root+'Device.ets'),{Engine}=load(root+'Engine.ets');
const same=(a,b)=>assert.equal(JSON.stringify(a),JSON.stringify(b));
const tick=()=>new Promise(r=>setTimeout(r,1));
async function until(fn,limit=400,info=()=>""){for(let i=0;i<limit;i++){if(fn())return;await tick();}throw new Error("等待超时 "+info());}
// 小窗桩：记录调用顺序；可配置截图结果与抛错。
function overlay(opts={}){const log=[];return {log,on:opts.on??true,active(){return this.on;},async beforeCapture(){log.push('before');if(opts.beforeThrows)throw new Error('隐形失败');return opts.state??{strategy:'transparent',hidden:true,masked:false,restoreSelf:false,error:''};},async afterCapture(s){log.push('after:'+s.strategy);},async setTouchable(v){log.push('touch:'+v);if(v===false&&opts.touchThrows)throw new Error('1300002');},windowRect(){return opts.rect??[];}};}
const node=(attrs,children=[])=>({attributes:attrs,children});
const selfWin=node({bundleName:SELF_BUNDLE,abilityName:'ProbeAbility',hostWindowId:'10',bounds:'[1800,200][2700,1600]',type:'root'},[node({hostWindowId:'10',type:'Button',text:'大肥鱼按钮',clickable:'true',bounds:'[1900,300][2100,400]'})]);
const calcWin=node({bundleName:'com.huawei.hmos.calculator',hostWindowId:'11',bounds:'[0,0][2800,1840]',type:'root'},[node({hostWindowId:'11',type:'Button',text:'7',clickable:'true',bounds:'[100,1000][300,1200]'}),node({hostWindowId:'11',type:'Button',text:'8',clickable:'true',bounds:'[2000,1000][2200,1200]'})]);
const screen=node({bounds:'[0,0][2800,1840]'},[selfWin,calcWin]);
const DUMP='AbilityRecord ID 1\n main name [ProbeAbility]\n bundle name ['+SELF_BUNDLE+']\n state #FOREGROUND\nAbilityRecord ID 2\n main name [com.huawei.hmos.calculator.CalculatorAbility]\n bundle name [com.huawei.hmos.calculator]\n state #FOREGROUND\n';
function device(o){const issued=[];const d=new Device({ready:true,execute:async cmd=>{issued.push(cmd);if(o)o.log.push('cmd:'+cmd.split(' ').slice(0,2).join(' '));if(cmd.startsWith('cat '))return JSON.stringify(screen);if(cmd==='aa dump -l')return DUMP;if(cmd.startsWith('toybox base64'))return Buffer.from('jpeg').toString('base64');if(cmd.startsWith('bm dump'))return '{"versionCode":1}';if(cmd.startsWith('aa start'))return 'start ability successfully.';return 'No Error';}},{root:'/tmp'});d.overlay=o??null;d.apps.set('x','y');return {d,issued};}
(async()=>{
 // 1. 紧凑模式判定与策略默认值
 assert.equal(F.isCompactWidth(599),true);assert.equal(F.isCompactWidth(600),false);assert.equal(F.isCompactWidth(0),false);
 // 0.8.1.1 规格变化：真机 V1/V2 不可行，默认改为 V3（privacy）
 assert.equal(F.normalizeStrategy(undefined),'privacy');assert.equal(F.normalizeStrategy('hide'),'hide');assert.equal(F.normalizeStrategy('x'),'privacy');assert.equal(F.DEFAULT_FLOAT_STRATEGY,'privacy');
 // 2. 剔除自身节点：真机 0.8.0.2 布局导出（大肥鱼全屏 + 两个系统窗口）
 const real=JSON.parse(fs.readFileSync('artifacts/ctx-1m-08002-layout.json','utf8'));const r1=F.stripSelf(real,SELF_BUNDLE);
 assert.ok(r1.removed>100);same(r1.rects,[[0,79,2800,1840]]);assert.ok(!JSON.stringify(r1.tree).includes(SELF_BUNDLE));assert.ok(!JSON.stringify(r1.tree).includes('"hostWindowId":"1466"'));assert.equal(r1.tree.children.length,2);
 assert.ok(JSON.stringify(real).includes(SELF_BUNDLE),'原树不被修改');
 const r2=F.stripSelf(screen,SELF_BUNDLE);same(r2.rects,[[1800,200,2700,1600]]);assert.equal(r2.removed,2);assert.ok(JSON.stringify(r2.tree).includes('"text":"7"'));
 // 弹窗等挂在自身窗口编号下、但不在自身根节点里的节点也剔除
 const popup=node({},[selfWin,node({hostWindowId:'10',type:'Dialog',text:'浮层'}),calcWin]);assert.ok(!JSON.stringify(F.stripSelf(popup,SELF_BUNDLE).tree).includes('浮层'));
 // 0.8.1.1：悬浮窗系统标题栏（sceneboard 单独成窗，真机 0.8.1 布局 artifacts/now-0810.json）一并剔除，矩形计入遮盖区域；不相邻的 sceneboard 窗口保留
 const decor=node({bundleName:'com.ohos.sceneboard',hostWindowId:'12',type:'WindowScene',bounds:'[1800,121][2700,185]'},[node({hostWindowId:'12',type:'Button',id:'floatingButtonClose',clickable:'true',bounds:'[2640,130][2690,180]'})]);
 const otherDecor=node({bundleName:'com.ohos.sceneboard',hostWindowId:'13',type:'WindowScene',bounds:'[100,121][900,185]'},[node({hostWindowId:'13',type:'Button',id:'floatingButtonClose',clickable:'true',bounds:'[840,130][890,180]'})]);
 const rd=F.stripSelf(node({bounds:'[0,0][2800,1840]'},[selfWin,decor,otherDecor,calcWin]),SELF_BUNDLE);same(rd.rects,[[1800,200,2700,1600],[1800,121,2700,185]]);assert.equal(rd.removed,4);assert.ok(!JSON.stringify(rd.tree).includes('"hostWindowId":"12"'));assert.ok(JSON.stringify(rd.tree).includes('"hostWindowId":"13"'));
 const realFloat=JSON.parse(fs.readFileSync('artifacts/now-0810.json','utf8'));const rf=F.stripSelf(realFloat,SELF_BUNDLE);assert.ok(!JSON.stringify(rf.tree).includes('floatingButtonClose'));assert.ok(!JSON.stringify(rf.tree).includes(SELF_BUNDLE));assert.ok(JSON.stringify(rf.tree).includes('com.huawei.hmos.calculator'));assert.equal(rf.rects.length,2);
 // 3. 前台应用：小窗时取下层应用
 assert.equal(F.foregroundBundle(DUMP,SELF_BUNDLE,true),'com.huawei.hmos.calculator');assert.equal(F.foregroundBundle(DUMP,SELF_BUNDLE,false),SELF_BUNDLE);assert.equal(F.foregroundAbility(DUMP,'com.huawei.hmos.calculator'),'com.huawei.hmos.calculator.CalculatorAbility');
 // 0.8.1.1：真机 aa dump（artifacts/s1-aa-dump-0810.txt）中 WPS 后台 Ability 停在 FOREGROUND 且排在前面；有可见窗口的优先
 const realDump=fs.readFileSync('artifacts/s1-aa-dump-0810.txt','utf8');assert.equal(F.foregroundBundle(realDump,SELF_BUNDLE,true),'cn.wps.office.hap','旧行为（无可见窗口信息）');
 same(F.windowBundles(realFloat),['com.harmonyloom.selfhdcprobe','com.ohos.sceneboard','com.huawei.hmos.calculator']);
 assert.equal(F.foregroundBundle(realDump,SELF_BUNDLE,true,F.windowBundles(realFloat)),'com.huawei.hmos.calculator');assert.equal(F.foregroundBundle(realDump,SELF_BUNDLE,false,[SELF_BUNDLE,'com.ohos.sceneboard']),SELF_BUNDLE);
 // 4. 点击穿透：注入前后切换，成功、失败、异常都恢复
 let o=overlay();let out=await F.passThrough(o,async()=>{o.log.push('run');return 7;});assert.equal(out,7);same(o.log,['touch:false','run','touch:true']);
 o=overlay();await assert.rejects(()=>F.passThrough(o,async()=>{o.log.push('run');throw new Error('注入失败');}),/注入失败/);same(o.log,['touch:false','run','touch:true']);
 o=overlay({touchThrows:true});await F.passThrough(o,async()=>{o.log.push('run');});same(o.log,['touch:false','run','touch:true']);
 o=overlay();o.on=false;await F.passThrough(o,async()=>{o.log.push('run');});same(o.log,['run']);
 // 5. 截图隐形：截图抛错也恢复；隐形本身失败 → 兜底遮盖
 o=overlay();await assert.rejects(()=>F.captureHidden(o,async()=>{throw new Error('截图失败');}),/截图失败/);same(o.log,['before','after:transparent']);
 o=overlay({beforeThrows:true});const st=await F.captureHidden(o,async s=>s);assert.equal(st.masked,true);assert.equal(st.hidden,false);same(o.log,['before','after:privacy']);// 0.8.1.1：失败时按默认策略（V3）恢复
 same(F.clipRects([[-10,5,3000,1900],[5,5,5,9]],2800,1840),[[0,5,2800,1840]]);assert.match(F.overlapNote([[1800,200,2700,1600]],2800,1840),/\[643,109,965,870\].*SELF_OVERLAP/);
 // 6. Device：小窗时注入命令被点击穿透包裹；aa start 与只读命令不切换触摸
 o=overlay();let {d,issued}=device(o);await d.command('uitest uiInput click 1 1');await d.command('aa start -b x -a y');await d.command('aa dump -l');same(o.log.filter(v=>v.startsWith('touch')),['touch:false','touch:true']);assert.equal(d.mutationCount,2);
 // 非小窗：不调用任何小窗接口
 o=overlay();o.on=false;({d}=device(o));await d.command('uitest uiInput click 1 1');same(o.log.filter(v=>v.startsWith('touch')),[]);
 // 7. Device.observe：V1 成功 → 截图前隐形、截图后恢复、布局无自身节点、无遮盖
 o=overlay();({d,issued}=device(o));let obs=await d.observe();assert.ok(o.log.indexOf('before')<o.log.findIndex(v=>v==='cmd:snapshot_display -f')&&o.log.findIndex(v=>v==='cmd:snapshot_display -f')<o.log.indexOf('after:transparent'));
 assert.ok(!obs.layout.includes('大肥鱼按钮'));assert.ok(obs.layout.includes('"text":"7"'));assert.ok(!obs.layout.includes('SELF_OVERLAP'));assert.equal(d.lastMasked,false);same(d.selfRects,[[1800,200,2700,1600]]);
 // V1 成功时点击小窗下方的位置照常执行（依赖点击穿透），不触发守卫
 assert.match(await d.execute('click',{x:800,y:300}),/No Error/);
 // 8. 隐形失败（或 V3 黑块）→ 灰块遮盖提示 + SELF_OVERLAP 守卫；小窗外的点照常
 o=overlay({state:{strategy:'privacy',hidden:false,masked:true,restoreSelf:false,error:''}});({d,issued}=device(o));obs=await d.observe();assert.match(obs.layout,/被大肥鱼的小窗挡住.*SELF_OVERLAP/);assert.equal(d.lastMasked,true);
 const before=d.mutationCount;await assert.rejects(()=>d.execute('click',{x:800,y:300}),e=>e.code==='SELF_OVERLAP');assert.equal(d.mutationCount,before,'被挡住时不注入');
 await assert.rejects(()=>d.execute('swipe',{x:100,y:500,x2:800,y2:300}),e=>e.code==='SELF_OVERLAP');
 assert.match(await d.execute('click',{x:100,y:600}),/No Error/);
 // 动作目标与前台判定取下层应用
 const target=await d.actionTarget('click',{x:100,y:600});assert.equal(target.app,'com.huawei.hmos.calculator');assert.equal(target.ability,'com.huawei.hmos.calculator.CalculatorAbility');assert.equal(target.label,'7');
 // 9. V2（最小化）：截图后切回大肥鱼
 o=overlay({state:{strategy:'hide',hidden:true,masked:false,restoreSelf:true,error:''}});({d,issued}=device(o));await d.observe();assert.ok(issued.some(c=>c.startsWith('aa start -b '+SELF_BUNDLE)));
 // 非小窗：布局不剔除（任务需要操作大肥鱼自身时仍能看见），也无隐形调用
 o=overlay();o.on=false;({d}=device(o));obs=await d.observe();assert.ok(obs.layout.includes('大肥鱼按钮'));same(o.log.filter(v=>v==='before'),[]);
 // restoreApproval inPlace：不重新启动目标应用
 ({d,issued}=device(overlay()));const t2=await d.actionTarget('click',{x:100,y:600});const n0=issued.length;await d.restoreApproval(t2,{},true);assert.ok(!issued.slice(n0).some(c=>c.startsWith('aa start')));
 ({d,issued}=device(overlay()));const n1=issued.length;await d.restoreApproval(t2,{},false);assert.ok(issued.slice(n1).some(c=>c.startsWith('aa start -b com.huawei.hmos.calculator')));
 // 10. Engine：小窗内确认不切回全屏；通知按钮按序号生效
 function engineFixture(floatOn){const state=T.defaults(),calls=[],notes=[];const ov=overlay();ov.on=floatOn;const dev={mutationCount:0,hdc:{ready:true},overlay:ov,active:()=>true,invalidate(){},sensitive:()=>false,observe:async()=>({snapshotId:'s1',layout:'屏幕',image:'',width:0,height:0,fingerprint:'x'}),bringSelf:async()=>true,showApproval:async()=>{calls.push('showApproval');}};const engine=new Engine(state,{save(){},secret:async()=>'k'},dev,()=>{});engine.foreground=floatOn;engine.notifier={progress:t=>notes.push(['progress',t]),approval:(s,t,f)=>notes.push(['approval',s,f]),clearApproval:()=>notes.push(['clear']),finished:t=>notes.push(['finished',t])};return {engine,calls,notes,state};}
 const NB=F.NotifyBridge;
 let e=engineFixture(true);let step=0;e.engine.model.next=async()=>{step++;return step===1?{text:'',calls:[{id:'c1',name:'request_confirmation',arguments:JSON.stringify({text:'在 微信 里点击「发送」'})}]}:{text:'好了',calls:[]};};
 let run=e.engine.start('发消息');await until(()=>!!e.engine.approval,400,()=>JSON.stringify([e.engine.current?.status,e.engine.current?.reason,e.engine.current?.records]));same(e.calls,[]);assert.equal(e.engine.foreground,true);assert.equal(e.engine.lease,-1);assert.equal(e.engine.approvalInFloat,true);same(e.notes.find(n=>n[0]==='approval'),['approval',1,true]);
 NB.dispatch('yes',99);await tick();assert.ok(e.engine.approval,'旧序号不生效');NB.dispatch('yes',1);await run;assert.equal(e.engine.current.status,'completed');assert.ok(e.notes.some(n=>n[0]==='clear'));assert.equal(e.engine.current.records[0].result,'用户同意此项具体操作');
 e=engineFixture(false);step=0;e.engine.model.next=async()=>{step++;return step===1?{text:'',calls:[{id:'c1',name:'request_confirmation',arguments:JSON.stringify({text:'删除'})}]}:{text:'不做了',calls:[]};};
 run=e.engine.start('删东西');await until(()=>!!e.engine.approval,400,()=>JSON.stringify([e.engine.current?.status,e.engine.current?.reason,e.engine.current?.records]));same(e.calls,['showApproval']);same(e.notes.find(n=>n[0]==='approval'),['approval',1,false]);NB.dispatch('no',1);await run;assert.match(e.engine.current.records[0].result,/拒绝/);
 // 11. 通知进度：运行中且不在前台才发；节流；暂停时留一条，完成时清除
 e=engineFixture(false);e.engine.model.next=async()=>{e.engine.current.currentAction='点击「发送」';e.engine.save();return {text:'完成',calls:[]};};await e.engine.start('后台任务');
 const prog=e.notes.filter(n=>n[0]==='progress');assert.ok(prog.length>=1);assert.match(prog[0][1],/^大肥鱼 · 第 0 步/);same(e.notes[e.notes.length-1],['finished','']);
 assert.equal(F.progressText({calls:12,currentAction:'正在点击「发送」'}),'大肥鱼 · 第 12 步 · 正在点击「发送」');assert.equal(F.shouldNotifyProgress(true,true),false);assert.equal(F.shouldNotifyProgress(true,false),true);
 e=engineFixture(true);e.engine.model.next=async()=>({text:'前台',calls:[]});await e.engine.start('前台任务');assert.equal(e.notes.filter(n=>n[0]==='progress').length,0);
 e=engineFixture(false);e.engine.model.next=async()=>{throw new Error('我先停一下：测试');};await e.engine.start('暂停任务');same(e.notes[e.notes.length-1],['finished','大肥鱼已暂停 · 我先停一下：测试']);
 // 12. 上下文显示（DSH 口径）：新会话接近 0%；有服务端用量后 = 提示 token + 之后新增估算；不计输出预留；压缩后退回估算
 e=engineFixture(true);let ctx=e.engine.contextStats(e.engine.session());assert.ok(ctx.output>=256000);assert.equal(ctx.served,undefined);assert.ok(S.contextPercent(ctx)<=1,'新会话 '+S.contextPercent(ctx)+'%');assert.equal(S.contextUsed(ctx),ctx.total-ctx.output);
 e.engine.model.next=async()=>{e.engine.model.onUsage({input:3000,cacheRead:47000,cacheWrite:0,output:200,total:50200,calls:1,model:'x'});return {text:'回答',calls:[]};};await e.engine.start('问个问题');
 const anchor=e.engine.session().contextAnchor;assert.equal(anchor.prompt,50000);assert.ok(anchor.estimate>0);
 ctx=e.engine.contextStats(e.engine.session());assert.equal(ctx.served,50000);assert.equal(S.contextUsed(ctx),50000+ctx.delta);assert.ok(ctx.delta>0,'回答与下一轮内容按估算增加');assert.equal(S.contextPercent(ctx),Math.round((50000+ctx.delta)*100/1000000));
 same(S.anchoredStats({system:1,tools:1,messages:8,images:0,output:5,total:15,window:100,time:0},{prompt:40,estimate:12,time:0}).used,38);
 same(S.anchoredStats({system:1,tools:1,messages:8,images:0,output:5,total:15,window:100,time:0},undefined).used,10);
 assert.equal(S.contextLabel(S.anchoredStats({system:1,tools:1,messages:8,images:0,output:90,total:100,window:100,time:0},undefined)),'10%');
 // 压缩成功后锚点作废，退回估算
 e.engine.model.compactConversation=async()=>'摘要';e.engine.session().messages.push(...Array.from({length:30},(_,i)=>({role:i%2?'assistant':'user',text:'很长的旧内容'.repeat(400),time:Date.now()+i})));await e.engine.compress();assert.equal(e.engine.session().contextAnchor,undefined);
 // 13. 紧凑时间线：只显示当前任务；思考默认展开最近一条；超出折叠计数
 const sess={id:'s',title:'t',messages:[{role:'user',text:'旧任务',time:1,taskId:'a'},{role:'user',text:'新任务',time:10,taskId:'b'},{role:'assistant',text:'先看看',time:11,taskId:'b',providerReasoning:'想一想',toolCallId:'r1'}],tasks:[{id:'a',records:[],calls:0,status:'completed'},{id:'b',records:[{id:'r1',name:'click',args:'{}',result:'ok',status:'success',time:12,targetLabel:'发送',providerReasoning:'再想想'},{id:'r2',name:'observe',args:'{}',result:'',status:'pending',time:13}],calls:2,status:'running'}]};
 const cv=C.compactView(sess);same(cv.rows.map(r=>r.kind),['user','think','assistant','think','tool','tool']);assert.ok(!cv.rows.some(r=>r.text==='旧任务'));assert.equal(cv.latestThink,'k:r1');assert.equal(cv.rows[4].text,'点击「发送」');assert.equal(C.toolMark('success'),'✓');
 const small=C.compactView(sess,3);assert.equal(small.hidden,3);assert.equal(small.rows.length,3);
 console.log('PASS: compact width/timeline, strip self nodes (real dump), foreground of underlying app, touch pass-through restored on error, capture hide/restore, mask note + SELF_OVERLAP guard, V2 restore, in-place approval, float confirmation without full screen, notification serials/progress, DSH context usage (served anchor + delta, no output reserve, new session ~0%)');
})().catch(e=>{console.error(e);process.exit(1);});
