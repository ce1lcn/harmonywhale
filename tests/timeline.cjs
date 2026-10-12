const fs=require('fs'),vm=require('vm'),assert=require('assert/strict');
const ts=require(process.env.HVIGOR_TS||'typescript');
function load(file){const module={exports:{}};const js=ts.transpileModule(fs.readFileSync(file,'utf8'),{compilerOptions:{module:ts.ModuleKind.CommonJS,target:ts.ScriptTarget.ES2020}}).outputText;vm.runInNewContext(js,{module,exports:module.exports,require:n=>n==='../agent/Markdown'?load('entry/src/main/ets/agent/Markdown.ets'):({}),Number,JSON,Date,Math,parseInt,RegExp});return module.exports;}
const T=load('entry/src/main/ets/pages/Timeline.ets');
assert.equal(T.toolItem({id:'launch',name:'launch_app',args:'{"appId":"com.huawei.hmos.notepad"}',result:'ok',status:'success',time:1,observation:'',appName:'备忘录'}).summary,'打开 备忘录');
const base=Date.now()-3600000;
const rec=(id,name,args,t,status)=>({id,name,args,result:'No Error',status,time:t,observation:'x',providerReasoning:id==='a'?'先看屏幕':undefined});
const session={id:'s',title:'t',messages:[
 {role:'user',text:'打开计算器',time:base+5},{role:'assistant',text:'先回到桌面',time:base+100},{role:'assistant',text:'**已**完成 `7+8`',time:base+9000},
 {role:'user',text:'再算 1+1',time:base+50000}],
 tasks:[{id:base.toString(36)+'-aaaaaa',goal:'打开计算器',constraints:[],status:'completed',summary:'',calls:2,reason:'x',records:[rec('a','home','{}',base+200,'success'),rec('b','click','{"x":500.4,"y":10}',base+500,'success')]},
 {id:(base+50000).toString(36)+'-bbbbbb',goal:'再算 1+1',constraints:[],status:'paused',summary:'',calls:1,reason:'后台额度到期',records:[rec('c','insert_text','{"text":"1+1"}',base+52000,'uncertain')]}]};
const kinds=l=>JSON.stringify(l.map(i=>i.kind));
let tl=T.buildTimeline(session,[]);
assert.equal(kinds(tl),JSON.stringify(['user','taskhead','assistant','think','tool','tool','assistant','actions','user','taskhead','tool','note']));
assert.equal(tl[4].label,'回到桌面');assert.equal(tl[3].text,'先看屏幕');assert.equal(tl[5].summary,'(500, 10)');assert.equal(tl[10].summary,'「1+1」');
assert.equal(tl[1].summary,'已结束／结果未分类，用时 9秒');assert.equal(tl[11].text,'已暂停：后台额度到期');assert.equal(tl[7].text,'**已**完成 `7+8`');assert.equal(tl[7].id,session.tasks[0].id);
// Three or more consecutive operations fold by default, and open on demand.
session.tasks[0].records.push(rec('extra','back','{}',base+700,'success'));
tl=T.buildTimeline(session,[]);assert.equal(tl.filter(i=>i.id==='a').length,0);assert.equal(tl.filter(i=>i.id==='k:a').length,1);assert.equal(tl.filter(i=>i.kind==='group').length,1);
tl=T.buildTimeline(session,['open:g:a']);assert.equal(tl.filter(i=>i.kind==='tool').length,4);assert.match(tl.find(i=>i.kind==='group').summary,/操作了 3 步/);
// 折叠任务：只留用户消息、任务头和最后一条助手回复
tl=T.buildTimeline(session,['t:'+session.tasks[0].id]);assert.equal(kinds(tl.slice(0,5)),JSON.stringify(['user','taskhead','assistant','actions','user']));assert.equal(tl[2].text,'**已**完成 `7+8`');assert.equal(tl.filter(i=>i.id==='g:a').length,0);
session.tasks[1].status='running';tl=T.buildTimeline(session,[]);assert.equal(tl[tl.length-1].kind,'tool');assert.match(tl.filter(i=>i.kind==='taskhead')[1].summary,/^执行中，已用/);
assert.equal(T.formatDuration(36*60000+27000),'36分27秒');assert.equal(T.formatTokens(222000),'222K');assert.equal(T.formatTokens(2858811),'2.9M');assert.equal(T.formatTokens(950),'950');assert.equal(T.groupDigits(2858811),'2,858,811');assert.match(T.formatClock(Date.now()),/^\d\d:\d\d$/);assert.equal(T.formatDuration(9000),'9秒');
const gs=T.groupSessions([{id:'a-1',title:'今天的',messages:[{role:'user',text:'你好',time:Date.now()}],tasks:[]},{id:'b-1',title:'旧的',messages:[{role:'user',text:'abc',time:Date.now()-40*86400000}],tasks:[]}],'');
assert.equal(JSON.stringify(gs.map(g=>g.label)),JSON.stringify(['今天','更早']));assert.equal(T.groupSessions([{id:'a-1',title:'x',messages:[{role:'user',text:'ABC',time:Date.now()}],tasks:[]}],'abc').length,1);
const pin=T.groupSessions([{id:'a-1',title:'普通',messages:[{role:'user',text:'x',time:Date.now()}],tasks:[]},{id:'b-1',title:'置顶的',pinned:true,messages:[{role:'user',text:'y',time:Date.now()-40*86400000}],tasks:[]}],'');
assert.equal(JSON.stringify(pin.map(g=>g.label)),JSON.stringify(['置顶','今天']));assert.equal(pin[0].items[0].title,'置顶的');
const rich=T.parseRich('# 标题\n- 第一\n普通 **粗** 和 `码`\n```\na\nb\n```');
assert.equal(JSON.stringify(rich.map(b=>b.kind)),JSON.stringify(['h','bullet','p','code']));assert.equal(rich[2].spans[1].bold,true);assert.equal(rich[3].text,'a\nb');
assert.equal(T.ago(Date.now()-3*60000),'3分钟');
console.log('PASS: timeline merge, task/group folding, session grouping and rich text');
const webRecord={...rec('web-only','web_fetch','{"url":"https://public.example"}',base+100,'success'),sources:[{title:'公开来源',domain:'public.example',url:'https://public.example'}]};
const webSession={id:'web-session',title:'联网',messages:[{role:'user',text:'查资料',time:base,taskId:'web-task'}],tasks:[{id:'web-task',goal:'查资料',constraints:[],status:'completed',reason:'',calls:1,summary:'',records:[webRecord]}]};
let webTimeline=T.buildTimeline(webSession,[]);assert.equal(webTimeline.filter(i=>i.kind==='tool').length,0);assert.equal(webTimeline.find(i=>i.kind==='group').summary,'查了 1 个网页');
webTimeline=T.buildTimeline(webSession,['open:g:web-only']);assert.equal(webTimeline.find(i=>i.kind==='tool').sources[0].title,'公开来源');
