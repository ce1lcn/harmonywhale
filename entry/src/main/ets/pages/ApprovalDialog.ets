import {BLUE,BLUE_SOFT,BLUE_DEEP,INK,INK2,LINE,WHITE} from './Theme';
@CustomDialog
export struct ApprovalDialog {
 controller:CustomDialogController;
 text:string='';
 scope:string='';
 remember:(value:boolean)=>void=()=>{};
 decide:(value:boolean)=>void=()=>{};
 cancelTask:()=>void=()=>{};
 build(){
  Column({space:18}){
   Text('需要你确认').fontSize(18).fontWeight(FontWeight.Medium).fontColor(BLUE)
   Scroll(){Text(this.text).fontSize(16).fontColor(INK).width('100%')}.constraintSize({maxHeight:280}).width('100%')
   if(this.scope){Row({space:8}){Checkbox({name:'remember-action'}).onChange(this.remember);Text(this.scope).fontSize(14).fontColor(INK2)}}
   Row({space:16}){
    // 0.8.6 阶段 3：两个按钮等宽，同意在右；高 44 保证点击区。
    Button('拒绝').layoutWeight(1).height(44).fontColor(INK2).backgroundColor(WHITE).border({width:1,color:LINE}).borderRadius(22).onClick(()=>{this.controller.close();this.decide(false);})
    Button('同意此操作').layoutWeight(1).height(44).fontColor(BLUE_DEEP).backgroundColor(BLUE_SOFT).borderRadius(22).onClick(()=>{this.controller.close();this.decide(true);})
   }.width('100%')
   Button('取消任务').height(44).fontColor(INK2).backgroundColor(WHITE).border({width:1,color:LINE}).borderRadius(22).onClick(()=>{this.controller.close();this.cancelTask();})
  }.padding(24).width(520).backgroundColor(WHITE).borderRadius(20)
 }
}
