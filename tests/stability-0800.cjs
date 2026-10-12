// 0.8.0 稳定性回归：等效用量预算与迁移、输出上限默认、自动续写、退避重试、后台额度回前台、任务结束回到大肥鱼、耗时统计与底栏数据、上下文分项估算、launch_app 含自身。
const fs=require('fs'),path=require('path'),vm=require('vm'),assert=require('assert/strict');
const ts=require(process.env.HVIGOR_TS||'typescript');
let leaseExpiry=null,leaseDelay=180000,timers=[];
// 网络桩：按队列返回每次请求的结果（'net' 网络失败、数字为 HTTP 状态码、对象为成功的 SSE 回复）。
let plan=[],requests=0,headersOf={};
function sse(h,parts){const b=Buffer.from(parts.map(p=>'data: '+JSON.stringify(p)+'\n\n').join('')+'data: [DONE]\n\n');queueMicrotask(()=>{h.dataReceive(Uint8Array.from(b).buffer);h.dataEnd();});}
const http={RequestMethod:{POST:'POST'},HttpDataType:{STRING:1},createHttp:()=>{const h={};return {on:(k,v)=>h[k]=v,off(){},destroy(){},requestInStream:async(u,o)=>{requests++;const next=plan.shift();if(next==='net')throw new Error('Failed to resolve the host name');if(typeof next==='number'){if(h.headersReceive)h.headersReceive(headersOf[next]??{});queueMicrotask(()=>{h.dataReceive(Uint8Array.from(Buffer.from('{"error":"x"}')).buffer);h.dataEnd();});return next;}if(next&&next.partialThenNet){queueMicrotask(()=>h.dataReceive(Uint8Array.from(Buffer.from('data: '+JSON.stringify({choices:[{delta:{content:'半句'}}]})+'\n\n')).buffer));await new Promise(r=>setTimeout(r,5));throw new Error('reset');}sse(h,next.parts);return 200;},request:async()=>{requests++;const next=plan.shift();if(next==='net')throw new Error('net');if(typeof next==='number')return {responseCode:next,result:'',header:headersOf[next]??{}};return {responseCode:200,result:JSON.stringify(next.body),header:{}};}};}};
const kit={'@kit.NetworkKit':{http},'@kit.BackgroundTasksKit':{backgroundTaskManager:{requestSuspendDelay:(r,cb)=>{leaseExpiry=cb;return {requestId:1,actualDelayTime:leaseDelay};},cancelSuspendDelay(){}}},'@kit.ArkTS':{buffer:{from:(x,e)=>Buffer.from(x,e)},util:{}},'@kit.CoreFileKit':{fileIo:{},picker:{}},'@kit.BasicServicesKit':{zlib:{}},'@kit.ImageKit':{},'@kit.AbilityKit':{},'@kit.UniversalKeystoreKit':{},'@kit.CryptoArchitectureKit':{}};
// 计时桩：记录请求的等待时长，立即执行（不真实等待 1 s/4 s/20 s）。
const fakeTimeout=(cb,ms)=>{timers.push(ms);return setTimeout(cb,0);};
const cache=new Map();function load(file){file=path.resolve(file);if(cache.has(file))return cache.get(file);const module={exports:{}};vm.runInNewContext(ts.transpileModule(fs.readFileSync(file,'utf8'),{compilerOptions:{module:ts.ModuleKind.CommonJS,target:ts.ScriptTarget.ES2020}}).outputText,{module,exports:module.exports,require:n=>n.startsWith('.')?load(path.resolve(path.dirname(file),n+'.ets')):kit[n]??{},setTimeout:(cb,ms)=>ms>=60000?0:fakeTimeout(cb,ms),clearTimeout,queueMicrotask,Uint8Array,ArrayBuffer,Map,Set,Buffer,Date,JSON,Math,Number,Object,Array,String,RegExp,Error,Promise});cache.set(file,module.exports);return module.exports;}
const root='entry/src/main/ets/agent/';
const same=(a,b)=>assert.equal(JSON.stringify(a),JSON.stringify(b));
const T=load(root+'Types.ets'),P=load(root+'ExecutionPolicy.ets'),M=load(root+'Model.ets'),{Engine}=load(root+'Engine.ets'),S=load(root+'Stats.ets'),R=load(root+'Risk.ets');
function fixture(){const state=T.defaults(),returned=[],device={mutationCount:0,hdc:{ready:true},active:()=>true,invalidate(){},sensitive:()=>false,observe:async()=>({snapshotId:'s1',layout:'屏幕',image:'',width:0,height:0,fingerprint:'x'}),bringSelf:async()=>{returned.push(Date.now());return true;}};const engine=new Engine(state,{save(){},secret:async()=>'fixture'},device,()=>{});engine.foreground=false;return {state,engine,returned};}
const ok=(text,usage)=>({text:text,calls:[],usage});
(async()=>{
 // 1. 等效用量口径：缓存读取按 1/10，未缓存输入与输出全价。
 assert.equal(P.costTokens({input:1000,cacheRead:100000,cacheWrite:0,output:500,total:101500,calls:1,model:'x'}),11500);
 assert.equal(P.costTokens(undefined),0);
 // 旧 budgetBase（total 口径）按占比折算。
 assert.equal(P.migrateBudgetBase(50750,{input:1000,cacheRead:100000,cacheWrite:0,output:500,total:101500,calls:1,model:'x'}),5750);
 assert.equal(P.migrateBudgetBase(0,undefined),0);
 // 99% 缓存命中的长任务：旧口径 90 步 × 6 万 = 540 万会耗尽 500 万；新口径约 74 万，不暂停。
 let f=fixture();f.engine.foreground=true;let round=0;
 f.engine.model.next=async()=>{round++;f.engine.model.onUsage({input:600,cacheRead:59000,cacheWrite:0,output:300,total:59900,calls:1,model:'fixture'});if(round<=90)return {text:'',calls:[{id:'w'+round,name:'file_list',arguments:'{}'}]};return ok('完成');};
 await f.engine.start('长任务预算');assert.equal(f.engine.current.status,'completed',f.engine.current.reason);assert.ok(f.engine.current.usage.total>5000000);assert.ok(P.costTokens(f.engine.current.usage)<1000000);assert.equal(f.engine.current.budgetUnit,'cost');
 // 2. 0.8.0.2 默认（对齐 DSH）：上下文 1M、输出 256000、思考开、强度 high、预算 2000 万；显式设置优先；小窗口按 1/2 收缩。
 const prof=T.defaults().profiles[0];assert.equal(prof.contextWindow,1000000);assert.equal(prof.thinking,'enabled');assert.equal(P.effortOf(prof),'high');assert.equal(P.outputLimit(prof),256000);assert.equal(P.tokenLimit(),20000000);
 prof.thinking='disabled';assert.equal(P.effortOf(prof),'off');assert.equal(P.outputLimit(prof),256000);prof.thinking='enabled';prof.effort='max';assert.equal(P.effortOf(prof),'max');
 assert.equal(P.outputLimit({...prof,contextWindow:262144}),131072);prof.outputTokens=2048;assert.equal(P.outputLimit(prof),2048);
 // 3. 自动续写：length 且无未完成工具调用时续写 2 次，第 3 次才暂停；续写不带工具。
 f=fixture();f.engine.foreground=true;let seen=[];f.engine.model.next=async(p,k,s,t,o,defs)=>{seen.push(defs.length);return seen.length<3?{text:'第'+seen.length+'段',incomplete:true,calls:[]}:ok('末段');};
 await f.engine.start('写长文');assert.equal(f.engine.current.status,'completed');assert.equal(f.engine.current.autoContinues,2);assert.ok(seen[0]>0);same(seen.slice(1),[0,0]);
 const TL=load('entry/src/main/ets/pages/Timeline.ets');const acts=TL.buildTimeline(f.engine.session(),[]).filter(it=>it.kind==='actions');assert.equal(acts.length,1);assert.equal(acts[0].text,'第1段第2段末段');
 let msgs=f.engine.session().messages.filter(m=>m.role==='assistant');same(msgs.map(m=>m.text),['第1段','第2段','末段']);same(msgs.map(m=>m.autoContinued??0),[0,1,2]);assert.ok(msgs.every(m=>!m.incomplete));
 f=fixture();f.engine.foreground=true;f.engine.model.next=async()=>({text:'一直截断',incomplete:true,calls:[]});await f.engine.start('超长');assert.equal(f.engine.current.status,'paused');assert.equal(f.engine.current.autoContinues,2);assert.match(f.engine.current.reason,/回复未完成/);
 // 手动继续后计数重新开始。
 let resumed=0;f.engine.model.next=async()=>{resumed++;return resumed<2?{text:'再截断',incomplete:true,calls:[]}:ok('终于写完');};await f.engine.start();assert.equal(f.engine.current.status,'completed');assert.equal(f.engine.current.autoContinues,1);
 // 工具调用在中途被截断：不续写文字，直接暂停。
 f=fixture();f.engine.foreground=true;f.engine.model.next=async()=>({text:'',incomplete:true,partialCalls:true,calls:[]});await f.engine.start('截断的工具');assert.equal(f.engine.current.status,'paused');assert.equal(f.engine.current.autoContinues,0);assert.match(f.engine.current.reason,/工具调用中途/);
 // 4. 退避重试（真实 Model 流式请求）。
 const m=new M.Model(),p=T.defaults().profiles[0];const notices=[];m.onRetry=n=>notices.push(n);let timing=null;m.onTiming=t=>timing=t;m.onText=()=>{};
 const good={parts:[{choices:[{delta:{reasoning_content:'想'}}]},{choices:[{delta:{content:'好的'},finish_reason:'stop'}]},{choices:[],usage:{prompt_tokens:10,completion_tokens:6,total_tokens:16}}]};
 let lastBody=null;const orig=http.createHttp;http.createHttp=()=>{const h=orig();const send=h.requestInStream;h.requestInStream=async(u,o)=>{lastBody=JSON.parse(o.extraData);return send(u,o);};return h;};
 plan=['net',503,good];requests=0;timers=[];let reply=await m.request(p,'k',[]);assert.equal(lastBody.max_tokens,256000);assert.equal(lastBody.thinking.type,'enabled');assert.equal(lastBody.reasoning_effort,'high');assert.equal(reply.text,'好的');assert.equal(requests,3);assert.deepEqual(notices.map(n=>n.attempt),[1,2]);assert.ok(notices[0].delayMs>=450&&notices[0].delayMs<=550);assert.ok(notices[1].delayMs>=900&&notices[1].delayMs<=1100);assert.ok(timing&&timing.firstByteAt>=timing.startedAt&&timing.endedAt>=timing.firstByteAt);assert.equal(timing.outputTokens,6);
 // 429 遵守 Retry-After，上限 20 秒。
 notices.length=0;headersOf={429:{'Retry-After':'30'}};plan=[429,good];reply=await m.request(p,'k',[]);same(notices.map(n=>n.delayMs),[20000]);
 headersOf={429:{'retry-after':'3'}};notices.length=0;plan=[429,good];await m.request(p,'k',[]);same(notices.map(n=>n.delayMs),[3000]);
 // 重试两次后仍失败：抛出原错误，不再重试。
 notices.length=0;plan=['net','net','net','net','net','net',good];requests=0;await assert.rejects(()=>m.request(p,'k',[]),e=>e instanceof M.ModelNetworkError&&!e.partialText);assert.equal(requests,6);plan=[];
 // 401/403 不重试。
 for(const code of [401,403]){notices.length=0;plan=[code,good];requests=0;await assert.rejects(()=>m.request(p,'k',[]),new RegExp('HTTP '+code));assert.equal(requests,1);assert.equal(notices.length,0);plan=[];}
 // 已收到部分正文：不重试，交给续写。
 notices.length=0;plan=[{partialThenNet:true},good];requests=0;await assert.rejects(()=>m.request(p,'k',[]),e=>e instanceof M.ModelNetworkError&&e.partialText);assert.equal(requests,1);plan=[];
 // 非流式（压缩等）同样重试。
 const plain=new M.Model();plan=[502,{body:{choices:[{finish_reason:'stop',message:{content:'摘要'}}]}}];requests=0;assert.equal((await plain.request(p,'k',[])).text,'摘要');assert.equal(requests,2);
 // 等待期间取消：立即停止，不发第二次请求。
 const c=new M.Model();c.onText=()=>{};c.onRetry=()=>{c.cancel();};plan=['net',good];requests=0;await assert.rejects(()=>c.request(p,'k',[]),/停止/);assert.equal(requests,1);plan=[];
 assert.equal(M.shouldRetry(new M.ModelHttpError(500,0,true)),false);assert.equal(M.shouldRetry(new M.ModelStreamError(false)),true);assert.equal(M.shouldRetry(new Error('其他')),false);
 assert.equal(P.retryAfterMs('Wed, 21 Oct 2015 07:28:00 GMT',Date.parse('Wed, 21 Oct 2015 07:27:55 GMT')),5000);
 // 5. Engine 显示重试进度并计数；成功后清掉“模型连接波动”。
 f=fixture();f.engine.foreground=true;let shownAction='';f.engine.model.next=async()=>{f.engine.model.onRetry({attempt:1,delayMs:1000,reason:'x'});shownAction=f.engine.current.currentAction;return ok('恢复后回答');};await f.engine.start('问个问题');assert.equal(f.engine.current.retries,1);assert.equal(f.engine.current.status,'completed');assert.match(shownAction,/模型连接波动/);assert.ok(!(f.engine.current.currentAction||'').includes('模型连接波动'));
 // 6. 后台额度到期前 10 秒：回到大肥鱼、聊天里提示一行、然后暂停。
 leaseDelay=10000;f=fixture();f.engine.model.next=async()=>ok('不应执行');await f.engine.start('后台任务');assert.equal(f.engine.current.status,'paused');assert.match(f.engine.current.reason,/后台额度/);assert.equal(f.returned.length,1);assert.ok(f.engine.session().messages.some(m=>m.text.includes('任务做到一半我回来了')));leaseDelay=180000;
 // 系统回调到期同样回前台。
 f=fixture();f.engine.model.next=async()=>{leaseExpiry();return ok('迟到');};await f.engine.start('后台任务2');assert.equal(f.engine.current.status,'paused');assert.equal(f.returned.length,1);
 // 7. 任务结束回到大肥鱼：用过设备、不在前台、设置开启时才回；任何结局都回。
 f=fixture();f.engine.model.next=async()=>{f.engine.current.deviceUsed=true;return ok('算完了');};await f.engine.start('计算器任务');await new Promise(r=>setTimeout(r,0));assert.equal(f.returned.length,1);assert.ok(f.engine.current.returnedToSelf>0);
 f=fixture();f.engine.model.next=async()=>{f.engine.current.deviceUsed=true;throw new Error('我先停一下：测试暂停');};await f.engine.start('暂停也回');assert.equal(f.engine.current.status,'paused');assert.equal(f.returned.length,1);
 f=fixture();f.state.returnToSelf=false;f.engine.model.next=async()=>{f.engine.current.deviceUsed=true;return ok('不回');};await f.engine.start('关闭设置');assert.equal(f.returned.length,0);
 f=fixture();f.engine.foreground=true;f.engine.model.next=async()=>{f.engine.current.deviceUsed=true;return ok('本来就在前台');};await f.engine.start('前台');assert.equal(f.returned.length,0);
 f=fixture();f.engine.model.next=async()=>ok('纯聊天');await f.engine.start('聊天');assert.equal(f.returned.length,0);
 // 8. 耗时统计与底栏数据。
 f=fixture();f.engine.foreground=true;f.engine.model.next=async()=>{f.engine.model.onUsage({input:100,cacheRead:900,cacheWrite:0,output:200,total:1200,calls:1,model:'x'});f.engine.model.onTiming({startedAt:1000,firstByteAt:1500,endedAt:3500,outputTokens:200});return ok('统计');};await f.engine.start('统计任务');
 const tm=f.engine.current.timing;same([tm.modelCalls,tm.modelMs,tm.ttftMs,tm.genMs,tm.genTokens],[1,2500,500,2000,200]);
 const st=S.sessionStats(f.engine.session(),5000000);assert.equal(st.rounds,1);assert.equal(st.steps,0);assert.equal(st.tps,100);assert.equal(st.ttftAvg,500);assert.equal(st.total,1200);assert.equal(Math.round(st.hitRate*100),90);assert.equal(st.cost,390);assert.equal(st.segmentCost,390);
 assert.equal(S.timeLabel(st),'1 轮 0 步 · 100 tok/s');assert.equal(S.tokenLabel(st),'1.2K tok · 缓存命中 90%');
 assert.equal(S.pauseLabel('后台额度快到期，我先回到大肥鱼暂停了，进度已保存'),'已暂停 · 后台额度快到期，我先回到大肥鱼暂停了，进…');
 // 工具耗时：每次工具调用都记录 durationMs。
 f=fixture();f.engine.foreground=true;round=0;f.engine.model.next=async()=>{round++;return round===1?{text:'',calls:[{id:'t1',name:'skill_load',arguments:'{"name":"无"}'}]}:ok('完');};await f.engine.start('工具耗时');assert.equal(typeof f.engine.current.records[0].durationMs,'number');assert.equal(f.engine.current.timing.toolCalls,1);
 // 9. 上下文分项估算与 estimate 一致。
 const model=new M.Model(),ctx=model.build(prof,{id:'s',title:'t',messages:[{role:'user',text:'你好',time:1}],tasks:[]},{id:'t',mode:'auto',goal:'你好',constraints:[],records:[],calls:0,status:'running',summary:'',reason:''},{snapshotId:'f',layout:'[]',image:'',width:0,height:0,fingerprint:''},[{name:'observe',description:'看',parameters:{type:'object',properties:{},required:[]},source:'平板内置',enabled:true,readOnly:true}],'');
 const b=model.breakdown(ctx,262144);assert.equal(b.system+b.tools+b.messages+b.images+b.output,b.total);assert.equal(b.total,model.estimate(ctx));assert.ok(b.system>0&&b.tools>0&&b.messages>0);assert.equal(b.output,2048);assert.equal(S.contextLabel(b),Math.round((b.total-b.output)*100/262144)+'%');// 0.8.1 规格变化：百分比不含输出预留
 f=fixture();f.engine.foreground=true;f.engine.model.next=async()=>ok('上下文');await f.engine.start('上下文任务');assert.ok(f.engine.session().contextStats.total>0);const idle=f.engine.contextStats(f.engine.session());assert.ok(idle.system>0&&idle.window===1000000);
 // 10. launch_app 列表含自身，名称“大肥鱼”。
 assert.equal(R.appTitle('com.harmonyloom.selfhdcprobe'),'大肥鱼');
 const D=load(root+'Device.ets');const dev=new D.Device({ready:true,execute:async(cmd)=>cmd.startsWith('aa dump')?'':'start ability successfully.'},{root:'.'});await dev.discover();assert.equal(dev.apps.get('com.harmonyloom.selfhdcprobe'),'ProbeAbility');assert.equal(await dev.bringSelf(),true);
 // 11. 旧数据迁移：默认保存的 4096 输出上限视为未设置；旧 budgetBase 折算为等效用量口径。
 const os=require('os');const dir=fs.mkdtempSync(path.join(os.tmpdir(),'hw-0800-'));kit['@kit.CoreFileKit'].fileIo={OpenMode:{READ_ONLY:0,READ_WRITE:fs.constants.O_RDWR,CREATE:fs.constants.O_CREAT,TRUNC:fs.constants.O_TRUNC},openSync:(q,fl)=>({fd:fs.openSync(q,fl)}),statSync:fs.fstatSync,readSync:(fd,buf)=>fs.readSync(fd,Buffer.from(buf),0,buf.byteLength,null),closeSync:fs.closeSync,writeSync:(fd,data)=>fs.writeSync(fd,data),fsyncSync:fs.fsyncSync,renameSync:fs.renameSync,unlinkSync:fs.unlinkSync,accessSync:q=>fs.existsSync(q)};
 const old=T.defaults();delete old.configVersion;old.tokenBudget=5000000;old.profiles[0].contextWindow=262144;old.profiles[0].outputTokens=4096;old.profiles[0].thinking='enabled';delete old.profiles[0].effort;old.profiles.push({...old.profiles[0],id:'custom',outputTokens:12000,contextWindow:500000});old.profiles.push({...old.profiles[0],id:'other',baseUrl:'https://other.example',contextWindow:262144});old.sessions[0].tasks.push({id:'old',goal:'旧任务',constraints:[],status:'paused',summary:'',records:[],calls:3,reason:'回复未完成，可继续生成',budgetBase:50750,usage:{input:1000,cacheRead:100000,cacheWrite:0,output:500,total:101500,calls:2,model:'x'}});fs.writeFileSync(path.join(dir,'agent.json'),JSON.stringify(old));
 const {Store}=load(root+'Store.ets');const loaded=new Store(dir).load();assert.equal(loaded.profiles[0].outputTokens,undefined);assert.equal(loaded.profiles[0].contextWindow,1000000);assert.equal(P.outputLimit(loaded.profiles[0]),256000);assert.equal(loaded.profiles[0].effort,'high');assert.equal(loaded.tokenBudget,undefined);assert.equal(loaded.configVersion,8002);assert.equal(loaded.profiles[1].outputTokens,12000);assert.equal(loaded.profiles[1].contextWindow,500000);assert.equal(loaded.profiles[2].contextWindow,262144);
 // 迁移只做一次：之后用户手动设回 262144 / 4096 也保留。
 fs.writeFileSync(path.join(dir,'agent.json'),JSON.stringify({...loaded,profiles:[{...loaded.profiles[0],contextWindow:262144,outputTokens:4096}]}));const again=new Store(dir).load();assert.equal(again.profiles[0].contextWindow,262144);assert.equal(again.profiles[0].outputTokens,4096);const migrated=loaded.sessions[0].tasks[0];assert.equal(migrated.budgetUnit,'cost');assert.equal(migrated.budgetBase,5750);fs.rmSync(dir,{recursive:true,force:true});
 console.log('PASS: 0.8.0 equivalent-cost budget and migration, output defaults, auto-continue x2, retry/backoff (net/429 Retry-After/5xx, no 401/403/partial), lease return-to-front, end-of-task return, timing/TTFT/TPS stats, context breakdown, self in launch list, legacy profile/budget migration');
})().catch(e=>{console.error(e);process.exit(1);});
