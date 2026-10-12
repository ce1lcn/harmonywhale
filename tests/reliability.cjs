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
 const {snapshot,relocate,DeviceError}=load(root+'Elements.ets');const {Device}=load(root+'Device.ets');const {builtins,validate}=load(root+'Registry.ets');
 const node=(text,x=0,extra={})=>({attributes:{text,type:'Button',bounds:`[${x},100][${x+100},200]`,clickable:'true',hostWindowId:'1',...extra}});
 const tree=(...children)=>({children});const old=snapshot(tree(node('7')),1000,1000);const moved=snapshot(tree(node('7',300)),1000,1000);assert.equal(relocate(old,moved,old.elements[0].elementId).bounds[0],300);
 assert.throws(()=>relocate(old,snapshot(tree(node('7'),node('7',200)),1000,1000),old.elements[0].elementId),/不唯一/);
 assert.throws(()=>relocate(old,snapshot(tree(node('8')),1000,1000),old.elements[0].elementId),/消失/);
 assert.throws(()=>relocate(old,snapshot(tree(node('7',0,{enabled:'false'})),1000,1000),old.elements[0].elementId),/不可用/);
 assert.throws(()=>relocate(old,snapshot(tree(node('7',0,{hostWindowId:'2'})),1000,1000),old.elements[0].elementId),/窗口/);
 assert.throws(()=>relocate(old,snapshot(tree(node('7')),2000,1000),old.elements[0].elementId),/尺寸/);
 const secret=snapshot(tree(node('secret',0,{password:'true',description:'secret'})),1000,1000);assert.ok(!JSON.stringify(secret).includes('secret'));
 const nested=snapshot({attributes:{type:'TextInput',text:'secret',password:'true'},children:[node('secret')]},1000,1000);assert.ok(!JSON.stringify(nested).includes('secret'));
 const d=new Device({execute:async()=> 'No Error'},{});d.latest=old;let issued=0;d.readLayout=async()=>moved;d.command=async()=>{issued++;return 'No Error';};await assert.rejects(()=>d.execute('click_element',{snapshotId:'old',elementId:old.elements[0].elementId}),/失效/);assert.equal(issued,0);
 await d.execute('click_element',{snapshotId:old.snapshotId,elementId:old.elements[0].elementId});assert.equal(issued,1);
 d.latest=old;d.readLayout=async()=>snapshot(tree(),1000,1000);assert.match(await d.waitFor({snapshotId:old.snapshotId,elementId:old.elements[0].elementId,condition:'disappears',timeoutMs:0}),/满足/);
 await assert.rejects(()=>d.waitFor({snapshotId:old.snapshotId,elementId:old.elements[0].elementId,condition:'appears',timeoutMs:0}),/超时/);
 d.active=()=>false;await assert.rejects(()=>d.delay(1),/暂停/);

 // Read-only waits must allow not-yet-present targets; cancellation during polling stops reads.
 d.latest=old;d.active=()=>true;let polls=0;d.readLayout=async()=>++polls===1?snapshot(tree(node('loading')),1000,1000):snapshot(tree(node('ready')),1000,1000);d.delay=async()=>{};
 assert.match(await d.waitFor({snapshotId:old.snapshotId,targetText:'ready',condition:'appears',timeoutMs:1000}),/满足/);assert.equal(polls,2);
 d.readLayout=async()=>snapshot(tree(node('loading')),1000,1000);d.delay=async()=>{throw new Error('任务已暂停');};await assert.rejects(()=>d.waitFor({snapshotId:old.snapshotId,targetText:'ready',condition:'appears',timeoutMs:1000}),/暂停/);
 // Missing layout is an explicit failure rather than a stable empty screen.
 const empty=new Device({execute:async cmd=>cmd.startsWith('cat ')?'{}':'ok'},{});await assert.rejects(()=>empty.readLayout(),/布局为空/);
 // Do not blindly replay a write whose result could not be confirmed.
 const input=new Device({execute:async()=> 'No Error'},{});const editable=snapshot(tree(node('原内容',0,{type:'TextInput',id:'input',editable:'true',focused:'true'})),1000,1000);input.latest=editable;input.readLayout=async()=>editable;
 await assert.rejects(()=>input.elementAction('replace_element',{snapshotId:editable.snapshotId,elementId:editable.elements[0].elementId,text:'新内容'}),/不符合预期/);assert.ok(input.mutationCount>0);
 input.latest=secret;await assert.rejects(()=>input.elementAction('replace_element',{snapshotId:secret.snapshotId,elementId:secret.elements[0].elementId,text:'secret'}));
 const blankTarget=snapshot(tree(node('',0,{id:'keyCode_12',description:' '})),1000,1000);d.active=()=>true;d.latest=blankTarget;d.readLayout=async()=>blankTarget;await assert.rejects(()=>d.execute('click_element',{snapshotId:blankTarget.snapshotId,elementId:blankTarget.elements[0].elementId}),/没有可读名称/);
 const definition=builtins().find(x=>x.name==='finish_task');assert.throws(()=>validate(definition,{outcome:'lie',reply:'x'}),/取值/);
 const {Engine}=load(root+'Engine.ets'),{defaults}=load(root+'Types.ets');
 const make=()=>{const state=defaults();const device={invalidate(){},sensitive:()=>false,mutationCount:0,hdc:{ready:true},observe:async()=>({snapshotId:'current',layout:'15',fingerprint:'15',image:'',width:1000,height:1000}),stable:async()=>{},execute:async()=>{throw new Error('No actions expected');}};const engine=new Engine(state,{save(){},secret:async()=> 'fixture'},device,()=>{});const start=engine.start.bind(engine);engine.start=(goal,mode)=>start(goal,mode??'device');return engine;};
 let engine=make();engine.model.next=async()=>({text:'',calls:[{id:'end',name:'finish_task',arguments:JSON.stringify({outcome:'success',reply:'15',snapshotId:'current',evidence:'屏幕显示15'})}]});await engine.start('计算器');assert.equal(engine.current.outcome,'success');assert.equal(engine.current.status,'completed');
 engine=make();engine.model.next=async()=>({text:'',calls:[{id:'end',name:'finish_task',arguments:JSON.stringify({outcome:'success',reply:'15',snapshotId:'stale',evidence:'15'})}]});await engine.start('计算器');assert.equal(engine.current.status,'completed');assert.equal(engine.current.outcome,'success');
 engine=make();engine.model.next=async()=>({text:'无法继续',calls:[]});await engine.start('打开应用');assert.equal(engine.current.status,'completed');assert.equal(engine.current.outcome,'chat');
 console.log('PASS: element movement, ambiguity, disappearance, disabled/window/rotation, stale reference, secret redaction, waits/cancel, explicit outcome evidence');
})().catch(e=>{console.error(e);process.exitCode=1;});
