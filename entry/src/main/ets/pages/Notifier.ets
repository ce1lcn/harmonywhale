import {notificationManager} from '@kit.NotificationKit';
import {wantAgent,WantAgent,common} from '@kit.AbilityKit';
import {vibrator} from '@kit.SensorServiceKit';
import {TaskNotifier,NoticeSink,NoticeChannel} from '../agent/FloatPolicy';
import {SELF_BUNDLE,SELF_ABILITY} from '../agent/Device';
// 0.8.1 F4：可更新的进度通知；确认时轻震，小窗未打开时另发带“同意 / 拒绝”按钮的通知。
// 按钮用 START_ABILITY 型 WantAgent 带参数回到 ProbeAbility（onNewWant 解析），会把大肥鱼带到前台。
// 0.8.1.2：0.8.1.1 真机“按钮不显示”是因为按钮默认折叠，点开通知后才出现（docs/ACCEPTANCE-0.8.1.md 0.8.1.2 一节）。
// 0.8.1.2：发布与清除统一经 NoticeChannel，结束 / 清除后在途的发布一律丢弃（修复进度通知残留）。
const PROGRESS_ID:number=8101;
const APPROVAL_ID:number=8102;
// 真机（0.8.1.2）：通知上的按钮默认折叠，要在通知中心里先点开这条通知（同一应用的通知先点分组展开），展开后才显示。
const APPROVAL_HINT:string='（点开这条通知，展开后有「同意 / 拒绝」按钮）';
export const APPROVAL_PARAM:string='hwApproval';
export const APPROVAL_SERIAL:string='hwApprovalSerial';
class SystemSink implements NoticeSink<notificationManager.NotificationRequest> {
 context:common.UIAbilityContext;
 constructor(context:common.UIAbilityContext){this.context=context;}
 async agent(code:number,action:string,serial:number):Promise<WantAgent>{
  const parameters:Record<string,Object>={};if(action){parameters[APPROVAL_PARAM]=action;parameters[APPROVAL_SERIAL]=serial;}
  return wantAgent.getWantAgent({wants:[{bundleName:SELF_BUNDLE,abilityName:SELF_ABILITY,parameters:parameters}],actionType:wantAgent.OperationType.START_ABILITY,requestCode:code,actionFlags:[wantAgent.WantAgentFlags.UPDATE_PRESENT_FLAG]});
 }
 async build(id:number,title:string,text:string,buttons:boolean,serial:number):Promise<notificationManager.NotificationRequest>{
  const request:notificationManager.NotificationRequest={id:id,content:{notificationContentType:notificationManager.ContentType.NOTIFICATION_CONTENT_BASIC_TEXT,normal:{title:title,text:text}},notificationSlotType:notificationManager.SlotType.SERVICE_INFORMATION,isAlertOnce:id===PROGRESS_ID,tapDismissed:id!==PROGRESS_ID,wantAgent:await this.agent(id,'',0)};
  if(buttons)request.actionButtons=[{title:'同意',wantAgent:await this.agent(id*10+1,'yes',serial)},{title:'拒绝',wantAgent:await this.agent(id*10+2,'no',serial)}];
  return request;
 }
 async publish(id:number,request:notificationManager.NotificationRequest):Promise<void>{await notificationManager.publish(request);}
 async cancel(id:number):Promise<void>{await notificationManager.cancel(id);}
}
export class Notifier implements TaskNotifier {
 context:common.UIAbilityContext;asked:boolean=false;channel:NoticeChannel<notificationManager.NotificationRequest>;
 constructor(context:common.UIAbilityContext){this.context=context;this.channel=new NoticeChannel<notificationManager.NotificationRequest>(new SystemSink(context));}
 // 第一次发任务时请求通知授权（系统弹窗由用户决定）；拒绝后不再追问。
 async ensureEnabled():Promise<void>{if(this.asked)return;this.asked=true;try{if(!(await notificationManager.isNotificationEnabled()))await notificationManager.requestEnableNotification(this.context);}catch(e){}}
 progress(text:string):void{this.channel.publish(PROGRESS_ID,'大肥鱼正在做任务',text,false,0).catch(()=>{});}
 approval(serial:number,text:string,inFloat:boolean):void{
  try{vibrator.startVibration({type:'time',duration:40},{id:0,usage:'notification'}).catch(()=>{});}catch(e){}
  if(!inFloat)this.channel.publish(APPROVAL_ID,'大肥鱼需要你确认',text+APPROVAL_HINT,true,serial).catch(()=>{});
 }
 clearApproval():void{this.channel.cancel(APPROVAL_ID).catch(()=>{});}
 // 任务结束：先清除（作废在途的进度发布），暂停时再留一条说明。
 finished(text:string):void{this.channel.cancel(PROGRESS_ID).catch(()=>{});if(text)this.channel.publish(PROGRESS_ID,'大肥鱼',text,false,0).catch(()=>{});}
}
