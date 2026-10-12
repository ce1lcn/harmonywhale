const fs=require('fs'),vm=require('vm'),assert=require('assert/strict');
const ts=require(process.env.HVIGOR_TS||'typescript');
const pc=require('../scripts/uitest-gate.cjs');
function compile(file,require){const m={exports:{}};vm.runInNewContext(ts.transpileModule(fs.readFileSync(file,'utf8'),{compilerOptions:{module:ts.ModuleKind.CommonJS,target:ts.ScriptTarget.ES2020}}).outputText,{module:m,exports:m.exports,require,Date,Uint8Array,Map,setTimeout,clearTimeout});return m.exports;}
const gate=compile('entry/src/main/ets/pages/UiTestGate.ets');
const {HdcClient}=compile('entry/src/main/ets/pages/HdcClient.ets',n=>n==='./UiTestGate'?gate:n==='@kit.NetworkKit'?{socket:{constructTCPSocketInstance:()=>({close:async()=>{}})}}:{});
const sleep=ms=>new Promise(r=>setTimeout(r,ms));
(async()=>{
 for(const cmd of ['uitest dumpLayout -p /data/local/tmp/x.json',"uitest uiInput inputText '中文 a'", "uitest uiInput inputText 'a'\\''b'"]){assert.equal(gate.uiTestCommand(cmd),pc.command(cmd));assert.match(pc.command(cmd),/flock -n 0/);assert.match(pc.command(cmd),/\) 0<&-/);}
 assert.equal(gate.uiTestReply('uitest dumpLayout',pc.BUSY),null);
 assert.equal(gate.uiTestReply('uitest dumpLayout',pc.READY+'\r\nDumpLayout saved to:/tmp/x'),'DumpLayout saved to:/tmp/x');
 for(const decode of [gate.uiTestReply,pc.reply]){assert.throws(()=>decode('uitest dumpLayout',pc.READY+'\nDumpLayout failed:timeout'));assert.throws(()=>decode('uitest uiInput click',pc.READY+'\n'+pc.BUSY));assert.throws(()=>decode('uitest dumpLayout',''));}
 let c=new HdcClient(()=>{},()=>{});c.ready=true;let wire=[];c.executeRaw=async(cmd)=>{wire.push(cmd);return wire.length===1?pc.BUSY:pc.READY+'\nNo Error';};assert.equal(await c.execute('uitest uiInput click 1 2',1000),'No Error');assert.equal(wire.length,2);
 c=new HdcClient(()=>{},()=>{});c.ready=true;wire=[];c.executeRaw=async cmd=>{wire.push(cmd);return pc.BUSY;};const queued=c.execute('uitest uiInput click 1 2',1000);await sleep(5);c.cancelCommands();await assert.rejects(queued,/取消/);assert.equal(wire.length,1,'cancelled queued input must not retry');
 c=new HdcClient(()=>{},()=>{});c.ready=true;let release;c.executeRaw=()=>new Promise(r=>{release=r;});const late=c.execute('uitest uiInput click 1 2',1000);c.cancelCommands();release(pc.READY+'\nNo Error');await assert.rejects(late,/结果未确认/);
 c=new HdcClient(()=>{},()=>{});c.ready=true;wire=[];c.executeRaw=async cmd=>{wire.push(cmd);return pc.BUSY;};await assert.rejects(c.execute('uitest dumpLayout -p /tmp/x',5),/排队超时/);assert.equal(wire.length,1);
 let calls=0;assert.throws(()=>pc.execute('uitest dumpLayout',()=>{calls++;return pc.READY+'\nDumpLayout failed:timeout';}),/读取失败/);assert.equal(calls,1,'failed execution must not retry');
 assert.equal(pc.execute('echo ordinary',cmd=>cmd),'echo ordinary');
 console.log('PASS: shared device lock protocol, shell quoting parity, busy-only retries, cancellation, deadline, late results, failure rejection; no scope changes.');
})().catch(e=>{console.error(e);process.exitCode=1});
