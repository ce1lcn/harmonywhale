import {INK,INK2,INK3,LINE,WHITE,SURFACE} from './Theme';
// 0.8.6 阶段 4（修订）：主界面命令菜单，取代加号弹窗（小窗 CompactChat 仍用 PlusPanel）。
// 顶部三个图标入口：拍照 / 相册 / 文件；分割线下三行列表：目标模式 / 计划模式 / 压缩上下文。
// 输入框开头输入「/」时弹出同一菜单：图标入口隐藏，只按列表行的中文名或英文 key 过滤。
export interface CommandRow {id:string;name:string;key:string;desc:string;enabled:boolean;}
export interface CommandEntry {id:string;label:string;enabled:boolean;}
interface ListDef {id:string;name:string;key:string;desc:string;}
interface EntryDef {id:string;label:string;}
const LIST_DEFS:ListDef[]=[
 {id:'goal',name:'目标模式',key:'goal',desc:'设置长期任务目标'},
 {id:'plan',name:'计划模式',key:'plan',desc:'进入或退出计划模式'},
 {id:'compact',name:'压缩上下文',key:'compact',desc:'压缩以上对话内容'}
];
const ENTRY_DEFS:EntryDef[]=[
 {id:'camera',label:'拍照'},
 {id:'album',label:'相册'},
 {id:'file',label:'文件'}
];
// 列表行：query 为空时全部显示；否则按中文名或英文 key 包含匹配。goalText 非空时目标行说明显示当前目标。
export function commandRows(query:string,running:boolean,goalText:string):CommandRow[]{
 const q:string=query.trim().toLowerCase();
 const out:CommandRow[]=[];
 LIST_DEFS.forEach((d:ListDef)=>{
  if(q&&d.name.indexOf(q)<0&&d.key.indexOf(q)<0)return;
  const desc:string=d.id==='goal'&&goalText?'当前：'+goalText.slice(0,20):d.desc;
  out.push({id:d.id,name:d.name,key:d.key,desc:desc,enabled:!running});
 });
 return out;
}
// 图标入口：过滤状态下隐藏。
export function commandEntries(running:boolean,filtered:boolean):CommandEntry[]{
 if(filtered)return [];
 return ENTRY_DEFS.map((e:EntryDef):CommandEntry=>{return {id:e.id,label:e.label,enabled:!running};});
}
function entryIcon(id:string):Resource{
 if(id==='camera')return $r('sys.symbol.camera');
 if(id==='album')return $r('sys.symbol.ohos_photo');
 return $r('sys.symbol.doc');
}
function rowIcon(id:string):Resource{
 if(id==='goal')return $r('sys.symbol.flag');
 if(id==='plan')return $r('sys.symbol.list_number');
 return $r('sys.symbol.arrow_down_right_and_arrow_up_left');
}
@Component
export struct CommandMenu {
 @Prop rows:CommandRow[]=[];
 @Prop entries:CommandEntry[]=[];
 @Prop menuWidth:number=380;
 onPick:(id:string)=>void=()=>{};
 build(){
  Column(){
   if(this.entries.length>0){
    Row(){
     ForEach(this.entries,(e:CommandEntry)=>{
      Column({space:6}){
       Row(){SymbolGlyph(entryIcon(e.id)).fontSize(22).fontColor([e.enabled?INK2:INK3])}.width(44).height(44).justifyContent(FlexAlign.Center).borderRadius(22).backgroundColor(SURFACE)
       Text(e.label).fontSize(13).fontColor(e.enabled?INK:INK3)
      }.layoutWeight(1).height(72).justifyContent(FlexAlign.Center).onClick(()=>{this.onPick(e.id);})
     },(e:CommandEntry)=>e.id+e.enabled)
    }.width('100%').padding({top:6,bottom:6})
    Divider().color(LINE)
   }
   ForEach(this.rows,(r:CommandRow)=>{
    Row({space:10}){
     SymbolGlyph(rowIcon(r.id)).fontSize(20).fontColor([r.enabled?INK2:INK3])
     Text(r.name).fontSize(15).fontColor(r.enabled?INK:INK3).maxLines(1)
     Text(r.key).fontSize(12).fontColor(INK3).maxLines(1)
     Text(r.desc).fontSize(12).fontColor(INK3).maxLines(1).textOverflow({overflow:TextOverflow.Ellipsis}).layoutWeight(1).textAlign(TextAlign.End)
    }.width('100%').height(44).padding({left:12,right:12}).borderRadius(10).opacity(r.enabled?1:0.6).onClick(()=>{this.onPick(r.id);}).stateStyles({pressed:{backgroundColor:SURFACE}})
   },(r:CommandRow)=>r.id+r.enabled+r.desc)
  }.width(this.menuWidth).padding({left:8,right:8,top:6,bottom:8}).backgroundColor(WHITE).borderRadius(16)
 }
}
