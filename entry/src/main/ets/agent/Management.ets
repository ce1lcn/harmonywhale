import {State,Skill,Memory,Arguments,uid} from './Types';
import {DeviceError} from './Elements';
import {saveSkill,rollbackSkill,setSkillEnabled,deleteSkill} from './SkillStore';
import {saveMemory,forgetMemory,memoryTotal,MEMORY_TOTAL_MAX} from './Memory';
interface Change {id:string;kind:string;key:string;before:string;after:string;}
interface ConfirmationReceipt {required:boolean;status:string;channel:string;}
interface ManagementReceipt {undoId:string;kind:string;key:string;before:Object|null;after:Object|null;note:string;confirmation?:ConfirmationReceipt;}
// 撤销仅保存在本进程；校验当前目标与修改后相同，避免旧卡片覆盖后续修改。
export class Management {
 state:State;changes:Map<string,Change>=new Map();
 constructor(state:State){this.state=state;}
 current(kind:string,key:string):string {const item=kind==='skill'?this.state.skills.find(s=>s.name===key):(this.state.memories??[]).find(m=>m.key===key);return item?JSON.stringify(item):'';}
 get(name:string):Skill {const item=this.state.skills.find(s=>s.name===name);if(!item)throw new DeviceError('NOT_FOUND','没有这个技能');return item;}
 async execute(name:string,args:Arguments,external:boolean,confirm:(text:string)=>Promise<boolean>):Promise<string>{
  if(name==='memory_list')return JSON.stringify({memories:this.state.memories??[],total:memoryTotal(this.state.memories??[]),limit:MEMORY_TOTAL_MAX,note:memoryTotal(this.state.memories??[])>=1600?'接近上限，请提出合并建议，用户同意后才合并':''});
  if(name==='skill_get'){const s=this.get(args.name??'');return JSON.stringify({name:s.name,description:s.description,whenToUse:s.whenToUse,body:s.body,version:s.version??1,enabled:s.enabled,external:!!s.external,history:s.history??[]});}
  const kind=name.startsWith('skill_')?'skill':'memory';let key=kind==='skill'?(args.name??''):(args.key??'');let before=this.current(kind,key);let confirmationApproved:boolean=false;
  if(name==='skill_delete'){const s=this.get(key);if(!await confirm('删除技能「'+key+'」？本次启动期间可撤销。'))throw new DeviceError('DENIED','未删除技能');confirmationApproved=true;if(this.current(kind,key)!==before)throw new DeviceError('CONFLICT','确认期间技能变化，请重新读取');deleteSkill(this.state,s.name);}
  else if(name==='skill_set_enabled'){const s=this.get(key);if(args.enabled===true&&s.external){if(!await confirm('启用含外部来源的技能「'+key+'」？正文仅作指导，不执行脚本。'))throw new DeviceError('DENIED','未启用技能');confirmationApproved=true;if(this.current(kind,key)!==before)throw new DeviceError('CONFLICT','确认期间技能变化');}setSkillEnabled(this.state,key,args.enabled===true);}
  else if(name==='skill_rollback'){rollbackSkill(this.state,key,args.version??0);}
  else if(name==='skill_save'){saveSkill(this.state,{name:key,description:args.description??'',whenToUse:args.whenToUse??'',body:args.body??'',baseVersion:args.baseVersion,external:external},Date.now());}
  else if(name==='memory_save'){if(!this.state.memories)this.state.memories=[];const m=saveMemory(this.state.memories,args.text??'',args.key,Date.now());key=m.key;}
  else if(name==='memory_forget'){forgetMemory(this.state.memories??[],key);}
  else throw new DeviceError('PARAMETER','未知管理工具');
  const change:Change={id:uid(),kind:kind,key:key,before:before,after:this.current(kind,key)};this.changes.set(change.id,change);
  const receipt:ManagementReceipt={undoId:change.id,kind:kind,key:key,before:before?JSON.parse(before) as Object:null,after:change.after?JSON.parse(change.after) as Object:null,note:'修改前后对比；本次启动期间可撤销，后续已修改时拒绝旧撤销。'};
  if(confirmationApproved)receipt.confirmation={required:true,status:'approved',channel:'host_confirmation_card'};
  return JSON.stringify(receipt);
 }
 undo(id:string):string {const c=this.changes.get(id);if(!c)throw new DeviceError('NOT_FOUND','撤销已使用或应用已重启');if(this.current(c.kind,c.key)!==c.after)throw new DeviceError('CONFLICT','这项已再次修改，请重新查看，不能覆盖后续修改');if(c.kind==='skill'){this.state.skills=this.state.skills.filter(s=>s.name!==c.key);if(c.before)this.state.skills.push(JSON.parse(c.before) as Skill);}else{const remaining=(this.state.memories??[]).filter(m=>m.key!==c.key);const previous:Memory|null=c.before?JSON.parse(c.before) as Memory:null;if(previous&&memoryTotal(remaining)+previous.text.length>MEMORY_TOTAL_MAX)throw new DeviceError('MEMORY_FULL','撤销会超过记忆上限，请先整理其他记忆');if(previous)remaining.push(previous);this.state.memories=remaining;}this.changes.delete(id);return '已撤销：'+c.key;}
}
