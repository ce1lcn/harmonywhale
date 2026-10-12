import {BLUE,BLUE_SOFT,BLUE_DEEP,INK,INK2,LINE,WHITE,SURFACE} from './Theme';
export interface SettingsGroup {id:string;title:string;}
// 0.8.6 阶段 2：设置分组由 11 个收为 8 个。旧 id 兼容：memory→skills（记忆分段），mcp→tools，connection→about。
export const SETTINGS_GROUPS:SettingsGroup[]=[{id:'general',title:'通用'},{id:'model',title:'模型'},{id:'skills',title:'技能与记忆'},{id:'tools',title:'工具与扩展'},{id:'execution',title:'权限与预算'},{id:'data',title:'文件与数据'},{id:'usage',title:'用量'},{id:'about',title:'连接与关于'}];
export function settingsGroupId(id:string):string{
 if(id==='memory')return 'skills';
 if(id==='mcp')return 'tools';
 if(id==='connection')return 'about';
 return id;
}
// 导航图标只用 sys.symbol.*，每个名字都已在 ets-loader/sysResource.js 的 symbol 段核对。
export function groupIcon(id:string):Resource{
 if(id==='general')return $r('sys.symbol.gearshape');
 if(id==='model')return $r('sys.symbol.cloud');
 if(id==='skills')return $r('sys.symbol.lightbulb');
 if(id==='tools')return $r('sys.symbol.wrench_and_screwdriver');
 if(id==='execution')return $r('sys.symbol.lock_shield');
 if(id==='data')return $r('sys.symbol.externaldrive');
 if(id==='usage')return $r('sys.symbol.gauge_with_dots_needle_33percent');
 return $r('sys.symbol.info_circle');
}
@Component
export struct SettingsShell {
 @Prop group:string='general';@Prop compact:boolean=false;@State detail:boolean=false;
 onSelect:(id:string)=>void=()=>{};
 @BuilderParam content:()=>void;
 @Builder nav(){Column({space:4}){ForEach(SETTINGS_GROUPS,(g:SettingsGroup)=>{Row({space:10}){SymbolGlyph(groupIcon(g.id)).fontSize(18).fontColor([this.group===g.id?BLUE_DEEP:INK2]).renderingStrategy(SymbolRenderingStrategy.SINGLE);Text(g.title).fontSize(15).fontColor(this.group===g.id?BLUE_DEEP:INK2)}.width('100%').height(44).padding({left:12,right:12}).borderRadius(10).backgroundColor(this.group===g.id?BLUE_SOFT:Color.Transparent).onClick(()=>{this.onSelect(g.id);this.detail=true;})},(g:SettingsGroup)=>g.id)}.padding(12).width('100%').alignItems(HorizontalAlign.Start)}
 build(){
  if(this.compact){Column(){if(this.detail){Row(){Text('‹ 设置').fontSize(15).fontColor(BLUE).height(44).onClick(()=>{this.detail=false;});Blank();Text(SETTINGS_GROUPS.find(g=>g.id===this.group)?.title??'设置').fontSize(16).fontColor(INK)}.padding({left:16,right:16}).width('100%');this.content()}else{Scroll(){this.nav()}.width('100%').layoutWeight(1).align(Alignment.Top)}}.width('100%').layoutWeight(1).backgroundColor(WHITE)}else{Row(){Scroll(){this.nav()}.align(Alignment.Top).width(176).height('100%').backgroundColor(SURFACE);Column(){this.content()}.layoutWeight(1).height('100%')}.width('100%').layoutWeight(1).backgroundColor(WHITE)}
 }
}
