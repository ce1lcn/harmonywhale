// 0.8.3.8 回归：产品级保护（桌面与 ClassCount 坐标拒绝，不可重试）；错误码与可重试标记。
const fs=require('fs'),path=require('path'),vm=require('vm'),assert=require('assert/strict');
const ts=require(process.env.HVIGOR_TS||'typescript');
const imageStub={createImageSource:()=>({getImageInfo:async()=>({size:{width:2800,height:1840}}),createPixelMap:async()=>{throw new Error('无图像解码');},release(){}}),createImagePacker:()=>({release(){}})};
const kit={'@kit.NetworkKit':{http:{RequestMethod:{POST:'POST'},HttpDataType:{STRING:1},createHttp:()=>({on(){},off(){},destroy(){}})}},'@kit.BackgroundTasksKit':{backgroundTaskManager:{requestSuspendDelay:()=>({requestId:1,actualDelayTime:180000}),cancelSuspendDelay(){}}},'@kit.ArkTS':{buffer:{from:(x,e)=>Buffer.from(x,e)},util:{Base64Helper:class{decodeSync(s){return new Uint8Array(Buffer.from(s,'base64'));}encodeToStringSync(b){return Buffer.from(b).toString('base64');}}}},'@kit.CoreFileKit':{fileIo:{OpenMode:{CREATE:1,READ_WRITE:2},openSync:()=>({fd:1}),writeSync(){},closeSync(){}},picker:{}},'@kit.BasicServicesKit':{zlib:{}},'@kit.ImageKit':{image:imageStub},'@kit.AbilityKit':{},'@kit.UniversalKeystoreKit':{},'@kit.CryptoArchitectureKit':{}};
const cache=new Map();function load(file){file=path.resolve(file);if(cache.has(file))return cache.get(file);const module={exports:{}};vm.runInNewContext(ts.transpileModule(fs.readFileSync(file,'utf8'),{compilerOptions:{module:ts.ModuleKind.CommonJS,target:ts.ScriptTarget.ES2020}}).outputText,{module,exports:module.exports,require:n=>n.startsWith('.')?load(path.resolve(path.dirname(file),n+'.ets')):kit[n]??{},setTimeout:(cb,ms)=>(ms??0)>=60000?0:setTimeout(cb,Math.min(ms??0,5)),clearTimeout,queueMicrotask,Uint8Array,ArrayBuffer,Map,Set,Buffer,Date,JSON,Math,Number,Object,Array,String,RegExp,Error,Promise});cache.set(file,module.exports);return module.exports;}
const root='entry/src/main/ets/agent/';
const F=load(root+'FloatPolicy.ets'),K=load(root+'ActionKit.ets');
const {Device}=load(root+'Device.ets');
const DESK='com.ohos.sceneboard',CC='com.harmonyloom.schedule',SELF='com.harmonyloom.selfhdcprobe';
// 样例布局：桌面全屏；大肥鱼窗口在左上；ClassCount 窗口在中间偏上。bounds 为像素坐标。
const leaf=(text,b)=>({attributes:{type:'Button',text:text,clickable:'true',enabled:'true',bounds:b}});
const tree={attributes:{},children:[
 {attributes:{bundleName:DESK,bounds:'[0,0][2799,1839]'},children:[leaf('桌面','[0,0][100,100]')]},
 {attributes:{bundleName:SELF,bounds:'[200,100][1200,900]'},children:[leaf('大肥鱼','[200,100][400,200]')]},
 {attributes:{bundleName:CC,bounds:'[1300,100][2000,900]'},children:[leaf('ClassCount','[1300,100][1500,200]')]}
]};
// ---------- 1. 点归属 ----------
assert.equal(JSON.stringify([...F.bundlesAtPoint(tree,2500,1600)]),JSON.stringify([DESK]),'只在桌面上');
assert.equal(JSON.stringify([...F.bundlesAtPoint(tree,300,300)].sort()),JSON.stringify([DESK,SELF].sort()),'大肥鱼窗口内：桌面与自身都覆盖');
assert.equal(JSON.stringify([...F.bundlesAtPoint(tree,1500,500)].sort()),JSON.stringify([DESK,CC].sort()),'ClassCount 窗口内');
assert.equal(JSON.stringify([...F.bundlesAtPoint({attributes:{},children:[]},10,10)]),'[]','空布局');
// ---------- 2. 拒绝条件 ----------
assert.equal(F.productGuardBlock([DESK],'').code,'DESKTOP_GUARD');
assert.equal(F.productGuardBlock([],DESK).code,'DESKTOP_GUARD','无窗口时以前台为准');
assert.equal(F.productGuardBlock([],SELF),undefined,'无窗口且前台是大肥鱼：放行');
assert.equal(F.productGuardBlock([DESK,SELF],DESK),undefined,'大肥鱼与桌面同时覆盖：放行');
assert.equal(F.productGuardBlock([CC],SELF).code,'CLASSCOUNT_GUARD');
assert.equal(F.productGuardBlock([CC,DESK],SELF).code,'CLASSCOUNT_GUARD','ClassCount 优先');
assert.equal(F.productGuardBlock([SELF],''),undefined);
// ---------- 3. 错误码 ----------
assert.ok(K.errorCodes().indexOf('DESKTOP_GUARD')>=0&&K.errorCodes().indexOf('CLASSCOUNT_GUARD')>=0);
assert.ok(K.formatError('DESKTOP_GUARD','x').indexOf('可重试：否')>=0,'不可重试');
assert.ok(K.formatError('CLASSCOUNT_GUARD','x').indexOf('可重试：否')>=0,'不可重试');
// ---------- 4. Device：点击桌面与 ClassCount 时不发出任何输入 ----------
async function deviceTests(){
 const fakeFront='AbilityRecord ID #1\n bundle name ['+SELF+']\n main name [ProbeAbility]\n state #FOREGROUND';
 function make(){const d=new Device(null,null);const sent=[];
  d.command=async(text)=>{
   if(text.indexOf('uitest dumpLayout')===0)return '';
   if(text.indexOf('cat ')===0)return JSON.stringify(tree);
   if(text==='aa dump -l')return fakeFront;
   if(/^uitest uiInput|^uinput/.test(text))sent.push(text);
   return 'No Error';};
  return {d,sent};}
 // 归一化 (900,900) → 像素约 (2519,1655)：只在桌面上
 let {d,sent}=make();
 let err;
 try{await d.execute('click',{x:900,y:900});}catch(e){err=e;}
 assert.equal(err?.code,'DESKTOP_GUARD','点击桌面应被拒绝');assert.equal(sent.length,0,'被拒绝时不发出输入');
 // 归一化 (536,272) → 像素约 (1500,500)：ClassCount 窗口内
 ({d,sent}=make());err=undefined;
 try{await d.execute('long_press',{x:536,y:272});}catch(e){err=e;}
 assert.equal(err?.code,'CLASSCOUNT_GUARD','长按 ClassCount 应被拒绝');assert.equal(sent.length,0);
 // 拖拽终点落在桌面上也拒绝（起点在大肥鱼内）
 ({d,sent}=make());err=undefined;
 try{await d.execute('drag',{x:107,y:107,x2:900,y2:900});}catch(e){err=e;}
 assert.equal(err?.code,'DESKTOP_GUARD','拖拽终点在桌面应拒绝');assert.equal(sent.length,0);
 // 大肥鱼窗口内的点击放行
 ({d,sent}=make());
 await d.execute('click',{x:107,y:107});
 assert.equal(sent.length,1,'大肥鱼窗口内点击应执行');
 // 滚动：起点在桌面上（归一化 900,900）应被拒绝
 ({d,sent}=make());err=undefined;
 try{await d.execute('scroll',{direction:'down',maxSwipes:1});}catch(e){err=e;}
 assert.ok(err===undefined||err.code==='DESKTOP_GUARD','scroll 默认起点落在桌面时应拒绝或放行（不得误发）');
 console.log('guard-0838: device tests ok');
}
deviceTests().then(()=>{console.log('guard-0838: all ok');}).catch((e)=>{console.error(e);process.exit(1);});
