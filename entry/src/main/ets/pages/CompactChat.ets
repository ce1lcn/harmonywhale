import {inputMethod} from '@kit.IMEKit';
import {PlusPanel,AttachmentStrip} from './PlusPanel';
import {Attachment} from '../agent/Types';
import {MarkdownView} from './MarkdownView';
import {AskCard,LearnCard,learnInfo} from './Cards';
import {TodoBar} from './TodoBar';
import {copyTodos} from '../agent/Todo';
import {BLUE,BLUE_SOFT,BLUE_LINE,BLUE_DEEP,INK,INK2,INK3,LINE,WHITE,ORANGE,GREEN,SURFACE} from './Theme';
import {Engine} from '../agent/Engine';
import {Task} from '../agent/Types';
import {compactView,CompactView,CompactRow,toolMark} from '../agent/CompactTimeline';
import {contextLabel} from '../agent/Stats';
import {statusLabel} from './Timeline';
// 0.8.1 紧凑模式（窗口宽度 < 600vp，例如鸿蒙悬浮窗）：顶部一行状态与控制、中间只显示当前任务、底部一行输入与状态缩略。
// 侧栏、收藏、设置收进右上角“⋯”。确认卡片固定在输入框上方。
interface MenuItemP {label:string;action:()=>void;}
@Component
export struct CompactChat {
 @Prop @Watch('onRevision') revision:number=0;
 @Prop fontScale:number=1;
 engine:Engine|null=null;
 @State opened:string[]=[];
 @State closed:string[]=[];
 @Link text:string;
 @State remember:boolean=false;
 @State plusOpen:boolean=false;
 @Prop attachments:Attachment[]=[];
 onPhoto:()=>void=()=>{};onAlbum:()=>void=()=>{};onFile:()=>void=()=>{};onGoal:()=>void=()=>{};onRemove:(id:string)=>void=()=>{};
 @Builder plusPanel(){PlusPanel({planning:!!this.eng()?.session().planning,onPhoto:()=>{this.plusOpen=false;this.onPhoto();},onAlbum:()=>{this.plusOpen=false;this.onAlbum();},onFile:()=>{this.plusOpen=false;this.onFile();},onGoal:()=>{this.plusOpen=false;this.onGoal();},onPlan:()=>{this.eng()?.togglePlan();}})}
 scroller:Scroller=new Scroller();
 onSend:(text:string)=>void=()=>{};
 onUndo:(row:CompactRow)=>string=()=>'';
 onResume:()=>void=()=>{};
 onNewChat:()=>void=()=>{};
 onSettings:()=>void=()=>{};
 onTrace:()=>void=()=>{};
 onRevision():void{setTimeout(()=>{try{this.scroller.scrollEdge(Edge.Bottom);}catch(e){}},60);}
 fs(n:number):number{return Math.round(n*(this.fontScale||1)*2)/2;}
 eng():Engine|null{return this.revision>=0?this.engine:null;}
 view():CompactView{const e=this.eng();return e?compactView(e.session()):{rows:[],hidden:0,latestThink:''};}
 task():Task|null{return this.eng()?.current??null;}
 running():boolean{return !!(this.eng()?.running||this.eng()?.compacting);}
 paused():boolean{return !this.running()&&this.task()?.status==='paused';}
 // 0.8.6 阶段 3：主按钮随状态变，与主界面输入栏一致：有输入=发送；运行中=暂停；已暂停=继续；空闲=发送。
 mode():string{const typed=!!this.text.trim()||this.attachments.length>0;if(this.running())return typed?'send':'pause';if(this.paused())return typed?'send':'resume';return 'send';}
 isOpen(r:CompactRow,latest:string):boolean{return this.opened.indexOf(r.id)>=0||(r.id===latest&&this.closed.indexOf(r.id)<0);}
 toggle(r:CompactRow,latest:string):void{if(this.isOpen(r,latest)){this.opened=this.opened.filter(v=>v!==r.id);if(r.id===latest)this.closed=this.closed.concat(r.id);}else{this.closed=this.closed.filter(v=>v!==r.id);this.opened=this.opened.concat(r.id);}}
 statusLine():string{const t=this.task();const e=this.eng();const steps=t?t.calls+' 步':'0 步';const ctx=e?contextLabel(e.contextStats(e.session())):'—';return steps+' · 上下文 '+ctx;}
 menu():MenuElement[]{const items:MenuItemP[]=[{label:'新会话',action:()=>{this.onNewChat();}},{label:'执行轨迹',action:()=>{this.onTrace();}},{label:'设置',action:()=>{this.onSettings();}}];return items.map((m:MenuItemP)=>{return {value:m.label,action:m.action} as MenuElement;});}
 send():void{const t=this.text.trim();if(!t&&!this.attachments.length)return;this.getUIContext().getFocusController().clearFocus();inputMethod.getController().hideTextInput().catch(()=>{});this.plusOpen=false;this.text='';this.onSend(t);}
 @Builder rowView(r:CompactRow,latest:string){
  if(r.kind==='user'){
   Text(r.text).fontSize(this.fs(14)).fontColor(INK).padding({left:12,right:12,top:7,bottom:7}).borderRadius(14).backgroundColor(BLUE_SOFT).alignSelf(ItemAlign.End).constraintSize({maxWidth:'90%'})
  }else if(r.kind==='assistant'){
   MarkdownView({text:r.text,fontScale:this.fontScale*0.875,cacheKey:this.running()&&r.text===this.task()?.progress?r.id:''})
  }else if(r.kind==='learn'){
   LearnCard({title:learnInfo(r.name,r.args,r.result).title,detail:r.result,fontScale:this.fontScale*0.875,onUndo:()=>{return this.onUndo(r);}})
  }else if(r.kind==='think'){
   Column({space:3}){
    Row({space:6}){
     Text('💡 思考').fontSize(this.fs(13)).fontColor(INK3)
     if(!this.isOpen(r,latest)){Text(r.text.replace(/\s+/g,' ')).fontSize(this.fs(13)).fontColor(INK2).maxLines(1).textOverflow({overflow:TextOverflow.Ellipsis}).layoutWeight(1)}
    }.width('100%').onClick(()=>{this.toggle(r,latest);})
    if(this.isOpen(r,latest)){Text(r.text).fontSize(this.fs(12)).fontColor(INK2).lineHeight(this.fs(18)).width('100%').padding({left:8}).border({width:{left:2},color:LINE}).onClick(()=>{this.toggle(r,latest);})}
   }.width('100%')
  }else{
   Row({space:6}){
    Text(r.label).fontSize(this.fs(12)).fontColor(INK3).maxLines(1)
    Text(r.text).fontSize(this.fs(13)).fontColor(INK2).maxLines(1).textOverflow({overflow:TextOverflow.Ellipsis}).layoutWeight(1)
    if(r.status==='pending'){LoadingProgress().width(12).height(12).color(BLUE)}else{Text(toolMark(r.status)).fontSize(this.fs(12)).fontColor(r.status==='success'?GREEN:r.status==='error'||r.status==='uncertain'?ORANGE:INK3)}
   }.width('100%')
  }
 }
 // 0.8.6 阶段 3：主按钮按模式切换；每种模式保留原 id（float_send / float_pause / float_resume）。
 @Builder mainButton(){
  if(this.mode()==='pause'){
   Row(){Row(){SymbolGlyph($r('sys.symbol.pause_fill')).fontSize(16).fontColor([WHITE])}.width(36).height(36).justifyContent(FlexAlign.Center).borderRadius(18).backgroundColor(BLUE)}.id('float_pause').width(44).height(44).justifyContent(FlexAlign.Center).accessibilityText('暂停').onClick(()=>{this.eng()?.pause();})
  }else if(this.mode()==='resume'){
   Row(){Row(){SymbolGlyph($r('sys.symbol.play_fill')).fontSize(16).fontColor([WHITE])}.width(36).height(36).justifyContent(FlexAlign.Center).borderRadius(18).backgroundColor(BLUE)}.id('float_resume').width(44).height(44).justifyContent(FlexAlign.Center).accessibilityText('继续').onClick(()=>{this.onResume();})
  }else{
   Row(){Row(){SymbolGlyph($r('sys.symbol.arrow_up')).fontSize(16).fontColor([WHITE])}.width(36).height(36).justifyContent(FlexAlign.Center).borderRadius(18).backgroundColor((this.text.trim()||this.attachments.length>0)?BLUE:BLUE_LINE)}.id('float_send').width(44).height(44).justifyContent(FlexAlign.Center).accessibilityText(this.running()?'发送补充':'发送').onClick(()=>{this.send();})
  }
 }
 @Builder approvalCard(){
  if(this.eng()?.approval){
   Column({space:8}){
    Text('需要你确认').fontSize(this.fs(13)).fontWeight(FontWeight.Medium).fontColor(BLUE)
    Scroll(){Text(this.eng()!.approval).fontSize(this.fs(14)).fontColor(INK).width('100%')}.constraintSize({maxHeight:140}).width('100%')
    if(this.eng()?.approvalScope){Row({space:6}){Checkbox({name:'float-remember'}).select(this.remember).onChange((v:boolean)=>{this.remember=v;if(this.engine)this.engine.approvalRemember=v;});Text(this.eng()!.approvalScope).fontSize(this.fs(12)).fontColor(INK2).layoutWeight(1)}.width('100%')}
    Row({space:8}){
     Row(){Row(){Text('拒绝').fontSize(this.fs(14)).fontColor(INK2)}.width('100%').height(34).justifyContent(FlexAlign.Center).borderRadius(17).backgroundColor(WHITE).border({width:1,color:LINE})}.id('float_reject').layoutWeight(1).height(44).justifyContent(FlexAlign.Center).onClick(()=>{this.remember=false;this.eng()?.approve(false);})
     Row(){Row(){Text('同意').fontSize(this.fs(14)).fontColor(BLUE_DEEP)}.width('100%').height(34).justifyContent(FlexAlign.Center).borderRadius(17).backgroundColor(BLUE_SOFT)}.id('float_approve').layoutWeight(1).height(44).justifyContent(FlexAlign.Center).onClick(()=>{this.remember=false;this.eng()?.approve(true);})
    }.width('100%')
   }.width('100%').padding(12).borderRadius(14).backgroundColor(WHITE).border({width:2,color:BLUE}).alignItems(HorizontalAlign.Start)
  }
 }
 build(){
  Column(){
   Row({space:6}){
    Column().width(8).height(8).borderRadius(4).backgroundColor(this.running()?BLUE:this.paused()?ORANGE:INK3)
    Text(this.eng()?.session().title??'新会话').fontSize(this.fs(14)).fontWeight(FontWeight.Medium).fontColor(INK).maxLines(1).textOverflow({overflow:TextOverflow.Ellipsis}).layoutWeight(1)
    Row(){Row(){SymbolGlyph($r('sys.symbol.ellipsis_message')).fontSize(18).fontColor([INK2])}.width(36).height(36).justifyContent(FlexAlign.Center).borderRadius(18)}.id('float_menu').width(44).height(44).justifyContent(FlexAlign.Center).bindMenu(this.menu())
   }.width('100%').height(44).padding({left:12,right:6})
   Divider().color(LINE)
   TodoBar({items:copyTodos(this.eng()?.session().todos),fontScale:this.fontScale*0.875,onClear:()=>{if(!this.running()){const s=this.eng()?.session();if(s){s.todos=[];this.eng()?.save();}}}})
   Scroll(this.scroller){
    Column({space:6}){
     if(this.view().hidden>0){Text('更早 '+this.view().hidden+' 条已折叠').fontSize(this.fs(12)).fontColor(INK3)}
     ForEach(this.view().rows,(r:CompactRow)=>{this.rowView(r,this.view().latestThink)},(r:CompactRow)=>r.id+r.status+r.text.length+(this.isOpen(r,this.view().latestThink)?'o':'c')+this.fontScale)
     if(this.running()){Row({space:6}){LoadingProgress().width(13).height(13).color(BLUE);Text(statusLabel(this.task()?.status??'')+(this.task()?.currentAction?' · '+this.task()!.currentAction:'')).fontSize(this.fs(12)).fontColor(INK3).maxLines(2).layoutWeight(1)}.width('100%')}
     if(this.paused()&&this.task()?.reason){Text('已暂停 · '+this.task()!.reason).fontSize(this.fs(12)).fontColor(ORANGE).width('100%')}
     if(!this.view().rows.length){Text('在下面交代任务，大肥鱼会在这里显示思考和每一步操作。').fontSize(this.fs(13)).fontColor(INK3).width('100%')}
    }.width('100%').padding({left:12,right:12,top:8,bottom:8}).alignItems(HorizontalAlign.Start)
   }.layoutWeight(1).width('100%').scrollBar(BarState.Off).align(Alignment.Top).onAppear(()=>{this.scroller.scrollEdge(Edge.Bottom);})
   Column({space:6}){
    this.approvalCard()
    if(this.eng()?.current?.askUser&&this.eng()?.current?.status==='paused'&&!this.eng()?.running){AskCard({question:this.eng()!.current!.askUser!.question,options:this.eng()!.current!.askUser!.options,fontScale:this.fontScale*0.875,onPick:(l:string)=>{this.eng()?.answerAsk(l).catch(()=>{});}})}
    if(this.attachments.length){AttachmentStrip({items:this.attachments,onRemove:this.onRemove})}
    Row({space:6}){
     Row(){Row(){SymbolGlyph($r('sys.symbol.plus')).fontSize(18).fontColor([INK2])}.width(36).height(36).justifyContent(FlexAlign.Center).borderRadius(18).backgroundColor(SURFACE)}.width(44).height(44).justifyContent(FlexAlign.Center).onClick(()=>{this.plusOpen=!this.plusOpen;}).bindPopup(this.plusOpen,{builder:this.plusPanel,placement:Placement.Top,popupColor:WHITE,enableArrow:false,onStateChange:(v:PopupStateChangeParam)=>{if(!v.isVisible)this.plusOpen=false;}})
     TextInput({text:this.text,placeholder:this.running()?'补充要求，下一步生效':this.eng()?.session().suggestion||'问点什么，或让大肥鱼帮你做事'}).id('float_input').onChange((v:string)=>{this.text=v;}).onSubmit(()=>{this.send();}).layoutWeight(1).height(38).fontSize(this.fs(14)).backgroundColor(SURFACE).borderRadius(19)
     if(!this.text&&this.eng()?.session().suggestion&&!this.running()){Text('采用').fontSize(this.fs(12)).fontColor(INK3).height(44).onClick(()=>{this.text=this.eng()!.session().suggestion!;})}
     if(this.running()||this.paused()){Row(){Text('取消').fontSize(this.fs(14)).fontColor(INK3)}.id('float_stop').height(44).padding({left:8,right:8}).justifyContent(FlexAlign.Center).onClick(()=>{this.eng()?.pause('用户取消',true);})}
     this.mainButton()
    }.width('100%')
    Text(this.statusLine()).id('float_status').fontSize(this.fs(11)).fontColor(INK3).width('100%')
   }.width('100%').padding({left:10,right:10,top:6,bottom:8}).border({width:{top:1},color:LINE})
  }.width('100%').height('100%').backgroundColor(WHITE)
 }
}
