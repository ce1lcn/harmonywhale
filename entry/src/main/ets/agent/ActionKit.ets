// 0.8.3.1 操作工具的纯逻辑（不依赖设备）：错误码与可重试标记、稳定元素编号、点击命中判定、
// 滚动计划、按条件等待、自适应稳定判定、按键映射。设备命令由 Device 执行，本文件只做判断与组装。

import {Element} from './Elements';

// ---- 错误码：枚举化，并标注 retryable（同一调用在重新观察后能否再试，无需用户处理）
export interface ErrorInfo {retryable:boolean;advice:string;}

export interface ErrorRow {code:string;retryable:boolean;advice:string;}
export const ERROR_ROWS:ErrorRow[]=[
 {code:'NOT_FOUND',retryable:true,advice:'重新 observe，用当前可见元素或坐标再试'},
 {code:'OCCLUDED',retryable:true,advice:'目标被遮挡，先关闭遮挡层（如弹窗）后重新 observe'},
 {code:'NOT_FOREGROUND',retryable:true,advice:'目标应用不在前台，先 launch_app 或回到目标页面再观察'},
 {code:'TIMEOUT',retryable:true,advice:'该工具超时，已取消。可以重试一次；仍然不行就换方式：换来源或关键词、缩小范围，屏幕操作先 observe 看现状；wait_for 超时说明条件没有出现，可延长 timeoutMs'},
 {code:'PERMISSION',retryable:false,advice:'系统权限不足，需要用户在系统设置中处理'},
 {code:'SELF_OVERLAP',retryable:true,advice:'大肥鱼小窗挡住了目标，移开小窗或切回全屏后重新 observe'},
 {code:'STALE',retryable:true,advice:'观察已过期，重新 observe 后再操作'},
 {code:'AMBIGUOUS',retryable:true,advice:'目标不唯一，用 observe 的 query 缩小范围或改用坐标'},
 {code:'DISABLED',retryable:false,advice:'目标当前不可用，改为完成前置条件后再操作'},
 {code:'NOT_EDITABLE',retryable:true,advice:'目标不是输入框，先找到可编辑元素再输入'},
 {code:'FOCUS',retryable:true,advice:'输入框未获得焦点，先点击输入框再输入'},
 {code:'UNLABELED',retryable:true,advice:'目标没有可读文字，改用截图坐标 click'},
 {code:'NOT_ACTIONABLE',retryable:true,advice:'目标暂不可操作，重新 observe 后再试'},
 {code:'PARAMETER',retryable:false,advice:'参数不合法，按工具说明修正后再调用'},
 {code:'DEVICE_OFFLINE',retryable:false,advice:'平板本机连接断开，需要用户在大肥鱼设置里重新连接'},
 {code:'DENIED',retryable:false,advice:'用户拒绝了这次操作，不要重复尝试'},
 {code:'SENSITIVE',retryable:false,advice:'敏感输入由用户自己完成'},
 {code:'INTERRUPTED',retryable:false,advice:'任务已暂停，等待用户恢复'},
 {code:'UNKNOWN_APP',retryable:false,advice:'应用不在已发现列表，先 get_capabilities 确认'},
 {code:'APPROVAL_UI',retryable:false,advice:'确认界面未能显示，需要用户处理'},
 {code:'NO_PROGRESS',retryable:false,advice:'连续没有进展，停止重复并说明情况'},
 {code:'EVIDENCE',retryable:false,advice:'完成步骤需要说明证据'},
 {code:'FILE_NOT_FOUND',retryable:false,advice:'文件不存在，用 file_list 查看当前会话文件'},
 {code:'FILE_ERROR',retryable:false,advice:'文件读写失败，可稍后重试或换一个文件名'},
 {code:'MEMORY_FULL',retryable:false,advice:'记忆总长已满，先删除旧记忆'},
 {code:'CONFLICT',retryable:false,advice:'版本冲突，先读取最新版本再保存'},
 {code:'EDIT_NOT_FOUND',retryable:true,advice:'用 file_read 重新读取文件，逐字核对要替换的原文（含空白与换行）再改'},
 {code:'EDIT_AMBIGUOUS',retryable:true,advice:'给 oldString 补充前后文使它唯一，或明确要改全部时设 replaceAll=true'},
 {code:'NOT_READ',retryable:true,advice:'先用 file_read 读取这个文件，再用 file_edit 修改'},
 {code:'FILE_CHANGED',retryable:true,advice:'文件在你读取之后变化了，用 file_read 重新读取再改'},
 {code:'DESKTOP_GUARD',retryable:false,advice:'桌面上不点击，打开应用请用 launch_app'},
 {code:'CLASSCOUNT_GUARD',retryable:false,advice:'ClassCount 不属于大肥鱼操作范围，不要点击其窗口'}
];

// 未在表中的错误码按不可重试处理，并给出通用建议。
export function errorInfo(code:string):ErrorInfo{
 const hit:ErrorRow|undefined=ERROR_ROWS.find((r:ErrorRow)=>r.code===code);
 return hit?{retryable:hit.retryable,advice:hit.advice}:{retryable:false,advice:'请说明情况并等待用户处理'};
}
// 测试与调试用：列出全部错误码。
export function errorCodes():string[]{return ERROR_ROWS.map((r:ErrorRow)=>r.code);}

// 给模型看的错误文本：错误码、是否可重试、一句建议。
export function formatError(code:string,message:string):string{
 const info:ErrorInfo=errorInfo(code);
 return '错误码 '+code+'（可重试：'+(info.retryable?'是':'否')+'）：'+message+'。建议：'+info.advice;
}

// ---- 稳定元素编号：由 类型、id、文字、描述、父路径、窗口 派生的哈希；同键重复时加序号后缀保证唯一。
export function fnv1a(text:string):string{
 let hash:number=0x811c9dc5;
 for(let i=0;i<text.length;i++){
  hash=hash^text.charCodeAt(i);
  hash=Math.imul(hash,0x01000193)>>>0;
 }
 return ('00000000'+hash.toString(16)).slice(-8);
}

export function stableKey(e:Element):string{
 return [e.type,e.id,e.text,e.description,e.parent,e.window].join('|');
}

// 原地改写 elementId：场景不变时同一控件得到同一编号。
export function assignStableIds(elements:Element[]):void{
 const seen:Map<string,number>=new Map<string,number>();
 elements.forEach((e:Element)=>{
  const key:string=stableKey(e);
  const count:number=seen.get(key)??0;
  seen.set(key,count+1);
  e.elementId='h'+fnv1a(key)+(count>0?'-'+count:'');
 });
}

// ---- 点击命中：坐标为 0–1000 比例；返回包含该点的最小可点击（否则最小有文字的）元素文字，无则为空白处。
export interface HitResult {hit:boolean;label:string;}
export function hitAt(elements:Element[],width:number,height:number,x:number,y:number):HitResult{
 if(!(width>0)||!(height>0))return {hit:false,label:'空白处'};
 const px:number=x*width/1000;
 const py:number=y*height/1000;
 let best:Element|null=null;
 let bestArea:number=Number.MAX_VALUE;
 elements.forEach((e:Element)=>{
  const b:number[]=e.bounds;
  if(b.length!==4||px<b[0]||px>b[2]||py<b[1]||py>b[3])return;
  const area:number=(b[2]-b[0])*(b[3]-b[1]);
  const named:boolean=!!(e.text||e.description);
  if(!named)return;
  // 可点击的优先；同等条件下取面积最小者（最具体的控件）。
  const score:number=(e.clickable?0:1e12)+area;
  if(score<bestArea){bestArea=score;best=e;}
 });
 if(best===null)return {hit:false,label:'空白处'};
 const found:Element=best as Element;
 return {hit:true,label:(found.text||found.description).slice(0,80)};
}

// ---- 滚动计划：direction 表示内容的移动方向（down 表示看向下方内容，手指向上滑）。坐标 0–1000，最多 8 次。
export interface Swipe {x1:number;y1:number;x2:number;y2:number;}
export function scrollPlan(direction:string,count:number):Swipe[]{
 const n:number=Math.max(1,Math.min(8,Math.round(count)));
 const out:Swipe[]=[];
 for(let i=0;i<n;i++){
  if(direction==='down')out.push({x1:500,y1:750,x2:500,y2:250});
  else if(direction==='up')out.push({x1:500,y1:250,x2:500,y2:750});
  else if(direction==='right')out.push({x1:250,y1:500,x2:750,y2:500});
  else out.push({x1:750,y1:500,x2:250,y2:500});
 }
 return out;
}

export function validScrollDirection(direction:string):boolean{
 return direction==='up'||direction==='down'||direction==='left'||direction==='right';
}

// ---- 按条件等待：textAppears / textDisappears / screenChanges。
export const WAIT_CONDITIONS:string[]=['textAppears','textDisappears','screenChanges'];

// 页面内容指纹（不含位置噪声）：仅用于判断屏幕是否变化。
export function sceneFingerprint(elements:Element[]):string{
 return elements.filter((e:Element)=>e.normalizedCenter[1]>=40).map((e:Element)=>[e.type,e.text,e.description].join('|')).sort().join('\n');
}

export function textPresent(elements:Element[],text:string):boolean{
 if(!text)return false;
 return elements.some((e:Element)=>e.text.indexOf(text)>=0||e.description.indexOf(text)>=0);
}

// 返回 true 表示条件满足。
export function waitSatisfied(condition:string,targetText:string,baseline:string,current:Element[]):boolean{
 if(condition==='textAppears')return textPresent(current,targetText);
 if(condition==='textDisappears')return !textPresent(current,targetText);
 if(condition==='screenChanges')return sceneFingerprint(current)!==baseline;
 return false;
}

// ---- 自适应稳定：每 300 ms 取一次指纹，相邻两次相同即稳定；默认上限 4 s，可由 settleMs 覆盖（≤12 s）。
export const SETTLE_INTERVAL_MS:number=300;
export const SETTLE_DEFAULT_CAP_MS:number=4000;
export const SETTLE_MAX_CAP_MS:number=12000;
export function settleCap(settleMs:number|undefined):number{
 if(settleMs===undefined||!Number.isFinite(settleMs))return SETTLE_DEFAULT_CAP_MS;
 return Math.max(SETTLE_INTERVAL_MS,Math.min(SETTLE_MAX_CAP_MS,Math.round(settleMs)));
}

// 给定上一个指纹与当前指纹，判断是否已稳定。
export function settled(previous:string|undefined,current:string):boolean{
 return previous!==undefined&&previous===current;
}

// ---- 按键映射（uitest uiInput keyEvent 的键码，取自 SDK 的 KeyCode 定义）。
export function keyCodeOf(name:string):string{
 if(name==='enter')return '2054';
 if(name==='backspace')return '2055';
 if(name==='tab')return '2049';
 if(name==='escape')return '2070';
 return '';
}
export const PRESS_KEYS:string[]=['enter','backspace','tab','escape'];

// ---- observe 的 query：只列出文字、描述、类型或编号包含该词的元素（大小写不敏感），匹配项不截断。
export function queryElements(elements:Element[],query:string):Element[]{
 const q:string=query.trim().toLowerCase();
 if(!q)return elements;
 return elements.filter((e:Element)=>[e.text,e.description,e.type,e.id].join('|').toLowerCase().indexOf(q)>=0);
}

// ---- 布局预算：超长时优先保留可点击元素，其次有文字的，最后其他；输出仍保持原始顺序。
export interface LayoutPick {kept:Element[];omitted:number;}
interface RankedElement {e:Element;i:number;r:number;}
export function pickForLayout(elements:Element[],budget:number,lineOf:(e:Element)=>string):LayoutPick{
 const rank=(e:Element):number=>e.clickable?0:((e.text||e.description)?1:2);
 const order:RankedElement[]=elements.map((e:Element,i:number):RankedElement=>{return {e:e,i:i,r:rank(e)} as RankedElement;});
 order.sort((a:RankedElement,b:RankedElement):number=>a.r!==b.r?a.r-b.r:a.i-b.i);
 const chosen:Set<number>=new Set<number>();
 let used:number=0;
 order.forEach((o:RankedElement)=>{const len:number=lineOf(o.e).length+1;if(used+len<=budget){chosen.add(o.i);used+=len;}});
 const kept:Element[]=elements.filter((e:Element,i:number)=>chosen.has(i));
 return {kept:kept,omitted:elements.length-kept.length};
}

// ---- 进度行文字：只用短标签，绝不使用工具描述（描述是给模型看的内部提示词）。
// ask_user 显示“正在询问你：问题”，其他工具显示动词短语。
interface ProgressName {name:string;label:string;}
const PROGRESS_NAMES:ProgressName[]=[
 {name:'click',label:'点击'},
 {name:'long_press',label:'长按'},
 {name:'double_click',label:'双击'},
 {name:'drag',label:'拖拽'},
 {name:'scroll',label:'滚动'},
 {name:'press_key',label:'按键'},
 {name:'insert_text',label:'输入文字'},
 {name:'replace_text',label:'替换文字'},
 {name:'swipe',label:'滑动'},
 {name:'back',label:'返回'},
 {name:'home',label:'回到桌面'},
 {name:'observe',label:'观察屏幕'},
 {name:'wait_for',label:'等待页面变化'},
 {name:'launch_app',label:'启动应用'},
 {name:'finish_task',label:'整理结果'},
 {name:'file_write',label:'写入文件'},
 {name:'file_read',label:'读取文件'},
 {name:'file_edit',label:'修改文件'},
 {name:'todo_write',label:'更新待办'},
 {name:'file_list',label:'查看文件列表'},
 {name:'skill_save',label:'保存技能'},
 {name:'skill_list',label:'查看技能'},
 {name:'memory_save',label:'保存记忆'},
 {name:'memory_forget',label:'删除记忆'},
 {name:'clipboard_write',label:'写入剪贴板'},
 {name:'get_capabilities',label:'查询能力'},
 {name:'request_confirmation',label:'请求确认'}
];
export function progressLabel(name:string,question:string):string{
 if(name==='ask_user'){const q:string=question.replace(/\s+/g,' ').trim();return q.length?'正在询问你：'+q.slice(0,40):'正在询问你';}
 const hit:ProgressName|undefined=PROGRESS_NAMES.find((p:ProgressName)=>p.name===name);
 return hit?hit.label:'执行 '+name;
}

// ---- 0.8.4 A6：OCR 触发判定。
// 模型可以用 observe 的 ocr:true 主动要求识别；否则只在“读不到文字”或“模型看不到图”时自动识别。
// 阈值与理由：
//  - 可读文字节点 < 8 个：状态栏（顶部 4% 以内）的时间、电量、网络文字不算；0.8.3 的阈值 5 在备忘录、浏览器这类自带标题栏和工具栏的页面上永远达不到，OCR 从未触发。
//  - 可读文字总长 < 40 字：节点数够但都是一两个字的按钮（工具栏图标标签）时，页面主体仍然没有文字。
//  - 大面积无文字区域：类型含 Image / Canvas / XComponent / Web / Video 的元素占屏幕面积 35% 以上，且其范围内可读文字节点少于 3 个（图片查看器、网页画布、游戏页面）。
//  - 当前模型不支持视觉：看不到截图，每次观察都识别，文字结果就是它唯一的“眼睛”。
// 0.8.4.1：整屏 2800×1840 直接识别在真机上超时；按长边依次尝试（先 1600，再 1024），坐标换回屏幕像素。
export const OCR_EDGES:number[]=[1600,1024];
export const OCR_MIN_NODES:number=8;
export const OCR_MIN_CHARS:number=40;
export const OCR_BIG_AREA:number=0.35;
export const OCR_INSIDE_MIN:number=3;
export interface OcrDecision {run:boolean;reason:string;}
export function readableElements(elements:Element[]):Element[]{
 return elements.filter((e:Element)=>e.type!=='ocr'&&e.text.trim().length>0&&e.normalizedCenter[1]>=40);
}
export function ocrDecision(elements:Element[],width:number,height:number,forced:boolean,vision:boolean):OcrDecision{
 if(forced)return {run:true,reason:'模型要求识别（ocr:true）'};
 if(!vision)return {run:true,reason:'当前模型不支持视觉'};
 const readable:Element[]=readableElements(elements);
 if(readable.length<OCR_MIN_NODES)return {run:true,reason:'可读文字节点只有 '+readable.length+' 个（少于 '+OCR_MIN_NODES+'）'};
 const chars:number=readable.reduce((n:number,e:Element)=>n+e.text.trim().length,0);
 if(chars<OCR_MIN_CHARS)return {run:true,reason:'可读文字只有 '+chars+' 字（少于 '+OCR_MIN_CHARS+'）'};
 const screen:number=Math.max(1,width*height);
 const big:Element|undefined=elements.find((e:Element)=>{
  if(e.type==='ocr'||!/Image|Canvas|XComponent|Web|Video/i.test(e.type)||e.bounds.length!==4)return false;
  const area:number=Math.max(0,e.bounds[2]-e.bounds[0])*Math.max(0,e.bounds[3]-e.bounds[1]);
  if(area<screen*OCR_BIG_AREA)return false;
  const inside:number=readable.filter((r:Element)=>r.bounds.length===4&&(r.bounds[0]+r.bounds[2])/2>=e.bounds[0]&&(r.bounds[0]+r.bounds[2])/2<=e.bounds[2]&&(r.bounds[1]+r.bounds[3])/2>=e.bounds[1]&&(r.bounds[1]+r.bounds[3])/2<=e.bounds[3]).length;
  return inside<OCR_INSIDE_MIN;
 });
 if(big)return {run:true,reason:'屏幕大面积（'+big.type+'）区域内没有可读文字'};
 return {run:false,reason:''};
}
