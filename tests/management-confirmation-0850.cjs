const fs=require('fs'),path=require('path'),vm=require('vm'),assert=require('assert/strict');
const ts=require(process.env.HVIGOR_TS||'typescript'),cache=new Map();
function load(p){p=path.resolve(p);if(cache.has(p))return cache.get(p);const m={exports:{}};vm.runInNewContext(ts.transpileModule(fs.readFileSync(p,'utf8'),{compilerOptions:{module:ts.ModuleKind.CommonJS,target:ts.ScriptTarget.ES2020}}).outputText,{module:m,exports:m.exports,require:n=>n.startsWith('.')?load(path.resolve(path.dirname(p),n+'.ets')):{},Map,Date,JSON,Error});cache.set(p,m.exports);return m.exports;}
(async()=>{
 const T=load('entry/src/main/ets/agent/Types.ets'),{Management}=load('entry/src/main/ets/agent/Management.ets');
 const state=T.defaults(),m=new Management(state);await m.execute('skill_save',{name:'external-test',description:'External confirmation test',whenToUse:'Only in the confirmation regression test',body:'Readonly instructions'},true,async()=>true);
 assert.equal(state.skills[0].enabled,false);let approve;
 const pending=m.execute('skill_set_enabled',{name:'external-test',enabled:true},false,()=>new Promise(r=>approve=r));
 assert.equal(state.skills[0].enabled,false);approve(true);const enabled=JSON.parse(await pending);
 assert.equal(enabled.confirmation?.status,'approved');assert.equal(enabled.confirmation.channel,'host_confirmation_card');assert.equal(enabled.confirmation.required,true);
 m.undo(enabled.undoId);assert.equal(state.skills[0].enabled,false);
 await assert.rejects(()=>m.execute('skill_set_enabled',{name:'external-test',enabled:true},false,async()=>false),/未启用/);assert.equal(state.skills[0].enabled,false);
 const disabled=JSON.parse(await m.execute('skill_set_enabled',{name:'external-test',enabled:false},false,async()=>{throw new Error('No confirmation expected');}));assert.equal(disabled.confirmation,undefined);
 const deleted=JSON.parse(await m.execute('skill_delete',{name:'external-test'},false,async()=>true));assert.equal(deleted.confirmation.status,'approved');m.undo(deleted.undoId);
 await assert.rejects(()=>m.execute('skill_set_enabled',{name:'external-test',enabled:true},false,async()=>{state.skills[0].body='Changed while confirming';return true;}),/确认期间技能变化/);assert.equal(state.skills[0].enabled,false);
 console.log('PASS actual host approval reported only after accepted confirmation; denial/conflict/default-disabled/undo preserved.');
})().catch(e=>{console.error(e);process.exitCode=1});
