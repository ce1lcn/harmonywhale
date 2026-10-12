import {TreeNode} from './Elements';
import {Task} from './Types';
// 0.8.1 小窗：纯逻辑部分（可在 node 测试中直接转译运行）。窗口 API 调用放在 pages/FloatWindow.ets。

// 截图隐形策略：V1 透明、V2 隐藏、V3 隐私窗口、仅遮盖（兜底）。
// 0.8.1.1 起默认 V3：真机（docs/FLOAT-0.8.1.md §3）V1 截图里小窗是不透明空白卡片、V2 恢复后变回全屏，只有 V3 + 灰块遮盖 + SELF_OVERLAP 可靠。
export const FLOAT_STRATEGIES:string[]=['transparent','hide','privacy','mask'];
export const DEFAULT_FLOAT_STRATEGY:string='privacy';
export function normalizeStrategy(s:string|undefined):string{return s&&FLOAT_STRATEGIES.indexOf(s)>=0?s:DEFAULT_FLOAT_STRATEGY;}
export function strategyLabel(s:string):string{return s==='hide'?'V2 截图瞬间隐藏':s==='privacy'?'V3 隐私窗口':s==='mask'?'仅灰块遮盖':'V1 截图瞬间透明';}

// 紧凑模式：窗口宽度小于 600vp。宽度未知（0）时不切换。
export const COMPACT_WIDTH_VP:number=600;
export function isCompactWidth(widthVp:number):boolean{return widthVp>0&&widthVp<COMPACT_WIDTH_VP;}

// 一次截图前后小窗的处理结果。
export interface CaptureState {
 strategy:string;
 hidden:boolean;      // 截图时小窗确实不可见（V1/V2 调用成功）
 masked:boolean;      // 需要灰块遮盖并启用 SELF_OVERLAP 守卫（V3 黑块、仅遮盖、或 V1/V2 失败）
 restoreSelf:boolean; // 截图后需要把大肥鱼切回前台（V2 用最小化实现时）
 error:string;
}
// Device 依赖的小窗接口；页面侧实现，测试里用桩。
export interface SelfOverlay {
 active():boolean;                       // 大肥鱼正以悬浮窗显示且在前台
 beforeCapture():Promise<CaptureState>;  // 截图前隐形
 afterCapture(state:CaptureState):Promise<void>; // 截图后恢复（必须调用）
 setTouchable(touchable:boolean):Promise<void>;
 windowRect():number[];                  // 小窗在屏幕上的像素矩形 [l,t,r,b]，未知时返回 []
}
export function failedCapture(strategy:string,error:string):CaptureState{return {strategy:strategy,hidden:false,masked:true,restoreSelf:false,error:error};}

// 注入期间让小窗不接收触摸（事件落到下层应用），无论成功、失败还是异常都恢复可触摸。
export async function passThrough<T>(o:SelfOverlay|null|undefined,fn:()=>Promise<T>):Promise<T>{
 if(!o||!o.active())return fn();
 try{await o.setTouchable(false);}catch(e){/* 设置失败照常执行；遮盖守卫兜底 */}
 try{return await fn();}
 finally{
  try{await o.setTouchable(true);}catch(e){try{await o.setTouchable(true);}catch(e2){}}
 }
}
// 截图前隐形、截图后恢复；fn 抛错时也一定恢复。
export async function captureHidden<T>(o:SelfOverlay,fn:(state:CaptureState)=>Promise<T>):Promise<T>{
 let state:CaptureState;
 try{state=await o.beforeCapture();}catch(e){state=failedCapture(DEFAULT_FLOAT_STRATEGY,(e as Error).message??String(e));}
 try{return await fn(state);}
 finally{try{await o.afterCapture(state);}catch(e){}}
}

// 从 uitest dumpLayout 中剔除属于自身包名的窗口节点。返回剔除后的新树与这些窗口的像素矩形。
export interface StripResult {tree:TreeNode;removed:number;rects:number[][];}
// 悬浮窗的系统标题栏（放大/最小化/关闭按钮）由 sceneboard 单独成窗，不带自身包名；真机 0.8.1 布局中可点击，需一并剔除。
const FLOAT_DECOR_IDS:string[]=['floatingButtonClose','floatingButtonMaximize','floatingButtonMinimize','SCBFloatTitleButton'];
function hasDecorId(n:TreeNode):boolean{const id=n.attributes?.id;if(id&&FLOAT_DECOR_IDS.indexOf(id)>=0)return true;return (n.children??[]).some(c=>hasDecorId(c));}
function decorOf(b:number[],rects:number[][]):boolean{return b.length===4&&rects.some(r=>Math.abs(b[0]-r[0])<=4&&Math.abs(b[2]-r[2])<=4&&b[3]>=r[1]-120&&b[1]<=r[1]+120);}
function boundsOf(a:Record<string,string>|undefined):number[]{const m=(a?.bounds??'').match(/-?\d+/g);if(!m||m.length!==4)return [];const b=m.map(v=>Number(v));return b[2]>b[0]&&b[3]>b[1]?b:[];}
export function stripSelf(tree:TreeNode,bundle:string):StripResult{
 const windows:string[]=[];const rects:number[][]=[];let removed=0;
 // 第一遍：找出自身窗口的根节点（带 bundleName 属性），记下窗口编号与矩形。
 const find=(n:TreeNode):void=>{const a=n.attributes;if(a&&a.bundleName===bundle){if(a.hostWindowId)windows.push(a.hostWindowId);const b=boundsOf(a);if(b.length)rects.push(b);return;}(n.children??[]).forEach(find);};
 find(tree);
 const count=(n:TreeNode):number=>1+(n.children??[]).reduce((s:number,c:TreeNode)=>s+count(c),0);
 // 第二遍：去掉自身窗口根节点，以及任何仍挂着自身窗口编号的节点（弹窗等）。
 const selfRects=rects.slice();
 const copy=(n:TreeNode):TreeNode|null=>{const a=n.attributes;if(a&&(a.bundleName===bundle||(!!a.hostWindowId&&windows.indexOf(a.hostWindowId)>=0))){removed+=count(n);return null;}
  if(a&&a.bundleName==='com.ohos.sceneboard'&&hasDecorId(n)){const b=boundsOf(a);if(decorOf(b,selfRects)){removed+=count(n);rects.push(b);return null;}}const out:TreeNode={attributes:a};const kids:TreeNode[]=[];(n.children??[]).forEach(c=>{const k=copy(c);if(k)kids.push(k);});if(n.children)out.children=kids;return out;};
 const result=copy(tree)??({attributes:tree.attributes,children:[]} as TreeNode);
 return {tree:result,removed:removed,rects:rects};
}

// aa dump -l 中的前台应用：小窗时自身与下层应用同为 FOREGROUND，优先返回非自身的那个。
// visible：最近一次 dumpLayout 中有窗口的包名。真机 0.8.1 发现 WPS 的后台 Ability 长期停在 FOREGROUND 且排在前面，有可见窗口的优先。
export function foregroundBundle(raw:string,self:string,preferOther:boolean,visible:string[]=[]):string{
 let found:string[]=[];raw.split('AbilityRecord ID').forEach(block=>{if(block.indexOf('state #FOREGROUND')<0)return;const b=/bundle name \[([^\]]+)\]/.exec(block)?.[1];if(b)found.push(b);});
 const shown=found.filter(b=>visible.indexOf(b)>=0);if(shown.length)found=shown;
 if(preferOther){const other=found.find(b=>b!==self);if(other)return other;}
 return found.length?found[0]:'';
}
// 布局树中各窗口根节点的包名（不含重复）。
export function windowBundles(tree:TreeNode):string[]{const out:string[]=[];const walk=(n:TreeNode):void=>{const b=n.attributes?.bundleName;if(b){if(out.indexOf(b)<0)out.push(b);return;}(n.children??[]).forEach(walk);};walk(tree);return out;}
// 0.8.4 A2：判断“当前在操作哪个应用”时，优先使用最近一次布局里有可见窗口的包名（排除桌面 sceneboard、输入法、系统界面，以及 preferOther 时的大肥鱼自己）。
// 真机 0.8.3.9：aa dump -l 的第一个 FOREGROUND 块是 WPS 的服务 Ability（cn.wps.office.hap:wpscloudsvr），把备忘录里的操作记成了 WPS。
// 有多个候选窗口（分屏、小窗）时，取同时出现在 aa dump FOREGROUND 列表里的第一个；都不在列表里就取布局里的第一个。没有可见候选时才退回 aa dump 的旧逻辑。
export function isChromeBundle(bundle:string):boolean{return bundle==='com.ohos.sceneboard'||/inputmethod|systemui/i.test(bundle);}
export function visibleAppBundles(visible:string[],self:string,preferOther:boolean):string[]{return visible.filter((b:string)=>!isChromeBundle(b)&&!(preferOther&&b===self));}
export function frontBundle(raw:string,self:string,preferOther:boolean,visible:string[]=[]):string{
 const pool:string[]=visibleAppBundles(visible,self,preferOther);
 if(pool.length===1)return pool[0];
 if(pool.length>1){
  const found:string[]=[];raw.split('AbilityRecord ID').forEach((block:string)=>{if(block.indexOf('state #FOREGROUND')<0)return;const b=/bundle name \[([^\]]+)\]/.exec(block)?.[1];if(b)found.push(b);});
  const hit:string|undefined=found.find((b:string)=>pool.indexOf(b)>=0);
  return hit??pool[0];
 }
 return foregroundBundle(raw,self,preferOther,visible);
}
export function foregroundAbility(raw:string,bundle:string):string|undefined{const block=raw.split('AbilityRecord ID').find(v=>v.indexOf('state #FOREGROUND')>=0&&v.indexOf('bundle name ['+bundle+']')>=0);return /main name \[([^\]]+)\]/.exec(block??'')?.[1];}

export function pointInRects(x:number,y:number,rects:number[][]):boolean{return rects.some(r=>r.length===4&&x>=r[0]&&x<=r[2]&&y>=r[1]&&y<=r[3]);}
export function normalizedRect(r:number[],width:number,height:number):number[]{return [Math.round(r[0]*1000/Math.max(1,width-1)),Math.round(r[1]*1000/Math.max(1,height-1)),Math.round(r[2]*1000/Math.max(1,width-1)),Math.round(r[3]*1000/Math.max(1,height-1))].map(v=>Math.min(1000,Math.max(0,v)));}
// 截图中需要灰块遮盖的区域（与屏幕求交，丢弃空矩形）。
export function clipRects(rects:number[][],width:number,height:number):number[][]{const out:number[][]=[];rects.forEach(r=>{if(r.length!==4)return;const c=[Math.max(0,Math.floor(r[0])),Math.max(0,Math.floor(r[1])),Math.min(width,Math.ceil(r[2])),Math.min(height,Math.ceil(r[3]))];if(c[2]>c[0]&&c[3]>c[1])out.push(c);});return out;}
export function overlapNote(rects:number[][],width:number,height:number):string{
 if(!rects.length)return '';
 return '\n注意：屏幕上 '+rects.map(r=>'['+normalizedRect(r,width,height).join(',')+']').join('、')+'（0–1000 坐标）区域被大肥鱼的小窗挡住，截图里是灰块，看不到下面的内容；点击该区域会返回 SELF_OVERLAP。需要操作那里时，请让用户把小窗拖开后再观察。';
}
// 0.8.1.2：小窗模式下 launch_app（aa start）把下层应用切换成另一个应用时，系统会把大肥鱼的小窗收到屏幕边缘并转入后台
// （真机复现：下层是计算器时启动备忘录；下层是桌面时启动计算器不会）。真机验证 `aa start` 大肥鱼自己能把它恢复成小窗，
// 这是应用对自己的正常启动，不绕过系统限制：启动后检测自身是否被收起，被收起则自动恢复，恢复失败再提示用户点屏幕边缘的把手。
export const LAUNCH_FLOAT_HINT:string='小窗模式提示：在下层已有应用时用 launch_app 切换到另一个应用，系统会把大肥鱼的小窗收到屏幕边缘（转入后台，后台额度开始计时）；启动后我会自动把小窗恢复，但会多花几秒。优先在已经打开的应用里操作，不要反复切换应用。';
export const SELF_RECOVERED_NOTE:string=' · 提示：启动后大肥鱼的小窗被系统收到了屏幕边缘，已自动恢复为小窗。';
export const SELF_COLLAPSED_NOTE:string=' · 注意：大肥鱼的小窗被系统收到了屏幕边缘（已转入后台），自动恢复没有成功。请用户点屏幕边缘的把手恢复小窗；恢复前后台额度在计时，不要反复启动应用。';
// aa dump -l 中自身有记录、但没有任何一条处于前台：小窗被收起（或进入后台）。
export function selfCollapsed(raw:string,self:string):boolean{
 const blocks=raw.split('AbilityRecord ID').filter(b=>b.indexOf('bundle name ['+self+']')>=0);
 return blocks.length>0&&!blocks.some(b=>b.indexOf('state #FOREGROUND')>=0);
}
export const SELF_OVERLAP_MESSAGE:string='目标位置在大肥鱼小窗下面，被挡住了，我没有点。请让用户把小窗拖开，然后重新观察。';

// 通知进度（F4）：一行文字，点开回到大肥鱼。
export function progressText(task:Task|null):string{
 if(!task)return '';
 const action=(task.currentAction??'').replace(/\s+/g,' ').trim();
 const step='第 '+(task.calls??0)+' 步';
 return '大肥鱼 · '+step+(action?' · '+(action.length>40?action.slice(0,40)+'…':action):'');
}
// 只有任务运行中、大肥鱼不可见（不在前台，也没有小窗）时才发进度通知。
export function shouldNotifyProgress(running:boolean,foreground:boolean):boolean{return running&&!foreground;}
export const NOTICE_THROTTLE_MS:number=1000;


// 通知（F4 与确认按钮）：页面侧实现，Engine 只决定何时发。
export interface TaskNotifier {
 progress(text:string):void;                              // 可更新的进度通知（同一编号覆盖）
 approval(serial:number,text:string,inFloat:boolean):void; // 需要确认：轻震；小窗未打开时另发带“同意/拒绝”按钮的通知
 clearApproval():void;
 finished(text:string):void;                              // 任务结束：text 为空则清除进度通知
}
// 0.8.1.2：通知发布通道。真机 0.8.1.1 发现任务结束时 cancel 之后又 publish 了一次（间隔 12 ms）：
// 发布前要先异步创建 WantAgent，这段时间里结束清除先执行了，在途的发布随后落地，进度通知因此残留。
// 做法：每个通知编号记一个“最新有效序号”；cancel / 结束时先把它作废（相当于置结束标记），再发 cancel；
// 在途发布在真正调用 publish 之前复核序号，已作废或被更新的发布一律丢弃（同时避免两条在途进度更新乱序覆盖）。
export interface NoticeSink<R> {
 build(id:number,title:string,text:string,buttons:boolean,serial:number):Promise<R>;
 publish(id:number,request:R):Promise<void>;
 cancel(id:number):Promise<void>;
}
export class NoticeChannel<R> {
 sink:NoticeSink<R>;latest:Map<number,number>=new Map();seq:number=0;dropped:number=0;
 constructor(sink:NoticeSink<R>){this.sink=sink;}
 async publish(id:number,title:string,text:string,buttons:boolean,serial:number):Promise<void>{
  const token=++this.seq;this.latest.set(id,token);
  const request=await this.sink.build(id,title,text,buttons,serial);
  // 复核与 publish 调用之间没有 await，不会再被 cancel 插队。
  if(this.latest.get(id)!==token){this.dropped++;return;}
  await this.sink.publish(id,request);
 }
 async cancel(id:number):Promise<void>{this.latest.set(id,-1);await this.sink.cancel(id);}
}

// 通知按钮回调桥：ProbeAbility.onNewWant 收到按钮参数后转给 Engine（只认当前这次确认的序号）。
export class NotifyBridge {
 static handler:((action:string,serial:number)=>void)|null=null;
 static dispatch(action:string,serial:number):void{if(NotifyBridge.handler)NotifyBridge.handler(action,serial);}
}

// 0.8.3.8 产品级保护（纯逻辑，可在 node 测试中运行）：模型的坐标动作落在桌面或 ClassCount 上时拒绝执行。
export const DESKTOP_BUNDLE:string='com.ohos.sceneboard';
export const CLASSCOUNT_BUNDLE:string='com.harmonyloom.schedule';
export interface GuardBlock {code:string;message:string;}
// 布局中覆盖该点的窗口包名（不含重复）。窗口矩形不含该点则跳过其子树；无矩形的节点不计入。
export function bundlesAtPoint(tree:TreeNode,x:number,y:number):string[]{
 const out:string[]=[];
 const walk=(n:TreeNode,inherited:string):void=>{
  const a:Record<string,string>=n.attributes??{};
  const own:string=a.bundleName??'';
  const r:number[]=(a.bounds??'').match(/-?\d+/g)?.map((v:string)=>Number(v))??[];
  const boxed:boolean=r.length===4;
  if(own.length>0&&boxed&&!(x>=r[0]&&x<=r[2]&&y>=r[1]&&y<=r[3]))return;
  if(own.length>0&&boxed&&out.indexOf(own)<0)out.push(own);
  const bundle:string=own.length>0?own:inherited;
  (n.children??[]).forEach((c:TreeNode)=>walk(c,bundle));
 };
 walk(tree,'');
 return out;
}
// 拒绝条件：点中出现 ClassCount 一律拒绝；点上只有桌面（无窗口时以前台为准）拒绝。
export function productGuardBlock(bundles:string[],front:string):GuardBlock|undefined{
 if(bundles.indexOf(CLASSCOUNT_BUNDLE)>=0)return {code:'CLASSCOUNT_GUARD',message:'目标坐标落在 ClassCount 上，一律不操作'};
 const desktopOnly:boolean=bundles.length>0?bundles.every((b:string)=>b===DESKTOP_BUNDLE):front===DESKTOP_BUNDLE;
 if(desktopOnly)return {code:'DESKTOP_GUARD',message:'桌面上不点击，打开应用请用 launch_app'};
 return undefined;
}
