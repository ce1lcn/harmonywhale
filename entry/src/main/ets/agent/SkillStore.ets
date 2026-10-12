// 0.8.3 Skill 自写与版本管理。纯逻辑：只改传入的 State，不读写文件，不执行 Skill 内容。
import {Skill,SkillVersion,State,uid} from './Types';
import {DeviceError} from './Elements';
import {utf8Length} from './TextFiles';

export const SKILL_NAME_RE:RegExp=/^[a-z0-9]+(?:-[a-z0-9]+)*$/;
export const SKILL_BODY_MAX_BYTES:number=16*1024;
export const SKILL_VERSION_LIMIT:number=5;
const CATALOG_LINE_MAX:number=200;

export interface SkillInput {name:string;description:string;whenToUse:string;body:string;baseVersion?:number;external:boolean;}
export interface SaveResult {skill:Skill;created:boolean;version:number;external:boolean;}

export function validateSkillInput(input:SkillInput):void{
 if(!SKILL_NAME_RE.test(input.name)||input.name.length>60)throw new DeviceError('PARAMETER','name 须为 kebab-case（小写字母、数字、单个连字符），不超过 60 字符');
 if(!input.description||!input.description.trim()||input.description.length>300)throw new DeviceError('PARAMETER','description 不能为空，且不超过 300 字');
 if(!input.whenToUse||!input.whenToUse.trim()||input.whenToUse.length>300)throw new DeviceError('PARAMETER','whenToUse 写清适用场景，不能为空，且不超过 300 字');
 if(!input.body||!input.body.trim())throw new DeviceError('PARAMETER','body 不能为空');
 if(utf8Length(input.body)>SKILL_BODY_MAX_BYTES)throw new DeviceError('PARAMETER','body 不能超过 16 KB');
}

export function isSelfSkill(skill:Skill):boolean{return skill.origin==='self';}
// 第三方应用窗口：非大肥鱼且非系统界面（状态栏、桌面等）。判定为保守近似，真机核对后调整。
const SYSTEM_BUNDLE_PREFIXES:string[]=['com.ohos.systemui','com.ohos.launcher','com.huawei.systemui','com.huawei.hmos.systemui','com.huawei.hmos.launcher'];
export function externalWindow(bundle:string|undefined,self:string):boolean{
 if(!bundle||bundle===self)return false;
 return !SYSTEM_BUNDLE_PREFIXES.some(prefix=>bundle.startsWith(prefix));
}

function currentVersion(skill:Skill):number{return skill.version??1;}

// 保存为新 Skill 或新版本。同名导入 Skill 不允许覆盖；baseVersion 与当前版本不一致时拒绝。
export function saveSkill(state:State,input:SkillInput,now:number):SaveResult{
 validateSkillInput(input);
 const existing=state.skills.find(s=>s.name===input.name);
 if(!state.skills)state.skills=[];
 if(existing&&!isSelfSkill(existing))throw new DeviceError('CONFLICT','同名 Skill 是导入的，不能覆盖；请换一个名字');
 if(existing){
  const current=currentVersion(existing);
  if(input.baseVersion!==current)throw new DeviceError('CONFLICT','Skill 当前为 v'+current+'，baseVersion 不一致；请先 skill_list 查看后再保存');
  const history:SkillVersion[]=(existing.history??[]).slice();
  history.push({version:current,description:existing.description,whenToUse:existing.whenToUse??'',body:existing.body,time:now});
  while(history.length>SKILL_VERSION_LIMIT-1)history.shift();
  existing.history=history;
  existing.version=current+1;
  existing.description=input.description.trim();
  existing.whenToUse=input.whenToUse.trim();
  existing.body=input.body;
  existing.external=!!existing.external||input.external;
  existing.enabled=!existing.external;
  existing.saved=now;
  return {skill:existing,created:false,version:existing.version,external:input.external};
 }
 const skill:Skill={id:uid(),name:input.name,description:input.description.trim(),whenToUse:input.whenToUse.trim(),body:input.body,enabled:!input.external,references:[],folder:'',scripts:false,origin:'self',version:1,history:[],external:input.external,saved:now};
 state.skills.push(skill);
 return {skill:skill,created:true,version:1,external:input.external};
}

// 回滚：把历史中的某一版换为当前版，原当前版进入历史，总版本数不变。
export function rollbackSkill(state:State,name:string,toVersion:number):Skill{
 const skill=state.skills.find(s=>s.name===name);
 if(!skill)throw new DeviceError('NOT_FOUND','Skill 不存在');
 if(!isSelfSkill(skill))throw new DeviceError('PARAMETER','导入的 Skill 没有本地版本历史');
 const history:SkillVersion[]=(skill.history??[]).slice();
 const index=history.findIndex(v=>v.version===toVersion);
 if(index<0)throw new DeviceError('NOT_FOUND','没有这个版本');
 const target=history[index];
 history.splice(index,1);
 history.push({version:currentVersion(skill),description:skill.description,whenToUse:skill.whenToUse??'',body:skill.body,time:Date.now()});
 while(history.length>SKILL_VERSION_LIMIT-1)history.shift();
 skill.history=history;
 skill.version=currentVersion(skill)+1;
 skill.description=target.description;
 skill.whenToUse=target.whenToUse;
 skill.body=target.body;
 return skill;
}

export function setSkillEnabled(state:State,name:string,enabled:boolean):Skill{
 const skill=state.skills.find(s=>s.name===name);
 if(!skill)throw new DeviceError('NOT_FOUND','Skill 不存在');
 skill.enabled=enabled;

 return skill;
}

export function deleteSkill(state:State,name:string):void{
 const index=state.skills.findIndex(s=>s.name===name);
 if(index<0)throw new DeviceError('NOT_FOUND','Skill 不存在');
 state.skills.splice(index,1);
}

// 撤销刚学会的 Skill：有上一版则回滚，没有则删除。
export function undoSkill(state:State,name:string):string{
 const skill=state.skills.find(s=>s.name===name);
 if(!skill)return '已不存在';
 const history:SkillVersion[]=skill.history??[];
 if(history.length===0){deleteSkill(state,name);return '已删除';}
 const last:number=history[history.length-1].version;
 rollbackSkill(state,name,last);
 return '已回到 v'+last;
}

function origin(skill:Skill):string{return isSelfSkill(skill)?'大肥鱼写的':'导入';}

// 模型可见的 Skill 目录：只列启用项，每项带 whenToUse，单行有长度上限。
export function skillDirectory(state:State):string{
 return state.skills.filter(s=>s.enabled).map(s=>{
  const line=s.name+': '+s.description+(s.whenToUse?'（适用：'+s.whenToUse+'）':'');
  return line.length>CATALOG_LINE_MAX?line.substring(0,CATALOG_LINE_MAX)+'…':line;
 }).sort().join('\n');
}

export interface SkillSummary {name:string;description:string;whenToUse:string;origin:string;version:number;enabled:boolean;external:boolean;}
export function skillSummaries(state:State):SkillSummary[]{
 return state.skills.map(s=>({name:s.name,description:s.description,whenToUse:s.whenToUse??'',origin:origin(s),version:s.version??1,enabled:s.enabled,external:!!s.external} as SkillSummary));
}
