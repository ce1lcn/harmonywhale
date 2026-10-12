const fs=require('fs'),vm=require('vm'),path=require('path'),assert=require('assert/strict');
const ts=require(process.env.HVIGOR_TS||'typescript');
const cache=new Map();let response={choices:[{finish_reason:'stop',message:{content:'完成',tool_calls:[]}}]},payload;let leaseCallback;let leaseDelay=180000;const crypto=require('crypto');
const kit={
 '@kit.BackgroundTasksKit':{backgroundTaskManager:{requestSuspendDelay:(r,cb)=>{leaseCallback=cb;return {requestId:1,actualDelayTime:leaseDelay};},cancelSuspendDelay(){}}},
 '@kit.NetworkKit':{http:{RequestMethod:{POST:'POST'},HttpDataType:{STRING:1},createHttp:()=>({destroy(){},request:async(url,opt)=>{payload=JSON.parse(opt.extraData);return {responseCode:200,result:JSON.stringify(response),header:{}};}})}},
 '@kit.CoreFileKit':{fileIo:{},picker:{}},'@kit.BasicServicesKit':{zlib:{}},'@kit.ImageKit':{},'@kit.AbilityKit':{},'@kit.UniversalKeystoreKit':{},'@kit.CryptoArchitectureKit':{},'@kit.ArkTS':{buffer:{from:(x,e)=>Buffer.from(x,e)},util:{}}
};
function load(file){file=path.resolve(file);if(cache.has(file))return cache.get(file);const module={exports:{}};const source=fs.readFileSync(file,'utf8');const js=ts.transpileModule(source,{compilerOptions:{module:ts.ModuleKind.CommonJS,target:ts.ScriptTarget.ES2020}}).outputText;vm.runInNewContext(js,{module,exports:module.exports,require:n=>n.startsWith('.')?load(path.resolve(path.dirname(file),n+'.ets')):kit[n],setTimeout,clearTimeout,Uint8Array,ArrayBuffer,Map,Buffer});cache.set(file,module.exports);return module.exports;}
const root='entry/src/main/ets/agent/';

// Acceptance-only PC transport: real Device implementation, real tablet UI.
// This bridge is NOT included in the HAP and is not a runtime dependency.
const {execFile}=require('child_process');const hdc=process.env.HDC_PATH||'hdc';
const shell=command=>new Promise((resolve,reject)=>execFile(hdc,['-t',(process.env.HDC_TARGET||''),'shell',command],{encoding:'utf8',timeout:35000,maxBuffer:4*1024*1024},(e,out)=>e?reject(e):resolve(out)));
(async()=>{
 const {Device}=load(root+'Device.ets');const d=new Device({execute:shell},{});d.latest=await d.readLayout();assert.ok(d.latest.elements.some(e=>e.id==='fixture_load'),'Open ExecutionFixture first; no other page may be tested');
 const find=id=>{const e=d.latest.elements.find(e=>e.id===id);assert.ok(e,'Missing '+id);return {snapshotId:d.latest.snapshotId,elementId:e.elementId};};
 await d.execute('click_element',find('fixture_load'));console.log(await d.waitFor({snapshotId:d.latest.snapshotId,targetText:'加载完成',condition:'appears',timeoutMs:10000}));await d.stable();
 d.latest=await d.readLayout();await d.execute('click_element',find('fixture_right'));await d.stable();d.latest=await d.readLayout();assert.ok(d.latest.elements.some(e=>e.text==='右侧按钮'));
 const before=d.latest.elements.find(e=>e.id==='fixture_move').bounds[0];await d.execute('click_element',find('fixture_move'));await d.stable();d.latest=await d.readLayout();assert.notEqual(d.latest.elements.find(e=>e.id==='fixture_move').bounds[0],before);
 console.log(await d.execute('replace_element',{...find('fixture_input'),text:'验收通过'}));await d.stable();d.latest=await d.readLayout();assert.ok(d.latest.elements.some(e=>e.id==='fixture_input'&&e.text==='验收通过'));
 await assert.rejects(()=>d.execute('click_element',{snapshotId:'stale',elementId:'e1'}),/失效/);d.active=()=>false;await assert.rejects(()=>d.execute('home',{}),/暂停/);
 console.log('PASS NATIVE: delayed load, wait, duplicate labels with unique ids, moving bounds, replace/focus/result, stale reference and pause');
})().catch(e=>{console.error(e);process.exitCode=1;});
