// 0.8.4 A4：侧边栏会话多选与批量删除的纯逻辑（可在 node 测试中直接运行）。界面在 pages/Index.ets，只负责显示与确认。
import {Session} from './Types';

// 在已选列表里切换一个会话。
export function togglePicked(picked:string[],id:string):string[]{
 return picked.indexOf(id)>=0?picked.filter((v:string)=>v!==id):picked.concat([id]);
}

// 选择或取消一组会话：组内已经全部选中时取消这一组，否则补齐。
export function toggleGroup(picked:string[],ids:string[]):string[]{
 const all:boolean=ids.length>0&&ids.every((id:string)=>picked.indexOf(id)>=0);
 if(all)return picked.filter((v:string)=>ids.indexOf(v)<0);
 const out:string[]=picked.slice();
 ids.forEach((id:string)=>{if(out.indexOf(id)<0)out.push(id);});
 return out;
}

// 只保留仍然存在的会话编号（删除或搜索过滤后清理）。
export function pruneSelection(picked:string[],sessions:Session[]):string[]{
 return picked.filter((id:string)=>sessions.some((s:Session)=>s.id===id));
}

export interface BulkPlan {ids:string[];titles:string[];pinned:number;current:boolean;}
export function bulkPlan(sessions:Session[],ids:string[],selectedId:string):BulkPlan{
 const chosen:Session[]=sessions.filter((s:Session)=>ids.indexOf(s.id)>=0);
 return {ids:chosen.map((s:Session)=>s.id),titles:chosen.map((s:Session)=>s.title),pinned:chosen.filter((s:Session)=>!!s.pinned).length,current:chosen.some((s:Session)=>s.id===selectedId)};
}

// 删除前确认：标题带条数；正文列出最多 5 个会话名，置顶会话单独提醒。
export function confirmTitle(plan:BulkPlan):string{
 return plan.ids.length>1?'删除 '+plan.ids.length+' 个会话':'删除会话';
}
export function confirmMessage(plan:BulkPlan):string{
 const shown:string[]=plan.titles.slice(0,5).map((t:string)=>'· '+(t.length>24?t.slice(0,24)+'…':t));
 const more:string=plan.titles.length>5?'\n…等共 '+plan.titles.length+' 个':'';
 const pinned:string=plan.pinned>0?'\n其中 '+plan.pinned+' 个是置顶会话。':'';
 return '将删除 '+plan.ids.length+' 个会话：\n'+shown.join('\n')+more+pinned+'\n会话及其任务记录将被删除，无法恢复。';
}

// 删除后：保证至少有一个会话，并选出新的当前会话。返回新的会话列表与选中编号。
export interface BulkResult {sessions:Session[];selected:string;}
export function afterDelete(sessions:Session[],ids:string[],selected:string,fresh:()=>Session):BulkResult{
 let rest:Session[]=sessions.filter((s:Session)=>ids.indexOf(s.id)<0);
 if(rest.length===0)rest=[fresh()];
 const keep:string=rest.some((s:Session)=>s.id===selected)?selected:rest[rest.length-1].id;
 return {sessions:rest,selected:keep};
}
