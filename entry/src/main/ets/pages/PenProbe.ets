import {common} from '@kit.AbilityKit';
import {router} from '@kit.ArkUI';
import {Store} from '../agent/Store';
import {APP_VERSION} from '../agent/BuildSecrets';
interface PenEvent {time:number;type:number;sourceType:number;sourceTool:number;pressure:number;tiltX:number;tiltY:number;deviceId:number;x:number;y:number;screenX:number;screenY:number;}
@Entry
@Component
struct PenProbe {
 @State status:string='等待输入';
 context:CanvasRenderingContext2D=new CanvasRenderingContext2D(new RenderingContextSettings(true));
 events:PenEvent[]=[];store:Store|null=null;down:boolean=false;lastX:number=0;lastY:number=0;
 aboutToAppear():void{const host=this.getUIContext().getHostContext() as common.UIAbilityContext;this.store=new Store(host.filesDir);}
 save():void{this.store?.write(this.store.root+'/pen-probe.json',JSON.stringify({version:APP_VERSION,events:this.events}));}
 touch(event:TouchEvent):void{
  const point=event.changedTouches[0]??event.touches[0];if(!point)return;
  const record:PenEvent={time:Date.now(),type:event.type,sourceType:event.source,sourceTool:event.sourceTool,pressure:event.pressure,tiltX:event.tiltX,tiltY:event.tiltY,deviceId:event.deviceId??-1,x:point.x,y:point.y,screenX:point.screenX,screenY:point.screenY};
  if(this.events.length<10000)this.events.push(record);
  this.status='事件 '+this.events.length+' · source='+event.source+' tool='+event.sourceTool+' pressure='+event.pressure;
  if(event.type===TouchType.Down){this.down=true;this.lastX=point.x;this.lastY=point.y;}
  else if(event.type===TouchType.Move&&this.down){this.context.strokeStyle='#145BCA';this.context.lineWidth=3;this.context.beginPath();this.context.moveTo(this.lastX,this.lastY);this.context.lineTo(point.x,point.y);this.context.stroke();this.lastX=point.x;this.lastY=point.y;}
  else if(event.type===TouchType.Up||event.type===TouchType.Cancel)this.down=false;
  this.save();event.stopPropagation();
 }
 build(){
  Column({space:10}){
   Text('笔输入探针 H0').fontSize(22)
   Text(this.status).id('pen_probe_status').fontSize(14)
   Row({space:20}){
    Button('清空探针').onClick(()=>{this.context.clearRect(0,0,this.context.width,this.context.height);this.events=[];this.down=false;this.status='等待输入';this.save();})
    Button('保存事件').onClick(()=>{this.save();})
    Button('返回').onClick(()=>{this.save();router.back();})
   }
   Canvas(this.context).id('pen_probe_canvas').width('90%').layoutWeight(1).backgroundColor('#FFFFFF').border({width:1,color:'#B0B0B0'}).onTouch((event:TouchEvent)=>this.touch(event))
  }.width('100%').height('100%').padding({top:60,bottom:50}).backgroundColor('#F4F5F7')
 }
}
