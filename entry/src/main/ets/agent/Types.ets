import {WebSource} from './WebTools';
import {StabilityReport} from './Stability';
export interface Usage { input:number; cacheRead:number; cacheWrite:number; output:number; total:number; calls:number; model:string; }
export interface DayUsage { day:string; total:number; calls:number; }
export interface Favorite { id:string; sessionId:string; sessionTitle:string; goal:string; reply:string; time:number; usage?:Usage; }
export interface ThinkingBlock {thinking:string;signature:string;}
export interface Attachment {id:string;name:string;kind:string;path:string;image?:string;ocr?:string;bytes?:number;}
export interface ChatEntry {thinkingBlocks?:ThinkingBlock[];attachments?:Attachment[];autoContinued?:number;providerReasoning?:string;reasoningMs?:number; role:string; text:string; time:number; taskId?:string;toolCallId?:string;incomplete?:boolean; }
export interface PlanStep {id:string;title:string;status:string;evidence:string;}
export interface Plan {id:string;text:string;status:string;steps:PlanStep[];}
export interface Goal {id:string;objective:string;criteria:string[];constraints:string[];status:string;}
export interface ContextState {usage?:Usage;method?:string;summary:string;through:number;recordCuts:Record<string,number>;before:number;after:number;time:number;}
export interface ToolRecord {parallel?:number;thinkingBlocks?:ThinkingBlock[];durationMs?:number;sources?:WebSource[];batchId?:string;targetLabel?:string;appName?:string;reasoningMs?:number; modelText?:string; stability?:StabilityReport; snapshotId?:string; verification?:string; errorCode?:string; id:string; name:string; args:string; result:string; status:string; time:number; observation:string; providerReasoning?:string; }
export interface FinalObservation {path:string;snapshotId:string;}
// 0.8.0：模型与工具耗时统计（底栏 ⏱ 胶囊），按任务累计。
export interface TaskTiming {modelCalls:number;modelMs:number;ttftMs:number;ttftCount:number;genMs:number;genTokens:number;toolMs:number;toolCalls:number;}
// 0.8.0：上下文按组成部分估算（底栏 ◔ 胶囊）。
export interface ContextStats {system:number;tools:number;messages:number;images:number;output:number;total:number;window:number;time:number;used?:number;served?:number;delta?:number;}
// 0.8.1 上下文锚点（DSH 口径）：最近一次请求服务端报告的提示 token（未缓存输入 + 缓存读 + 缓存写），以及发出该请求时的输入估算。
export interface ContextAnchor {prompt:number;estimate:number;time:number;}
export interface Task {leaseRenewals?:number;leaseRenewMs?:number;leaseNoticed?:boolean;hostNote?:string;toolTextRetries?:number;askUser?:AskUser;externalRead?:boolean;autoContinues?:number;retries?:number;returnedToSelf?:number;budgetUnit?:string;timing?:TaskTiming;resumeReason?:string;resumedThrough?:number;needsFinalObservation?:boolean;finalObservation?:FinalObservation;executionNote?:string;budgetBase?:number;fileIdsSnapshot?:string[];planId?:string;goalSnapshot?:Goal;planSnapshot?:Plan;continuingText?:boolean;fileTask?:boolean;deviceUsed?:boolean;replyIncomplete?:boolean; mode?:string; segmentCalls?:number; outcome?:string; evidence?:string; deviceTask?:boolean; id:string; goal:string; constraints:string[]; status:string; summary:string; records:ToolRecord[]; calls:number; reason:string; compactedThrough?:number; progress?:string;currentAction?:string; usage?:Usage; activeMs?:number; }
// 0.8.4 B4：待办清单，按会话保存，每次整体替换。status 为 pending / in_progress / done。
export interface TodoItem {text:string;status:string;}
export interface Session {todos?:TodoItem[];deletedFileIds?:string[];suggestion?:string; contextStats?:ContextStats; contextAnchor?:ContextAnchor; goal?:Goal;plan?:Plan;planning?:boolean;context?:ContextState;contextHistory?:ContextState[]; fileIds?:string[]; id:string; title:string; messages:ChatEntry[]; tasks:Task[]; pinned?:boolean; touched?:number; }
export interface Profile {protocol?:string; effort?:string; outputTokens?:number; id:string; title:string; baseUrl:string; model:string; vision:boolean; tools:boolean; contextWindow:number; thinking:string; }
export interface SkillVersion {version:number;description:string;whenToUse:string;body:string;time:number;}
// 0.8.3：origin 缺省为导入的 Skill；self 为大肥鱼写的。external 表示本任务读过网页或第三方屏幕后写入，默认停用。
export interface Skill { id:string; name:string; description:string; body:string; enabled:boolean; references:string[]; folder:string; scripts:boolean; whenToUse?:string; origin?:string; version?:number; history?:SkillVersion[]; external?:boolean; saved?:number; }
// 0.8.3 记忆：跨会话的用户偏好与事实，总长 2000 字以内。
export interface Memory {id:string;key:string;text:string;time:number;}
export interface AskOption {label:string;impact:string;recommended:boolean;}
export interface AskUser {question:string;options:AskOption[];time:number;}
export interface McpServer { id:string; title:string; url:string; enabled:boolean; }
export interface FileAsset {spillKey?:string;id:string;name:string;kind:string;path:string;folder:string;verified:boolean;sourceId?:string;origin?:string;callId?:string;time?:number;}
export interface State {compactConfigVersion?:number;downloadLimitMB?:number;compactReplay?:boolean;spillThreshold?:number;leaseRenew?:boolean;floatStrategy?:string;configVersion?:number;returnToSelf?:boolean;callBudget?:number;tokenBudget?:number; files?:FileAsset[]; sessions:Session[]; selected:string; profiles:Profile[]; activeProfile:string; skills:Skill[]; servers:McpServer[]; disabledTools?:string[]; memories?:Memory[]; fontScale?:number; favorites?:Favorite[]; usageDaily?:DayUsage[]; longestTaskMs?:number; }
// 0.8.4 B4：array 类型的参数用 items 描述元素（元素为对象时给出 properties 与 required）。
export interface PropertyItems { type:string; properties?:Record<string,Property>; required?:string[]; }
export interface Property { type:string; description?:string; enum?:string[]; items?:PropertyItems; }
export interface Schema { type:string; properties:Record<string,Property>; required:string[]; }
export interface Definition { name:string; description:string; parameters:Schema; source:string; enabled:boolean; readOnly:boolean; }
export interface Call { id:string; name:string; arguments:string; }
export interface Decision {thinkingBlocks?:ThinkingBlock[]; partialCalls?:boolean;incomplete?:boolean;finishReason?:string; text:string; calls:Call[]; providerReasoning?:string; usage?:Usage; }
export interface Observation {path?:string; snapshotId?:string; layout:string; image:string; width:number; height:number; fingerprint:string; }
export interface Arguments {format?:string;page?:number;entry?:string;sheetsJson?:string;blocksJson?:string;title?:string;imageId?:string;enabled?:boolean;version?:number;oldString?:string;newString?:string;replaceAll?:boolean;items?:TodoItem[]|string;ocr?:boolean;description?:string;whenToUse?:string;body?:string;baseVersion?:number;key?:string;question?:string;optionsJson?:string;content?:string;encoding?:string;limit?:number;strokesJson?:string;tool?:string;speed?:number;canvasElementId?:string;query?:string;count?:number;freshness?:string;url?:string;stepsJson?:string;stepId?:string;stepStatus?:string;fileId?:string;sheet?:string;offset?:number;slide?:number;paragraphId?:string;rowsJson?:string;patchesJson?:string;slidesJson?:string; snapshotId?:string;elementId?:string;condition?:string;direction?:string;maxSwipes?:number;untilText?:string;targetText?:string;timeoutMs?:number;appId?:string;outcome?:string;reply?:string;evidence?:string; x?:number;y?:number;x2?:number;y2?:number;text?:string;seconds?:number;name?:string;path?:string; }
export function uid():string{return Date.now().toString(36)+'-'+Math.random().toString(36).substring(2,8);}
export function newSession():Session{return {id:uid(),title:'新会话',messages:[],tasks:[]};}
export function defaults():State{const s=newSession();return {sessions:[s],selected:s.id,profiles:[{id:'deepseek',title:'DeepSeek',baseUrl:'https://api.deepseek.com',model:'deepseek-flash',vision:true,tools:true,contextWindow:1000000,thinking:'enabled',effort:'high'}],activeProfile:'deepseek',skills:[],servers:[],compactReplay:false,compactConfigVersion:8500,configVersion:8002};}
export function addUsage(a:Usage|undefined,b:Usage):Usage{if(!a)return {input:b.input,cacheRead:b.cacheRead,cacheWrite:b.cacheWrite,output:b.output,total:b.total,calls:b.calls,model:b.model};return {input:a.input+b.input,cacheRead:a.cacheRead+b.cacheRead,cacheWrite:a.cacheWrite+b.cacheWrite,output:a.output+b.output,total:a.total+b.total,calls:a.calls+b.calls,model:b.model||a.model};}

