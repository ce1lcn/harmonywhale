import {Session,Task,Usage,ContextStats,ContextAnchor} from './Types';
import {costTokens} from './ExecutionPolicy';
// 0.8.0 底栏三胶囊的数据：全部来自会话里已持久化的真实记录，切换会话即切换。
export interface SessionStats {
 rounds:number;steps:number;
 modelCalls:number;modelMs:number;toolMs:number;toolCalls:number;ttftAvg:number;tps:number;
 total:number;input:number;cacheRead:number;output:number;hitRate:number;cost:number;
 segmentCost:number;budget:number;
 paused:boolean;pauseReason:string;
}
export function sessionStats(s:Session,budget:number):SessionStats {
 let modelCalls=0,modelMs=0,toolMs=0,toolCalls=0,ttftMs=0,ttftCount=0,genMs=0,genTokens=0;
 let total=0,input=0,cacheRead=0,output=0,cost=0;
 s.tasks.forEach((t:Task)=>{
  const m=t.timing;if(m){modelCalls+=m.modelCalls;modelMs+=m.modelMs;toolMs+=m.toolMs;toolCalls+=m.toolCalls;ttftMs+=m.ttftMs;ttftCount+=m.ttftCount;genMs+=m.genMs;genTokens+=m.genTokens;}
  const u:Usage|undefined=t.usage;if(u){total+=u.total;input+=u.input;cacheRead+=u.cacheRead;output+=u.output;cost+=costTokens(u);}
 });
 const last=s.tasks.length?s.tasks[s.tasks.length-1]:null;
 const segmentCost=last?Math.max(0,costTokens(last.usage)-(last.budgetUnit==='cost'?(last.budgetBase??0):0)):0;
 return {
  rounds:s.messages.filter(m=>m.role==='user').length,
  steps:s.tasks.reduce((n:number,t:Task)=>n+t.calls,0),
  modelCalls:modelCalls,modelMs:modelMs,toolMs:toolMs,toolCalls:toolCalls,
  ttftAvg:ttftCount?Math.round(ttftMs/ttftCount):0,
  tps:genMs>0?genTokens*1000/genMs:0,
  total:total,input:input,cacheRead:cacheRead,output:output,
  hitRate:cacheRead+input>0?cacheRead/(cacheRead+input):0,
  cost:cost,segmentCost:segmentCost,budget:budget,
  paused:!!last&&last.status==='paused',pauseReason:last&&last.status==='paused'?last.reason:''
 };
}
export function compactTokens(n:number):string{if(n<1000)return Math.round(n).toString();if(n<1000000)return (n<10000?(n/1000).toFixed(1):Math.round(n/1000).toString())+'K';return (n/1000000).toFixed(1)+'M';}
export function seconds(ms:number):string{if(ms<=0)return '0 秒';if(ms<1000)return ms+' 毫秒';const s=ms/1000;if(s<60)return s.toFixed(1)+' 秒';const m=Math.floor(s/60);return m+' 分 '+Math.round(s%60)+' 秒';}
export function timeLabel(v:SessionStats):string{return v.rounds+' 轮 '+v.steps+' 步'+(v.tps>0?' · '+Math.round(v.tps)+' tok/s':'');}
export function tokenLabel(v:SessionStats):string{return compactTokens(v.total)+' tok · 缓存命中 '+Math.round(v.hitRate*100)+'%';}
// 状态栏上下文的实际输入估算（总估算减去输出预留），输出预留在浮层单独列出。
export function contextInput(c:ContextStats|null):number{if(!c)return 0;return Math.max(0,c.total-c.output);}
// 0.8.1（DSH 口径）：已用 = 上次请求服务端报告的提示 token + 此后新增内容的估算增量；不计输出预留。
// 没有服务端用量（新会话、压缩后）时退回纯输入估算。
export function anchoredStats(c:ContextStats,anchor:ContextAnchor|undefined):ContextStats{
 const input=contextInput(c);const out:ContextStats={system:c.system,tools:c.tools,messages:c.messages,images:c.images,output:c.output,total:c.total,window:c.window,time:c.time};
 if(anchor&&anchor.prompt>0){const delta=input-anchor.estimate;out.served=anchor.prompt;out.delta=delta;out.used=Math.max(0,anchor.prompt+delta);}else out.used=input;
 return out;
}
export function contextUsed(c:ContextStats|null):number{if(!c)return 0;return c.used!==undefined?c.used:contextInput(c);}
// 百分比 = 已用 ÷ 窗口，上限 100%；自动压缩阈值逻辑不变（0.8.2 再按 DSH 公式调整）。
export function contextPercent(c:ContextStats|null):number{if(!c||!c.window)return 0;return Math.min(100,Math.round(contextUsed(c)*100/c.window));}
export function contextLabel(c:ContextStats|null):string{return c?contextPercent(c)+'%':'—';}
export function pauseLabel(reason:string):string{const r=reason.replace(/\s+/g,' ').trim();return '已暂停 · '+(r.length>20?r.slice(0,20)+'…':r);}
