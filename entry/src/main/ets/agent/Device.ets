import {drawingRequest,drawingPixels,DrawingBounds,DrawingRequest,DrawingPoint} from './Drawing';
import {calculatorLabels} from './CalculatorLabels';
import {Snapshot,Element,TreeNode,snapshot,relocate,layoutOf,DeviceError,scene} from './Elements';
import {riskOf} from './Risk';
import {StabilityTracker,StabilityReport} from './Stability';
import {HdcClient} from '../pages/HdcClient';
import {util} from '@kit.ArkTS';
import {image} from '@kit.ImageKit';
import {Observation,Arguments} from './Types';
import {AppCatalogCache,BundleInfo,BundleLabel,InstalledApps,parseBundleList,parseBundleListJson,parseBundleInfo} from './AppCatalog';
import {textRecognition} from '@kit.CoreVisionKit';
import {HitResult,hitAt,queryElements,pickForLayout,scrollPlan,validScrollDirection,textPresent,waitSatisfied,sceneFingerprint,keyCodeOf,WAIT_CONDITIONS,SETTLE_INTERVAL_MS,SETTLE_DEFAULT_CAP_MS,assignStableIds,ocrDecision,OcrDecision,OCR_EDGES} from './ActionKit';
import {Store} from './Store';
import {fileIo as fs} from '@kit.CoreFileKit';
import {SelfOverlay,CaptureState,passThrough,captureHidden,stripSelf,windowBundles,foregroundBundle,frontBundle,foregroundAbility,pointInRects,clipRects,overlapNote,SELF_OVERLAP_MESSAGE,LAUNCH_FLOAT_HINT,SELF_COLLAPSED_NOTE,SELF_RECOVERED_NOTE,selfCollapsed,bundlesAtPoint,productGuardBlock,isChromeBundle} from './FloatPolicy';
// 0.8.4 A1：续租时要回到的应用。
export interface LeaseTarget {bundle:string;ability:string;}
export interface ActionTarget {label:string;app:string;ability?:string;snapshot?:Snapshot;elementId?:string;}
// 0.8.1.2：记录上一次已执行的点击，供“确认后弹出菜单已关闭”时重放打开菜单的那一次点击。
// before 是点击前的观察；seq 是点击当时的动作序号（之后只要有任何别的动作就不再是“上一步”）。
export interface LastClick {x:number;y:number;label:string;app:string;before:Snapshot|null;seq:number;}
interface PendingTarget {x:number;y:number;label:string;app:string;}
export function labelOfElement(e:Element):string{return e.text.trim()||e.description.trim()||e.id;}
// 某个像素点上最小的元素（面积最小者）；没有则返回 undefined。
export function elementAtPoint(s:Snapshot,x:number,y:number):Element|undefined{return s.elements.filter(e=>x>=e.bounds[0]&&x<=e.bounds[2]&&y>=e.bounds[1]&&y<=e.bounds[3]).sort((l:Element,r:Element)=>(l.bounds[2]-l.bounds[0])*(l.bounds[3]-l.bounds[1])-(r.bounds[2]-r.bounds[0])*(r.bounds[3]-r.bounds[1]))[0];}
// 同一个控件：标识、类型、名称、描述、父级、所在窗口和位置都相同。
export function sameElement(a:Element,b:Element):boolean{return a.id===b.id&&a.type===b.type&&a.text===b.text&&a.description===b.description&&a.parent===b.parent&&a.window===b.window&&a.bounds.join(',')===b.bounds.join(',');}
interface CalculatorMetadata {versionCode?:number;}
interface Node {attributes?:Record<string,string>;children?:Node[];}
interface VisibleNode {type:string;text:string;id:string;description:string;clickable:boolean;enabled:boolean;normalizedCenter?:number[];}
function quote(s:string):string{return "'"+s.replace(/'/g,"'\\''")+"'";}
export const SELF_BUNDLE:string='com.harmonyloom.selfhdcprobe';
export const SELF_ABILITY:string='ProbeAbility';
export class Device {
 width:number=2800;height:number=1840;active:()=>boolean=()=>true;
 hdc:HdcClient;store:Store;constructor(hdc:HdcClient,store:Store){this.hdc=hdc;this.store=store;}
 // 0.8.1 小窗：overlay 由页面注入；selfRects 为最近一次布局中自身窗口的像素矩形；lastMasked 表示最近一次截图未能隐形（已灰块遮盖）。
 overlay:SelfOverlay|null=null;selfRects:number[][]=[];lastMasked:boolean=false;visibleBundles:string[]=[];
 // 0.8.3.8：最近一次布局的原始树（未剔除自身窗口），供产品级保护按坐标判断窗口包名。
 lastTree:TreeNode|null=null;
 // forceFloat：一次观察期间锁定小窗状态（V2 最小化会让窗口短暂离开前台）。
 forceFloat:boolean=false;
 // 0.8.1.2：actionSeq 只在 execute 里递增（不含确认后重新启动应用的 aa start），lastClick 为紧邻上一步的点击。
 actionSeq:number=0;lastClick:LastClick|null=null;pendingTarget:PendingTarget|null=null;
 floatActive():boolean{return !!this.overlay&&(this.forceFloat||this.overlay.active());}
 operationEpoch:number=0;
 cancelCommands():void{this.operationEpoch++;this.invalidate();this.hdc.cancelCommands();}
 checkOperation(epoch:number,active:()=>boolean):void{if(epoch!==this.operationEpoch||!active())throw new DeviceError('INTERRUPTED','任务已暂停');}
 async command(text:string,timeout:number=30000):Promise<string>{const epoch=this.operationEpoch,active=this.active;this.checkOperation(epoch,active);if(/^uitest uiInput|^aa start|^uinput -T -m/.test(text))this.mutationCount++;const inject=/^uitest uiInput|^uinput -T -m/.test(text);const result=inject&&this.floatActive()?await passThrough(this.overlay,()=>this.hdc.execute(text,timeout)):await this.hdc.execute(text,timeout);this.checkOperation(epoch,active);return result;}
 // 小窗时前台列表里自身与下层应用同为 FOREGROUND，取下层应用。
 frontOf(raw:string):string{return frontBundle(raw,SELF_BUNDLE,this.floatActive(),this.visibleBundles);}
 // 小窗遮挡守卫：仅在最近一次截图没能隐形时生效（像素坐标）。
 guardOverlap(x:number,y:number):void{if(this.floatActive()&&this.lastMasked&&pointInRects(x,y,this.selfRects))throw new DeviceError('SELF_OVERLAP',SELF_OVERLAP_MESSAGE);}
 // 0.8.3.8 产品级保护：坐标动作发出前读取一次布局，按该点的窗口包名拒绝桌面与 ClassCount（不可重试）。
 async guardPoints(points:number[][]):Promise<void>{
  await this.readLayout();
  const tree:TreeNode|null=this.lastTree;
  if(!tree)return;// readLayout 每次都会更新 lastTree；缺失只出现在测试桩中
  for(const p of points){
   const bundles:string[]=tree?bundlesAtPoint(tree,p[0],p[1]):[];
   const front:string=bundles.length>0?'':this.frontOf(await this.command('aa dump -l'));
   const block=productGuardBlock(bundles,front);
   if(block)throw new DeviceError(block.code,block.message);
  }
 }
 async reconnect():Promise<void>{if(this.hdc.ready)return;this.invalidate();await this.hdc.connect(40373);const started=Date.now();while(!this.hdc.ready){if(!this.active())throw new Error('任务已暂停');if(!this.hdc.connecting)throw new Error('本机 HDC 重连失败，请检查无线调试端口');if(Date.now()-started>120000)throw new Error('本机 HDC 认证超时，请在平板确认信任');await this.delay(200);}}
 calculatorVersion:number|undefined=undefined;
 mutationCount:number=0; latest:Snapshot|null=null;apps:Map<string,string>=new Map();installed:AppCatalogCache=new AppCatalogCache();
 sensitive(a:Arguments):boolean{return (this.latest?.elements??[]).some(e=>e.password&&(e.elementId===a.elementId||(typeof a.x==='number'&&typeof a.y==='number'&&Math.abs(e.normalizedCenter[0]-a.x)<100&&Math.abs(e.normalizedCenter[1]-a.y)<50)));}
 invalidate():void{this.latest=null;this.calculatorVersion=undefined;}
 async readLayout(timeout:number=30000):Promise<Snapshot>{const end=Date.now()+timeout;await this.command('uitest dumpLayout -p /data/local/tmp/tablet-agent.json',timeout);const raw=await this.command('cat /data/local/tmp/tablet-agent.json',Math.max(1,end-Date.now()));let tree=JSON.parse(raw) as TreeNode;this.lastTree=tree;this.visibleBundles=windowBundles(tree);if(this.floatActive()){const stripped=stripSelf(tree,SELF_BUNDLE);tree=stripped.tree;const rect=this.overlay!.windowRect();this.selfRects=stripped.rects.length?stripped.rects:(rect.length===4?[rect]:[]);}else this.selfRects=[];const result=snapshot(tree,this.width,this.height);if(!result.elements.length)throw new Error('布局为空，无法可靠观察');const front=await this.command('aa dump -l');const app=this.frontOf(front);if(app==='com.huawei.hmos.calculator'){if(this.calculatorVersion===undefined){try{const meta=await this.command('bm dump -n com.huawei.hmos.calculator');this.calculatorVersion=(JSON.parse(meta.slice(meta.indexOf('{'))) as CalculatorMetadata).versionCode??0;}catch(e){this.calculatorVersion=0;}}calculatorLabels(result,app,this.calculatorVersion);}return result;}
 async delay(ms:number):Promise<void>{const epoch=this.operationEpoch,active=this.active;await new Promise<void>(resolve=>setTimeout(resolve,ms));this.checkOperation(epoch,active);}
 lastStability:StabilityReport|undefined=undefined;
 async stable():Promise<void>{const start=Date.now(),tracker=new StabilityTracker(start);this.lastStability=undefined;const end=start+SETTLE_DEFAULT_CAP_MS;try{while(Date.now()<end){if(!this.active())throw new Error('任务已暂停');const began=Date.now();let current:Snapshot;try{current=await this.readLayout(Math.max(1,end-began));}catch(e){if(this.active()&&Date.now()>=end&&tracker.samples>0&&/timeout/i.test((e as Error).message)){this.lastStability=tracker.report(Date.now());return;}this.lastStability=tracker.report(Date.now(),'LAYOUT_READ_FAILED');throw new Error('页面稳定检查布局读取失败：'+(e as Error).message);}if(!this.active())throw new Error('任务已暂停');tracker.sample(layoutOf(current),Date.now(),Date.now()-began);this.lastStability=tracker.report(Date.now());if(tracker.done)return;await this.delay(Math.min(SETTLE_INTERVAL_MS,Math.max(1,end-Date.now())));}this.lastStability=tracker.report(Date.now());return;}finally{if(!this.active())this.lastStability=tracker.report(Date.now(),'INTERRUPTED');}}
 async installedApps(refresh:boolean):Promise<InstalledApps>{
  const now=Date.now();
  if(!refresh&&this.installed.fresh(now)&&this.installed.bundles.length>0){const cached:InstalledApps={list:this.installed.listAll(),note:'缓存结果；名称来自 bm dump -a -l'};return cached;}
  // 0.8.3.1：名称优先取 `bm dump -a -l`（真机已核对），`bm dump -a` 仅作兜底。
  const named:BundleLabel[]=parseBundleListJson(await this.command('bm dump -a -l',30000));
  const labels:Map<string,string>=new Map<string,string>();
  named.forEach((n:BundleLabel)=>labels.set(n.bundle,n.label));
  let bundles:string[]=named.map((n:BundleLabel)=>n.bundle);
  let source:string='bm dump -a -l（名称来自系统）';
  if(bundles.length===0){bundles=parseBundleList(await this.command('bm dump -a',30000));source='bm dump -a 兜底（名称未取到）';}
  const infos:BundleInfo[]=[];
  // 只对未缓存的包取 `bm dump -n`，用于启动 Ability；名称仍以 -a -l 为准。
  for(const bundle of this.installed.planFetch(bundles)){try{const meta:BundleInfo=parseBundleInfo(await this.command('bm dump -n '+bundle,15000),bundle);const named:string=labels.get(bundle)??'';infos.push({bundle:bundle,label:named.length>0?named:meta.label,ability:meta.ability});}catch(e){if(!this.active())throw new DeviceError('INTERRUPTED','任务已暂停');}}
  this.installed.commit(bundles,infos,now);
  this.installed.labels={};labels.forEach((v:string,k:string)=>{this.installed.labels[k]=v;});
  const fresh:InstalledApps={list:this.installed.listAll(),note:source+'；共 '+bundles.length+' 个包'};
  return fresh;
 }
 installedAbility(bundle:string):string{const hit=this.installed.infos.find(i=>i.bundle===bundle);return hit?hit.ability:'';}
 async discover():Promise<void>{const raw=await this.command('aa dump -l');this.apps.clear();const entries=raw.split('AbilityRecord ID');entries.forEach(entry=>{const bundle=/bundle name \[([^\]]+)\]/.exec(entry)?.[1];const ability=/main name \[([^\]]+)\]/.exec(entry)?.[1];if(bundle&&ability&&/^[\w.]+$/.test(bundle)&&/^[\w.]+$/.test(ability)&&bundle!=='com.huawei.shell_assistant')this.apps.set(bundle,ability);});this.apps.set(SELF_BUNDLE,SELF_ABILITY);}
 // 0.8.4 A1：续租前记下要回去的应用（当前前台应用及其启动 Ability）；前台是大肥鱼、桌面、输入法或取不到时返回 null。
 async leaseTarget():Promise<LeaseTarget|null>{
  const raw:string=await this.hdc.execute('aa dump -l',10000);
  const bundle:string=this.frontOf(raw);
  if(!bundle||bundle===SELF_BUNDLE||isChromeBundle(bundle)||!/^[\w.]+$/.test(bundle))return null;
  const ability:string=foregroundAbility(raw,bundle)??this.apps.get(bundle)??this.installedAbility(bundle);
  if(!ability||!/^[\w.]+$/.test(ability))return null;
  return {bundle:bundle,ability:ability};
 }
 // 用 aa start 回到目标应用（它还在后台，会被带回前台）。不经过 command()，不计入设备变更次数。
 async returnToApp(target:LeaseTarget):Promise<boolean>{
  if(!/^[\w.]+$/.test(target.bundle)||!/^[\w.]+$/.test(target.ability))return false;
  const out:string=await this.hdc.execute('aa start -b '+target.bundle+' -a '+target.ability,10000);
  return /success/i.test(out);
 }
 // 0.8.0：把大肥鱼自己切回前台（不计入设备变更次数，不受任务暂停影响）。
 async bringSelf():Promise<boolean>{if(!this.hdc.ready)return false;const result=await this.hdc.execute('aa start -b '+SELF_BUNDLE+' -a '+SELF_ABILITY,10000);return /success/i.test(result);}


 // 0.8.1.2：launch_app 之后大肥鱼的小窗被收起时，用 aa start 自身恢复为小窗；恢复后再核对，仍没回来则提示用户点边缘把手。
 async recoverFloat():Promise<string>{try{await this.bringSelf();await this.delay(1200);const raw=await this.command('aa dump -l');return selfCollapsed(raw,SELF_BUNDLE)?SELF_COLLAPSED_NOTE:SELF_RECOVERED_NOTE;}catch(e){if(!this.active())throw new Error('任务已暂停');return SELF_COLLAPSED_NOTE;}}
 async snapshotScreen():Promise<void>{await this.command('snapshot_display -f /data/local/tmp/tablet-agent.jpeg');}
 // 小窗时截图前隐形（策略见 FloatPolicy），截图后一定恢复；V2 用最小化实现时再把大肥鱼切回前台。
 async captureScreen():Promise<CaptureState|null>{if(!this.floatActive()){await this.snapshotScreen();return null;}const overlay=this.overlay!;const state=await captureHidden(overlay,async(s:CaptureState)=>{await this.snapshotScreen();return s;});if(state.restoreSelf){try{await this.bringSelf();await new Promise<void>(resolve=>setTimeout(resolve,400));}catch(e){}}return state;}
 // 兜底：把截图中小窗所在区域涂成灰块（失败时只保留文字提示）。
 async maskScreenshot(bytes:Uint8Array,rects:number[][]):Promise<Uint8Array>{const src=image.createImageSource(bytes.buffer);try{const map=await src.createPixelMap({editable:true});try{for(const r of rects){const w=r[2]-r[0],h=r[3]-r[1];const gray=new Uint8Array(w*h*4);for(let i=0;i<gray.length;i+=4){gray[i]=128;gray[i+1]=128;gray[i+2]=128;gray[i+3]=255;}await map.writePixels({pixels:gray.buffer,offset:0,stride:w*4,region:{size:{width:w,height:h},x:r[0],y:r[1]}});}const packer=image.createImagePacker();try{return new Uint8Array(await packer.packToData(map,{format:'image/jpeg',quality:85}));}finally{packer.release();}}finally{map.release();}}finally{src.release();}}
 // 0.8.4 A6：modelVision 由 Engine 在任务开始时按当前模型设置；ocr 为模型主动要求识别。
 modelVision:boolean=true;lastOcrNote:string='';ocrError:string='';
 // 0.8.4 B1：布局文本超过阈值时由 Engine 转存并返回头尾预览；未设置（测试桩、执行层测试页）时原样返回。
 layoutSpill:((full:string)=>Promise<string>)|null=null;
 // 识别原目标截图时短暂回前台；恢复后布局变了就丢弃这次观察，不沿用坐标。
 async recognizeSnapshot(bytes:Uint8Array,current:Snapshot):Promise<Element[]>{
  const epoch=this.operationEpoch,active=this.active;
  const target=this.floatActive()?null:await this.leaseTarget();this.checkOperation(epoch,active);
  if(!target)return this.ocrElements(bytes);
  let result:Element[]=[];
  try{
   if(!await this.bringSelf())throw new DeviceError('OCR_FOREGROUND','无法回到前台识别');
   this.checkOperation(epoch,active);await this.waitApp(SELF_BUNDLE,epoch,active);
   result=await this.ocrElements(bytes);this.checkOperation(epoch,active);
  }finally{
   // 取消后留在大肥鱼，绝不让旧操作重新打开外部应用。
   if(epoch===this.operationEpoch&&active()){
    if(!await this.returnToApp(target))throw new DeviceError('OCR_RESTORE','识别后未能返回原应用');
    this.checkOperation(epoch,active);await this.waitApp(target.bundle,epoch,active);
   }
  }
  this.checkOperation(epoch,active);
  const after=await this.readLayout();
  const shown=(s:Snapshot):Element[]=>s.elements.filter(e=>e.normalizedCenter[1]>=40&&e.bounds[2]>0&&e.bounds[3]>0&&e.bounds[0]<s.width&&e.bounds[1]<s.height);
  const positions=(s:Snapshot):string=>shown(s).map(e=>e.elementId+'|'+e.bounds.join(',')).sort().join(';');
  if(scene(current)!==scene(after)||positions(current)!==positions(after)){
   const changed=shown(current).find(e=>!shown(after).some(v=>v.elementId===e.elementId&&v.bounds.join(',')===e.bounds.join(',')));
   const match=changed?shown(after).find(e=>e.elementId===changed.elementId):undefined;
   const detail=changed?'（'+changed.elementId+' '+changed.bounds.join(',')+' → '+(match?match.bounds.join(','):'已消失')+'）':'';
   this.invalidate();throw new DeviceError('STALE','识别期间页面变化'+detail+'，请重新观察');
  }
  return result;
 }
 async waitApp(bundle:string,epoch:number,active:()=>boolean):Promise<void>{
  const end=Date.now()+5000;
  do{this.checkOperation(epoch,active);const raw=await this.command('aa dump -l',Math.max(1,end-Date.now()));this.checkOperation(epoch,active);if(foregroundBundle(raw,SELF_BUNDLE,false,[bundle])===bundle)return;await this.delay(100);}while(Date.now()<end);
  throw new DeviceError('OCR_FOREGROUND','等待应用前台状态超时');
 }
 async observe(query:string='',ocr:boolean=false):Promise<Observation>{this.forceFloat=this.floatActive();try{return await this.observeOnce(query,ocr);}finally{this.forceFloat=false;}}
 async observeOnce(query:string='',ocr:boolean=false):Promise<Observation>{const capture=await this.captureScreen();let data=(await this.command('toybox base64 -w 0 /data/local/tmp/tablet-agent.jpeg',60000)).trim();if(!/^[A-Za-z0-9+/=]+$/.test(data))throw new Error('截图数据无效');let bytes=new util.Base64Helper().decodeSync(data);const src=image.createImageSource(bytes.buffer);try{const size=(await src.getImageInfo()).size;this.width=size.width;this.height=size.height;}finally{src.release();}const current=await this.readLayout();this.lastMasked=!!capture&&capture.masked;let note='';if(capture&&capture.masked){const rects=clipRects(this.selfRects,this.width,this.height);if(rects.length){try{bytes=await this.maskScreenshot(bytes,rects);data=new util.Base64Helper().encodeToStringSync(bytes);}catch(e){}note=overlapNote(rects,this.width,this.height);}}// 0.8.3.1：布局文字过少（少于 5 个）时，用端侧 OCR 识别截图，识别行作为 ocr 元素并入布局（坐标来自 cornerPoints）。
this.lastOcrNote='';const ocrPlan:OcrDecision=ocrDecision(current.elements,this.width,this.height,ocr,this.modelVision);
if(ocrPlan.run){const ocrEls=await this.recognizeSnapshot(bytes,current);ocrEls.forEach((e:Element)=>current.elements.push(e));assignStableIds(current.elements);this.lastOcrNote='\nOCR：'+ocrPlan.reason+'；'+(this.ocrError?'识别失败（'+this.ocrError+'）':'识别到 '+ocrEls.length+' 行文字（'+this.ocrDetail+'），已作为 type=ocr 的元素列出（用其 normalizedCenter 点击）');}
this.latest=current;
const path=this.store.root+'/screen-'+Date.now()+'.jpeg';const f=fs.openSync(path,fs.OpenMode.CREATE|fs.OpenMode.READ_WRITE);try{fs.writeSync(f.fd,bytes.buffer);}finally{fs.closeSync(f.fd);}if(!this.apps.size)await this.discover();// 0.8.3.1：observe 的 query 只列出匹配元素且不截断；无 query 时超长布局按可点击、有文字、其他的优先级保留并标注省略数。
const picked:Element[]=query.trim().length?queryElements(current.elements,query):current.elements;const pick=pickForLayout(picked,24000,(e:Element)=>JSON.stringify(e));const layout=('屏幕 '+this.width+'x'+this.height+(this.width>=this.height?' 横屏':' 竖屏')+'\n'+pick.kept.map((e:Element)=>JSON.stringify(e)).join('\n')).slice(0,30000);const queryNote=query.trim().length?'\n查询「'+query.trim()+'」匹配 '+picked.length+' 项（未截断）':(pick.omitted>0?'\n布局过长，已省略 '+pick.omitted+' 项（优先保留可点击与有文字的元素；可用 observe 的 query 查找）':'');const shownLayout:string=this.layoutSpill?await this.layoutSpill(layout):layout;return {path:path,snapshotId:current.snapshotId,image:data,layout:shownLayout+queryNote+this.lastOcrNote+note+'\n已发现应用：'+JSON.stringify(Array.from(this.apps.keys()))+'\n其中 '+SELF_BUNDLE+' 是大肥鱼（你自己），需要回到大肥鱼时可 launch_app 它。'+(this.forceFloat?'\n'+LAUNCH_FLOAT_HINT:''),width:this.width,height:this.height,fingerprint:layout};}
 walk(n:Node,lines:string[]):void{if(lines.length>=120)return;const a=n.attributes;if(a&&(a.text||a.clickable==='true')&&a.visible!=='false'&&(a.text??'').length<500){const bounds=(a.bounds??'').match(/\d+/g);const item:VisibleNode={type:a.type??'',text:a.text??'',id:a.id??'',description:(a.description??'').slice(0,200),clickable:a.clickable==='true',enabled:a.enabled!=='false'};if(bounds?.length===4)item.normalizedCenter=[Math.round((Number(bounds[0])+Number(bounds[2]))*500/this.width),Math.round((Number(bounds[1])+Number(bounds[3]))*500/this.height)];lines.push(JSON.stringify(item));}n.children?.forEach(c=>this.walk(c,lines));}

 async resolve(a:Arguments,checkScene:boolean=true):Promise<Element>{if(!this.latest||a.snapshotId!==this.latest.snapshotId)throw new DeviceError('STALE','观察引用已失效，请重新观察');const current=await this.readLayout();if(checkScene&&scene(this.latest)!==scene(current))throw new DeviceError('STALE','页面内容变化，请重新观察');return relocate(this.latest,current,a.elementId??'');}
 // 0.8.3.1：点击类动作的反馈：只给命中的文字（或空白处）与动作后屏幕是否变化，不返回像素坐标。
 async actionFeedback(verb:string,x:number,y:number,sent:string):Promise<string>{
  const before:Snapshot|null=this.latest;
  const hit:HitResult=before?hitAt(before.elements,this.width,this.height,x,y):{hit:false,label:''};
  await this.delay(600);
  let changed:string='未知';
  try{const after=await this.readLayout(8000);if(before)changed=scene(before)!==scene(after)?'是':'否';}catch(e){changed='未知';}
  return verb+'：命中'+(hit.hit?'「'+hit.label+'」':'空白处')+'；动作后屏幕变化：'+changed+'（相对最近一次观察；效果以下次观察为准）；命令结果：'+sent.trim();
 }
 // 0.8.3.1：滚动，最多 8 次；给出 untilText 时找到即停止。
 async scroll(a:Arguments):Promise<string>{
  const direction:string=typeof a.direction==='string'?a.direction:'';
  if(!validScrollDirection(direction))throw new DeviceError('PARAMETER','滚动方向必须为 up/down/left/right');
  const count:number=a.maxSwipes??3;
  if(!Number.isFinite(count)||count<1||count>8)throw new DeviceError('PARAMETER','滚动次数必须为 1–8');
  const untilText:string=typeof a.untilText==='string'?a.untilText:'';
  let sent:number=0;let found:boolean=false;
  for(const s of scrollPlan(direction,count)){
   if(!this.active())throw new Error('任务已暂停');
   const x1=Math.round(s.x1*(this.width-1)/1000),y1=Math.round(s.y1*(this.height-1)/1000),x2=Math.round(s.x2*(this.width-1)/1000),y2=Math.round(s.y2*(this.height-1)/1000);
   this.guardOverlap(x1,y1);
   await this.guardPoints([[x1,y1],[x2,y2]]);
   const result=await this.command('uitest uiInput swipe '+x1+' '+y1+' '+x2+' '+y2);
   if(!result.includes('No Error'))throw new Error('设备操作失败');
   sent++;
   await this.delay(300);
   if(untilText.trim().length){const current=await this.readLayout();if(textPresent(current.elements,untilText)){found=true;break;}}
  }
  if(untilText.trim().length)return '滚动 '+sent+' 次（'+direction+'），'+(found?'已找到「'+untilText+'」':'未找到「'+untilText+'」，可换方向或重新观察');
  return '滚动 '+sent+' 次（'+direction+'）；效果以下次观察为准';
 }
 // 0.8.3.1：按条件等待（textAppears / textDisappears / screenChanges），每 500 ms 检查，默认 10 s、最多 30 s。
 async waitForCondition(a:Arguments):Promise<string>{
  const condition:string=typeof a.condition==='string'?a.condition:'';
  const targetText:string=typeof a.targetText==='string'?a.targetText:'';
  if((condition==='textAppears'||condition==='textDisappears')&&!targetText.trim())throw new DeviceError('PARAMETER','该条件需要 targetText');
  const timeout:number=a.timeoutMs??10000;
  if(!Number.isFinite(timeout)||timeout<0||timeout>30000)throw new DeviceError('PARAMETER','等待期限必须为 0–30000ms');
  const baseline:string=sceneFingerprint((await this.readLayout()).elements);
  const end:number=Date.now()+timeout;
  const label:string=condition+(targetText?'「'+targetText+'」':'');
  while(true){
   const current=await this.readLayout();
   if(waitSatisfied(condition,targetText,baseline,current.elements))return '等待条件已满足：'+label;
   if(Date.now()>=end)throw new DeviceError('TIMEOUT','等待条件超时：'+label);
   await this.delay(500);
  }
 }
 // 0.8.3.1：端侧 OCR（@hms.ai.ocr.textRecognition：blocks→lines，行的 cornerPoints 取外接矩形）。失败时返回空数组，不影响观察。
 // 0.8.4.1：真机上对 2800×1840 的整屏截图做 OCR 会报 “Run timed out, please try again later.”（约 9 秒后失败），所以先缩到长边 OCR_EDGES[0]，失败再缩小重试；
 // 行的 cornerPoints 是缩放后图片里的坐标，要按比例换回屏幕像素。ocrDetail 记录最终用的尺寸和耗时，写进布局文字里便于核对。
 ocrDetail:string='';
 async ocrElements(bytes:Uint8Array):Promise<Element[]>{
  const epoch=this.operationEpoch,active=this.active;
  this.ocrError='';this.ocrDetail='';
  const tried:string[]=[];
  for(const edge of OCR_EDGES){
   this.checkOperation(epoch,active);
   const out:Element[]=[];const began:number=Date.now();
   const src=image.createImageSource(bytes.buffer);
   let pixels:image.PixelMap|null=null;
   try{
    const scale:number=Math.min(1,edge/Math.max(1,Math.max(this.width,this.height)));
    const size:image.Size={width:Math.max(1,Math.round(this.width*scale)),height:Math.max(1,Math.round(this.height*scale))};
    pixels=await src.createPixelMap({desiredPixelFormat:image.PixelMapFormat.RGBA_8888,desiredSize:size});
    const info:image.ImageInfo=await pixels.getImageInfo();
    const k:number=this.width/Math.max(1,info.size.width);
    const result=await textRecognition.recognizeText({pixelMap:pixels});
    this.checkOperation(epoch,active);
    result.blocks.forEach((block)=>{block.lines.forEach((line)=>{
     const text:string=line.value.trim();
     if(!text||line.cornerPoints.length===0)return;
     const xs:number[]=line.cornerPoints.map((p)=>p.x*k);const ys:number[]=line.cornerPoints.map((p)=>p.y*k);
     const bounds:number[]=[Math.round(Math.min(...xs)),Math.round(Math.min(...ys)),Math.round(Math.max(...xs)),Math.round(Math.max(...ys))];
     out.push({elementId:'',type:'ocr',text:text.slice(0,200),id:'',description:'',parent:'ocr',bounds:bounds,normalizedCenter:[Math.round((bounds[0]+bounds[2])*500/this.width),Math.round((bounds[1]+bounds[3])*500/this.height)],enabled:true,editable:false,focused:false,password:false,clickable:false,window:'ocr'});
    });});
    this.ocrDetail='图片 '+info.size.width+'×'+info.size.height+'，用时 '+(Date.now()-began)+' ms'+(tried.length?'；前面的尝试：'+tried.join('；'):'');this.ocrError='';
    return out.slice(0,80);
   }catch(e){this.checkOperation(epoch,active);tried.push('长边 '+edge+' 失败（'+((e as Error).message??'未知错误').slice(0,60)+'，用时 '+(Date.now()-began)+' ms）');this.ocrError=tried.join('；');}finally{await pixels?.release();src.release();}
  }
  return [];
 }
 async waitFor(a:Arguments):Promise<string>{if(!this.latest||a.snapshotId!==this.latest.snapshotId)throw new DeviceError('STALE','观察引用已失效');const old=this.latest;const target=old.elements.find(e=>e.elementId===a.elementId);if(!target&&!a.targetText)throw new DeviceError('NOT_FOUND','等待需要元素编号或 targetText');if(a.condition==='text'&&typeof a.text!=='string')throw new DeviceError('PARAMETER','缺少预期文本');const timeout=a.timeoutMs??10000;if(!Number.isFinite(timeout)||timeout<0||timeout>30000)throw new DeviceError('PARAMETER','等待期限必须为 0–30000ms');const end=Date.now()+timeout;while(true){const current=await this.readLayout();const matches=current.elements.filter(e=>target?(e.id===target.id&&e.type===target.type&&e.parent===target.parent&&(a.condition==='text'||e.text===target.text)):e.text===a.targetText);if(matches.length>1)throw new DeviceError('AMBIGUOUS','等待目标不唯一');if((a.condition==='disappears'&&matches.length===0)||(a.condition==='appears'&&matches.length===1)||(a.condition==='text'&&matches.length===1&&matches[0].text===a.text))return '等待条件已满足';if(Date.now()>=end)throw new Error('等待条件超时');await this.delay(500);}}
 async elementAction(name:string,a:Arguments):Promise<string>{const target=await this.resolve(a);if(name==='click_element'){if(!target.text&&!target.description)throw new DeviceError('UNLABELED','元素没有可读名称；请根据最新截图明确定位后使用坐标 click，不猜 keyCode 含义');if(!target.clickable)throw new DeviceError('NOT_ACTIONABLE','目标不可点击');return this.execute('click',{x:target.normalizedCenter[0],y:target.normalizedCenter[1]});}if(!target.editable)throw new DeviceError('NOT_EDITABLE','目标不是输入框');if(target.password)throw new DeviceError('SENSITIVE','敏感输入请由用户操作');if(typeof a.text!=='string'||a.text.length>2000)throw new DeviceError('PARAMETER','输入文本无效');await this.execute('click',{x:target.normalizedCenter[0],y:target.normalizedCenter[1]});const focused=await this.resolve(a,false);if(!focused.focused)throw new DeviceError('FOCUS','未确认输入焦点');const result=await this.execute(name==='replace_element'?'replace_text':'insert_text',{x:focused.normalizedCenter[0],y:focused.normalizedCenter[1],text:a.text});const after=await this.readLayout();const matches=after.elements.filter(e=>e.id===target.id&&e.type===target.type&&e.parent===target.parent);if(matches.length!==1)return result+' · 未验证：输入结果不可唯一读取，请观察后判断，不自动重输';const value=matches[0].text;if(name==='replace_element'?value!==a.text:(value.length!==target.text.length+a.text.length||value.indexOf(a.text)<0))throw new Error('输入结果不符合预期，请重新观察；不自动重输');return result+' · 已验证输入结果';}
 async actionTarget(name:string,a:Arguments):Promise<ActionTarget>{let target:Element|undefined;let observed:Snapshot|undefined;if(name.indexOf('_element')>=0){target=await this.resolve(a);observed=this.latest??undefined;}else if(name==='click'){const current=await this.readLayout();observed=current;const x=(a.x??0)*(this.width-1)/1000,y=(a.y??0)*(this.height-1)/1000;target=current.elements.filter(e=>e.clickable&&x>=e.bounds[0]&&x<=e.bounds[2]&&y>=e.bounds[1]&&y<=e.bounds[3]).sort((l:Element,r:Element)=>(l.bounds[2]-l.bounds[0])*(l.bounds[3]-l.bounds[1])-(r.bounds[2]-r.bounds[0])*(r.bounds[3]-r.bounds[1]))[0];}const front=await this.command('aa dump -l');const app=this.frontOf(front);const label=target?labelOfElement(target):'';const center:number[]=name==='click'?[a.x??0,a.y??0]:(target?target.normalizedCenter:[]);this.pendingTarget=center.length===2?{x:center[0],y:center[1],label:label,app:app||'当前应用'}:null;return {label:label,app:app||'当前应用',ability:app?foregroundAbility(front,app):undefined,snapshot:observed,elementId:target?.elementId};}
 async showApproval():Promise<void>{if(!this.hdc.ready)return;const result=await this.command('aa start -b com.harmonyloom.selfhdcprobe -a ProbeAbility');if(!/success/i.test(result))throw new DeviceError('APPROVAL_UI','无法显示确认界面，未执行目标动作');await this.delay(350);}
 // inPlace：确认卡片显示在小窗里、目标应用一直在下层前台时，不重新启动目标应用。
 // 返回说明文字：确认后弹出菜单被关闭而自动重放了打开菜单的点击时非空，由 Engine 附在动作结果里。
 async restoreApproval(target:ActionTarget,args:Arguments,inPlace:boolean=false):Promise<string>{if(!target.snapshot||!target.elementId||!target.ability||!/^[\w.]+$/.test(target.app)||!/^[\w.]+$/.test(target.ability))throw new DeviceError('STALE','确认目标无法重新定位，请重新观察');if(target.app!=='com.harmonyloom.selfhdcprobe'&&!inPlace){const result=await this.command('aa start -b '+target.app+' -a '+target.ability);if(!/success/i.test(result))throw new DeviceError('STALE','无法返回确认的目标应用');await this.stable();}else await this.delay(350);const current=await this.readLayout();
  if(scene(target.snapshot)===scene(current)){const element=relocate(target.snapshot,current,target.elementId);args.x=element.normalizedCenter[0];args.y=element.normalizedCenter[1];return '';}
  // 0.8.1.2：整页不一致时（软键盘、联想条、“N 分钟前”会自己变化）先看目标本身是不是还在：标识、类型、名称、描述、父级、所在窗口都相同且唯一，才算同一个目标。
  try{const element=relocate(target.snapshot,current,target.elementId);args.x=element.normalizedCenter[0];args.y=element.normalizedCenter[1];return '';}catch(e){/* relocate 只会抛 DeviceError（找不到、不唯一、窗口变化等）：都转入下面的重放判断 */}
  return this.reopenMenu(target,current,args);}
 // 0.8.1.2：真机上点小窗里的“同意”会让下层应用的弹出菜单关闭（焦点转到小窗），确认的目标随之消失。
 // 只有同时满足以下条件才重放“打开菜单”的那一次点击，任何一条不满足都抛 STALE，把现状交还给模型，不盲点：
 //  1) 紧邻的上一步动作就是一次点击（之后没有别的动作），且发生在同一个应用里；
 //  2) 这次点击本身不属于危险类别（重放不会重复危险操作）；
 //  3) 被点的那个控件现在仍在原处、名称与属性都没变（弹出层关掉了，但点击目标还在，重放能复现原结果）；
 //  4) 目标在点击前的页面里不存在（说明确实是这次点击把它带出来的）；
 //  5) 重放后在新布局里按文字/描述和类型只能唯一匹配到目标。
 // 授权只对这一个目标：Engine 在此之后仍会复核标签与应用，再点击这一个元素。
 async reopenMenu(target:ActionTarget,current:Snapshot,args:Arguments):Promise<string>{
  const fail=(why:string):DeviceError=>new DeviceError('STALE','确认后页面内容变化，'+why+'，请重新观察再决定。');
  const old=target.snapshot!;const click=this.lastClick;const wanted=old.elements.find(e=>e.elementId===target.elementId);
  if(!wanted||!target.label)throw fail('确认的目标没有可读名称，无法重新定位');
  if(!click||click.seq!==this.actionSeq)throw fail('且上一步不是打开该菜单的点击');
  if(click.app!==target.app)throw fail('且上一步点击不在同一个应用里');
  if(riskOf(click.label,click.app))throw fail('且上一步点击本身是危险操作，不自动重放');
  if(!click.before||click.before.width!==current.width||click.before.height!==current.height)throw fail('无法确认点击前的页面，不自动重放');
  const px=Math.round(click.x*(this.width-1)/1000),py=Math.round(click.y*(this.height-1)/1000);
  // 重放的安全条件：被点的那个控件（点击前布局里该点上最小的元素）现在仍在原处、名称与属性都没变。
  // 不要求整页一致：键盘联想条、“3 分钟前”这类相对时间会自己变化，整页比较会误拒（真机 0.8.1.2 实测）。
  const clicked=elementAtPoint(click.before,px,py);
  if(!clicked||!current.elements.some(e=>sameElement(e,clicked)&&e.enabled))throw fail('且上一步点击的控件已经变了，不自动重放');
  if(click.before.elements.some(e=>labelOfElement(e)===target.label&&e.type===wanted.type&&e.window===wanted.window&&e.parent===wanted.parent))throw fail('目标在上一步点击前就已存在，不是这次点击打开的');
  this.guardOverlap(px,py);
  const result=await this.command('uitest uiInput click '+px+' '+py);if(!result.includes('No Error'))throw fail('重放打开菜单的点击失败');
  await this.delay(500);await this.stable();
  const after=await this.readLayout();
  // 只在“重放后新出现的元素”里找：页面上本来就有的同名控件（如笔记工具栏的“删除”图标）不算。
  const matches=after.elements.filter(e=>labelOfElement(e)===target.label&&e.type===wanted.type&&e.clickable===wanted.clickable&&e.enabled&&!click.before!.elements.some(o=>sameElement(o,e)));
  if(matches.length!==1)throw fail('重新打开菜单后「'+target.label+'」'+(matches.length?'有 '+matches.length+' 个同名项':'不见了')+'，不自动点击');
  const found=matches[0];this.latest=after;args.snapshotId=after.snapshotId;args.elementId=found.elementId;args.x=found.normalizedCenter[0];args.y=found.normalizedCenter[1];
  return '确认时下层应用的弹出菜单被关闭了，已重放上一步打开菜单的点击并按「'+target.label+'」重新定位。';
 }
 async drawPath(a:Arguments):Promise<string>{
 let request:DrawingRequest;try{request=drawingRequest(a.strokesJson??'',a.tool??'finger',a.speed??20);}catch(e){throw new DeviceError('PARAMETER',(e as Error).message);}
 const old=this.latest;if(!old||(a.snapshotId!==undefined&&a.snapshotId!==old.snapshotId))throw new DeviceError('STALE','绘制需要最新屏幕观察');
 if(a.canvasElementId&&!a.snapshotId)throw new DeviceError('PARAMETER','画布编号需要 snapshotId');
 await this.observe();const current=this.latest!;
 if(old.width!==current.width||old.height!==current.height||scene(old)!==scene(current))throw new DeviceError('STALE','画面变化，请重新观察并规划绘制路径');
 let bounds:DrawingBounds|undefined=undefined;
 if(a.canvasElementId){const target=relocate(old,current,a.canvasElementId);if(!/Canvas|XComponent/.test(target.type))throw new DeviceError('NOT_ACTIONABLE','引用的元素不是可识别画布');bounds={left:target.bounds[0],top:target.bounds[1],right:target.bounds[2],bottom:target.bounds[3]};}
 let strokes:DrawingPoint[][];try{strokes=drawingPixels(request,current.width,current.height,bounds);}catch(e){throw new DeviceError('PARAMETER',(e as Error).message);}
 // Reject paths crossing visible controls before any write, including segment interiors.
 for(const stroke of strokes){for(let i=1;i<stroke.length;i++){const start=stroke[i-1],end=stroke[i];const samples=Math.max(1,Math.ceil(Math.hypot(end.x-start.x,end.y-start.y)/2));for(let j=0;j<=samples;j++){const x=start.x+(end.x-start.x)*j/samples,y=start.y+(end.y-start.y)*j/samples;if(current.elements.some(e=>e.clickable&&x>=e.bounds[0]&&x<e.bounds[2]&&y>=e.bounds[1]&&y<e.bounds[3]))throw new DeviceError('PARAMETER','路径经过可点击控件，请重新规划画布路径');}}}
 for(const stroke of strokes){for(const p of stroke)this.guardOverlap(p.x,p.y);}
 const foreground=(raw:string):string=>this.frontOf(raw);const front=foreground(await this.command('aa dump -l'));if(!front)throw new DeviceError('STALE','无法确认绘制应用前台');let count=0;
 for(const stroke of strokes){for(let i=1;i<stroke.length;i++){
  if(!this.active())throw new Error('绘制已暂停，已发出 '+count+' 段；恢复后观察，不自动重画');
  const fresh=await this.readLayout();if(scene(current)!==scene(fresh)||current.elements.some(e=>{const found=fresh.elements.find(f=>f.elementId===e.elementId);return !found||e.bounds.join(',')!==found.bounds.join(',');})||foreground(await this.command('aa dump -l'))!==front)throw new DeviceError('STALE','绘制中页面变化，已发出 '+count+' 段；请重新观察');
  const start=stroke[i-1],end=stroke[i];const result=await this.command('uinput -T -m '+start.x+' '+start.y+' '+end.x+' '+end.y+' '+request.speed,10000);count++;
  if(/error|invalid|failed/i.test(result.replace(/No Error/gi,'')))throw new Error('绘制段结果不确定，已发出 '+count+' 段；请观察，不重试');
  if(!this.active())throw new Error('绘制已暂停，已发出 '+count+' 段；恢复后观察，不自动重画');
 }}
 return '分段手指绘制：已发出 '+count+' 段，每段抬起手指；没有电容笔压力。效果未验证，请核验最新截图';
 }
 async execute(name:string,a:Arguments):Promise<string>{if((name==="launch_app"||name==="home")&&this.hdc.ready===false)throw new DeviceError("DEVICE_OFFLINE","本机 HDC 未连接，已留在大肥鱼，未让出前台；请在大肥鱼里点「本机重连」并确认信任后再继续");/* 0.8.3.9：让出前台（启动其他应用或回桌面）之前必须先确认 HDC 已连接 */if(['click','draw_path','launch_app','insert_text','replace_text','swipe','back','home','long_press','double_click','drag','scroll','press_key'].indexOf(name)>=0){this.lastClick=null;this.actionSeq++;}if(name==='draw_path')return this.drawPath(a);if(name==='wait_for')return WAIT_CONDITIONS.indexOf(typeof a.condition==='string'?a.condition:'')>=0?this.waitForCondition(a):this.waitFor(a);if(name.indexOf('_element')>=0)return this.elementAction(name,a);if(name==='launch_app'){if(a.appId==='大肥鱼'){a.appId=SELF_BUNDLE;}if(a.appId===SELF_BUNDLE&&!this.apps.has(SELF_BUNDLE))this.apps.set(SELF_BUNDLE,SELF_ABILITY);let ability=this.apps.get(a.appId??'')??this.installedAbility(a.appId??'');
 // 0.8.3.4：缓存缺失（模型未先调用 get_capabilities）时，直接用 bm dump -n 取该包的启动 Ability。
 if(!ability&&/^[\w.]+$/.test(a.appId??'')){const meta=parseBundleInfo(await this.command('bm dump -n '+(a.appId??''),15000),a.appId??'');ability=meta.ability;}
 if(!ability)throw new DeviceError('UNKNOWN_APP','应用不在已发现列表，且取不到启动 Ability；请先 get_capabilities 查看应用列表，或确认包名');const wasFloat=this.floatActive()&&a.appId!==SELF_BUNDLE;const result=await this.command('aa start -b '+a.appId+' -a '+ability);if(!/success/i.test(result))throw new Error('应用启动失败');await this.stable();const foreground=await this.command('aa dump -l');if(!foreground.split('AbilityRecord ID').some(block=>block.includes('bundle name ['+a.appId+']')&&block.includes('state #FOREGROUND')))throw new Error('未确认目标应用前台状态');return '应用启动命令成功；前台列表包含目标，请核验最新屏幕'+(wasFloat&&selfCollapsed(foreground,SELF_BUNDLE)?await this.recoverFloat():'');}let command='';const needs=['click','insert_text','replace_text','swipe','long_press','double_click','drag'].indexOf(name)>=0;if(needs&&(!Number.isFinite(a.x)||!Number.isFinite(a.y)||(a.x??-1)<0||(a.y??-1)<0||(a.x??1001)>1000||(a.y??1001)>1000))throw new Error('坐标必须为 0–1000');const x=Math.round((a.x??0)*(this.width-1)/1000),y=Math.round((a.y??0)*(this.height-1)/1000);if(needs)this.guardOverlap(x,y);if((name==='swipe'||name==='drag')&&Number.isFinite(a.x2)&&Number.isFinite(a.y2))this.guardOverlap(Math.round(a.x2!*(this.width-1)/1000),Math.round(a.y2!*(this.height-1)/1000));
 // 0.8.3.8：产品级保护，目标坐标（含拖拽/滑动终点）落在桌面或 ClassCount 上时拒绝，不发出任何输入。
 if(needs){const pts:number[][]=[[x,y]];if((name==='swipe'||name==='drag')&&Number.isFinite(a.x2)&&Number.isFinite(a.y2))pts.push([Math.round(a.x2!*(this.width-1)/1000),Math.round(a.y2!*(this.height-1)/1000)]);await this.guardPoints(pts);}
 if(name==='click'){command='uitest uiInput click '+x+' '+y;const sent=await this.command(command);if(!sent.includes('No Error'))throw new Error('设备操作失败');const p=this.pendingTarget;this.pendingTarget=null;const own=!!p&&Math.abs(p.x-(a.x??0))<=2&&Math.abs(p.y-(a.y??0))<=2;this.lastClick={x:a.x??0,y:a.y??0,label:own?p!.label:'',app:own?p!.app:'',before:this.latest,seq:this.actionSeq};return await this.actionFeedback('点击',a.x??0,a.y??0,sent);}
 if(name==='insert_text'||name==='replace_text'){if(typeof a.text!=='string'||a.text.length>2000)throw new Error('输入文字无效');if(name==='replace_text'){await this.command('uitest uiInput click '+x+' '+y);await this.command('uitest uiInput keyEvent 2072 2017');command='uitest uiInput text '+quote(a.text);}else command='uitest uiInput inputText '+x+' '+y+' '+quote(a.text);}
 if(name==='swipe'){if(!Number.isFinite(a.x2)||!Number.isFinite(a.y2)||(a.x2??-1)<0||(a.y2??-1)<0||(a.x2??1001)>1000||(a.y2??1001)>1000)throw new Error('滑动终点无效');command='uitest uiInput swipe '+x+' '+y+' '+Math.round(a.x2!*(this.width-1)/1000)+' '+Math.round(a.y2!*(this.height-1)/1000);}
 if(name==='long_press'||name==='double_click'){command='uitest uiInput '+(name==='long_press'?'longClick ':'doubleClick ')+x+' '+y;const sent=await this.command(command);if(!sent.includes('No Error'))throw new Error('设备操作失败');return await this.actionFeedback(name==='long_press'?'长按':'双击',a.x??0,a.y??0,sent);}
 if(name==='drag'){if(!Number.isFinite(a.x2)||!Number.isFinite(a.y2)||(a.x2??-1)<0||(a.y2??-1)<0||(a.x2??1001)>1000||(a.y2??1001)>1000)throw new DeviceError('PARAMETER','拖拽终点必须为 0–1000');const x2=Math.round(a.x2!*(this.width-1)/1000),y2=Math.round(a.y2!*(this.height-1)/1000);const dragged=await this.command('uitest uiInput drag '+x+' '+y+' '+x2+' '+y2);if(!dragged.includes('No Error'))throw new Error('设备操作失败');return await this.actionFeedback('拖拽（起点）',a.x??0,a.y??0,dragged);}
 if(name==='press_key'){const code=keyCodeOf(typeof a.key==='string'?a.key:'');if(!code)throw new DeviceError('PARAMETER','按键必须为 enter/backspace/tab/escape');const pressed=await this.command('uitest uiInput keyEvent '+code);if(!pressed.includes('No Error'))throw new Error('设备操作失败');return '已发送按键 '+a.key+'；效果以下次观察为准';}
 if(name==='scroll')return this.scroll(a);
 if(name==='back'||name==='home')command='uitest uiInput keyEvent '+(name==='home'?'Home':'Back');
 if(!command)throw new Error('未知设备工具');const result=await this.command(command);if(!result.includes('No Error'))throw new Error('设备操作失败');return result.trim()+' · screen='+this.width+'x'+this.height+' · point='+x+','+y;}
}
