import {Session,Task,DayUsage} from './Types';

// Token 看板的数据层：持久的每日用量账本 + 由账本和现有任务推算的统计。
// 账本与会话分开保存，删除会话不会丢失累计数据。

export interface Stats { total:number; peak:number; longest:number; bestStreak:number; curStreak:number; activeDays:number; }
export interface HeatCell { day:string; total:number; level:number; future:boolean; }
export interface HeatWeek { key:string; cells:HeatCell[]; month:number; }
export interface BarItem { label:string; total:number; }

function pad(v:number):string{return v<10?'0'+v:v.toString();}
export function dayKey(ms:number):string{const d=new Date(ms);return d.getFullYear()+'-'+pad(d.getMonth()+1)+'-'+pad(d.getDate());}
function dayNumber(key:string):number{const p=key.split('-');return Math.round(Date.UTC(Number(p[0]),Number(p[1])-1,Number(p[2]))/86400000);}
export function taskStartMs(t:Task):number{const n=parseInt(t.id.split('-')[0],36);return Number.isFinite(n)?n:0;}

export function addDaily(list:DayUsage[],ms:number,total:number,calls:number):void{
 const key=dayKey(ms);
 const found=list.find((d:DayUsage)=>d.day===key);
 if(found){found.total+=total;found.calls+=calls;}else list.push({day:key,total:total,calls:calls});
}

// 首次升级：把已有任务里记录过的用量折算进账本
export function seedLedger(sessions:Session[]):DayUsage[]{
 const list:DayUsage[]=[];
 sessions.forEach((s:Session)=>{s.tasks.forEach((t:Task)=>{if(t.usage&&t.usage.total>0)addDaily(list,taskStartMs(t),t.usage.total,t.usage.calls);});});
 return list;
}

// 任务实际运行时长：优先用累计的运行毫秒；旧任务用首尾工具记录的跨度估算
export function taskDuration(t:Task):number{
 if(t.activeMs!==undefined&&t.activeMs>0)return t.activeMs;
 if(t.records.length<2)return 0;
 let first=t.records[0].time;let last=first;
 t.records.forEach((r)=>{first=Math.min(first,r.time);last=Math.max(last,r.time);});
 return Math.max(0,last-first);
}

export function computeStats(sessions:Session[],ledger:DayUsage[],storedLongest:number,now:number):Stats{
 let total=0;let peak=0;
 ledger.forEach((d:DayUsage)=>{total+=d.total;peak=Math.max(peak,d.total);});
 let longest=storedLongest;
 const days=new Set<string>();
 ledger.forEach((d:DayUsage)=>{if(d.total>0)days.add(d.day);});
 sessions.forEach((s:Session)=>{s.tasks.forEach((t:Task)=>{longest=Math.max(longest,taskDuration(t));const st=taskStartMs(t);if(st>0)days.add(dayKey(st));});});
 const nums:number[]=Array.from(days).map((k:string)=>dayNumber(k)).sort((a:number,b:number)=>a-b);
 let best=0;let run=0;
 nums.forEach((n:number,i:number)=>{run=i>0&&n===nums[i-1]+1?run+1:1;best=Math.max(best,run);});
 const today=dayNumber(dayKey(now));
 const set=new Set<number>(nums);
 let cur=0;let cursor=set.has(today)?today:today-1;
 while(set.has(cursor)){cur++;cursor--;}
 return {total:total,peak:peak,longest:longest,bestStreak:best,curStreak:cur,activeDays:nums.length};
}

function levelOf(v:number,max:number):number{
 if(v<=0||max<=0)return 0;
 const r=v/max;
 return r<=0.25?1:r<=0.5?2:r<=0.75?3:4;
}

// 近 weeks 周的热力图，周一在上；最后一列是包含今天的那一周
export function heatWeeks(ledger:DayUsage[],now:number,weeks:number):HeatWeek[]{
 const map=new Map<string,number>();
 let max=0;
 ledger.forEach((d:DayUsage)=>{map.set(d.day,d.total);max=Math.max(max,d.total);});
 const todayNum=dayNumber(dayKey(now));
 const todayDow=(new Date(now).getDay()+6)%7;
 const lastMonday=todayNum-todayDow;
 const out:HeatWeek[]=[];
 for(let w=weeks-1;w>=0;w--){
  const monday=lastMonday-w*7;
  const cells:HeatCell[]=[];
  for(let i=0;i<7;i++){
   const n=monday+i;
   const date=new Date(n*86400000);
   const key=date.getUTCFullYear()+'-'+pad(date.getUTCMonth()+1)+'-'+pad(date.getUTCDate());
   const v=map.get(key)??0;
   cells.push({day:key,total:v,level:levelOf(v,max),future:n>todayNum});
  }
  out.push({key:cells[0].day,cells:cells,month:Number(cells[0].day.split('-')[1])});
 }
 return out;
}

// 每周合计；cumulative 为 true 时返回累计值
export function weekBars(ledger:DayUsage[],now:number,weeks:number,cumulative:boolean):BarItem[]{
 const list=heatWeeks(ledger,now,weeks);
 const out:BarItem[]=[];
 let before=0;
 const firstKey=list[0].key;
 ledger.forEach((d:DayUsage)=>{if(d.day<firstKey)before+=d.total;});
 let running=before;
 list.forEach((w:HeatWeek)=>{
  const sum=w.cells.reduce((a:number,c:HeatCell)=>a+c.total,0);
  running+=sum;
  out.push({label:w.key.slice(5),total:cumulative?running:sum});
 });
 return out;
}

export function formatCn(n:number):string{
 if(n<10000)return Math.round(n).toString();
 const strip=(v:string):string=>v.endsWith('.0')?v.slice(0,-2):v;
 if(n<100000000)return strip((n/10000).toFixed(1))+'万';
 return strip((n/100000000).toFixed(1))+'亿';
}

export function formatSpan(ms:number):string{
 if(ms<1000)return '—';
 const s=Math.round(ms/1000);
 const h=Math.floor(s/3600);const m=Math.floor((s%3600)/60);
 if(h>0)return h+' 小时 '+m+' 分';
 if(m>0)return m+' 分 '+(s%60)+' 秒';
 return s+' 秒';
}
