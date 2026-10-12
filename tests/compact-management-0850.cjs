// Real compact timeline must retain the management receipt needed by the UI undo.
const fs=require('fs'),path=require('path'),vm=require('vm'),assert=require('assert/strict');
const ts=require(process.env.HVIGOR_TS||'typescript'),cache=new Map();
function load(p){p=path.resolve(p);if(cache.has(p))return cache.get(p);const m={exports:{}};vm.runInNewContext(ts.transpileModule(fs.readFileSync(p,'utf8'),{compilerOptions:{module:ts.ModuleKind.CommonJS,target:ts.ScriptTarget.ES2020}}).outputText,{module:m,exports:m.exports,require:n=>n.startsWith('.')?load(path.resolve(path.dirname(p),n+'.ets')):{},Map,Date,JSON,Error});cache.set(p,m.exports);return m.exports;}
const T=load('entry/src/main/ets/agent/Types.ets'),C=load('entry/src/main/ets/agent/CompactTimeline.ets');
const session=T.newSession();session.tasks=[{id:'task',records:[],calls:0}];
const result=JSON.stringify({undoId:'receipt',kind:'skill',key:'test',before:{version:3},after:null});
session.tasks[0].records=[{id:'delete',name:'skill_delete',args:'{"name":"test"}',result,status:'success',time:1,observation:''},{id:'denied',name:'skill_delete',args:'{}',result:'DENIED',status:'error',time:2,observation:''}];
const view=C.compactView(session);assert.equal(view.rows[0].kind,'learn');assert.equal(view.rows[0].name,'skill_delete');assert.equal(view.rows[0].args,'{"name":"test"}');assert.equal(view.rows[0].result,result);assert.equal(view.rows[1].kind,'tool');
// Failed requests must never acquire a successful management card / undo action.
for(const status of ['pending','uncertain','skipped']){session.tasks[0].records[0].status=status;assert.equal(C.compactView(session).rows[0].kind,'tool');}
console.log('PASS compact management receipts retained; failed/pending actions do not offer undo. Draft window transition requires separate native acceptance.');
