import {Session,Task} from './Types';
// New tasks have an exact snapshot. For legacy tasks, use files already imported
// at task creation or actually referenced by that task and its predecessors.
export function branchFiles(session:Session,task:Task):string[]{
 if(task.fileIdsSnapshot)return task.fileIdsSnapshot.slice();
 const index=session.tasks.findIndex(t=>t.id===task.id);if(index<0)return [];
 const at=parseInt(task.id.split('-')[0],36),records=session.tasks.slice(0,index+1).flatMap(t=>t.records);
 return (session.fileIds??[]).filter(id=>parseInt(id.split('-')[0],36)<=at||records.some(r=>r.args.includes(id)||r.result.includes(id)));
}
