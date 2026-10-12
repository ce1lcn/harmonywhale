// 0.8.3 新增工具的定义与参数解析：Skill、记忆、ask_user、get_capabilities、剪贴板。文件工具定义见 FileRegistry.ets。
import {Definition,Property,PropertyItems,Schema,AskOption} from './Types';
import {DeviceError} from './Elements';

export const ASK_OPTION_MAX:number=4;
export const ASK_LABEL_MAX:number=20;
export const ASK_IMPACT_MAX:number=60;
export const ASK_QUESTION_MAX:number=300;

// 工具名称集合：Engine 据此判断哪些调用走本地分支而不是设备分支。
export const LOCAL_TOOL_NAMES:string[]=['memory_list','skill_get','skill_set_enabled','skill_delete','skill_rollback','skill_list','skill_save','memory_save','memory_forget','ask_user','get_capabilities','clipboard_write','todo_write'];

function prop(type:string,description:string):Property{const p:Property={type:type,description:description};return p;}
function def(name:string,description:string,props:Record<string,Property>,required:string[],source:string,readOnly:boolean,disabled:string[]):Definition{
 const parameters:Schema={type:'object',properties:props,required:required};
 const d:Definition={name:name,description:description,parameters:parameters,source:source,enabled:disabled.indexOf(name)<0,readOnly:readOnly};
 return d;
}

export function generalDefinitions(disabled:string[]):Definition[]{
 const out:Definition[]=[];
 const none:Record<string,Property>={};
 out.push(def('skill_list','列出全部 Skill：名称、适用场景、来源（导入或大肥鱼写的）、版本、是否启用、是否含外部来源。只读。',none,[],'平板内置',true,disabled));
 out.push(def('memory_list','用户问记住什么时列出全部记忆、key、内容与保存时间。接近上限先提合并建议，用户同意才执行。',none,[],'平板内置',true,disabled));
 const target:Record<string,Property>={};target['name']=prop('string','skill_list 返回的名称');const enabledProps:Record<string,Property>={};enabledProps['name']=target['name'];enabledProps['enabled']=prop('boolean','true 启用，false 停用');const versionProps:Record<string,Property>={};versionProps['name']=target['name'];versionProps['version']=prop('number','历史版本号');
 out.push(def('skill_get','查看技能全文、当前版本、启用状态和外部来源；修改前先查看，与执行用 skill_load 区分。',target,['name'],'平板内置',true,disabled));
 out.push(def('skill_delete','删除指定技能，宿主先显示具体确认卡片；本次启动可撤销。',target,['name'],'平板内置',false,disabled));
 out.push(def('skill_set_enabled','启停技能；停用直接执行，含外部来源的启用须用户确认。',enabledProps,['name','enabled'],'平板内置',false,disabled));
 out.push(def('skill_rollback','回滚到 skill_get 返回的历史版本，保留当前版本历史。',versionProps,['name','version'],'平板内置',false,disabled));
 const skillProps:Record<string,Property>={};
 skillProps['name']=prop('string','kebab-case 名称，如 back-to-self');
 skillProps['description']=prop('string','一句话说明这个 Skill 做什么');
 skillProps['whenToUse']=prop('string','何时应该使用，写清场景');
 skillProps['body']=prop('string','Markdown 正文：步骤、界面文字、注意事项，不超过 16 KB');
 skillProps['baseVersion']=prop('number','更新时填写当前版本号；新建时不填');
 out.push(def('skill_save','把你摸索成功、以后还会用的流程保存为 Skill。name 用 kebab-case；whenToUse 写清何时用；body 写步骤和要找的界面文字，不写死坐标。同名导入 Skill 不能覆盖；更新自己写的 Skill 时传 baseVersion（当前版本号）防止覆盖别人改过的版本。本任务读过网页或第三方应用屏幕时，新 Skill 默认停用，需用户启用。',skillProps,['name','description','whenToUse','body'],'平板内置',false,disabled));
 const memProps:Record<string,Property>={};
 memProps['text']=prop('string','要记住的内容，一条一事');
 memProps['key']=prop('string','可选，用于以后覆盖或删除这条记忆');
 out.push(def('memory_save','记住用户的偏好或事实（用户说“记住…”时使用）。text 不超过 200 字；传 key 时同 key 覆盖旧内容。全部记忆总长不超过 2000 字，超出时先合并或删除旧条目。',memProps,['text'],'平板内置',false,disabled));
 const forgetProps:Record<string,Property>={};
 forgetProps['key']=prop('string','要删除的记忆 key');
 out.push(def('memory_forget','删除一条记忆（按 memory_save 时的 key）。',forgetProps,['key'],'平板内置',false,disabled));
 const askProps:Record<string,Property>={};
 askProps['question']=prop('string','要问用户的问题，一句话，不超过 300 字');
 askProps['optionsJson']=prop('string','可选，JSON 数组，最多 4 项，每项 {"label":"…","impact":"…","recommended":true}');
 out.push(def('ask_user','信息不足、需要用户做选择时提问，不用于危险动作确认（危险动作用 request_confirmation）。给出选项时 optionsJson 为 JSON 数组，每项 {label, impact, recommended?}：label 不超过 20 字，impact 用一句话说明选择的影响，推荐项放第一位并标 recommended=true。用户也可以直接输入文字回答。提问后本次任务暂停，等待回答。',askProps,['question'],'平板内置',true,disabled));
 out.push(def('get_capabilities','查看本机能力：已注册工具、已安装可启动应用（名称与包名）、屏幕尺寸与方向、网络、当前时间。只读，结果会缓存；安装或卸载应用后可刷新。',none,[],'平板内置',true,disabled));
 const clipProps:Record<string,Property>={};
 clipProps['text']=prop('string','要写入剪贴板的文字，不超过 100000 字');
 out.push(def('clipboard_write','把文字写入系统剪贴板，方便用户粘贴。不读取剪贴板，不需要确认。',clipProps,['text'],'平板内置',false,disabled));
 // 0.8.4 B4：待办清单。参照 DSH tool-todo：每次整体替换，同一时间最多一项进行中。
 const itemProps:Record<string,Property>={};
 itemProps['text']=prop('string','这一步要做什么，一句话，不超过 100 字');
 const todoStatus:Property={type:'string',description:'pending 未开始 | in_progress 正在做（同一时间最多一项）| done 已完成',enum:['pending','in_progress','done']};
 itemProps['status']=todoStatus;
 const todoItem:PropertyItems={type:'object',properties:itemProps,required:['text','status']};
 const todoProps:Record<string,Property>={};
 const todoItems:Property={type:'array',description:'完整的待办清单，整体替换此前的清单；最多 20 项。传空数组表示清空',items:todoItem};
 todoProps['items']=todoItems;
 out.push(def('todo_write','记录并更新待办清单，用来规划多步任务并显示进度；一两步的小事不要用。三步以上的任务开始前先为每个具体步骤列一项，做完一项就重新提交整份清单并把它标 done，同一时间只有一项 in_progress。每次调用都是整体替换。',todoProps,['items'],'平板内置',true,disabled));
 return out;
}

// 解析 ask_user 选项：最多 4 项，推荐项排第一，且只保留一个推荐。
export function parseAskOptions(raw:string|undefined):AskOption[]{
 if(raw===undefined||raw.trim()==='')return [];
 let data:Object;
 try{data=JSON.parse(raw) as Object;}catch(e){throw new DeviceError('PARAMETER','optionsJson 不是合法 JSON');}
 if(!Array.isArray(data))throw new DeviceError('PARAMETER','optionsJson 必须是数组');
 const items=data as Object[];
 if(items.length>ASK_OPTION_MAX)throw new DeviceError('PARAMETER','选项最多 4 项');
 const options:AskOption[]=[];
 items.forEach((item:Object)=>{
  const o=item as Record<string,Object>;
  const label=typeof o['label']==='string'?(o['label'] as string).trim():'';
  const impact=typeof o['impact']==='string'?(o['impact'] as string).trim():'';
  if(!label||label.length>ASK_LABEL_MAX)throw new DeviceError('PARAMETER','每个选项的 label 需为 1–20 字');
  if(impact.length>ASK_IMPACT_MAX)throw new DeviceError('PARAMETER','impact 不超过 60 字');
  options.push({label:label,impact:impact,recommended:o['recommended']===true});
 });
 // 推荐项只保留第一个并排在最前；其余（包括多余的推荐标记）按普通选项保留原顺序。
 const result:AskOption[]=[];
 let promoted=false;
 options.forEach((o:AskOption)=>{
  if(o.recommended&&!promoted){promoted=true;result.unshift({label:o.label,impact:o.impact,recommended:true});}
  else result.push({label:o.label,impact:o.impact,recommended:false});
 });
 return result;
}

export function parseAskQuestion(raw:string|undefined):string{
 const value=(raw??'').trim();
 if(!value)throw new DeviceError('PARAMETER','question 不能为空');
 if(value.length>ASK_QUESTION_MAX)throw new DeviceError('PARAMETER','question 不超过 300 字');
 return value;
}
