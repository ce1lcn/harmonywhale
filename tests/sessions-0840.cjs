// 0.8.4 A4：侧边栏会话多选与批量删除的纯逻辑（界面在 pages/Index.ets，无法离线渲染；真机验证见验收文档）。
const fs=require('fs'),vm=require('vm'),path=require('path'),assert=require('assert/strict');
const ts=require(process.env.HVIGOR_TS||'typescript');
function load(file){const module={exports:{}};vm.runInNewContext(ts.transpileModule(fs.readFileSync(path.resolve(file),'utf8'),{compilerOptions:{module:ts.ModuleKind.CommonJS,target:ts.ScriptTarget.ES2020}}).outputText,{module,exports:module.exports,require:()=>({})});return module.exports;}
const B=load('entry/src/main/ets/agent/SessionBulk.ets');
const deq=(a,b,m)=>assert.deepEqual(JSON.parse(JSON.stringify(a)),b,m);
const mk=(id,title,pinned)=>({id:id,title:title,messages:[],tasks:[],pinned:pinned});
const list=[mk('a','测试一'),mk('b','测试二'),mk('c','我的重要会话',true),mk('d','测试三'),mk('e','测试四')];
deq(B.togglePicked([],'a'),['a']);deq(B.togglePicked(['a','b'],'a'),['b']);
deq(B.toggleGroup(['a'],['a','b','d']),['a','b','d'],'组内未全选：补齐');deq(B.toggleGroup(['a','b','d','c'],['a','b','d']),['c'],'组内已全选：取消这一组');deq(B.toggleGroup([],[]),[]);
deq(B.pruneSelection(['a','zzz','b'],list),['a','b']);
const plan=B.bulkPlan(list,['a','c','d'],'c');
deq(plan.ids,['a','c','d']);assert.equal(plan.pinned,1);assert.equal(plan.current,true);
assert.equal(B.confirmTitle(plan),'删除 3 个会话');assert.equal(B.confirmTitle(B.bulkPlan(list,['a'],'x')),'删除会话');
const msg=B.confirmMessage(plan);assert.match(msg,/将删除 3 个会话/);assert.match(msg,/· 测试一/);assert.match(msg,/其中 1 个是置顶会话/);assert.match(msg,/无法恢复/);
const many=Array.from({length:8},(_,i)=>mk('s'+i,'第'+i+'个'));const mm=B.confirmMessage(B.bulkPlan(many,many.map(x=>x.id),'s0'));assert.match(mm,/将删除 8 个会话/);assert.match(mm,/等共 8 个/);assert.equal(mm.split('\n').filter(l=>l.startsWith('· ')).length,5);
assert.ok(B.confirmMessage(B.bulkPlan([mk('x','很长很长很长很长很长很长很长很长很长很长很长很长很长很长的标题')],['x'],'x')).includes('…'),'长标题截断');
// 删除后：当前会话被删时选最后一个；全部删光补一个新会话；不删用户没选的
let r=B.afterDelete(list,['a','b','d','e'],'a',()=>mk('new','新会话'));deq(r.sessions.map(s=>s.id),['c']);assert.equal(r.selected,'c');
r=B.afterDelete(list,['a'],'c',()=>mk('new','新会话'));assert.equal(r.selected,'c');assert.equal(r.sessions.length,4);
r=B.afterDelete(list,list.map(s=>s.id),'a',()=>mk('new','新会话'));deq(r.sessions.map(s=>s.id),['new']);assert.equal(r.selected,'new');
assert.equal(list.length,5,'不修改传入的列表');
console.log('sessions-0840: ok');
