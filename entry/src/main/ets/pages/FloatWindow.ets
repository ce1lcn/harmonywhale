import {window} from '@kit.ArkUI';
import {BusinessError} from '@kit.BasicServicesKit';
import {Activity} from '../agent/Activity';
import {SelfOverlay,CaptureState,normalizeStrategy,failedCapture,DEFAULT_FLOAT_STRATEGY} from '../agent/FloatPolicy';
// 0.8.1 小窗：主窗口状态、截图隐形策略与点击穿透的窗口 API 实现（需真机验证，见 docs/FLOAT-0.8.1.md）。
function wait(ms:number):Promise<void>{return new Promise<void>(resolve=>setTimeout(resolve,ms));}
function why(e:Object):string{const b=e as BusinessError;return (b.code!==undefined?'错误码 '+b.code+'：':'')+(b.message??String(e));}
export class FloatWindow implements SelfOverlay {
 static main:window.Window|null=null;
 static status:number=-1;
 static strategy:()=>string=()=>DEFAULT_FLOAT_STRATEGY;
 // V1 透明后等待一帧再截图（约 50 ms，留余量取 80 ms）；V2 最小化动画更长。
 static settleMs:number=80;static hideMs:number=350;
 static attach(main:window.Window,px2vp:(px:number)=>number):void{
  FloatWindow.main=main;
  try{FloatWindow.setStatus(main.getWindowStatus());}catch(e){}
  try{main.on('windowStatusChange',(s:window.WindowStatusType)=>{FloatWindow.setStatus(s);});}catch(e){}
  try{const r=main.getWindowProperties().windowRect;AppStorage.setOrCreate('winWidthVp',px2vp(r.width));}catch(e){}
  try{main.on('windowSizeChange',(size:window.Size)=>{AppStorage.setOrCreate('winWidthVp',px2vp(size.width));});}catch(e){}
 }
 static setStatus(s:number):void{FloatWindow.status=s;AppStorage.setOrCreate('floating',s===window.WindowStatusType.FLOATING);}
 static floating():boolean{return FloatWindow.status===window.WindowStatusType.FLOATING;}
 active():boolean{return !!FloatWindow.main&&FloatWindow.floating()&&Activity.foreground;}
 async beforeCapture():Promise<CaptureState>{
  const strategy=normalizeStrategy(FloatWindow.strategy());const main=FloatWindow.main;
  if(!main)return failedCapture(strategy,'没有主窗口');
  try{
   if(strategy==='transparent'){main.setWindowBackgroundColor('#00000000');AppStorage.setOrCreate('floatOpacity',0);await wait(FloatWindow.settleMs);return {strategy:strategy,hidden:true,masked:false,restoreSelf:false,error:''};}
   if(strategy==='hide'){await main.minimize();await wait(FloatWindow.hideMs);return {strategy:strategy,hidden:true,masked:false,restoreSelf:true,error:''};}
   if(strategy==='privacy'){await main.setWindowPrivacyMode(true);await wait(FloatWindow.settleMs);return {strategy:strategy,hidden:false,masked:true,restoreSelf:false,error:''};}
   return failedCapture(strategy,'');
  }catch(e){return failedCapture(strategy,why(e as Object));}
 }
 // 无论 beforeCapture 成败都会被调用：恢复不透明、白色背景、关闭隐私模式。V2 的切回前台由 Device 执行。
 async afterCapture(state:CaptureState):Promise<void>{
  const main=FloatWindow.main;
  if(state.strategy==='transparent'){AppStorage.setOrCreate('floatOpacity',1);try{main?.setWindowBackgroundColor('#FFFFFF');}catch(e){}}
  if(state.strategy==='privacy'&&main){try{await main.setWindowPrivacyMode(false);}catch(e){}}
 }
 async setTouchable(touchable:boolean):Promise<void>{const main=FloatWindow.main;if(!main)throw new Error('没有主窗口');await main.setWindowTouchable(touchable);}
 windowRect():number[]{try{const r=FloatWindow.main!.getWindowProperties().windowRect;return [r.left,r.top,r.left+r.width,r.top+r.height];}catch(e){return [];}}
 // F2：主窗口 recover() 切成悬浮窗。官方文档：仅在支持自由多窗且处于自由多窗状态时可用，否则返回 801。
 static async enterFloating():Promise<string>{
  const main=FloatWindow.main;if(!main)return '没有主窗口，无法切换';
  if(FloatWindow.floating())return '';
  try{await main.recover();return '';}catch(e){return why(e as Object);}
 }
}
