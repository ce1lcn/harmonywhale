const fs=require('fs'),vm=require('vm'),path=require('path'),assert=require('assert/strict');
const ts=require(process.env.HVIGOR_TS||'typescript');
let clock=0;const cache=new Map();
function load(file){file=path.resolve(file);if(cache.has(file))return cache.get(file);const m={exports:{}};vm.runInNewContext(ts.transpileModule(fs.readFileSync(file,'utf8'),{compilerOptions:{module:ts.ModuleKind.CommonJS,target:ts.ScriptTarget.ES2020}}).outputText,{module:m,exports:m.exports,require:n=>n.startsWith('.')?load(path.resolve(path.dirname(file),n+'.ets')):{},Date:{now:()=>clock},setTimeout,clearTimeout,Uint8Array,ArrayBuffer,Map,Set,Buffer});cache.set(file,m.exports);return m.exports;}
const {Device}=load('entry/src/main/ets/agent/Device.ets');
const sample={snapshotId:'s',width:2800,height:1840,elements:[{text:'0850测试',normalizedCenter:[500,500],bounds:[0,100,100,200]}]};
function device(){clock=0;const d=new Device({ready:true},{});d.delay=async ms=>{clock+=ms};return d;}
(async()=>{
 let d=device(),calls=0;d.readLayout=async timeout=>{if(calls++===0){clock+=2200;return sample;}clock+=timeout+2;throw Error('Command timeout');};await d.stable();assert.equal(d.lastStability.reason,'INSUFFICIENT_SAMPLES');assert.equal(d.lastStability.samples,1);assert.equal(calls,2);const note=load('entry/src/main/ets/agent/Stability.ets').stabilityNote(d.lastStability);assert.match(note,/4\.0秒/);assert.match(note,/样本不足/);assert.ok(!note.includes('12')&&!note.includes('仍在变化'));
 d=device();d.readLayout=async timeout=>{clock+=timeout+2;throw Error('Command timeout');};await assert.rejects(d.stable(),/读取失败/);assert.equal(d.lastStability.samples,0);
 d=device();calls=0;d.readLayout=async()=>{if(calls++===0){clock+=500;return sample;}clock+=10;throw Error('invalid JSON');};await assert.rejects(d.stable(),/invalid JSON/);assert.equal(d.lastStability.reason,'LAYOUT_READ_FAILED');
 d=device();d.readLayout=async()=>{clock+=500;return sample;};await d.stable();assert.equal(d.lastStability.reason,'STABLE');assert.equal(d.lastStability.consecutive,2);
 d=device();d.readLayout=async timeout=>{clock+=timeout+2;d.active=()=>false;throw Error('Command timeout');};await assert.rejects(d.stable());assert.equal(d.lastStability.reason,'INTERRUPTED');
 console.log('PASS: real Device stable deadline with prior valid sample, zero samples, early malformed layout, normal stable result and cancellation.');
})().catch(e=>{console.error(e);process.exitCode=1;});
