// 0.8.3 阶段一：通用文件、Skill 与记忆、工具文字检测、应用目录与能力文本、ask_user 选项的纯逻辑测试。
const fs=require('fs'),vm=require('vm'),path=require('path'),assert=require('assert/strict'),os=require('os');
const ts=require(process.env.HVIGOR_TS||'typescript');
const cache=new Map();
const kit={'@kit.CoreFileKit':{fileIo:{}, picker:{}},'@kit.ArkTS':{buffer:Buffer,util:{}},'@kit.AbilityKit':{},'@kit.BasicServicesKit':{zlib:{},pasteboard:{}},'@kit.BackgroundTasksKit':{backgroundTaskManager:{}}};
function load(file){file=path.resolve(file);if(cache.has(file))return cache.get(file);const module={exports:{}};vm.runInNewContext(ts.transpileModule(fs.readFileSync(file,'utf8'),{compilerOptions:{module:ts.ModuleKind.CommonJS,target:ts.ScriptTarget.ES2020}}).outputText,{module,exports:module.exports,require:n=>n.startsWith('.')?load(path.resolve(path.dirname(file),n+'.ets')):(kit[n]??{}),setTimeout,clearTimeout,Uint8Array,ArrayBuffer,Map,Buffer,Date,JSON,RegExp});cache.set(file,module.exports);return module.exports;}
const root='entry/src/main/ets/agent/';
const {DeviceError}=load(root+'Elements.ets');
const T=load(root+'Types.ets');
const TF=load(root+'TextFiles.ets');
const SS=load(root+'SkillStore.ets');
const M=load(root+'Memory.ets');
const G=load(root+'ToolTextGuard.ets');
const AC=load(root+'AppCatalog.ets');
const CAP=load(root+'Capabilities.ets');
const LT=load(root+'LocalTools.ets');
// vm 沙箱内对象与主进程 realm 不同，比较前经 JSON 转换。
const deq=(actual,expected)=>assert.deepEqual(JSON.parse(JSON.stringify(actual)),expected);
const code=(fn)=>{try{fn();return null;}catch(e){return e;}};
const expectError=(fn,codeName,pattern)=>{const e=code(fn);assert.ok(e,'expected error '+codeName);assert.ok(e instanceof DeviceError,'expected DeviceError, got '+(e&&e.message));assert.equal(e.code,codeName);if(pattern)assert.match(e.message,pattern);};

// ---- 通用文件：文件名、类型、写入校验、行号窗口
assert.equal(TF.cleanName('../../etc/passwd.txt'),'passwd.txt');
assert.equal(TF.cleanName('C:\\temp\\a<b>.md'),'a_b_.md');
assert.equal(TF.cleanName('..hidden.txt'),'hidden.txt');
assert.equal(TF.prepareTextName('笔记'),'笔记.txt');
assert.equal(TF.prepareTextName('data.JSON'),'data.JSON');
expectError(()=>TF.prepareTextName('run.exe'),'PARAMETER',/不支持的文件类型/);
expectError(()=>TF.prepareTextName('..\\'),'PARAMETER',/文件名无效/);
TF.validateTextWrite('a.json','{"ok":1}','utf-8');
expectError(()=>TF.validateTextWrite('a.json','{"ok":',"utf-8"),'PARAMETER',/JSON 不合法/);
expectError(()=>TF.validateTextWrite('a.txt','x','gbk'),'PARAMETER',/utf-8/);
expectError(()=>TF.validateTextWrite('a.txt','字'.repeat(700000),'utf-8'),'PARAMETER',/2 MB/);
assert.equal(TF.utf8Length('a字😀'),1+3+4);
const sample=Array.from({length:5},(_,i)=>'第'+(i+1)+'行').join('\n')+'\n';
const first=TF.lineWindow(sample,1,2);assert.equal(first.total,5);assert.equal(first.next,3);assert.match(first.text,/offset=3/);assert.match(first.text,/     1\t第1行/);
const rest=TF.lineWindow(sample,3);assert.equal(rest.next,-1);assert.match(rest.text,/第5行/);assert.doesNotMatch(rest.text,/offset=/);
expectError(()=>TF.lineWindow(sample,9),'PARAMETER',/超过文件末尾/);
expectError(()=>TF.lineWindow(sample,0),'PARAMETER',/offset/);
assert.match(TF.lineWindow('x'.repeat(2500)).text,/本行过长已截断/);

// ---- Skill：名称、版本、冲突、回滚、启停、目录
const state=T.defaults();
state.skills.push({id:'imp',name:'import-only',description:'导入的',body:'旧',enabled:true,references:[],folder:'',scripts:false});
const input=(over)=>Object.assign({name:'back-to-self',description:'回到大肥鱼',whenToUse:'需要回到大肥鱼时',body:'1. 返回桌面\n2. 找大肥鱼图标',external:false},over);
expectError(()=>SS.saveSkill(state,input({name:'Bad_Name'}),1),'PARAMETER',/kebab-case/);
expectError(()=>SS.saveSkill(state,input({name:'a--b'}),1),'PARAMETER',/kebab-case/);
expectError(()=>SS.saveSkill(state,input({whenToUse:''}),1),'PARAMETER',/whenToUse/);
expectError(()=>SS.saveSkill(state,input({body:'字'.repeat(6000)}),1),'PARAMETER',/16 KB/);
expectError(()=>SS.saveSkill(state,input({name:'import-only'}),1),'CONFLICT',/导入/);
const created=SS.saveSkill(state,input({}),100);assert.equal(created.created,true);assert.equal(created.version,1);assert.equal(state.skills.find(s=>s.name==='back-to-self').enabled,true);
expectError(()=>SS.saveSkill(state,input({body:'新版',baseVersion:9}),200),'CONFLICT',/baseVersion/);
for(let i=2;i<=8;i++)SS.saveSkill(state,input({body:'版本'+i,baseVersion:i-1}),300+i);
const kept=state.skills.find(s=>s.name==='back-to-self');
assert.equal(kept.version,8);assert.equal(kept.history.length,4,'history keeps 4 previous versions plus current = 5');
assert.equal(kept.history[0].version,4);
const rolled=SS.rollbackSkill(state,'back-to-self',5);assert.equal(rolled.body,'版本5');assert.equal(rolled.version,9);assert.ok(rolled.history.every(v=>v.version!==5));assert.ok(rolled.history.length<=4);
expectError(()=>SS.rollbackSkill(state,'back-to-self',1),'NOT_FOUND',/没有这个版本/);
// 外部来源：默认停用，启用后生效
const external=SS.saveSkill(state,input({name:'from-web',body:'来自网页',external:true}),400);assert.equal(external.external,true);assert.equal(state.skills.find(s=>s.name==='from-web').enabled,false);
assert.ok(!SS.skillDirectory(state).includes('from-web'));
SS.setSkillEnabled(state,'from-web',true);assert.ok(SS.skillDirectory(state).includes('from-web: 回到大肥鱼'));
assert.match(SS.skillDirectory(state),/（适用：需要回到大肥鱼时）/);
assert.equal(SS.undoSkill(state,'from-web'),'已删除');assert.equal(state.skills.some(s=>s.name==='from-web'),false);
assert.equal(SS.undoSkill(state,'back-to-self'),'已回到 v8');
const summaries=SS.skillSummaries(state);assert.equal(summaries.find(s=>s.name==='import-only').origin,'导入');assert.equal(summaries.find(s=>s.name==='back-to-self').origin,'大肥鱼写的');
assert.equal(SS.externalWindow('com.example.app','com.harmonyloom.selfhdcprobe'),true);
assert.equal(SS.externalWindow('com.harmonyloom.selfhdcprobe','com.harmonyloom.selfhdcprobe'),false);
assert.equal(SS.externalWindow('com.ohos.systemui','com.harmonyloom.selfhdcprobe'),false);
assert.equal(SS.externalWindow(undefined,'x'),false);
SS.deleteSkill(state,'import-only');assert.equal(state.skills.some(s=>s.name==='import-only'),false);

// ---- 记忆：单条、总长、覆盖、删除
const mem=[];
M.saveMemory(mem,'喜欢简短回答',undefined,1);
assert.equal(mem.length,1);assert.match(M.memoryBlock(mem),/关于用户/);
M.saveMemory(mem,'喜欢中文','lang',2);M.saveMemory(mem,'喜欢中文回答','lang',3);
assert.equal(mem.filter(m=>m.key==='lang').length,1);assert.equal(mem.find(m=>m.key==='lang').text,'喜欢中文回答');
expectError(()=>M.saveMemory(mem,'字'.repeat(201),undefined,4),'PARAMETER',/200/);
expectError(()=>M.saveMemory(mem,'x',' bad key!',4),'PARAMETER',/key/);
const big=[];for(let i=0;i<10;i++)M.saveMemory(big,'字'.repeat(200),'k'+i,i);
assert.equal(M.memoryTotal(big),2000);
expectError(()=>M.saveMemory(big,'新',undefined,11),'MEMORY_FULL',/2000/);
M.saveMemory(big,'字'.repeat(200),'k0',12);
assert.equal(M.memoryTotal(big),2000,'overwrite replaces the old text instead of adding');
M.forgetMemory(mem,'lang');assert.equal(mem.some(m=>m.key==='lang'),false);
expectError(()=>M.forgetMemory(mem,'missing'),'NOT_FOUND',/没有这条记忆/);
assert.equal(M.memoryBlock([]),'');

// ---- 工具文字检测：正文泄漏要剔除、代码示例不误判
const names=['click','observe','finish_task','file_write'];
const leaked=G.toolTextGuard('好的，我来点击。\n<tool_call>{"name":"click","arguments":{"x":1}}</tool_call>',names);
assert.equal(leaked.leaked,true);assert.equal(leaked.cleaned,'好的，我来点击。');assert.match(leaked.marker,/tool_call/);
assert.equal(G.toolTextGuard('<function_calls><invoke name="observe"></invoke></function_calls>',names).leaked,true);
assert.equal(G.toolTextGuard('{"name":"observe","arguments":{}}',names).leaked,true);
assert.equal(G.toolTextGuard('finish_task({"outcome":"success"})',names).leaked,true);
const example='下面是 JSON 写法示例：\n```json\n{"name":"click","arguments":{"x":1}}\n<tool_call>demo</tool_call>\n```\n以上只是示例。';
assert.equal(G.toolTextGuard(example,names).leaked,false,'fenced examples are not tool calls');
assert.equal(G.toolTextGuard('可以用 `<tool_call>` 标签，但我没有调用。',names).leaked,false,'inline code is not a tool call');
assert.equal(G.toolTextGuard('普通回答：计算结果是 15。',names).leaked,false);
assert.equal(G.toolTextGuard('```\n<invoke name="click">\n',names).leaked,false,'unclosed fence is code');
assert.equal(G.toolTextGuard('文字里提到 click 工具但没有括号',names).leaked,false);
assert.equal(G.toolTextGuard('',names).leaked,false);

// ---- 应用目录：解析（输出格式待真机核对）与缓存差分
// 以下 bm dump 样例为按官方文档编写的假设格式，待真机核对。
const bmA='bundleNames:\n  com.huawei.hmos.calculator\n  com.harmonyloom.selfhdcprobe\n  com.huawei.hmos.calculator\n  bad token\n  1.0.0\n';
deq(AC.parseBundleList(bmA),['com.huawei.hmos.calculator','com.harmonyloom.selfhdcprobe']);
// 待真机核对：bm dump -n 的 label 与 mainAbility 字段。
const bmN='{"bundleName":"com.huawei.hmos.calculator","label":"计算器","mainAbility":"MainAbility"}';
deq(AC.parseBundleInfo(bmN,'com.huawei.hmos.calculator'),{bundle:'com.huawei.hmos.calculator',label:'计算器',ability:'MainAbility'});
assert.equal(AC.parseBundleInfo('label: $string:app_name\nmainAbility: EntryAbility','com.x.y').label,'');
assert.equal(AC.parseBundleInfo('label: $string:app_name\nmainAbility: EntryAbility','com.x.y').ability,'EntryAbility');
deq(AC.diffBundles(['a.b.c','d.e.f'],['d.e.f','g.h.i']),{added:['g.h.i'],removed:['a.b.c']});
const cacheObj=new AC.AppCatalogCache();
deq(cacheObj.planFetch(['a.b.c','d.e.f']),['a.b.c','d.e.f']);
cacheObj.commit(['a.b.c','d.e.f'],[{bundle:'a.b.c',label:'A',ability:'MainAbility'}],1000);
deq(cacheObj.planFetch(['a.b.c','d.e.f']),['d.e.f'],'known bundles are not fetched again');
assert.equal(cacheObj.fresh(1000+AC.CATALOG_TTL_MS-1),true);assert.equal(cacheObj.fresh(1000+AC.CATALOG_TTL_MS),false);
cacheObj.commit(['d.e.f'],[],2000);assert.equal(cacheObj.list().length,0,'removed bundles leave the cache');

// ---- 能力文本
const capText=CAP.capabilitiesText({tools:['click','file_write'],apps:[{bundle:'com.huawei.hmos.calculator',label:'计算器',ability:'MainAbility'},{bundle:'com.x.y',label:'',ability:''}],appsNote:'待真机核对',width:2800,height:1840,network:'未检测',now:new Date(2026,9,8,12,30)});
assert.match(capText,/工具：click、file_write/);assert.match(capText,/横屏 2800×1840/);assert.match(capText,/计算器  com\.huawei\.hmos\.calculator  \[MainAbility\]/);assert.match(capText,/名称未知/);assert.match(capText,/2026-10-08 12:30/);
assert.equal(CAP.orientationText(0,0),'未知');assert.match(CAP.orientationText(1840,2800),/竖屏/);

// ---- ask_user 选项：推荐项排第一、最多 4 项、长度限制；新工具分类
const opts=LT.parseAskOptions(JSON.stringify([{label:'A',impact:'a影响'},{label:'B',impact:'b影响',recommended:true},{label:'C',impact:'c影响',recommended:true}]));
assert.equal(opts[0].label,'B');assert.equal(opts[0].recommended,true);assert.equal(opts[1].recommended,false);assert.equal(opts.filter(o=>o.recommended).length,1);assert.equal(opts.length,3);
expectError(()=>LT.parseAskOptions('[1,2,3,4,5]'),'PARAMETER',/最多 4/);
expectError(()=>LT.parseAskOptions('{}'),'PARAMETER',/数组/);
expectError(()=>LT.parseAskOptions('[{"label":"","impact":"x"}]'),'PARAMETER',/label/);
expectError(()=>LT.parseAskOptions('[{"label":"ok","impact":"'+'字'.repeat(61)+'"}]'),'PARAMETER',/impact/);
deq(LT.parseAskOptions(undefined),[]);
expectError(()=>LT.parseAskQuestion('  '),'PARAMETER',/不能为空/);
const defs=LT.generalDefinitions([]);
const byName=(n)=>defs.find(d=>d.name===n);
assert.equal(byName('skill_list').readOnly,true);assert.equal(byName('skill_save').readOnly,false);assert.equal(byName('ask_user').readOnly,true);
deq(byName('skill_save').parameters.required,['name','description','whenToUse','body']);
assert.equal(LT.generalDefinitions(['memory_save']).find(d=>d.name==='memory_save').enabled,false);
for(const n of LT.LOCAL_TOOL_NAMES)assert.ok(byName(n)||n==='x','missing '+n);
console.log('PASS: general file limits and line windows, skill versions/conflicts/rollback/external disable, memory limits, tool-text guard with code-fence exemptions, app catalog parsing (format pending device check), capability text, ask_user option ordering');
