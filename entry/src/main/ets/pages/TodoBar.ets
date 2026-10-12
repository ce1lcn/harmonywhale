// 0.8.4 B4：待办清单的紧凑显示。一行进度（待办 2/5 · 正在：xxx），点开看全部，可清除。全屏时间线顶部与小窗顶部共用。
import {TodoItem} from '../agent/Types';
import {todoProgress,todoMark} from '../agent/Todo';
import {BLUE,BLUE_SOFT,INK,INK2,INK3,GREEN,ORANGE} from './Theme';

@Component
export struct TodoBar {
 @Prop items:TodoItem[]=[];
 @Prop fontScale:number=1;
 @State open:boolean=false;
 onClear:()=>void=()=>{};
 fs(n:number):number{return Math.round(n*(this.fontScale||1)*2)/2;}
 build(){
  if(this.items.length>0){
   Column({space:4}){
    Row({space:8}){
     Text(todoProgress(this.items)).fontSize(this.fs(12)).fontColor(BLUE).maxLines(1).textOverflow({overflow:TextOverflow.Ellipsis}).layoutWeight(1)
     Text(this.open?'收起':'展开').fontSize(this.fs(12)).fontColor(INK3).height(32).textAlign(TextAlign.Center)
    }.width('100%').onClick(()=>{this.open=!this.open;})
    if(this.open){
     ForEach(this.items,(x:TodoItem)=>{
      Row({space:6}){
       Text(todoMark(x.status)).fontSize(this.fs(12)).fontColor(x.status==='done'?GREEN:x.status==='in_progress'?ORANGE:INK3)
       Text(x.text).fontSize(this.fs(13)).fontColor(x.status==='done'?INK3:INK).decoration({type:x.status==='done'?TextDecorationType.LineThrough:TextDecorationType.None}).layoutWeight(1)
      }.width('100%')
     },(x:TodoItem)=>x.text+x.status)
     Text('清除清单').fontSize(this.fs(12)).fontColor(INK2).height(32).onClick(()=>{this.onClear();})
    }
   }.width('100%').padding({left:20,right:20,top:6,bottom:6}).backgroundColor(BLUE_SOFT).alignItems(HorizontalAlign.Start)
  }
 }
}
