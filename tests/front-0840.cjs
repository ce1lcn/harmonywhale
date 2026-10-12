// 0.8.4 A2：工具记录的应用名取自布局里的可见窗口，而不是 aa dump -l 里的第一个 FOREGROUND 块（WPS 服务 Ability 会排在前面）。
// 样例：0.8.1 留下的真机 aa dump（artifacts/s1-aa-dump-0810.txt）与真机备忘录布局（artifacts/notes*.json）。
const fs=require('fs'),path=require('path'),vm=require('vm'),assert=require('assert/strict');
const ts=require(process.env.HVIGOR_TS||'typescript');
const kit={'@kit.NetworkKit':{http:{}},'@kit.BackgroundTasksKit':{backgroundTaskManager:{}},'@kit.ArkTS':{buffer:Buffer,util:{}},'@kit.CoreFileKit':{fileIo:{}},'@kit.BasicServicesKit':{},'@kit.ImageKit':{image:{}},'@kit.CoreVisionKit':{textRecognition:{}},'@kit.AbilityKit':{},'@kit.UniversalKeystoreKit':{},'@kit.CryptoArchitectureKit':{}};
const cache=new Map();function load(file){file=path.resolve(file);if(cache.has(file))return cache.get(file);const module={exports:{}};vm.runInNewContext(ts.transpileModule(fs.readFileSync(file,'utf8'),{compilerOptions:{module:ts.ModuleKind.CommonJS,target:ts.ScriptTarget.ES2020}}).outputText,{module,exports:module.exports,require:n=>n.startsWith('.')?load(path.resolve(path.dirname(file),n+'.ets')):(kit[n]??{}),setTimeout:(cb,ms)=>setTimeout(cb,Math.min(ms??0,5)),clearTimeout,Uint8Array,ArrayBuffer,Map,Set,Buffer,Date,JSON,Math,Number,Object,Array,String,RegExp,Error,Promise});cache.set(file,module.exports);return module.exports;}
const root='entry/src/main/ets/agent/';
const F=load(root+'FloatPolicy.ets'),{Device,SELF_BUNDLE}=load(root+'Device.ets');
const realDump=fs.readFileSync('artifacts/s1-aa-dump-0810.txt','utf8');
const notes2=JSON.parse(fs.readFileSync('artifacts/notes2.json','utf8'));// 悬浮窗：备忘录 + sceneboard + 大肥鱼
const notes1=JSON.parse(fs.readFileSync('artifacts/notes1.json','utf8'));
const NOTEPAD='com.huawei.hmos.notepad';
(async()=>{
 // 1. 真机 dump 里没有备忘录的 FOREGROUND 块，旧逻辑要么取 WPS（无可见窗口信息）要么取大肥鱼
 assert.equal(F.foregroundBundle(realDump,SELF_BUNDLE,true),'cn.wps.office.hap','旧逻辑在没有可见窗口信息时取到 WPS 服务 Ability');
 const visible=F.windowBundles(notes2);
 assert.ok(visible.includes(NOTEPAD)&&visible.includes('com.ohos.sceneboard')&&visible.includes(SELF_BUNDLE));
 assert.notEqual(F.foregroundBundle(realDump,SELF_BUNDLE,true,visible),NOTEPAD,'旧逻辑不能得到备忘录');
 // 2. 新逻辑：可见窗口优先（排除 sceneboard、输入法、大肥鱼自己）
 assert.equal(F.frontBundle(realDump,SELF_BUNDLE,true,visible),NOTEPAD,'悬浮窗：备忘录');
 assert.equal(F.frontBundle(realDump,SELF_BUNDLE,false,[NOTEPAD,'com.ohos.sceneboard']),NOTEPAD,'全屏在备忘录里操作（大肥鱼在后台，布局里没有它）');
 assert.equal(F.frontBundle(realDump,SELF_BUNDLE,false,[SELF_BUNDLE,'com.ohos.sceneboard']),SELF_BUNDLE,'大肥鱼全屏时仍是大肥鱼');
 assert.equal(F.frontBundle(realDump,SELF_BUNDLE,false,[NOTEPAD,'com.huawei.hmos.inputmethod','com.ohos.sceneboard']),NOTEPAD,'输入法窗口不算应用');
 assert.equal(F.frontBundle(realDump,SELF_BUNDLE,true,['com.ohos.sceneboard','com.huawei.hmos.inputmethod']),'cn.wps.office.hap','没有可见应用窗口：退回 aa dump 的旧逻辑');
 assert.equal(F.frontBundle(realDump,SELF_BUNDLE,true),'cn.wps.office.hap','没有布局信息：退回 aa dump 的旧逻辑');
 // 多个候选（分屏）：取同时出现在 aa dump FOREGROUND 列表里的那个
 assert.equal(F.frontBundle(realDump,SELF_BUNDLE,true,[NOTEPAD,'com.huawei.hmos.calculator']),'com.huawei.hmos.calculator');
 assert.equal(F.frontBundle(realDump,SELF_BUNDLE,true,[NOTEPAD,'com.x.y']),NOTEPAD,'都不在列表里：取布局里的第一个');
 assert.deepEqual(F.visibleAppBundles(['com.ohos.sceneboard',SELF_BUNDLE,NOTEPAD],SELF_BUNDLE,true),[NOTEPAD]);
 // 3. Device 集成：真实布局 + 真实 dump，actionTarget 与 frontOf 得到备忘录
 const layoutOf=(tree)=>{const issued=[];const hdc={ready:true,execute:async(cmd)=>{issued.push(cmd);if(cmd.startsWith('cat '))return JSON.stringify(tree);if(cmd==='aa dump -l')return realDump;return 'No Error';}};return {hdc,issued};};
 let l=layoutOf(notes2);
 let d=new Device(l.hdc,{root:'/tmp'});d.overlay={active:()=>true,windowRect:()=>[],beforeCapture:async()=>({}),afterCapture:async()=>{},setTouchable:async()=>{}};
 let target=await d.actionTarget('click',{x:300,y:500});
 assert.equal(target.app,NOTEPAD,'悬浮窗下的备忘录');
 // 全屏：大肥鱼窗口不在布局里
 const fullscreenNotes={attributes:notes1.attributes,children:notes1.children.filter(c=>c.attributes.bundleName!==SELF_BUNDLE&&!(c.attributes.bundleName==='com.ohos.sceneboard'&&c.attributes.bounds==='[2459,114][2746,624]'))};
 l=layoutOf(fullscreenNotes);d=new Device(l.hdc,{root:'/tmp'});
 target=await d.actionTarget('click',{x:300,y:500});
 assert.equal(target.app,NOTEPAD,'全屏备忘录（大肥鱼在后台）');
 // 未取到布局信息的旧测试路径不变：visibleBundles 为空时仍按 aa dump
 d.visibleBundles=[];assert.equal(d.frontOf(realDump),'cn.wps.office.hap');
 console.log('front-0840: ok');
})().catch(e=>{console.error('FAIL',e);process.exitCode=1;});
