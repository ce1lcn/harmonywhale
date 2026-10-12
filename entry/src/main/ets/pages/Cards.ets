// 0.8.3 时间线卡片：文件卡片（预览 / 另存）、学会与记住卡片（展开 / 撤销）、ask_user 选项卡片。
// 解析函数是纯函数，便于测试；组件只负责展示，回调由页面注入。
import {AskOption} from '../agent/Types';
import {MarkdownView} from './MarkdownView';
import {BLUE,BLUE_SOFT,BLUE_DEEP,INK,INK2,INK3,LINE,WHITE,ORANGE,SURFACE} from './Theme';

export interface FileInfo {fileId:string;name:string;bytes:number;}
export interface LearnInfo {title:string;key:string;}

// 从 file_write 的结果（JSON）取出文件信息；解析失败返回空 fileId，卡片不显示。
export function fileInfo(raw:string):FileInfo {
 try{
  const v=JSON.parse(raw.split('\n自动读回：')[0]) as Record<string,Object>;
  return {fileId:typeof v['fileId']==='string'?(v['fileId'] as string):'',name:typeof v['name']==='string'?(v['name'] as string):'文件',bytes:typeof v['bytes']==='number'?(v['bytes'] as number):0} as FileInfo;
 }catch(e){
  return {fileId:'',name:'文件',bytes:0} as FileInfo;
 }
}

export function sizeText(bytes:number):string{
 if(!(bytes>=0))return '';
 if(bytes<1024)return bytes+' B';
 if(bytes<1024*1024)return (bytes/1024).toFixed(1)+' KB';
 return (bytes/1024/1024).toFixed(2)+' MB';
}

export function extensionBadge(name:string):string{
 const dot=name.lastIndexOf('.');
 return dot>0&&dot<name.length-1?name.substring(dot+1).toUpperCase().substring(0,4):'TXT';
}

export function isMarkdownName(name:string):boolean{const lower=name.toLowerCase();return lower.endsWith('.md')||lower.endsWith('.markdown');}

// 学会 / 记住卡片的标题与可撤销的 key。memory_save 结果里带 “（key: …）”，撤销时据此删除。
export function learnInfo(name:string,args:string,result:string):LearnInfo {
 try{const data=JSON.parse(result) as Record<string,Object>;if(typeof data['undoId']==='string')return {title:'已更新'+(data['kind']==='skill'?'技能：':'记忆：')+String(data['key']),key:String(data['key'])};}catch(e){}
 if(name==='skill_save'){
  let skill='';
  try{const v=JSON.parse(args) as Record<string,Object>;skill=typeof v['name']==='string'?(v['name'] as string):'';}catch(e){skill='';}
  return {title:'学会了新技能：'+skill,key:skill} as LearnInfo;
 }
 const match=/（key: ([^）]+)）/.exec(result);
 let text='';
 try{const v=JSON.parse(args) as Record<string,Object>;text=typeof v['text']==='string'?(v['text'] as string):'';}catch(e){text='';}
 return {title:'记住了：'+text.slice(0,40),key:match?match[1]:''} as LearnInfo;
}

// ask_user 选项的展示文字：推荐项带标记。
export function optionTitle(option:AskOption):string{return (option.recommended?'推荐 · ':'')+option.label;}

// 代码块“存为文件”的扩展名；未知语言按 txt。全部在 file_write 白名单内。
export function codeExtension(language:string):string{
 const lang=(language??'').trim().toLowerCase();
 const table:Record<string,string>={'json':'json','markdown':'md','md':'md','html':'html','xml':'xml','yaml':'yaml','yml':'yaml','csv':'csv','typescript':'ts','ts':'ts','javascript':'js','js':'js','python':'py','py':'py','arkts':'ets','ets':'ets','css':'css','sql':'sql','shell':'sh','bash':'sh','sh':'sh','java':'java','kotlin':'kt','go':'go','rust':'rs','c':'c','cpp':'cpp','swift':'swift','log':'log'};
 const hit=table[lang];
 return hit?hit:'txt';
}

@Component
export struct FileCard {
 @Prop fileId:string='';@Prop name:string='';@Prop bytes:number=0;@Prop fontScale:number=1;
 @State opened:boolean=false;@State preview:string='';@State failed:string='';@State deleted:boolean=false;
 onPreview:(fileId:string)=>string=()=>'';
 onSave:(fileId:string)=>void=()=>{};
 // 0.8.4 A3：删除前的确认由页面完成，返回 true 表示已删除。
 onDelete:(fileId:string)=>Promise<boolean>=async()=>false;
 toggle():void{
  this.opened=!this.opened;
  if(this.opened&&this.preview===''&&this.failed===''){
   try{this.preview=this.onPreview(this.fileId);}catch(e){this.failed=(e as Error).message;}
  }
 }
 build(){
  Column({space:8}){
   Row({space:10}){
    Text(extensionBadge(this.name)).fontSize(11*this.fontScale).fontColor(BLUE_DEEP).backgroundColor(BLUE_SOFT).borderRadius(6).padding({left:6,right:6,top:4,bottom:4})
    Column({space:2}){
     Text(this.name).fontSize(15*this.fontScale).fontColor(INK).maxLines(1).textOverflow({overflow:TextOverflow.Ellipsis}).width('100%')
     Text(sizeText(this.bytes)+' · 已保存在本会话').fontSize(12*this.fontScale).fontColor(INK3)
    }.layoutWeight(1).alignItems(HorizontalAlign.Start)
    if(this.deleted){Text('已删除').fontSize(13*this.fontScale).fontColor(INK3)}
    else{
     // 0.8.6 阶段 3：外层 44 高、左右各 10 的点击区，文字大小不变。
     Row(){Text(this.opened?'收起':'预览').fontSize(14*this.fontScale).fontColor(BLUE)}.height(44).padding({left:10,right:10}).justifyContent(FlexAlign.Center).onClick(()=>{this.toggle();})
     Row(){Text('删除').fontSize(14*this.fontScale).fontColor(ORANGE)}.height(44).padding({left:10,right:10}).justifyContent(FlexAlign.Center).onClick(()=>{this.onDelete(this.fileId).then((ok:boolean)=>{if(ok){this.deleted=true;this.opened=false;}}).catch(()=>{});})
    }
   }.width('100%').onClick(()=>{if(!this.deleted)this.toggle();})
   if(this.opened&&!this.deleted){
    if(this.failed!==''){
     Text('预览失败：'+this.failed).fontSize(13*this.fontScale).fontColor(ORANGE).width('100%')
    }else if(isMarkdownName(this.name)){
     MarkdownView({text:this.preview,fontScale:this.fontScale*0.9})
    }else{
     Scroll(){Text(this.preview).fontFamily('monospace').fontSize(13*this.fontScale).fontColor(INK2).width('100%').copyOption(CopyOptions.LocalDevice)}.constraintSize({maxHeight:360}).width('100%').scrollable(ScrollDirection.Vertical)
    }
    Row({space:14}){
     Row(){Text('另存为').fontSize(14*this.fontScale).fontColor(BLUE)}.height(44).padding({left:10,right:10}).justifyContent(FlexAlign.Center).onClick(()=>{this.onSave(this.fileId);})
    }.width('100%').justifyContent(FlexAlign.End)
   }
  }.width('100%').padding(12).borderRadius(12).backgroundColor(SURFACE).border({width:1,color:LINE}).alignItems(HorizontalAlign.Start)
 }
}

@Component
export struct LearnCard {
 @Prop title:string='';@Prop detail:string='';@Prop fontScale:number=1;
 @State opened:boolean=false;@State note:string='';
 onUndo:()=>string=()=>'';
 build(){
  Column({space:6}){
   Row({space:8}){
    Text(this.title).fontSize(14*this.fontScale).fontColor(INK).layoutWeight(1).maxLines(1).textOverflow({overflow:TextOverflow.Ellipsis})
    Row(){Text(this.opened?'收起':'展开').fontSize(13*this.fontScale).fontColor(BLUE)}.height(44).padding({left:10,right:10}).justifyContent(FlexAlign.Center).onClick(()=>{this.opened=!this.opened;})
   }.width('100%')
   if(this.opened){
    Text(this.detail).fontSize(13*this.fontScale).fontColor(INK2).width('100%').copyOption(CopyOptions.LocalDevice)
    Row({space:14}){
     if(this.note!==''){Text(this.note).fontSize(13*this.fontScale).fontColor(INK3)}
     Row(){Text('撤销').fontSize(13*this.fontScale).fontColor(ORANGE)}.height(44).padding({left:10,right:10}).justifyContent(FlexAlign.Center).onClick(()=>{this.note=this.onUndo();})
    }.width('100%').justifyContent(FlexAlign.End)
   }
  }.width('100%').padding(12).borderRadius(12).backgroundColor(WHITE).border({width:1,color:LINE}).alignItems(HorizontalAlign.Start)
 }
}

@Component
export struct AskCard {
 @Prop question:string='';@Prop options:AskOption[]=[];@Prop fontScale:number=1;
 onPick:(label:string)=>void=()=>{};
 build(){
  Column({space:8}){
   Text('大肥鱼想确认一件事').fontSize(13*this.fontScale).fontColor(BLUE)
   Text(this.question).fontSize(16*this.fontScale).fontColor(INK).width('100%')
   ForEach(this.options,(o:AskOption)=>{
    Column({space:2}){
     Text(optionTitle(o)).fontSize(15*this.fontScale).fontColor(o.recommended?BLUE:INK).width('100%')
     if(o.impact){Text(o.impact).fontSize(12*this.fontScale).fontColor(INK3).width('100%')}
    }
    .width('100%').padding(12).borderRadius(10).border({width:1,color:o.recommended?BLUE:LINE}).alignItems(HorizontalAlign.Start)
    .onClick(()=>{this.onPick(o.label);})
   },(o:AskOption)=>o.label)
   Text('也可以直接在输入框里回答').fontSize(12*this.fontScale).fontColor(INK3)
  }.width('100%').padding(14).borderRadius(14).backgroundColor(SURFACE).border({width:1,color:LINE}).alignItems(HorizontalAlign.Start)
 }
}
