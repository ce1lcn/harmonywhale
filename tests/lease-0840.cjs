// 0.8.4 A1：全屏后台租约续租。用脚本化模型驱动真实 Engine，设备用桩；租约与续租定时器在测试里不会自然触发（>5 s 的定时器被桩吞掉），
// 所以用直接设置 leaseDeadline 与调用 onRenewWindow 的办法模拟“离到期不足 60 秒”。
const fs=require('fs'),vm=require('vm'),path=require('path'),os=require('os'),assert=require('assert/strict');
const ts=require(process.env.HVIGOR_TS||'typescript');
const scratch=fs.mkdtempSync(path.join(os.tmpdir(),'whale-lease-0840-'));
const cache=new Map();
let leaseCalls=0,leaseDelay=180000,leaseThrows=false;
const kit={
 '@kit.BackgroundTasksKit':{backgroundTaskManager:{requestSuspendDelay:()=>{leaseCalls++;if(leaseThrows)throw new Error('quota');return {requestId:leaseCalls,actualDelayTime:leaseDelay};},cancelSuspendDelay(){}}},
 '@kit.NetworkKit':{http:{RequestMethod:{POST:'POST'},HttpDataType:{STRING:1},createHttp:()=>({destroy(){},request:async()=>({responseCode:500,result:'',header:{}})})}},
 '@kit.CoreFileKit':{fileIo:{OpenMode:{},accessSync:()=>false,mkdirSync(){},statSync:()=>({size:0})},picker:{}},
 '@kit.BasicServicesKit':{zlib:{},pasteboard:{}},'@kit.ArkTS':{buffer:Buffer,util:{}},'@kit.AbilityKit':{},'@kit.ImageKit':{},'@kit.CryptoArchitectureKit':{},'@kit.UniversalKeystoreKit':{}
};
function load(file){file=path.resolve(file);if(cache.has(file))return cache.get(file);const module={exports:{}};const js=ts.transpileModule(fs.readFileSync(file,'utf8'),{compilerOptions:{module:ts.ModuleKind.CommonJS,target:ts.ScriptTarget.ES2020}}).outputText;vm.runInNewContext(js,{module,exports:module.exports,require:n=>n.startsWith('.')?load(path.resolve(path.dirname(file),n+'.ets')):kit[n],setTimeout:(cb,ms)=>ms>5000?0:setTimeout(cb,0),clearTimeout,Uint8Array,ArrayBuffer,Map,Buffer,Date,JSON,RegExp,Promise,Math,Number,Object,Array,String,Error});cache.set(file,module.exports);return module.exports;}
const root='entry/src/main/ets/agent/';
const T=load(root+'Types.ets');const {Engine}=load(root+'Engine.ets');
const NOTEPAD={bundle:'com.huawei.hmos.notepad',ability:'EntryAbility'};
function makeDevice(engineRef,opts={}){
 const log=[];
 const device={log,hdc:{ready:true},width:2800,height:1840,mutationCount:0,latest:null,invalidate(){},sensitive:()=>false,stable:async()=>{log.push('stable');},reconnect:async()=>{},overlay:null};
 device.observe=async()=>({layout:'screen',snapshotId:'s',image:'',width:2800,height:1840,fingerprint:'fp'});
 device.execute=async()=> 'No Error';
 device.installedApps=async()=>({list:[],note:''});
 device.leaseTarget=async()=>{log.push('target');return opts.noTarget?null:NOTEPAD;};
 device.bringSelf=async()=>{log.push('self');if(opts.selfFails)return false;engineRef.e.setForeground(true);return true;};
 device.returnToApp=async(t)=>{log.push('return:'+t.bundle);if(opts.returnFails)return false;if(!opts.stayForeground)engineRef.e.setForeground(false);return true;};
 return device;
}
function build(opts){
 const ref={e:null};const state=T.defaults();state.skills=[];if(opts&&opts.disable)state.leaseRenew=false;
 const store={root:scratch,read:p=>fs.readFileSync(p,'utf8'),save(){},secret:async()=>'x'};
 const device=makeDevice(ref,opts||{});const engine=new Engine(state,store,device,()=>{});ref.e=engine;
 return {engine,device,state};
}
const calls=(name,args,id)=>({text:'',calls:[{id:id,name:name,arguments:JSON.stringify(args)}]});
const done=(t)=>({text:t,calls:[]});
const near=(e,ms=30000)=>{e.leaseDeadline=Date.now()+ms;};
let finished=false;process.on('exit',()=>{if(!finished&&!process.exitCode){console.error('测试没有跑完就退出（有 promise 永远不返回）');process.exitCode=1;}});
(async()=>{
 const P=load(root+'ExecutionPolicy.ets');
 assert.equal(P.LEASE_RENEW_LEAD,60000);assert.equal(P.LEASE_RENEW_MAX,30);

 // 1. 步骤边界续租：离到期 30 秒，下一轮开头先续租（回大肥鱼 → 回备忘录 → 新租约），任务不暂停
 let f=build();let steps=[(t)=>{near(f.engine);return calls('observe',{},'o1');},()=>done('完成')];let i=0;
 f.engine.model.next=async()=>steps[Math.min(i++,steps.length-1)]();
 const before=leaseCalls;
 await f.engine.start('在备忘录里滚动','auto');
 let task=f.engine.current;
 assert.equal(task.status,'completed',task.reason);
 assert.equal(task.leaseRenewals,1);assert.ok(task.leaseRenewMs>=0);
 assert.deepEqual(f.device.log.filter(x=>x!=='stable'),['target','self','return:com.huawei.hmos.notepad','target','self'],'续租四步，最后一个 self 是任务结束后回到大肥鱼（既有行为）');
 assert.equal(leaseCalls-before,2,'start 一次、续租一次');
 assert.ok(!f.engine.session().messages.some(m=>/回到前台/.test(m.text)),'没有“回到前台”暂停提示');
 assert.ok(f.engine.session().messages.some(m=>/后台时间提示/.test(m.text)),'进入后台时给过一次提示');

 // 2. 模型思考期间续租（定时器到点时没有设备动作在途）
 f=build();i=0;
 f.engine.model.next=async()=>{if(i++===0){f.engine.current.deviceUsed=true;near(f.engine);f.engine.onRenewWindow(f.engine.generation,f.engine.leaseSerial);await new Promise(r=>setTimeout(r,60));}return done('思考完毕');};
 await f.engine.start('长时间思考','auto');
 task=f.engine.current;assert.equal(task.status,'completed',task.reason);assert.equal(task.leaseRenewals,1);

 // 3. 续租失败：前台不是普通应用 → 如实暂停并回到大肥鱼（旧行为的变体，带原因）
 f=build({noTarget:true});i=0;steps=[()=>{near(f.engine);return calls('observe',{},'o1');},()=>done('不该到这里')];
 f.engine.model.next=async()=>steps[Math.min(i++,steps.length-1)]();
 await f.engine.start('x','auto');
 task=f.engine.current;assert.equal(task.status,'paused');assert.match(task.reason,/续租没有成功|续租/);assert.match(task.reason,/不知道该回到哪里/);
 // 3b. 切回大肥鱼失败 / 回不到目标 / 回去后大肥鱼仍在前台
 for(const [opt,re] of [[{selfFails:true},/没能切回大肥鱼/],[{returnFails:true},/没能回到/],[{stayForeground:true},/大肥鱼仍在前台/]]){
  f=build(opt);i=0;steps=[()=>{near(f.engine);return calls('observe',{},'o1');},()=>done('不该到这里')];f.engine.model.next=async()=>steps[Math.min(i++,steps.length-1)]();
  await f.engine.start('x','auto');task=f.engine.current;assert.equal(task.status,'paused',JSON.stringify(opt));assert.match(task.reason,re);
 }

 // 3c. 0.8.4.1：页面稳定检查失败（真机上长笔记的布局读取超时）不应让已经成功的续租判失败
 f=build();i=0;steps=[()=>{near(f.engine);return calls('observe',{},'o1');},()=>done('完成')];f.engine.model.next=async()=>steps[Math.min(i++,steps.length-1)]();
 f.device.stable=async()=>{throw new Error('页面稳定检查布局读取失败：Command timeout');};
 await f.engine.start('x','auto');task=f.engine.current;assert.equal(task.status,'completed',task.reason);assert.equal(task.leaseRenewals,1);

 // 4. 关闭续租：沿用旧行为，到期即暂停
 f=build({disable:true});i=0;steps=[()=>{f.engine.leaseDeadline=Date.now()-1;return calls('observe',{},'o1');},()=>done('不该到这里')];f.engine.model.next=async()=>steps[Math.min(i++,steps.length-1)]();
 await f.engine.start('x','auto');task=f.engine.current;assert.equal(task.status,'paused');assert.match(task.reason,/后台额度即将到期/);assert.deepEqual(f.device.log.filter(x=>x!=='stable'),[]);
 f.engine.leaseNotice({id:'x',deviceUsed:true});
 assert.ok(f.engine.session().messages.some(m=>/到期前我会回到大肥鱼并暂停/.test(m.text)),'关闭续租时提示文字不同');
 f.engine.leaseNotice({id:'y',deviceUsed:false});assert.equal(f.engine.session().messages.filter(m=>/后台时间提示/.test(m.text)).length,1,'没用过设备的任务不提示');

 // 5. 次数上限与前台/远期不续租
 f=build();f.engine.running=true;f.engine.foreground=false;f.engine.current={id:'t',leaseRenewals:0};near(f.engine,30000);assert.equal(f.engine.wantRenew(),true);
 near(f.engine,90000);assert.equal(f.engine.wantRenew(),false,'离到期还远');
 near(f.engine,30000);f.engine.current.leaseRenewals=P.LEASE_RENEW_MAX;assert.equal(f.engine.wantRenew(),false,'次数用完');
 f.engine.current.leaseRenewals=0;f.engine.foreground=true;assert.equal(f.engine.wantRenew(),false,'在前台（含小窗）不需要');
 f.engine.foreground=false;f.engine.leaseDeadline=0;assert.equal(f.engine.wantRenew(),false,'没有租约');

 // 6. 新租约申请失败（今日额度用完）：任务暂停，原因写明
 f=build();i=0;steps=[()=>{near(f.engine);return calls('observe',{},'o1');},()=>done('不该到这里')];f.engine.model.next=async()=>steps[Math.min(i++,steps.length-1)]();
 const origReturn=f.device.returnToApp;f.device.returnToApp=async(t)=>{leaseThrows=true;try{return await origReturn(t);}finally{leaseThrows=false;}};
 await f.engine.start('x','auto');task=f.engine.current;assert.equal(task.status,'paused');assert.match(task.reason,/额度/);

 // 7. 小窗：已经是前台，不提示、不续租
 f=build();f.device.overlay={active:()=>true};i=0;f.engine.model.next=async()=>i++===0?calls('observe',{},'o1'):done('完成');
 await f.engine.start('小窗里操作','auto');assert.ok(!f.engine.session().messages.some(m=>/后台时间提示/.test(m.text)));

 finished=true;console.log('lease-0840: ok');
})().catch(e=>{console.error('FAIL',e);process.exitCode=1;}).finally(()=>fs.rmSync(scratch,{recursive:true,force:true}));
