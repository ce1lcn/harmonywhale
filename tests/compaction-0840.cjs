// 0.8.4 B6：压缩改进。压缩请求 = 原样回放前缀（系统提示 + 被压缩的那段历史 + 同一份工具列表）+ 末尾一条压缩指令；
// 固定的中文五节摘要、再次压缩合并旧摘要、旧的超大工具结果头尾修剪、缓存命中率记录，以及可切回 0.8.3 的旧方式用于对比。
const fs=require('fs'),vm=require('vm'),path=require('path'),os=require('os'),assert=require('assert/strict');
const ts=require(process.env.HVIGOR_TS||'typescript');
const scratch=fs.mkdtempSync(path.join(os.tmpdir(),'whale-compact-0840-'));
const cache=new Map();
const kit={'@kit.BackgroundTasksKit':{backgroundTaskManager:{requestSuspendDelay:()=>({requestId:1,actualDelayTime:180000}),cancelSuspendDelay(){}}},'@kit.NetworkKit':{http:{RequestMethod:{POST:'POST'},HttpDataType:{STRING:1},createHttp:()=>({destroy(){}})}},'@kit.CoreFileKit':{fileIo:{OpenMode:{},accessSync:()=>false,mkdirSync(){},statSync:()=>({size:0})},picker:{}},'@kit.BasicServicesKit':{zlib:{},pasteboard:{}},'@kit.ArkTS':{buffer:Buffer,util:{}},'@kit.AbilityKit':{},'@kit.ImageKit':{},'@kit.CryptoArchitectureKit':{},'@kit.UniversalKeystoreKit':{}};
function load(file){file=path.resolve(file);if(cache.has(file))return cache.get(file);const module={exports:{}};const js=ts.transpileModule(fs.readFileSync(file,'utf8'),{compilerOptions:{module:ts.ModuleKind.CommonJS,target:ts.ScriptTarget.ES2020}}).outputText;vm.runInNewContext(js,{module,exports:module.exports,require:n=>n.startsWith('.')?load(path.resolve(path.dirname(file),n+'.ets')):kit[n],setTimeout:(cb,ms)=>ms>5000?0:setTimeout(cb,0),clearTimeout,Uint8Array,ArrayBuffer,Map,Set,Buffer,Date,JSON,RegExp,Promise,Math,Number,Object,Array,String,Error});cache.set(file,module.exports);return module.exports;}
const root='entry/src/main/ets/agent/';
const T=load(root+'Types.ets'),{Engine}=load(root+'Engine.ets'),CV=load(root+'Conversation.ets'),CP=load(root+'Compaction.ets');
const deq=(a,b,m)=>assert.deepEqual(JSON.parse(JSON.stringify(a)),JSON.parse(JSON.stringify(b)),m);
let finished=false;process.on('exit',()=>{if(!finished&&!process.exitCode){console.error('测试没有跑完就退出');process.exitCode=1;}});
const text=(i)=>'第'+i+'条消息：'+'这是一段比较长的对话内容用来占上下文。'.repeat(8);
function makeDevice(){return {hdc:{ready:true},width:2800,height:1840,mutationCount:0,latest:null,invalidate(){},sensitive:()=>false,stable:async()=>{},reconnect:async()=>{},observe:async()=>({layout:'',snapshotId:'s',image:'',width:0,height:0,fingerprint:''}),execute:async()=>'ok',installedApps:async()=>({list:[],note:''})};}
function session(engine,count,from=0){
 const s=engine.session();
 for(let i=from;i<from+count;i++)s.messages.push({role:i%2?'assistant':'user',text:text(i),time:1000+i*10,taskId:'t1'});
 return s;
}
const OBS={layout:'',image:'',snapshotId:'x',width:0,height:0,fingerprint:''};
(async()=>{
 const state=T.defaults();state.skills=[];state.compactReplay=true; // 0.8.5 默认旧方式；此段显式测试回放选项
 const store={root:scratch,read:p=>fs.readFileSync(p,'utf8'),save(){},secret:async()=>'x'};
 const engine=new Engine(state,store,makeDevice(),()=>{});
 const s=session(engine,30);
 const big='行'.repeat(30000);
 const mk=(id,time,result)=>({id:id,name:'web_fetch',args:'{"url":"https://x"}',result:result,status:'success',time:time,observation:'',batchId:'b'+id});
 s.tasks=[{id:'t1',mode:'auto',goal:'g',constraints:[],status:'completed',summary:'',calls:12,reason:'',records:[mk('r1',1005,big),mk('r2',1025,'行'.repeat(9000)),mk('r3',1045,'短结果三'),mk('r4',1065,'短结果四'),...[5,6,7,8,9,10,11,12].map(i=>mk('r'+i,2000+i,'晚结果'+i))]}];
 const profile=state.profiles[0];assert.equal(profile.thinking,'enabled');
 const probe={id:'z',mode:'auto',goal:'g',status:'running',records:[],constraints:[],summary:'',calls:0,reason:''};
 const Model=load(root+'Model.ets').Model;const m=new Model();
 // ---- 修剪：旧的超大工具结果只保留头尾；limit 内原样
 const before=m.build(profile,s,probe,OBS,engine.definitions,'');
 const toolMsg=before.messages.find(x=>x.role==='tool'&&x.tool_call_id==='r1');
 assert.ok(toolMsg.content.length<16384+200,'修剪后不超过限额附近：'+toolMsg.content.length);assert.ok(toolMsg.content.length>15000);assert.match(toolMsg.content,/工具结果中间省略 \d+ 字/);assert.match(toolMsg.content,/上下文为预览/);assert.ok(toolMsg.content.startsWith('success: 行行'));assert.ok(toolMsg.content.includes('行'.repeat(500)+'\n[上下文为预览'),'尾部保留');
 assert.equal(before.messages.find(x=>x.role==='tool'&&x.tool_call_id==='r2').content.indexOf('中间省略'),-1,'限额内的结果不动');
 assert.equal(CP.HISTORY_RESULT_LIMIT,load(root+'Spill.ets').SPILL_THRESHOLD_CHARS,'历史上限与转存阈值对齐');
 assert.equal(CP.pruneMiddle('短',4000),'短');const pm=CP.pruneMiddle('甲'.repeat(10000),4000);assert.ok(pm.length<=4000+40);assert.ok(pm.startsWith('甲'.repeat(3000)));
 // ---- 摘要整理
 const full=CP.normalizeSummary('## 目标\n- 做表格\n## 用户偏好\n- 简短');
 assert.ok(CP.hasAllSections(full));assert.match(full,/## 已完成\n- （无）/);assert.match(full,/## 目标\n- 做表格/);assert.ok(full.indexOf('## 目标')<full.indexOf('## 已完成')&&full.indexOf('## 未完成与下一步')<full.indexOf('## 用户偏好'));
 const loose=CP.normalizeSummary('<compacted-summary>\n没有按结构写的一段话\n</compacted-summary>');assert.match(loose,/## 关键事实与文件\n没有按结构写的一段话/);assert.ok(!loose.includes('compacted-summary'));assert.equal(CP.normalizeSummary(full),full,'幂等');
 assert.equal(CP.hitText(undefined),'缓存命中：无数据');assert.match(CP.hitText({input:200,cacheRead:1800,cacheWrite:0,output:300,total:2300,calls:1,model:'m'}),/缓存命中 90\.0%/);
 // ---- 回放前缀的压缩请求
 const captured=[];const SUMMARY='## 目标\n- 做三步任务\n\n## 已完成\n- 搜索了资料\n\n## 关键事实与文件\n- fileId=abc\n\n## 未完成与下一步\n- 写总结\n\n## 用户偏好\n- 简短';
 engine.model.request=async(p,key,messages,tools)=>{captured.push({p:p,messages:messages,tools:tools});if(engine.model.onUsage)engine.model.onUsage({input:200,cacheRead:1800,cacheWrite:0,output:300,total:2300,calls:1,model:'m'});return {text:SUMMARY,calls:[],incomplete:false};};
 await engine.compress();
 let c=captured[0];assert.ok(c,'压缩请求发出了');
 assert.equal(c.messages[0].role,'system');assert.equal(c.messages[0].content,CV.CHAT_RULES,'系统提示与普通请求相同');
 const last=c.messages[c.messages.length-1];assert.equal(last.role,'user');assert.equal(last.content,CP.COMPACT_INSTRUCTION,'末尾是一条压缩指令');
 const region=c.messages.slice(0,-1);
 deq(region,before.messages.slice(0,region.length),'回放的部分是普通请求前缀的原样一段（可复用前缀缓存）');
 assert.ok(region.length>=1+18,'含被压缩的那段历史：'+region.length);assert.ok(region.length<before.messages.length-3,'不含尾部保留的内容');
 assert.ok(region.some(x=>x.role==='tool'&&x.tool_call_id==='r1'),'被压缩的工具记录在前缀里');assert.ok(!region.some(x=>x.role==='tool'&&x.tool_call_id==='r12'),'晚的记录不在前缀里');
 deq(c.tools,before.tools,'工具列表与普通请求相同');
 assert.equal(c.p.thinking,'enabled','沿用思考设置（提示词前缀才一致）');assert.equal(c.p.outputTokens,CP.COMPACT_OUTPUT_TOKENS);assert.equal(c.p.effort,'low');
 for(const name of CP.SUMMARY_SECTIONS)assert.ok(CP.COMPACT_INSTRUCTION.includes('## '+name),'指令含小节 '+name);
 const ctx=s.context;assert.ok(ctx);assert.equal(ctx.method,'replay');assert.ok(CP.hasAllSections(ctx.summary),'摘要是固定五节');assert.equal(ctx.usage.cacheRead,1800);assert.match(CP.hitText(ctx.usage),/90\.0%/);assert.equal(ctx.through,18);
 // 压缩后的普通请求：摘要用 <compacted-summary> 包着，排在系统提示之后第一条
 const after=m.build(profile,s,probe,OBS,engine.definitions,'');
 assert.match(after.messages[1].content,/<compacted-summary>[\s\S]*做三步任务[\s\S]*<\/compacted-summary>/);assert.ok(!JSON.stringify(after.messages).includes('第0条消息'));
 // ---- 再次压缩：合并旧摘要（旧摘要在回放前缀里，指令要求合并）
 session(engine,20,30);
 s.tasks[0].records.push(mk('r13',1500,'新的中间结果'));
 captured.length=0;await engine.compress();c=captured[0];assert.ok(c);
 assert.match(c.messages[1].content,/<compacted-summary>[\s\S]*做三步任务/,'前缀含上一份摘要');
 assert.match(CP.COMPACT_INSTRUCTION,/不要原样抄，保留仍然成立的内容、去掉过时的、把新信息合并进同一份五节摘要/);
 assert.equal(c.messages[c.messages.length-1].content,CP.COMPACT_INSTRUCTION);
 assert.equal(s.contextHistory.length,1,'旧摘要进历史');assert.ok(s.context.through>18);
 // ---- 摘要不合格：缺小节自动补齐；模型没写完则保留原上下文
 session(engine,20,50);
 engine.model.request=async()=>({text:'## 目标\n- 只写了目标',calls:[],incomplete:false});const throughBefore=s.context.through;
 await engine.compress();assert.match(s.context.summary,/## 用户偏好\n- （无）/);assert.ok(CP.hasAllSections(s.context.summary));
 session(engine,20,70);const kept=s.context;
 engine.model.request=async()=>({text:'半截',calls:[],incomplete:true});await assert.rejects(()=>engine.compress(),/摘要未完成/);assert.equal(s.context,kept,'失败时保留原上下文');
 // ---- 旧方式（0.8.3）：compactReplay=false，用于缓存命中率对比
 state.compactReplay=false;captured.length=0;
 engine.model.request=async(p,key,messages,tools)=>{captured.push({p:p,messages:messages,tools:tools});if(engine.model.onUsage)engine.model.onUsage({input:1900,cacheRead:100,cacheWrite:0,output:300,total:2300,calls:1,model:'m'});return {text:SUMMARY,calls:[],incomplete:false};};
 await engine.compress();c=captured[0];assert.equal(c.messages.length,2,'旧方式：独立短系统提示 + JSON 输入');assert.match(c.messages[0].content,/压缩较早历史/);assert.notEqual(c.messages[0].content,CV.CHAT_RULES);assert.equal(c.p.thinking,'disabled','旧方式关闭思考');
 assert.equal(s.context.method,'legacy');assert.match(CP.hitText(s.context.usage),/5\.0%/);assert.equal(s.context.summary,SUMMARY,'旧方式不整理摘要格式');
 finished=true;console.log('PASS: compaction-0840 (prefix replay identical to normal request, fixed Chinese sections, merge of prior summary, head/tail prune, hit-rate record, legacy switch)');
})().catch(e=>{console.error('FAIL',e);process.exitCode=1;}).finally(()=>fs.rmSync(scratch,{recursive:true,force:true}));
