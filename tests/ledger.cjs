const fs=require('fs'),vm=require('vm'),path=require('path'),assert=require('assert/strict');
const ts=require(process.env.HVIGOR_TS||'typescript');
const cache=new Map();
function load(file){file=path.resolve(file);if(cache.has(file))return cache.get(file);const module={exports:{}};const js=ts.transpileModule(fs.readFileSync(file,'utf8'),{compilerOptions:{module:ts.ModuleKind.CommonJS,target:ts.ScriptTarget.ES2020}}).outputText;vm.runInNewContext(js,{module,exports:module.exports,require:n=>load(path.resolve(path.dirname(file),n+'.ets')),Number,Math,JSON,Date,Set,Map,Array,String,parseInt,RegExp,Object},{});cache.set(file,module.exports);return module.exports;}
const L=load('entry/src/main/ets/agent/Ledger.ets');
const DAY=86400000;const now=new Date(2026,9,4,12,0,0).getTime(); // 2026-10-04 周日
const at=d=>new Date(2026,9,4-d,12,0,0).getTime();
const task=(d,usage,activeMs)=>({id:at(d).toString(36)+'-abcdef',goal:'g',constraints:[],status:'completed',summary:'',records:[],calls:0,reason:'',usage,activeMs});
const sessions=[{id:'s',title:'t',messages:[],tasks:[task(0,{input:1,cacheRead:0,cacheWrite:0,output:1,total:100,calls:2,model:'m'},60000),task(1,undefined,3600000*9),task(2,{input:1,cacheRead:0,cacheWrite:0,output:1,total:300,calls:1,model:'m'},1000),task(5,undefined,0),task(6,undefined,0)]}];
// 迁移：只折算有用量的任务
const ledger=L.seedLedger(sessions);
assert.equal(ledger.length,2);assert.equal(ledger.reduce((a,d)=>a+d.total,0),400);
L.addDaily(ledger,now,50,1);assert.equal(ledger.find(d=>d.day==='2026-10-04').total,150);
// 统计：累计、峰值、最长任务、连续天数（4、3、2 号有任务，6、5 号断开两天后再接上）
const st=L.computeStats(sessions,ledger,0,now);
assert.equal(st.total,450);assert.equal(st.peak,300);assert.equal(st.longest,3600000*9);
assert.equal(st.curStreak,3);assert.equal(st.bestStreak,3);assert.equal(st.activeDays,5);
// 今天没有活动、昨天有，当前连续天数仍按昨天往前算
const st2=L.computeStats(sessions,ledger,0,now+DAY);assert.equal(st2.curStreak,3);
const st3=L.computeStats(sessions,ledger,0,now+3*DAY);assert.equal(st3.curStreak,0);
// 已存最长任务用时不会被删除的会话丢掉
assert.equal(L.computeStats([],[],7200000,now).longest,7200000);
// 热力图：52 周 × 7 天，最后一列含今天，之后的日子标为未来
const weeks=L.heatWeeks(ledger,now,52);assert.equal(weeks.length,52);assert.equal(weeks[0].cells.length,7);
const last=weeks[51];assert.equal(last.cells[6].day,'2026-10-04');assert.equal(last.cells[6].future,false);assert.equal(last.cells[6].level>0,true);
assert.equal(last.cells[0].day,'2026-09-28');assert.equal(weeks[50].cells.every(c=>!c.future),true);
// 周合计与累计
const bars=L.weekBars(ledger,now,26,false);const cum=L.weekBars(ledger,now,26,true);
assert.equal(bars.length,26);assert.equal(bars[25].total,450);assert.equal(cum[25].total,450);
// 格式
assert.equal(L.formatCn(5157),'5157');assert.equal(L.formatCn(123456),'12.3万');assert.equal(L.formatCn(378000000),'3.8亿');assert.equal(L.formatCn(20000),'2万');
assert.equal(L.formatSpan(9*3600000+37*60000),'9 小时 37 分');assert.equal(L.formatSpan(75000),'1 分 15 秒');assert.equal(L.formatSpan(0),'—');
console.log('PASS: ledger seed/add, stats, streaks, heat weeks, weekly bars, formatting');
