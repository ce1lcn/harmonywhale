// 0.8.3.9 回归：让出前台前必须确认本机 HDC 已连接。
const fs=require('fs'),path=require('path'),vm=require('vm'),assert=require('assert/strict');
const ts=require(process.env.HVIGOR_TS||'typescript');
const imageStub={createImageSource:()=>({getImageInfo:async()=>({size:{width:2800,height:1840}}),createPixelMap:async()=>{throw new Error('无图像解码');},release(){}}),createImagePacker:()=>({release(){}})};
const kit={'@kit.NetworkKit':{http:{RequestMethod:{POST:'POST'},HttpDataType:{STRING:1},createHttp:()=>({on(){},off(){},destroy(){}})}},'@kit.BackgroundTasksKit':{backgroundTaskManager:{requestSuspendDelay:()=>({requestId:1,actualDelayTime:180000}),cancelSuspendDelay(){}}},'@kit.ArkTS':{buffer:{from:(x,e)=>Buffer.from(x,e)},util:{Base64Helper:class{decodeSync(s){return new Uint8Array(Buffer.from(s,'base64'));}encodeToStringSync(b){return Buffer.from(b).toString('base64');}}}},'@kit.CoreFileKit':{fileIo:{OpenMode:{CREATE:1,READ_WRITE:2},openSync:()=>({fd:1}),writeSync(){},closeSync(){}},picker:{}},'@kit.BasicServicesKit':{zlib:{}},'@kit.ImageKit':{image:imageStub},'@kit.AbilityKit':{},'@kit.UniversalKeystoreKit':{},'@kit.CryptoArchitectureKit':{}};
const cache=new Map();function load(file){file=path.resolve(file);if(cache.has(file))return cache.get(file);const module={exports:{}};vm.runInNewContext(ts.transpileModule(fs.readFileSync(file,'utf8'),{compilerOptions:{module:ts.ModuleKind.CommonJS,target:ts.ScriptTarget.ES2020}}).outputText,{module,exports:module.exports,require:n=>n.startsWith('.')?load(path.resolve(path.dirname(file),n+'.ets')):kit[n]??{},setTimeout:(cb,ms)=>(ms??0)>=60000?0:setTimeout(cb,Math.min(ms??0,5)),clearTimeout,queueMicrotask,Uint8Array,ArrayBuffer,Map,Set,Buffer,Date,JSON,Math,Number,Object,Array,String,RegExp,Error,Promise});cache.set(file,module.exports);return module.exports;}
// 0.8.3.9 回归：让出前台前必须确认本机 HDC 已连接；未连接时留在大肥鱼并返回 DEVICE_OFFLINE（不可重试）。
const root='entry/src/main/ets/agent/';
const {Device}=load(root+'Device.ets');
const K=load(root+'ActionKit.ets');
function make(ready){const d=new Device({ready:ready},null);const sent=[];d.command=async(text)=>{sent.push(text);return 'No Error';};return {d,sent};}
async function run(){
 // 1) HDC 未连接：启动其他应用与回桌面都拒绝，且不发出任何命令
 for(const name of ['launch_app','home']){
  const {d,sent}=make(false);let err;
  try{await d.execute(name,{appId:'com.huawei.hmos.calculator'});}catch(e){err=e;}
  if(!err||err.code!=='DEVICE_OFFLINE')throw new Error(name+'：HDC 未连接时应返回 DEVICE_OFFLINE，实际 '+(err&&err.code));
  if(sent.length!==0)throw new Error(name+'：拒绝时不得发出任何命令，实际 '+sent.length);
 }
 // 2) HDC 已连接：回桌面照常发出按键
 {const {d,sent}=make(true);const r=await d.execute('home',{});
  if(!sent.some(t=>t.indexOf('keyEvent Home')>=0))throw new Error('已连接时 home 应发出 keyEvent Home');
  if(typeof r!=='string')throw new Error('返回值应为字符串');}
 // 3) 错误码：DEVICE_OFFLINE 不可重试，并给出重连建议
 if(K.formatError('DEVICE_OFFLINE','x').indexOf('可重试：否')<0)throw new Error('DEVICE_OFFLINE 应不可重试');
 console.log('recover-0839: ok');
}
run().catch((e)=>{console.error(e);process.exit(1);});
