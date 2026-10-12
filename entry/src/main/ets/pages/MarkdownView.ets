// DSH policy/design adaptation: Copyright (c) 2026 DeepSeek. MIT; see docs/THIRD-PARTY.md.
import {RichBlock,RichSpan,IncrementalMarkdown,markdownFor,plainText,inline} from '../agent/Markdown';
import {pasteboard} from '@kit.BasicServicesKit';
import {common} from '@kit.AbilityKit';
import {BLUE,INK,INK2,INK3,SURFACE,LINE,WHITE} from './Theme';
@Component
struct CodeCard {
 @Prop text:string='';@Prop language:string='代码';@Prop fontScale:number=1;@Prop saveEnabled:boolean=false;
 @State copied:boolean=false;@State wrap:boolean=false;timer:number=0;
 onSave:(text:string)=>void=()=>{};
 aboutToDisappear():void{clearTimeout(this.timer);}
 async copy():Promise<void>{try{await pasteboard.getSystemPasteboard().setData(pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN,this.text));this.copied=true;clearTimeout(this.timer);this.timer=setTimeout(()=>{this.copied=false;},1500);}catch(e){this.copied=false;}}
 build(){Column({space:0}){
  Row({space:12}){Text(this.language).fontSize(12*this.fontScale).fontColor(INK3).layoutWeight(1);Text(this.wrap?'不换行':'换行').fontSize(12*this.fontScale).fontColor(INK2).width(44).height(44).textAlign(TextAlign.Center).onClick(()=>{this.wrap=!this.wrap;});Text(this.copied?'✓':'复制').fontSize(12*this.fontScale).fontColor(BLUE).width(44).height(44).textAlign(TextAlign.Center).onClick(()=>{this.copy();})
  if(this.saveEnabled){Text('存为文件').fontSize(12*this.fontScale).fontColor(BLUE).height(44).textAlign(TextAlign.Center).onClick(()=>{this.onSave(this.text);})}}.width('100%').padding({left:12,right:12})
  if(this.wrap){Text(this.text).fontFamily('monospace').fontSize(13*this.fontScale).fontColor(INK).width('100%').padding(12).copyOption(CopyOptions.LocalDevice)}else{Scroll(){Text(this.text).fontFamily('monospace').fontSize(13*this.fontScale).fontColor(INK).padding(12).copyOption(CopyOptions.LocalDevice)}.scrollable(ScrollDirection.Horizontal).width('100%').align(Alignment.Start)}
 }.width('100%').borderRadius(12).backgroundColor(SURFACE).border({width:1,color:LINE}).alignItems(HorizontalAlign.Start)}
}
@Component
export struct MarkdownView {
 @Prop text:string='';@Prop fontScale:number=1;@Prop cacheKey:string='';@Prop saveEnabled:boolean=false;
 onSaveCode:(text:string,language:string)=>void=()=>{};
 parser:IncrementalMarkdown=new IncrementalMarkdown();
 async copy(markdown:boolean):Promise<void>{await pasteboard.getSystemPasteboard().setData(pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN,markdown?this.text:plainText(this.text)));}
 open(url:string):void{if(!/^https?:\/\/[^\s]+$/.test(url))return;const context=getContext(this) as common.UIAbilityContext;context.startAbility({action:'ohos.want.action.viewData',uri:url,entities:['entity.system.browsable']}).catch(()=>{});}
 @Builder spans(items:RichSpan[],heading:boolean){
  Text(){ForEach(items,(s:RichSpan)=>{Span(s.text).fontColor(s.href||s.code?BLUE:INK).fontWeight(s.bold||heading?FontWeight.Bold:FontWeight.Normal).fontStyle(s.italic?FontStyle.Italic:FontStyle.Normal).fontFamily(s.code?'monospace':'sans-serif').onClick(()=>{if(s.href)this.open(s.href);})},(s:RichSpan,i:number)=>i+s.text)}.fontSize(16*this.fontScale).lineHeight(25*this.fontScale).width('100%')
 }
 @Builder copyMenu(){Menu(){MenuItem({content:'复制纯文本'}).onClick(()=>{this.copy(false);});MenuItem({content:'复制 Markdown'}).onClick(()=>{this.copy(true);})}}
 @Builder table(b:RichBlock){
  Scroll(){Column({space:0}){ForEach(b.rows??[],(row:string[],ri:number)=>{Row({space:0}){ForEach(row,(cell:string)=>{Text(){ForEach(inline(cell),(s:RichSpan)=>{Span(s.text).fontColor(s.href?BLUE:INK).fontWeight(ri===0||s.bold?FontWeight.Bold:FontWeight.Normal).onClick(()=>{if(s.href)this.open(s.href);})})}.fontSize(14*this.fontScale).width(180).padding(10).border({width:0.5,color:LINE})})}.backgroundColor(ri%2===0?SURFACE:WHITE)},(row:string[],ri:number)=>ri+row.join('|'))}}.scrollable(ScrollDirection.Horizontal).width('100%')
 }
 build(){Column({space:8}){
  ForEach(this.cacheKey?markdownFor(this.cacheKey,this.text):this.parser.parse(this.text),(b:RichBlock)=>{
   if(b.kind==='code'){CodeCard({text:b.text,language:b.language??'代码',fontScale:this.fontScale,saveEnabled:this.saveEnabled,onSave:(t:string)=>{this.onSaveCode(t,b.language??'代码');}})}
   else if(b.kind==='table'){this.table(b)}
   else if(b.kind==='rule'){Divider().color(LINE).margin({top:8,bottom:8})}
   else if(b.kind==='h'){Text(b.text).fontSize((b.level===1?24:b.level===2?20:18)*this.fontScale).fontColor(INK).fontWeight(FontWeight.Bold).width('100%').margin({top:12,bottom:4})}
   else if(b.kind==='bullet'){Row({space:8}){Text(b.marker??'•').fontSize(16*this.fontScale).fontColor(INK3).width(26);Column(){this.spans(b.spans,false)}.layoutWeight(1)}.width('100%').padding({left:(b.level??0)*24}).alignItems(VerticalAlign.Top)}
   else if(b.kind==='quote'){Column(){this.spans(b.spans,false)}.width('100%').padding({left:12,top:4,bottom:4}).border({width:{left:3},color:LINE})}
   else{this.spans(b.spans,false)}
  },(b:RichBlock,i:number)=>i+'-'+(b.start??0)+'-'+b.kind)
 }.width('100%').alignItems(HorizontalAlign.Start).bindContextMenu(this.copyMenu,ResponseType.LongPress)}
}
