const fs=require('fs'),vm=require('vm'),path=require('path'),assert=require('assert/strict');
const ts=require(process.env.HVIGOR_TS||'typescript');
const cache=new Map();
function load(file){file=path.resolve(file);if(cache.has(file))return cache.get(file);const module={exports:{}};vm.runInNewContext(ts.transpileModule(fs.readFileSync(file,'utf8'),{compilerOptions:{module:ts.ModuleKind.CommonJS,target:ts.ScriptTarget.ES2020}}).outputText,{module,exports:module.exports,require:n=>n.startsWith('.')?load(path.resolve(path.dirname(file),n+'.ets')):{},setTimeout,clearTimeout,Uint8Array,ArrayBuffer,Map,Buffer});cache.set(file,module.exports);return module.exports;}
const root='entry/src/main/ets/agent/';
(async()=>{
 const {Model}=load(root+'Model.ets'),T=load(root+'Types.ets');const m=new Model(),s=T.defaults(),p=s.profiles[0];assert.equal(p.contextWindow,1000000);/* 0.8.0.2 默认 1M */
 const record=i=>({id:'r'+i,name:'home',args:'{}',result:'result'+i,status:'success',time:i,observation:'old'+i,providerReasoning:'reason'+i});
 const t={id:'t',goal:'目标',constraints:[],summary:'',records:Array.from({length:12},(_,i)=>record(i)),calls:12,reason:'',status:'paused'};
 const o={snapshotId:'new',layout:'latest',image:'IMAGE',width:1000,height:1000};
 const defs=[{name:'z',description:'z',parameters:{type:'object',properties:{b:{type:'number'},a:{type:'string'}},required:['b','a']},enabled:true,source:'test',readOnly:true},{name:'a',description:'a',parameters:{type:'object',properties:{},required:[]},enabled:true,source:'test',readOnly:true}];
 const a=m.build(p,s.sessions[0],t,o,defs,'b: B\na: A');assert.equal(a.messages.filter(x=>x.role==='assistant').length,12);assert.equal(a.tools[0].function.name,'a');
 defs[0].parameters.additionalProperties=false;a.tools.find(x=>x.function.name==='z').function.parameters.additionalProperties=false;const extra=m.build(p,s.sessions[0],t,o,defs,'');assert.equal(extra.tools.find(x=>x.function.name==='z').function.parameters.additionalProperties,false);
 const frozen=JSON.stringify(a.messages.slice(0,-1));t.records.push(record(12));t.constraints.push('新要求');const b=m.build(p,s.sessions[0],t,{...o,snapshotId:'next',image:'NEXT'},defs.reverse(),'a: A\nb: B');assert.equal(JSON.stringify(b.messages.slice(0,a.messages.length-1)),frozen);assert.equal(JSON.stringify(a.tools),JSON.stringify(b.tools));
 assert.equal(JSON.stringify(b).split('data:image/jpeg;base64,').length-1,1);assert.ok(JSON.stringify(b).includes('新要求'));assert.ok(!JSON.stringify(b).includes('IMAGE'));assert.ok(m.estimate(b)>4096);
 t.summary='保留目标与不确定动作';t.compactedThrough=5;const compact=m.build(p,s.sessions[0],t,o,defs,'');assert.equal(compact.messages.filter(x=>x.role==='assistant').length,8);assert.ok(!JSON.stringify(compact).includes('result0'));
 const {StabilityTracker,stabilityFingerprint}=load(root+'Stability.ets');const line=(text,focused=false)=>JSON.stringify({elementId:'e1',text,bounds:[0,100,100,200],normalizedCenter:[50,150],focused,enabled:true});
 assert.equal(stabilityFingerprint(line('15')),stabilityFingerprint(line('15',true)));assert.notEqual(stabilityFingerprint(line('15')),stabilityFingerprint(line('16')));
 let tracker=new StabilityTracker(0);tracker.sample(line('15'),1600,1600);tracker.sample(line('15'),3700,1600);assert.equal(tracker.done,true);assert.equal(tracker.report(5800).extended,true);
 tracker=new StabilityTracker(0);for(let i=0;i<4;i++)tracker.sample(line(String(i)),1000+i*2000,1000);assert.equal(tracker.report(12000).reason,'CONTENT_CHANGING');assert.ok(tracker.report(12000).changedFields.includes('text'));
 tracker=new StabilityTracker(0);tracker.sample(line('15'),6000,6000);assert.equal(tracker.report(12000).reason,'INSUFFICIENT_SAMPLES');
 const {Device}=load(root+'Device.ets');const d=new Device({},{});d.active=()=>false;await assert.rejects(()=>d.stable(),/暂停/);
 console.log('PASS: 256K, append-only history, stable tools/catalog, latest image, compression boundary, adaptive stability diagnostics/cancel');
})().catch(e=>{console.error(e);process.exitCode=1;});
