import {BLUE,INK,INK2,INK3,LINE,WHITE,SURFACE} from './Theme';
import {Attachment} from '../agent/Types';
// 0.8.6 阶段 1：主界面的＋面板只保留附件三项（showPlan=false，计划开关已移到输入栏工具行）；目标为底部文字链接。
// 小窗（CompactChat）仍使用默认 showPlan=true，保留原来的计划模式开关。
@Component
export struct PlusPanel {
 @Prop planning:boolean=false;
 @Prop showPlan:boolean=true;
 onPhoto:()=>void=()=>{};onAlbum:()=>void=()=>{};onFile:()=>void=()=>{};onPlan:()=>void=()=>{};onGoal:()=>void=()=>{};
 @Builder entry(symbol:Resource,label:string,action:()=>void){Column({space:6}){Row(){Row(){SymbolGlyph(symbol).fontSize(22).fontColor([INK2])}.width(36).height(36).justifyContent(FlexAlign.Center).borderRadius(18).backgroundColor(SURFACE)}.width(44).height(44).justifyContent(FlexAlign.Center);Text(label).fontSize(14).fontColor(INK)}.layoutWeight(1).onClick(action)}
 build(){Column({space:14}){Row(){this.entry($r('sys.symbol.camera'),'拍照',this.onPhoto);this.entry($r('sys.symbol.ohos_photo'),'相册',this.onAlbum);this.entry($r('sys.symbol.doc'),'文件',this.onFile)}.width('100%');Divider().color(LINE);if(this.showPlan){Row(){Text('计划模式').fontSize(14).fontColor(INK).layoutWeight(1);Toggle({type:ToggleType.Switch,isOn:this.planning}).onChange(()=>{this.onPlan();})}.width('100%')}
  Row(){Text('会话目标').fontSize(14).fontColor(INK).layoutWeight(1);Text('设置 ›').fontSize(14).fontColor(BLUE)}.width('100%').height(44).onClick(this.onGoal)}.width(300).padding(16).backgroundColor(WHITE).borderRadius(16)}
}
@Component
export struct AttachmentStrip {
 @Prop items:Attachment[]=[];onRemove:(id:string)=>void=()=>{};
 build(){Scroll(){Row({space:8}){ForEach(this.items,(a:Attachment)=>{Column({space:3}){Stack({alignContent:Alignment.TopEnd}){if(a.kind==='image'){Image('file://'+a.path).width(64).height(64).objectFit(ImageFit.Cover).borderRadius(8)}else{Row(){SymbolGlyph($r('sys.symbol.doc')).fontSize(24).fontColor([INK3])}.width(64).height(64).justifyContent(FlexAlign.Center).backgroundColor(SURFACE).borderRadius(8)}Row(){Row(){SymbolGlyph($r('sys.symbol.xmark')).fontSize(14).fontColor([INK])}.width(36).height(36).justifyContent(FlexAlign.Center).borderRadius(18).backgroundColor(WHITE)}.width(44).height(44).justifyContent(FlexAlign.Center).onClick(()=>{this.onRemove(a.id);})};Text(a.ocr?'已转文字':a.kind==='image'?'图片':a.name).fontSize(11).fontColor(INK3).maxLines(1).width(80)}},(a:Attachment)=>a.id+(a.ocr?'ocr':''))}.padding({left:12,right:12,top:8})}.scrollable(ScrollDirection.Horizontal).width('100%')}
}
