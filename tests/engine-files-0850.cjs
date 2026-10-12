// 0.8.3 阶段一：用脚本化模型驱动真实 Engine 循环，验证工具文字重试、ask_user、记忆、Skill 外部来源、文件工具、剪贴板与能力查询。
const fs=require('fs'),vm=require('vm'),path=require('path'),os=require('os'),assert=require('assert/strict');
const ts=require(process.env.HVIGOR_TS||'typescript');
const scratch=fs.mkdtempSync(path.join(os.tmpdir(),'whale-engine-0830-'));
const cache=new Map();const clipboard=[];
const io={OpenMode:{READ_ONLY:0,CREATE:64,READ_WRITE:2,TRUNC:512},accessSync:p=>fs.existsSync(p),mkdirSync:p=>fs.mkdirSync(p),openSync:(p,m)=>({fd:fs.openSync(p,m?'w+':'r')}),closeSync:fd=>fs.closeSync(fd),statSync:p=>typeof p==='number'?fs.fstatSync(p):fs.statSync(p),readSync:(fd,b)=>fs.readSync(fd,new Uint8Array(b)),writeSync:(fd,b)=>fs.writeSync(fd,new Uint8Array(b)),fsyncSync:fd=>fs.fsyncSync(fd),unlinkSync:p=>fs.unlinkSync(p),renameSync:(a,b)=>fs.renameSync(a,b)};
const kit={
 '@kit.BackgroundTasksKit':{backgroundTaskManager:{requestSuspendDelay:()=>({requestId:1,actualDelayTime:180000}),cancelSuspendDelay(){}}},
 '@kit.NetworkKit':{http:{RequestMethod:{POST:'POST'},HttpDataType:{STRING:1},createHttp:()=>({destroy(){},request:async()=>({responseCode:500,result:'',header:{}})})}},
 '@kit.CoreFileKit':{fileIo:io,picker:{}},
 '@kit.BasicServicesKit':{zlib:{decompressFile:async()=>{}},pasteboard:{MIMETYPE_TEXT_PLAIN:'text/plain',createData:(type,text)=>({type:type,text:text}),getSystemPasteboard:()=>({setData:async(data)=>{clipboard.push(data.text);}})}},
 '@kit.ArkTS':{buffer:Buffer,util:{},url:{URL}},'@kit.AbilityKit':{},'@kit.ImageKit':{},'@kit.CryptoArchitectureKit':{},'@kit.UniversalKeystoreKit':{}
};
function load(file){file=path.resolve(file);if(cache.has(file))return cache.get(file);const module={exports:{}};const js=ts.transpileModule(fs.readFileSync(file,'utf8'),{compilerOptions:{module:ts.ModuleKind.CommonJS,target:ts.ScriptTarget.ES2020}}).outputText;vm.runInNewContext(js,{module,exports:module.exports,require:n=>n.startsWith('.')?load(path.resolve(path.dirname(file),n+'.ets')):kit[n],setTimeout:(cb,ms)=>ms>5000?0:setTimeout(cb,0),clearTimeout,Uint8Array,ArrayBuffer,Map,Buffer,Date,JSON,RegExp});cache.set(file,module.exports);return module.exports;}
const root='entry/src/main/ets/agent/';

function makeDevice(){
 const device={hdc:{ready:true},width:2800,height:1840,mutationCount:0,latest:null,observed:0,lastStability:undefined,invalidate(){},sensitive:()=>false,stable:async()=>{},reconnect:async()=>{}};
 device.observe=async()=>{device.observed++;device.latest={snapshotId:'snap-'+device.observed,width:2800,height:1840,elements:[{elementId:'e1',type:'Text',text:'第三方页面文字',id:'',description:'',parent:'',bounds:[0,0,10,10],normalizedCenter:[5,5],enabled:true,editable:false,focused:false,password:false,clickable:false,window:'com.third.party.app',labelSource:''}]};return {layout:'screen layout '+device.observed,snapshotId:'snap-'+device.observed,image:'',width:2800,height:1840,fingerprint:'fp'+device.observed};};
 device.execute=async()=> 'No Error';
 device.installedApps=async()=>({list:[{bundle:'com.huawei.hmos.calculator',label:'计算器',ability:'MainAbility'}],note:'待真机核对'});
 return device;
}
// 脚本化模型：按顺序返回决策，并记录每次调用时收到的任务与记忆参数。
function scripted(engine,steps){const seen=[];let i=0;engine.model.next=async(p,key,s,t,o,defs,catalog,memory)=>{seen.push({hostNote:t.hostNote,memory:memory,catalog:catalog});const step=steps[Math.min(i,steps.length-1)];i++;return typeof step==='function'?step(t,o):step;};return seen;}
function calls(name,args,id){return {text:'',calls:[{id:id,name:name,arguments:JSON.stringify(args)}]};}
const done=(text)=>({text:text,calls:[]});

(async()=>{
 const T=load(root+'Types.ets'),{Engine}=load(root+'Engine.ets'),state=T.defaults(),e=new Engine(state,{root:scratch,save(){},secret:async()=>'x'},makeDevice(),()=>{});let received=[],confirmed=[];e.confirm=async text=>{confirmed.push(text);return false};e.files.execute=async(name,args)=>{received.push([name,args]);if(name==='sheet_list')return '["明细","汇总"]';if(name==='sheet_read'){assert.equal(args.sheet,'明细');return '{"cells":[]}'}return '{"fileId":"new","verified":true}'};e.files.list=()=>[{id:'new',kind:'xlsx',name:'test.xlsx'}];e.files.observe=()=>({layout:'files',image:'',snapshotId:'files',width:0,height:0,fingerprint:'files'});scripted(e,[calls('web_download',{url:'https://example.com/t.txt',name:'t.txt'},'d1'),done('拒绝')]);await e.start('下载测试','auto');assert.equal(confirmed.length,1);assert.match(confirmed[0],/example.com/);assert.equal(received.length,0,'确认拒绝之前不得下载');received=[];confirmed=[];e.confirm=async text=>{confirmed.push(text);return true};scripted(e,[calls('web_download',{url:'https://example.com/t.txt'},'d2'),done('完成')]);await e.start('下载测试批准','auto');assert.equal(received[0][0],'web_download');assert.equal(confirmed.length,1);received=[];e.files.execute=async(name,args)=>{received.push([name,args]);if(name==='sheet_create')return '{"fileId":"new","verified":true}';if(name==='sheet_list')return '["明细","汇总"]';assert.equal(args.sheet,'明细');return '{"cells":[]}'};scripted(e,[calls('sheet_create',{sheetsJson:'[]'},'s1'),done('完成')]);await e.start('多表测试','auto');assert.deepEqual(received.map(r=>r[0]),['sheet_create','sheet_list','sheet_read']);assert.equal(e.current.records[0].status,'success');
 // Real confirmation waiter interrupted by lease expiry must never become user denial.
 e.confirm=Engine.prototype.confirm.bind(e);
 received=[];
 scripted(e,[calls('web_download',{url:'https://example.com/t.txt'},'expire-download'),done('完成')]);
 const pending=e.start('确认到期测试','auto');
 for(let i=0;i<100&&!e.approvalResolve;i++)await new Promise(resolve=>setTimeout(resolve,5));
 assert.ok(e.approvalResolve,'real confirmation is pending');
 e.pause('后台额度快到期');await pending;
 assert.equal(received.length,0);assert.equal(e.current.status,'paused');assert.equal(e.current.reason,'后台额度快到期');
 assert.equal(e.current.records[0].errorCode,'INTERRUPTED');assert.equal(e.current.records[0].status,'skipped');
 assert.doesNotMatch(e.current.records[0].result,/DENIED|拒绝/);
 await e.management.execute('skill_save',{name:'expiry-flow',description:'测试',whenToUse:'测试',body:'仅文字'},false,async()=>true);
 scripted(e,[calls('skill_delete',{name:'expiry-flow'},'expire-skill'),done('完成')]);
 const deleting=e.start('删除确认取消测试','auto');
 for(let i=0;i<100&&!e.approvalResolve;i++)await new Promise(resolve=>setTimeout(resolve,5));
 assert.ok(e.approvalResolve);e.pause('用户取消',true);await deleting;
 assert.equal(e.current.status,'cancelled');assert.equal(e.current.records[0].errorCode,'INTERRUPTED');
 assert.doesNotMatch(e.current.records[0].result,/DENIED|拒绝/);assert.ok(state.skills.some(s=>s.name==='expiry-flow'));
 // Bringing the confirmation UI forward is not a download write.
 e.confirm=async()=>{e.device.mutationCount++;return true};
 const {DeviceError}=load(root+'Elements.ets');e.files.execute=async()=>{throw new DeviceError('WEB_HTTP','下载返回HTTP 403')};
 scripted(e,[calls('web_download',{url:'https://example.com/no.png'},'http-denied'),done('源站拒绝')]);
 await e.start('下载明确拒绝','auto');assert.equal(e.current.records[0].status,'error');assert.equal(e.current.records[0].errorCode,'WEB_HTTP');
 assert.doesNotMatch(e.current.records[0].result,/效果不确定/);
 console.log('PASS: download confirmation deny/allow, workbook discovery, confirmation expiry/cancel never writes or reports user denial.');

})().catch(e=>{console.error(e);process.exitCode=1}).finally(()=>fs.rmSync(scratch,{recursive:true,force:true}));
