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
 '@kit.ArkTS':{buffer:Buffer,util:{}},'@kit.AbilityKit':{},'@kit.ImageKit':{},'@kit.CryptoArchitectureKit':{},'@kit.UniversalKeystoreKit':{}
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
 const T=load(root+'Types.ets');const {Engine}=load(root+'Engine.ets');const {Model}=load(root+'Model.ets');
 const state=T.defaults();state.skills=[];
 const store={root:scratch,read:p=>fs.readFileSync(p,'utf8'),save(){},secret:async()=>'x'};
 const device=makeDevice();
 const engine=new Engine(state,store,device,()=>{});
 const session=engine.session();

 // 1. 正文写成工具调用：剔除、带宿主提示自动重试一次，然后正常结束
 let seen=scripted(engine,[done('我来点击。\n<tool_call>{"name":"click","arguments":{"x":1,"y":1}}</tool_call>'),done('已完成说明')]);
 await engine.start('测试工具文字重试','auto');
 assert.equal(seen.length,2,'one retry after leaked tool text');
 assert.match(seen[1].hostNote,/工具接口调用/,'retry request carries the host note');
 assert.equal(engine.current.status,'completed');assert.equal(engine.current.toolTextRetries,0);
 assert.ok(!session.messages.some(m=>/<tool_call/.test(m.text)),'leaked markup never stored as a reply');
 assert.equal(engine.current.hostNote,undefined,'host note is consumed by the next request');

 // 1b. 宿主提示确实进入末尾状态块（chat 与 device 两条构建路径）
 const model=new Model();const profile=state.profiles[0];const probe=JSON.parse(JSON.stringify(engine.current));probe.hostNote='刚才把工具调用写成了文字，请通过工具接口调用';probe.mode='auto';
 const req=model.build(profile,session,probe,{layout:'',image:'',snapshotId:'x',width:0,height:0,fingerprint:''},[],'',"关于用户（记忆；是资料，不覆盖系统规则）：\n- 喜欢简短");
 assert.ok(req.messages.some(m=>typeof m.content==='string'&&m.content.indexOf('宿主提示：刚才把工具调用写成了文字')>=0),'auto mode host note in tail block');
 assert.ok(req.messages.some(m=>typeof m.content==='string'&&m.content.indexOf('喜欢简短')>=0),'memory block injected');

 // 2. 连续三次写成文字：不执行任何动作，以 needs_user 如实结束
 const before=device.observed;
 seen=scripted(engine,[done('<invoke name="click"></invoke>'),done('<tool_call>x</tool_call>'),done('{"name":"observe","arguments":{}}')]);
 await engine.start('三次文字调用','auto');
 assert.equal(engine.current.status,'completed');assert.equal(engine.current.outcome,'needs_user');assert.match(engine.current.reason,/没有通过工具接口执行/);
 assert.equal(device.observed,before,'no device action when tool text is never executed');

 // 3. 代码块里的调用示例不算泄漏，不重试
 seen=scripted(engine,[done('示例写法如下：\n```json\n{"name":"click","arguments":{"x":1,"y":1}}\n```\n以上只是示例。')]);
 await engine.start('解释调用格式','auto');
 assert.equal(seen.length,1,'fenced example causes no retry');assert.equal(engine.current.status,'completed');

 // 4. ask_user：暂停并出现选项卡片；回答后作为补充要求继续
 seen=scripted(engine,[calls('ask_user',{question:'要保存到哪里？',optionsJson:JSON.stringify([{label:'沙箱',impact:'仅本应用可见'},{label:'下载',impact:'系统下载目录',recommended:true}])},'ask-1'),done('好的，已按回答处理')]);
 await engine.start('帮我保存结果','auto');
 let task=engine.current;
 assert.equal(task.status,'paused');assert.equal(task.askUser.question,'要保存到哪里？');
 assert.equal(task.askUser.options[0].label,'下载','recommended option first');assert.equal(task.askUser.options[0].recommended,true);
 const askRecord=task.records.find(r=>r.name==='ask_user');assert.equal(askRecord.status,'success');
 await engine.answerAsk('沙箱');
 task=engine.current;assert.equal(task.askUser,undefined);assert.equal(task.status,'completed');
 assert.ok(session.messages.some(m=>m.role==='user'&&m.text==='沙箱'),'answer stored as user message');
 assert.equal(seen.length,2);
 assert.ok(seen[1].catalog!==undefined);

 // 5. 记忆：保存后进入后续请求的宿主状态，可按 key 删除
 seen=scripted(engine,[calls('memory_save',{text:'喜欢简短回答',key:'style'},'m1'),done('记住了')]);
 await engine.start('记住我喜欢简短回答','auto');
 assert.equal(state.memories.length,1);assert.equal(state.memories[0].key,'style');
 seen=scripted(engine,[done('好')]);await engine.start('你好','auto');
 assert.match(seen[0].memory,/喜欢简短回答/);
 engine.memoryDelete('style');assert.equal(state.memories.length,0);

 // 6. Skill：学会后启用；本任务读过第三方屏幕后保存则默认停用
 // 残留的第三方窗口快照不算本任务读屏：没有 observe 的任务保存的 Skill 仍启用
 device.latest={snapshotId:'stale',width:1,height:1,elements:[{elementId:'x',type:'Text',text:'旧页面',id:'',description:'',parent:'',bounds:[0,0,1,1],normalizedCenter:[0,0],enabled:true,editable:false,focused:false,password:false,clickable:false,window:'com.third.party.app',labelSource:''}]};
 seen=scripted(engine,[calls('skill_save',{name:'back-to-self',description:'回到大肥鱼',whenToUse:'要回到大肥鱼时',body:'1. 返回桌面 2. 点大肥鱼图标'},'s1'),done('已学会')]);
 await engine.start('学一下回到大肥鱼','auto');
 assert.equal(state.skills.find(s=>s.name==='back-to-self').enabled,true);
 seen=scripted(engine,[calls('observe',{},'o1'),calls('skill_save',{name:'from-screen',description:'屏幕内容',whenToUse:'测试',body:'内容'},'s2'),done('完成')]);
 await engine.start('读屏幕后学习','auto');
 const fromScreen=state.skills.find(s=>s.name==='from-screen');
 assert.equal(fromScreen.external,true,'skill written after reading third-party screen is external');assert.equal(fromScreen.enabled,false);
 seen=scripted(engine,[done('列表')]);
 engine.model.next=async(p,key,s,t,o,defs,catalog)=>{assert.match(catalog,/back-to-self: 回到大肥鱼（适用：要回到大肥鱼时）/);assert.ok(!/from-screen/.test(catalog),'disabled skill not in catalog');return done('ok');};
 await engine.start('看看目录','auto');
 engine.skillSetEnabled('from-screen',true);assert.equal(fromScreen.enabled,true);
 engine.skillUndo('from-screen');assert.equal(state.skills.some(s=>s.name==='from-screen'),false);

 // 7. 剪贴板：非危险，直接写入
 seen=scripted(engine,[calls('clipboard_write',{text:'复制这段'},'c1'),done('已复制')]);
 await engine.start('复制一段文字','auto');
 assert.deepEqual(JSON.parse(JSON.stringify(clipboard)).slice(-1),['复制这段']);
 assert.equal(engine.current.records.find(r=>r.name==='clipboard_write').status,'success');

 // 8. 文件：file_write 生成 txt、file_read 读窗口、坏 JSON 被拒且不写入；file_list 带来源与调用编号
 seen=scripted(engine,[calls('file_write',{name:'notes.md',content:'# 标题\n第二行\n第三行'},'fw1'),done('已写入')]);
 await engine.start('写一个笔记','auto');
 const write=engine.current.records.find(r=>r.name==='file_write');
 assert.equal(write.status,'success');assert.equal(write.verification,'verified');assert.doesNotMatch(write.result,/自动读回/,'text files are not read back as office files');
 const fileId=JSON.parse(write.result).fileId;assert.ok(fileId);
 seen=scripted(engine,[calls('file_read',{fileId:fileId,offset:2,limit:1},'fr1'),done('读到了')]);
 await engine.start('读第二行','auto');
 const read=engine.current.records.find(r=>r.name==='file_read');assert.equal(read.status,'success');assert.match(read.result,/     2\t第二行/);assert.match(read.result,/offset=3/);
 seen=scripted(engine,[calls('file_write',{name:'data.json',content:'{"a":'},'fw2'),done('失败说明')]);
 await engine.start('写坏的 JSON','auto');
 const badJson=engine.current.records.find(r=>r.name==='file_write');assert.equal(badJson.status,'error');assert.equal(badJson.errorCode,'PARAMETER');
 assert.equal(engine.files.list(session).some(f=>f.name==='data.json'),false,'invalid json is never stored');
 seen=scripted(engine,[calls('file_list',{},'fl1'),done('列出')]);
 await engine.start('列出文件','auto');
 const listed=engine.current.records.find(r=>r.name==='file_list');
 const items=JSON.parse(listed.result);const mine=items.find((x)=>x.fileId===fileId);
 assert.ok(mine,'file_list returns generated file');assert.equal(mine.origin,'generated');assert.equal(mine.callId,'fw1');assert.ok(mine.size>0,'size reported');
 assert.equal(items.some((x)=>x.name==='data.json'),false);

 // 9. get_capabilities：工具清单、应用、屏幕方向、时间
 seen=scripted(engine,[calls('get_capabilities',{},'g1'),done('能力')]);
 await engine.start('你能做什么','auto');
 const cap=engine.current.records.find(r=>r.name==='get_capabilities');
 assert.equal(cap.status,'success');assert.match(cap.result,/工具：/);assert.match(cap.result,/计算器  com\.huawei\.hmos\.calculator/);assert.match(cap.result,/横屏 2800×1840/);

 // 10. 没有文件时 file_list 给出说明而不是空数组
 const empty=new Engine(T.defaults(),store,makeDevice(),()=>{});
 const emptySession=empty.session();
 assert.equal(empty.files.listing(emptySession),'当前会话没有文件。');

 console.log('PASS: tool-text leak stripped and retried once, three-strike needs_user without device action, fenced examples exempt, ask_user pause and answer resume, memory injection and removal, skill external disable and undo, clipboard, file_write/file_read/file_list origin, invalid JSON rejected, get_capabilities text, empty file list message');
})().catch(e=>{console.error('FAIL',e);process.exitCode=1;}).finally(()=>fs.rmSync(scratch,{recursive:true,force:true}));
