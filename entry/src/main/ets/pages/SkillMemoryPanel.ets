// 0.8.3 设置页“技能”与“记忆”分组的列表。操作全部通过页面注入的回调进入 Engine，这里不直接改状态。
// 0.8.6 阶段 2：技能项改为「名称 + 来源标签 + 启用开关」，点开显示内容与版本；删除与回滚放在展开区。
import {Skill,SkillVersion,Memory} from '../agent/Types';
import {BLUE,BLUE_SOFT,BLUE_DEEP,INK,INK2,INK3,LINE,WHITE,ORANGE,ORANGE_SOFT,RED,SURFACE} from './Theme';

export function originText(skill:Skill):string{return skill.origin==='self'?'大肥鱼写的':'导入';}

export function skillStateText(skill:Skill):string{
 const parts:string[]=[originText(skill),'v'+(skill.version??1)];
 if(skill.external)parts.push('含外部来源');
 parts.push(skill.enabled?'已启用':'已停用');
 return parts.join(' · ');
}

// 0.8.6：列表里的来源标签（自写 / 导入 / 外部）。
export function sourceTag(skill:Skill):string{return skill.external?'外部':(skill.origin==='self'?'自写':'导入');}
// 0.8.6：列表项第三行，版本与启用状态；外部来源保留“含外部来源”提示（停用时橙色）。
export function metaText(skill:Skill):string{
 const parts:string[]=['v'+(skill.version??1)];
 if(skill.external)parts.push('含外部来源');
 parts.push(skill.enabled?'已启用':'已停用');
 return parts.join(' · ');
}

// 0.8.3.4：按字段复制技能（ArkTS 不允许对象展开），用于让列表在状态变化后重新渲染。
export function copySkill(x:Skill):Skill{
 return {id:x.id,name:x.name,description:x.description,body:x.body,enabled:x.enabled,references:x.references,folder:x.folder,scripts:x.scripts,whenToUse:x.whenToUse,origin:x.origin,version:x.version,history:x.history,external:x.external,saved:x.saved} as Skill;
}
// 历史版本从新到旧排列，便于回滚时先看到最近的版本。
export function historyNewestFirst(skill:Skill):SkillVersion[]{return (skill.history??[]).slice().reverse();}

@Component
export struct SkillList {
 // 0.8.3.7：普通成员只在创建时赋值一次，ForEach 不依赖 rev，所以之前改 rev 列表也不刷新。
 // 改为 @State 列表，rev 变化时从 source() 重新取一份新数组赋值，触发 ForEach 重新渲染。
 @Prop @Watch('reload') rev:number=0;@State items:Skill[]=[];@State expandedId:string='';source:()=>Skill[]=()=>[];fontScale:number=1;
 aboutToAppear():void{this.reload();}
 reload():void{this.items=this.source().map((x:Skill):Skill=>copySkill(x));}
 onToggle:(name:string,enabled:boolean)=>void=()=>{};
 onDelete:(name:string)=>void=()=>{};
 onRollback:(name:string,version:number)=>void=()=>{};
 onView:(body:string)=>void=()=>{};
 @Builder pill(label:string,primary:boolean,action:()=>void){
  Text(label).fontSize(13*this.fontScale).fontColor(BLUE_DEEP).backgroundColor(BLUE_SOFT).borderRadius(16).padding({left:12,right:12}).height(34).textAlign(TextAlign.Center).onClick(()=>{action();})
 }
 build(){
  Column({space:10}){
  if(this.items.length===0){Text('还没有 Skill。大肥鱼摸索成功的流程会自动学会，也可以在上方导入。').fontSize(13*this.fontScale).fontColor(INK3).width('100%')}
  ForEach(this.items,(s:Skill)=>{
   Column({space:8}){
    Row({space:10}){
     Column({space:4}){
      Row({space:8}){
       Text(s.name).fontSize(15*this.fontScale).fontColor(INK).maxLines(1).textOverflow({overflow:TextOverflow.Ellipsis}).layoutWeight(1)
       Text(sourceTag(s)).fontSize(11*this.fontScale).fontColor(s.external?ORANGE:BLUE_DEEP).padding({left:6,right:6,top:2,bottom:2}).borderRadius(6).backgroundColor(s.external?ORANGE_SOFT:BLUE_SOFT)
      }.width('100%')
      Text(s.description).fontSize(12*this.fontScale).fontColor(INK2).maxLines(1).textOverflow({overflow:TextOverflow.Ellipsis}).width('100%')
      Text(metaText(s)).fontSize(12*this.fontScale).fontColor(s.external&&!s.enabled?ORANGE:INK3).width('100%')
     }.layoutWeight(1).alignItems(HorizontalAlign.Start).onClick(()=>{this.expandedId=this.expandedId===s.id?'':s.id;})
     Toggle({type:ToggleType.Switch,isOn:s.enabled}).selectedColor(BLUE).onChange((v:boolean)=>{this.onToggle(s.name,v);})
    }.width('100%')
    if(this.expandedId===s.id){
     Column({space:8}){
      if(s.whenToUse){Text('适用：'+s.whenToUse).fontSize(12*this.fontScale).fontColor(INK2).width('100%')}
      Text(s.body).fontSize(13*this.fontScale).fontColor(INK).width('100%').padding(10).borderRadius(8).backgroundColor(SURFACE).maxLines(8).textOverflow({overflow:TextOverflow.Ellipsis})
      Row({space:8}){
       this.pill('查看全文',false,()=>{this.onView(s.body);})
      }.width('100%').justifyContent(FlexAlign.Start)
      if(s.origin==='self'&&(s.history??[]).length>0){
       Text('历史版本（可回滚）').fontSize(12*this.fontScale).fontColor(INK3).width('100%')
       Row({space:8}){
        ForEach(historyNewestFirst(s),(v:SkillVersion)=>{
         this.pill('回到 v'+v.version,false,()=>{this.onRollback(s.name,v.version);})
        },(v:SkillVersion)=>String(v.version))
       }.width('100%').justifyContent(FlexAlign.Start)
      }
      Row(){
       Blank()
       Text('删除').fontSize(13*this.fontScale).fontColor(RED).height(44).padding({left:12,right:4}).textAlign(TextAlign.Center).onClick(()=>{this.onDelete(s.name);})
      }.width('100%')
     }.width('100%').alignItems(HorizontalAlign.Start)
    }
   }.width('100%').padding(12).borderRadius(10).border({width:1,color:LINE}).alignItems(HorizontalAlign.Start)
  },(s:Skill)=>s.id+s.enabled+(s.version??1)+this.fontScale)
  }.width('100%').alignItems(HorizontalAlign.Start)
 }
}

@Component
export struct MemoryList {
 @Prop @Watch('reload') rev:number=0;@State items:Memory[]=[];source:()=>Memory[]=()=>[];fontScale:number=1;
 onDelete:(key:string)=>void=()=>{};
 aboutToAppear():void{this.reload();}
 reload():void{this.items=this.source().slice();}
 build(){
  Column({space:10}){
  if(this.items.length===0){Text('还没有记忆。对大肥鱼说“记住…”即可保存，之后的新会话也会生效。').fontSize(13*this.fontScale).fontColor(INK3).width('100%')}
  ForEach(this.items,(m:Memory)=>{
   Row({space:10}){
    Text(m.text).fontSize(14*this.fontScale).fontColor(INK).layoutWeight(1).maxLines(3).textOverflow({overflow:TextOverflow.Ellipsis})
    Text('删除').fontSize(13*this.fontScale).fontColor(RED).height(44).textAlign(TextAlign.Center).onClick(()=>{this.onDelete(m.key);})
   }.width('100%').padding(12).borderRadius(10).border({width:1,color:LINE})
  },(m:Memory)=>m.id)
  if(this.items.length>0){
   Text('共 '+this.items.length+' 条，总长 '+this.items.reduce((n:number,m:Memory)=>n+m.text.length,0)+' / 2000 字').fontSize(12*this.fontScale).fontColor(INK3).width('100%')
  }
  }.width('100%').alignItems(HorizontalAlign.Start)
 }
}
