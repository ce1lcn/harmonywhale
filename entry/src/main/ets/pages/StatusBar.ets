import {BLUE,BLUE_SOFT,BLUE_DEEP,INK,INK2,INK3,LINE,WHITE,ORANGE,ORANGE_SOFT} from './Theme';
import {ContextStats} from '../agent/Types';
import {SessionStats,timeLabel,tokenLabel,contextLabel,contextPercent,contextUsed,compactTokens,seconds} from '../agent/Stats';
import {groupDigits} from './Timeline';
// 0.8.0 底栏：输入框下方三个可点胶囊（轮/步/TPS、token/缓存命中、上下文%），点击弹出浮层。
export interface StatusView {stats:SessionStats;ctx:ContextStats;running:boolean;compacting:boolean;scale:number;}
interface LineP {label:string;value:string;}
@Component
export struct StatusBar {
 @Prop view:StatusView;
 @State open:string='';
 onResume:()=>void=()=>{};
 onCompress:()=>void=()=>{};
 fs(n:number):number{return Math.round(n*(this.view.scale||1)*2)/2;}
 @Builder line(p:LineP){Row(){Text(p.label).fontSize(this.fs(13)).fontColor(INK2).layoutWeight(1);Text(p.value).fontSize(this.fs(13)).fontColor(INK).fontWeight(FontWeight.Medium)}.width('100%')}
 @Builder timePanel(){
  Column({space:8}){
   Text('会话统计').fontSize(this.fs(15)).fontWeight(FontWeight.Medium).fontColor(INK)
   this.line({label:'轮次（用户消息）',value:this.view.stats.rounds+' 轮'})
   this.line({label:'工具调用',value:this.view.stats.steps+' 步'})
   this.line({label:'模型用时',value:seconds(this.view.stats.modelMs)+'（'+this.view.stats.modelCalls+' 次请求）'})
   this.line({label:'工具调用用时',value:seconds(this.view.stats.toolMs)+'（'+this.view.stats.toolCalls+' 次）'})
   this.line({label:'首 token 平均（TTFT）',value:this.view.stats.ttftAvg?seconds(this.view.stats.ttftAvg):'—'})
   this.line({label:'输出速度（TPS）',value:this.view.stats.tps>0?this.view.stats.tps.toFixed(1)+' tok/s':'—'})
   Text('耗时与速度只统计 0.8.0 起的流式请求；TPS = 输出 token ÷（结束 − 首字节）。').fontSize(this.fs(11)).fontColor(INK3)
  }.width(320).padding(16).alignItems(HorizontalAlign.Start)
 }
 @Builder tokenPanel(){
  Column({space:8}){
   Text('Token 用量').fontSize(this.fs(15)).fontWeight(FontWeight.Medium).fontColor(INK)
   this.line({label:'总量',value:groupDigits(this.view.stats.total)})
   this.line({label:'缓存命中率',value:(this.view.stats.hitRate*100).toFixed(1)+'%'})
   this.line({label:'未缓存输入',value:groupDigits(this.view.stats.input)})
   this.line({label:'缓存读取',value:groupDigits(this.view.stats.cacheRead)})
   this.line({label:'输出',value:groupDigits(this.view.stats.output)})
   Divider().color(LINE)
   this.line({label:'等效用量（本会话）',value:groupDigits(this.view.stats.cost)})
   this.line({label:'本段等效用量 / 预算',value:compactTokens(this.view.stats.segmentCost)+' / '+(this.view.stats.budget>0?compactTokens(this.view.stats.budget):'不限')})
   Text('等效用量 = 未缓存输入 + 输出 + 缓存读取 × 0.1').fontSize(this.fs(11)).fontColor(INK3)
  }.width(320).padding(16).alignItems(HorizontalAlign.Start)
 }
 @Builder ctxPanel(){
  Column({space:8}){
   Text('上下文已用 '+contextLabel(this.view.ctx)).fontSize(this.fs(15)).fontWeight(FontWeight.Medium).fontColor(INK)
   Progress({value:contextPercent(this.view.ctx),total:100,type:ProgressType.Linear}).color(contextPercent(this.view.ctx)>=80?ORANGE:BLUE).width('100%')
   Text('~'+compactTokens(contextUsed(this.view.ctx))+' / '+compactTokens(this.view.ctx.window)).fontSize(this.fs(13)).fontColor(INK2)
   Text(this.view.ctx.served!==undefined?'服务端上次报告 '+compactTokens(this.view.ctx.served)+' '+((this.view.ctx.delta??0)>=0?'+ ':'− ')+'之后变化估算 '+compactTokens(Math.abs(this.view.ctx.delta??0)):'还没有服务端用量，按字符估算').fontSize(this.fs(11)).fontColor(INK3)
   Text('构成（估算）').fontSize(this.fs(12)).fontColor(INK3)
   this.line({label:'系统提示词',value:compactTokens(this.view.ctx.system)})
   this.line({label:'工具定义',value:compactTokens(this.view.ctx.tools)})
   this.line({label:'对话消息',value:compactTokens(this.view.ctx.messages)})
   if(this.view.ctx.images>0){this.line({label:'截图',value:compactTokens(this.view.ctx.images)})}
   Divider().color(LINE)
   this.line({label:'输出预留（不计入）',value:compactTokens(this.view.ctx.output)})
   Text('输出预留不计入百分比。上面分项按字符估算，仅作构成参考，可能与总数不等。自动压缩阈值本版不变（估算输入 + 输出预留超过窗口 80% 时压缩）。').fontSize(this.fs(11)).fontColor(INK3)
   Button(this.view.compacting?'正在压缩…':'压缩上下文',{type:ButtonType.Capsule}).id('status_compress').height(34).fontSize(this.fs(13)).backgroundColor(BLUE_SOFT).fontColor(BLUE_DEEP).enabled(!this.view.compacting).opacity(this.view.compacting?0.5:1).onClick(()=>{this.open='';this.onCompress();})
  }.width(320).padding(16).alignItems(HorizontalAlign.Start)
 }
 // 0.8.6 阶段 3：继续只由输入栏主按钮负责，这里只显示暂停原因。
 @Builder pausePanel(){
  Column({space:10}){
   Text('已暂停').fontSize(this.fs(15)).fontWeight(FontWeight.Medium).fontColor(ORANGE)
   Scroll(){Text(this.view.stats.pauseReason).fontSize(this.fs(13)).fontColor(INK).width('100%')}.constraintSize({maxHeight:240}).width('100%')
   Text('点输入栏右侧的按钮即可继续').fontSize(this.fs(12)).fontColor(INK3)
  }.width(320).padding(16).alignItems(HorizontalAlign.Start)
 }
 // 注意：胶囊文字直接绑定 this.view，不经过按值传参的 @Builder，否则数值不会随会话刷新。
 // 0.8.6 阶段 3：每个胶囊外层补到 44 高的点击区，视觉大小不变。
 // 0.8.6 阶段 4：三项平铺、无边框无底色、灰字，整行水平居中；图标用 SymbolGlyph；上下文用真实进度圆环。
 build(){
  Row({space:14}){
   if(this.view.stats.paused&&!this.view.running){
    Row(){
     Row({space:6}){
      Column().width(7).height(7).borderRadius(4).backgroundColor(ORANGE)
      Text('已暂停').fontSize(this.fs(12)).fontColor(ORANGE).maxLines(1)
      // 继续按钮已由输入栏主按钮承担；这里保留 status_resume 的 0 尺寸占位，兼容旧脚本的 id。
      Column().id('status_resume').width(0).height(0).onClick(()=>{this.open='';this.onResume();})
     }.padding({left:6,right:6})
    }.id('status_pause').height(32).onClick(()=>{this.open=this.open==='pause'?'':'pause';})
     .bindPopup(this.open==='pause',{builder:this.pausePanel,placement:Placement.Top,popupColor:WHITE,enableArrow:false,radius:16,onStateChange:(e)=>{if(!e.isVisible&&this.open==='pause')this.open='';}})
   }else{
    Row(){
     Row({space:5}){
      if(this.view.running){Column().width(7).height(7).borderRadius(4).backgroundColor(BLUE)}
      SymbolGlyph($r('sys.symbol.timer')).fontSize(this.fs(13)).fontColor([this.view.running?BLUE:INK2]).renderingStrategy(SymbolRenderingStrategy.SINGLE)
      Text(timeLabel(this.view.stats)).fontSize(this.fs(12)).fontColor(this.view.running?BLUE:INK2).maxLines(1)
     }.padding({left:6,right:6})
    }.id('status_time').height(32).onClick(()=>{this.open=this.open==='time'?'':'time';})
     .bindPopup(this.open==='time',{builder:this.timePanel,placement:Placement.Top,popupColor:WHITE,enableArrow:false,radius:16,onStateChange:(e)=>{if(!e.isVisible&&this.open==='time')this.open='';}})
   }
   Row(){
    Row({space:5}){
     SymbolGlyph($r('sys.symbol.square_stack_3d')).fontSize(this.fs(13)).fontColor([INK2]).renderingStrategy(SymbolRenderingStrategy.SINGLE)
     Text(tokenLabel(this.view.stats)).fontSize(this.fs(12)).fontColor(INK2).maxLines(1)
    }.padding({left:6,right:6})
   }.id('status_token').height(32).onClick(()=>{this.open=this.open==='token'?'':'token';})
    .bindPopup(this.open==='token',{builder:this.tokenPanel,placement:Placement.Top,popupColor:WHITE,enableArrow:false,radius:16,onStateChange:(e)=>{if(!e.isVisible&&this.open==='token')this.open='';}})
   Row(){
    Row({space:5}){
     Progress({value:contextPercent(this.view.ctx),total:100,type:ProgressType.Ring}).width(16).height(16).color(contextPercent(this.view.ctx)>=80?ORANGE:BLUE).backgroundColor(LINE).style({strokeWidth:2.5})
     Text(contextLabel(this.view.ctx)).fontSize(this.fs(12)).fontColor(contextPercent(this.view.ctx)>=80?ORANGE:INK2).maxLines(1)
    }.padding({left:6,right:6})
   }.id('status_ctx').height(32).onClick(()=>{this.open=this.open==='ctx'?'':'ctx';})
    .bindPopup(this.open==='ctx',{builder:this.ctxPanel,placement:Placement.Top,popupColor:WHITE,enableArrow:false,radius:16,onStateChange:(e)=>{if(!e.isVisible&&this.open==='ctx')this.open='';}})
  }.width('100%').justifyContent(FlexAlign.Center).padding({left:6,right:6,top:0})
 }
}
