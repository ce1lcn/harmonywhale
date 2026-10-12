import {Session,Task,ChatEntry,ToolRecord} from './Types';
import {toolItem,TimelineItem} from '../pages/Timeline';
// 0.8.1 紧凑模式（小窗）的时间线：只显示当前任务；思考默认展开最近一条；工具调用一行一条；旧内容折叠成一行计数。
export interface CompactRow {id:string;kind:string;text:string;label:string;status:string;time:number;name:string;args:string;result:string;}
export interface CompactView {rows:CompactRow[];hidden:number;latestThink:string;}
export const COMPACT_ROWS:number=30;
function row(id:string,kind:string,text:string,label:string,status:string,time:number):CompactRow{return {id:id,kind:kind,text:text,label:label,status:status,time:time,name:'',args:'',result:''};}
export function compactView(session:Session,max:number=COMPACT_ROWS):CompactView{
 const task:Task|undefined=session.tasks.length?session.tasks[session.tasks.length-1]:undefined;
 if(!task)return {rows:[],hidden:0,latestThink:''};
 const rows:CompactRow[]=[];
 session.messages.forEach((m:ChatEntry,i:number)=>{
  if(m.taskId!==task.id||m.toolCallId&&!m.text)return;
  if(m.role==='assistant'&&m.providerReasoning)rows.push(row('km:'+i,'think',m.providerReasoning,'思考','',m.time-1));
  if(m.text)rows.push(row('m:'+i,m.role==='user'?'user':'assistant',m.text,'','',m.time));
 });
 task.records.forEach((r:ToolRecord)=>{
  if(r.providerReasoning)rows.push(row('k:'+r.id,'think',r.providerReasoning,'思考','',r.time-1));
  const it:TimelineItem=toolItem(r);
  const learning=r.status==='success'&&['skill_save','skill_set_enabled','skill_delete','skill_rollback','memory_save','memory_forget'].includes(r.name);
  const item=row('r:'+r.id,learning?'learn':'tool',it.summary||it.label,it.label,r.status,r.time);
  item.name=r.name;item.args=r.args;item.result=r.result;rows.push(item);
 });
 rows.sort((a:CompactRow,b:CompactRow)=>a.time-b.time);
 const hidden=Math.max(0,rows.length-max);const shown=rows.slice(hidden);
 let latestThink='';shown.forEach((r:CompactRow)=>{if(r.kind==='think')latestThink=r.id;});
 return {rows:shown,hidden:hidden,latestThink:latestThink};
}
export function toolMark(status:string):string{return status==='success'?'✓':status==='pending'?'…':status==='error'?'没成功':status==='uncertain'?'不确定':status==='skipped'?'未执行':'';}
