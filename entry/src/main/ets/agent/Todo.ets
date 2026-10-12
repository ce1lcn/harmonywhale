// Portions adapted from DeepSeek Harness packages/todo/tool-todo (src/index.ts toTodoList, tool description).
// Copyright (c) 2026 DeepSeek. Licensed under the MIT License; full notice in docs/THIRD-PARTY.md.
// 0.8.4 B4：待办清单。每次整体替换；校验规则取自 DSH：内容去空白后非空、不重复、同一时间最多一项进行中（DSH 的 allowParallelInProgress=false 配置）。
// 与 DSH 的差别：DSH 的字段叫 content/status(completed)，这里按任务书用 text/status(done)；上限 20 项、每项 100 字是大肥鱼自加的，防止清单撑满上下文。
import {TodoItem} from './Types';
import {DeviceError} from './Elements';

export const TODO_STATUSES:string[]=['pending','in_progress','done'];
export const TODO_MAX_ITEMS:number=20;
export const TODO_MAX_TEXT:number=100;

// 模型有时把数组写成 JSON 字符串，宽松接受；解析不了按参数错误处理。
export function parseTodos(raw:TodoItem[]|string|undefined):TodoItem[]{
 let list:Object[];
 if(typeof raw==='string'){
  try{const v=JSON.parse(raw) as Object;if(!Array.isArray(v))throw new Error('x');list=v as Object[];}catch(e){throw new DeviceError('PARAMETER','items 必须是 [{text,status}] 数组');}
 }else if(Array.isArray(raw))list=raw as Object[];
 else throw new DeviceError('PARAMETER','items 必须是 [{text,status}] 数组（要清空待办就传空数组）');
 if(list.length>TODO_MAX_ITEMS)throw new DeviceError('PARAMETER','待办最多 '+TODO_MAX_ITEMS+' 项，请合并步骤');
 const out:TodoItem[]=[];let active:number=0;
 list.forEach((item:Object)=>{
  const o=item as Record<string,Object>;
  const text:string=typeof o['text']==='string'?(o['text'] as string).trim():'';
  const status:string=typeof o['status']==='string'?(o['status'] as string):'';
  if(!text)throw new DeviceError('PARAMETER','每项待办的 text 不能为空');
  if(text.length>TODO_MAX_TEXT)throw new DeviceError('PARAMETER','每项待办不超过 '+TODO_MAX_TEXT+' 字，写成简短的一句');
  if(TODO_STATUSES.indexOf(status)<0)throw new DeviceError('PARAMETER','status 只能是 pending / in_progress / done');
  if(out.some((x:TodoItem)=>x.text===text))throw new DeviceError('PARAMETER','待办重复：'+text);
  if(status==='in_progress')active++;
  out.push({text:text,status:status});
 });
 if(active>1)throw new DeviceError('PARAMETER','同一时间最多一项 in_progress（现在有 '+active+' 项）');
 return out;
}

export interface TodoCounts {pending:number;inProgress:number;done:number;total:number;}
export function todoCounts(items:TodoItem[]):TodoCounts{
 const count=(s:string):number=>items.filter((x:TodoItem)=>x.status===s).length;
 return {pending:count('pending'),inProgress:count('in_progress'),done:count('done'),total:items.length};
}
// 工具结果（给模型）。
export function todoResult(items:TodoItem[]):string{
 const c:TodoCounts=todoCounts(items);
 if(c.total===0)return '待办已清空。';
 return '待办已更新：共 '+c.total+' 项，完成 '+c.done+'，进行中 '+c.inProgress+'，待做 '+c.pending+'。';
}
export function todoMark(status:string):string{return status==='done'?'[x]':status==='in_progress'?'[>]':'[ ]';}
// 放进末尾宿主状态块的文字：模型每一步都能看到当前清单，不必翻历史。
export function todoBlock(items:TodoItem[]|undefined):string{
 if(!items||items.length===0)return '';
 const c:TodoCounts=todoCounts(items);
 return '当前待办清单（完成 '+c.done+'/'+c.total+'；每次用 todo_write 整体替换，做完一项就标 done）：\n'+items.map((x:TodoItem,i:number)=>(i+1)+'. '+todoMark(x.status)+' '+x.text).join('\n');
}
// 界面上的紧凑进度：「待办 2/5 · 正在：xxx」。
export function todoProgress(items:TodoItem[]):string{
 const c:TodoCounts=todoCounts(items);
 const now:TodoItem|undefined=items.find((x:TodoItem)=>x.status==='in_progress');
 return '待办 '+c.done+'/'+c.total+(now?' · 正在：'+(now.text.length>24?now.text.slice(0,24)+'…':now.text):(c.done===c.total&&c.total>0?' · 全部完成':''));
}
export function copyTodos(items:TodoItem[]|undefined):TodoItem[]{return (items??[]).map((x:TodoItem):TodoItem=>({text:x.text,status:x.status}));}
