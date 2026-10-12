import {PdfSurface} from './PdfSurface';
import {inputMethod} from '@kit.IMEKit';
import {FileAsset as importFileAsset} from '../agent/Types';
import {KeyCode} from '@kit.InputKit';
import {Attachments} from '../agent/Attachments';
import {Attachment} from '../agent/Types';
import {AttachmentStrip} from './PlusPanel';
import {CommandMenu,commandRows,commandEntries} from './CommandMenu';
import {SettingsShell,settingsGroupId} from './SettingsShell';
import {MarkdownView} from './MarkdownView';
import {FileCard,LearnCard,AskCard,fileInfo,learnInfo,codeExtension} from './Cards';
import {SkillList,MemoryList} from './SkillMemoryPanel';
import {TodoBar} from './TodoBar';
import {hitText} from '../agent/Compaction';
import {copyTodos} from '../agent/Todo';
import {AskUser} from '../agent/Types';
import {Memory} from '../agent/Types';
import {plainText} from '../agent/Markdown';
import {APP_VERSION} from '../agent/BuildSecrets';
import {FixtureBridge} from './FixtureBridge';
import {readOnlyProbe} from '../agent/ReadOnlyProbe';
import {WebSource} from '../agent/WebTools';
import {ApprovalDialog} from './ApprovalDialog';
import {isResume,tokenLimit,effortOf,DEFAULT_TOKEN_BUDGET,DEFAULT_OUTPUT_TOKENS,MAX_OUTPUT_TOKENS} from '../agent/ExecutionPolicy';
import {StatusBar,StatusView} from './StatusBar';
import {sessionStats} from '../agent/Stats';
import {CompactChat} from './CompactChat';
import {CompactRow} from '../agent/CompactTimeline';
import {FloatWindow} from './FloatWindow';
import {Notifier} from './Notifier';
import {isCompactWidth,normalizeStrategy,strategyLabel,FLOAT_STRATEGIES} from '../agent/FloatPolicy';
import {router} from '@kit.ArkUI';
import {KeyboardAvoidMode} from '@kit.ArkUI';
import {common} from '@kit.AbilityKit';
import {pasteboard} from '@kit.BasicServicesKit';
import {picker,fileIo as fs} from '@kit.CoreFileKit';
import {Store} from '../agent/Store';
import {computeStats,heatWeeks,weekBars,formatCn,formatSpan,HeatWeek,HeatCell,BarItem} from '../agent/Ledger';
import {Engine} from '../agent/Engine';
import {branchFiles} from '../agent/Branch';
import {togglePicked,toggleGroup,bulkPlan,confirmTitle,confirmMessage,afterDelete} from '../agent/SessionBulk';
import {Device} from '../agent/Device';
import {HdcClient} from './HdcClient';
import {newSession,uid,Profile,Session,Task,ToolRecord,Skill,McpServer,Definition,ChatEntry,Favorite,Usage,DayUsage,ContextStats,PlanStep as importPlanStep} from '../agent/Types';
import {BLUE,BLUE_SOFT,BLUE_LINE,BLUE_DEEP,INK,INK2,INK3,LINE,WHITE,SIDEBAR,SURFACE,SELECTED,GREEN,ORANGE,ORANGE_SOFT,RED,GOLD,HEAT,CHAT_WIDTH,SIDEBAR_WIDTH} from './Theme';
import {TimelineItem,RichBlock,RichSpan,SessionGroup,buildTimeline,groupSessions,parseRich,statusLabel,toolItem,taskStart,formatTokens,groupDigits,formatClock} from './Timeline';
interface StatCell {value:string;label:string;}
interface ModeOpt {key:string;label:string;}
interface MonthLabel {text:string;x:number;}
interface BarView {label:string;total:number;h:number;}
interface UsageRowP {label:string;value:string;}
interface MenuRowP {res:Resource;label:string;color:string;last:boolean;}
interface IconP {res:Resource;size:number;color:string;}
interface DotP {color:string;}
interface IconBtnP {res:Resource;active:boolean;action:()=>void;}
interface PillP {label:string;primary:boolean;enabled:boolean;action:()=>void;grow?:boolean;}
interface ChipP {res:Resource;label:string;fg:string;bg:string;action:()=>void;}
interface NavTileP {res:Resource;label:string;active:boolean;action:()=>void;}
interface FoldP {label:string;open:boolean;action:()=>void;}
// 0.8.6 阶段 4：模型胶囊就地气泡的一行（返回 / 选项 / 导航）。
interface MenuLineP {label:string;value:string;checked:boolean;arrow:boolean;back:boolean;action:()=>void;}
interface EffortChoice {key:string;label:string;}
const EFFORT_CHOICES:EffortChoice[]=[{key:'off',label:'Off'},{key:'low',label:'Low'},{key:'high',label:'High'},{key:'max',label:'Max'}];
// 推理等级的显示名：取自 effortOf(profile)，'off' 表示思考未开启。
function effortLabel(key:string):string{if(key==='off')return 'Off';if(key==='low')return 'Low';if(key==='max')return 'Max';return 'High';}
const VERSION:string=APP_VERSION;
const APP_NAME:string='HarmonyWhale';
const USER_NAME:string='cell';
// 0.8.6 阶段 1：空会话的起手胶囊，点击只填入输入框，不自动发送。
const STARTERS:string[]=['读一个文件并总结','帮我做一份 PPT','打开计算器算 123×45','记住：我习惯用简洁的回答'];
@Entry
@Component
struct Index {
 @State revision:number=0;
 @State skillRev:number=0;
 @State panel:string='chat';
 @State taskMode:string='auto';
 @State goalText:string='';
 @State goalCriteria:string='';
 @State goalConstraints:string='';
 @State outputTokens:string='';
 @State effort:string='high';
 @State importingOffice:boolean=false;
 @State input:string='';
 @State attachments:Attachment[]=[];
 @State plusOpen:boolean=false;
 // 0.8.6 阶段 4：「/目标」模式、「/」命令过滤、模型胶囊就地菜单的状态。
 @State composerGoal:boolean=false;
 @State slashMode:boolean=false;
 @State slashQuery:string='';
 @State modelMenuOpen:boolean=false;
 @State modelMenuPage:string='root';
 @State settingsGroup:string='general';
 @State skillTab:string='skills';
 @State advGeneral:boolean=false;
 @State advModel:boolean=false;
 @State devAbout:boolean=false;
 @State protocol:string='chat-completions';
 @State ready:boolean=false;
 @State @Watch('onMessage') message:string='';
 @State detail:string='';
 @State sidebarOpen:boolean=true;
 @State openRecords:string[]=[];
 @State folded:string[]=[];
 @State usageOpen:string='';
 @State statsMode:string='day';
 @State renaming:string='';
 @State renameText:string='';
 @State selectMode:boolean=false;
 @State picked:string[]=[];
 @State query:string='';
 @State fontScale:number=1;
 @State profileId:string='deepseek';
 @State title:string='DeepSeek';
 @State baseUrl:string='https://api.deepseek.com';
 @State model:string='deepseek-flash';
 @State apiKey:string='';
 @State keyConfigured:boolean=false;
 @State vision:boolean=true;
 @State tools:boolean=true;
 @State contextWindow:string='1000000';
 @State thinking:boolean=true;
 @State serverTitle:string='';
 @State serverUrl:string='';
 @State token:string='';
 @StorageProp('topInset') topInset:number=0;
 @StorageProp('bottomInset') bottomInset:number=0;
 // 0.8.1 小窗：窗口宽度（vp，来自 windowSizeChange）、V1 截图瞬间透明用的根组件不透明度。
 @StorageProp('winWidthVp') @Watch('onWidth') winWidthVp:number=0;
 @StorageProp('floatOpacity') floatOpacity:number=1;
 @State areaWidth:number=0;
 notifier:Notifier|null=null;
 onWidth():void{this.syncApproval();}
 compact():boolean{return isCompactWidth(this.winWidthVp>0?this.winWidthVp:this.areaWidth);}
 async enterFloat():Promise<void>{const error=await FloatWindow.enterFloating();this.message=error?'没能自动切成小窗（'+error+'）。请从屏幕侧边栏把大肥鱼拖出来，变成悬浮窗；窗口变窄后会自动切换到紧凑布局。':(FloatWindow.floating()?'已是小窗':'已请求切换到小窗');}
 sendText(text:string):void{this.input=text;this.follow=true;this.send();}
 chatScroll:Scroller=new Scroller();
 follow:boolean=true;messageTimer:number=0;
 store:Store|null=null;engine:Engine|null=null;connectionEvents:string[]=[];
 hdc:HdcClient=new HdcClient((s:string)=>{this.recordConnection(s);},(r:boolean,c:boolean)=>{this.ready=r;});
 onMessage():void{if(this.messageTimer)clearTimeout(this.messageTimer);this.messageTimer=0;if(this.message)this.messageTimer=setTimeout(()=>{this.message='';},9000);}
 scrollToEnd():void{setTimeout(()=>{try{this.chatScroll.scrollEdge(Edge.Bottom);}catch(e){}},60);}
 recordConnection(text:string):void{this.connectionEvents.push(new Date().toISOString()+' '+text);this.connectionEvents=this.connectionEvents.slice(-128);this.detail=this.connectionEvents.slice(-6).join('\n');try{this.store?.write(this.store.root+'/connection-events.json',JSON.stringify(this.connectionEvents));}catch(e){}}
 approvalDialog:CustomDialogController|null=null;
 // 紧凑模式下确认卡片内嵌在小窗里（CompactChat），不弹全屏对话框。
 syncApproval():void{if(this.approvalDialog&&this.compact()){this.approvalDialog.close();this.approvalDialog=null;return;}if(this.engine?.approval&&!this.approvalDialog&&!this.compact()){this.approvalDialog=new CustomDialogController({builder:ApprovalDialog({text:this.engine.approval,scope:this.engine.approvalScope,cancelTask:()=>{this.approvalDialog=null;this.engine?.pause('用户取消',true);},remember:(v:boolean)=>{if(this.engine)this.engine.approvalRemember=v;},decide:(v:boolean)=>{this.approvalDialog=null;this.engine?.approve(v);}}),autoCancel:false,customStyle:true});this.approvalDialog.open();}else if(!this.engine?.approval&&this.approvalDialog){this.approvalDialog.close();this.approvalDialog=null;}}
 aboutToAppear():void{const context=this.getUIContext().getHostContext() as common.UIAbilityContext;try{this.getUIContext().setKeyboardAvoidMode(KeyboardAvoidMode.RESIZE);}catch(e){}this.store=new Store(context.filesDir);try{this.connectionEvents=JSON.parse(this.store.read(context.filesDir+'/connection-events.json')) as string[];}catch(e){}try{this.engine=new Engine(this.store.load(),this.store,new Device(this.hdc,this.store),()=>{this.revision++;this.syncApproval();if(this.follow)this.scrollToEnd();});this.engine.device.overlay=new FloatWindow();FloatWindow.strategy=()=>normalizeStrategy(this.engine?.state.floatStrategy);this.notifier=new Notifier(context);this.engine.notifier=this.notifier;FixtureBridge.run=(goal:string)=>{this.engine?.start(goal).catch((e:Error)=>{this.message=e.message;});};FixtureBridge.sample=async(phase:string,active:()=>boolean):Promise<string>=>{const e=this.engine;if(!e||e.running||e.compacting)throw new Error('请先结束当前任务');if(!this.hdc.ready)throw new Error('请先连接本机HDC');const report=await readOnlyProbe(phase,(cmd:string,timeout:number):Promise<string>=>this.hdc.execute(cmd,timeout),active);this.store!.write(this.store!.root+'/readonly-0850-'+phase+'.json',JSON.stringify(report));return '只读对照完成：'+report.samples.filter(v=>v.ok).length+'/'+report.samples.length+'次读取成功';};this.fontScale=Math.min(1.15,Math.max(0.8,this.engine.state.fontScale??1));this.pruneEmpty(this.engine.state.selected);this.loadProfile(this.engine.state.activeProfile);this.engine.refreshMcp().catch(()=>{this.message='部分 MCP 连接失败，可在扩展设置重试';});}catch(e){this.message='加载失败：'+(e as Error).message;}}
 loadProfile(id:string):void{const p=this.engine?.state.profiles.find(p=>p.id===id);if(!p)return;this.profileId=p.id;this.protocol=p.protocol??'chat-completions';this.title=p.title;this.baseUrl=p.baseUrl;this.model=p.model;this.vision=p.vision;this.tools=p.tools;this.contextWindow=p.contextWindow.toString();this.outputTokens=p.outputTokens?p.outputTokens.toString():'';this.thinking=p.thinking==='enabled';this.effort=p.effort==='low'||p.effort==='max'?p.effort:'high';this.apiKey='';this.keyConfigured=false;this.store?.secret('model-'+id).then(value=>{if(this.profileId===id)this.keyConfigured=!!value;}).catch(()=>{this.message='无法读取密钥，请运行存储自检';});}
 async saveProfile():Promise<void>{if(!this.engine||!this.store)return;try{const out=this.outputTokens.trim();if(out&&(!Number.isInteger(Number(out))||Number(out)<256||Number(out)>MAX_OUTPUT_TOKENS||Number(out)>Number(this.contextWindow)-2048))throw new Error('单次输出上限须为256～393216且低于上下文窗口，或留空自动');if(!/^https:\/\//.test(this.baseUrl)||!this.model.trim()||!Number.isFinite(Number(this.contextWindow))||Number(this.contextWindow)<8192)throw new Error('请填写 HTTPS 地址、模型名和至少 8192 的上下文窗口');const p:Profile={protocol:this.protocol,id:this.profileId,title:this.title,baseUrl:this.baseUrl.trim(),model:this.model.trim(),vision:this.vision,tools:this.tools,contextWindow:Number(this.contextWindow),outputTokens:out?Number(out):undefined,thinking:this.thinking?'enabled':'disabled',effort:this.thinking?this.effort:undefined};const index=this.engine.state.profiles.findIndex(v=>v.id===p.id);if(index>=0)this.engine.state.profiles[index]=p;else this.engine.state.profiles.push(p);if(this.apiKey)await this.store.secret('model-'+p.id,this.apiKey);this.apiKey='';this.engine.state.activeProfile=p.id;this.engine.save();this.keyConfigured=!!(await this.store.secret('model-'+p.id));this.message='模型配置已保存；密钥'+(this.keyConfigured?'已加密存储':'尚未配置');}catch(e){this.message=(e as Error).message;}}
 async send():Promise<void>{if(!this.engine||(!this.input.trim()&&!this.attachments.length)||this.importingOffice||this.engine.compacting)return;if(this.pendingAsk()&&!this.engine.running&&this.input.trim()&&this.attachments.length===0){const typed=this.input.trim();this.input='';this.answer(typed);return;}
if(this.composerGoal){if(this.engine.running){this.message='任务运行中，先暂停再设置目标';return;}try{this.engine.setGoal(this.input,[],[]);}catch(e){this.message=(e as Error).message;return;}}
 const text=this.input.trim()||'请查看附件';const attached=this.attachments.slice();this.getUIContext().getFocusController().clearFocus();inputMethod.getController().hideTextInput().catch(()=>{});this.plusOpen=false;if(!this.profiles().find(p=>p.id===this.engine!.state.activeProfile)?.vision){try{const service=new Attachments(this.store!.root);this.attachments=await Promise.all(attached.map(a=>service.ocr(a)));attached.splice(0,attached.length,...this.attachments);}catch(e){this.message='图片转文字失败，附件保留：'+(e as Error).message;return;}}this.input='';this.attachments=[];this.slashMode=false;this.slashQuery='';this.notifier?.ensureEnabled();if(this.engine.running){if(attached.length){this.input=text;this.attachments=attached;this.message='请暂停当前任务后发送附件';return;}this.engine.supplement(text);return;}if(!attached.length&&this.cur()?.status==='paused'&&isResume(text)){this.engine.supplement(text);await this.engine.start();return;}this.composerGoal=false;await this.engine.start(text,'auto',attached);}
 // 0.8.3：提问卡片、文件卡片、学会/记住卡片、代码块存为文件的页面入口。
 pendingAsk():AskUser|undefined{const t=this.cur();return t&&t.status==='paused'?t.askUser:undefined;}
 skillAction(action:()=>void):void{try{action();this.skillRev++;this.message='已更新';}catch(e){this.message=(e as Error).message;}}
 answer(text:string):void{const e=this.eng();if(!e)return;e.answerAsk(text).catch((err:Error)=>{this.message=err.message;});}
 compactLine():string{const c=this.eng()?.session().context;if(!c)return '';return (c.method==='replay'?'回放前缀压缩':'旧方式压缩（0.8.3）')+' · '+hitText(c.usage);}
 clearTodos():void{const e=this.eng();if(!e||e.running)return;e.session().todos=[];e.save();}
 previewFile(id:string):string{const e=this.eng();if(!e)return '';return e.files.previewText(e.session(),id);}
 undoLearn(it:TimelineItem):string{return this.undoManagement(it.name,it.args,it.result);}
 undoManagement(name:string,args:string,result:string):string{const e=this.eng();if(!e||e.running)return '运行中不能撤销';const info=learnInfo(name,args,result);try{const data=JSON.parse(result) as Record<string,Object>;if(typeof data['undoId']==='string')return e.managementUndo(data['undoId'] as string);if(name==='skill_save'){return e.skillUndo(info.key);}e.memoryDelete(info.key);return '已忘记';}catch(err){return (err as Error).message;}}
 saveCodeAsFile(text:string,language:string):void{const e=this.eng();if(!e||e.running){this.message='运行中不能保存文件，请稍后再试';return;}const now=new Date();const two=(n:number):string=>n<10?'0'+String(n):String(n);const name='代码-'+two(now.getHours())+two(now.getMinutes())+two(now.getSeconds())+'.'+codeExtension(language);e.files.writeText(e.session(),name,text).then((r:string)=>{e.save();this.message='已保存为 '+name+'，可在“数据与隐私”里另存';}).catch((err:Error)=>{this.message=err.message;});}
 async importOffice():Promise<void>{if(!this.engine||this.engine.running||this.importingOffice)return;const session=this.engine.session();this.importingOffice=true;try{const asset=await this.engine.files.import(this.getUIContext().getHostContext() as common.UIAbilityContext,session);if(asset){if(this.engine.session().id===session.id)this.attachments=this.attachments.concat({id:asset.id,name:asset.name,kind:'file',path:asset.path});this.taskMode='auto';this.engine.save();this.message='已导入 '+asset.name+'，原件保留';}}catch(e){this.message=(e as Error).message;}finally{this.importingOffice=false;}}
 // 0.8.4 A3：删除会话文件，先确认；只删本应用沙箱里的会话文件。
 async deleteFile(id:string,name:string):Promise<boolean>{const e=this.eng();if(!e)return false;if(e.running||e.compacting){this.message='运行中不能删除文件，请先暂停或等任务结束';return false;}const r=await this.getUIContext().getPromptAction().showDialog({title:'删除文件',message:'「'+name+'」将从本会话和应用沙箱中删除，无法恢复。',buttons:[{text:'取消',color:INK2},{text:'删除',color:RED}]});if(r.index!==1)return false;try{this.message=e.fileDelete(id);return true;}catch(err){this.message=(err as Error).message;return false;}}
 async exportOffice(id:string):Promise<void>{if(!this.engine)return;try{await this.engine.files.export(this.getUIContext().getHostContext() as common.UIAbilityContext,this.engine.session(),id);this.message='另存操作已结束';}catch(e){this.message=(e as Error).message;}}
 async importSkill():Promise<void>{if(!this.engine)return;try{const s=await this.engine.skills.import(this.getUIContext().getHostContext() as common.UIAbilityContext);if(this.engine.state.skills.some(v=>v.name===s.name)){this.engine.skills.remove(s);throw new Error('已存在同名 Skill，请先移除原条目');}this.engine.state.skills.push(s);this.engine.save();this.message='已导入 '+s.name;}catch(e){this.message=(e as Error).message;}}
 async addServer():Promise<void>{if(!this.engine||!this.store)return;try{if(!/^https:\/\//.test(this.serverUrl))throw new Error('MCP 地址需要 HTTPS');const id=uid();await this.store.secret('mcp-'+id,this.token);this.token='';this.engine.state.servers.push({id:id,title:this.serverTitle||'远程 MCP',url:this.serverUrl.trim(),enabled:true});this.engine.save();await this.engine.refreshMcp();this.message='MCP 工具已连接';this.serverTitle='';this.serverUrl='';}catch(e){this.message=(e as Error).message;}}
 async checkVault():Promise<void>{try{await this.store!.secret('selftest','加密自检✓');const value=await this.store!.secret('selftest');await this.store!.secret('selftest','');this.message=value==='加密自检✓'?'HUKS 加密、解密自检通过':'HUKS 自检失败';}catch(e){this.message='HUKS 自检失败：'+(e as Error).message;}}
 async exportExample():Promise<void>{try{const selected=await new picker.DocumentViewPicker(this.getUIContext().getHostContext() as common.UIAbilityContext).save({newFileNames:['SKILL.md']});if(!selected.length)return;const f=fs.openSync(selected[0],fs.OpenMode.READ_WRITE|fs.OpenMode.TRUNC);try{fs.writeSync(f.fd,'---\nname: 简洁验收\ndescription: 只读任务的简洁输出指导\n---\n完成只读任务时，用中文回复，以“验收结果：”开头。只陈述实际观察，不执行额外操作。\n');}finally{fs.closeSync(f.fd);}this.message='示例 Skill 已保存，可使用系统文件选择器导入';}catch(e){this.message='示例保存失败';}}
 async exportChat():Promise<void>{try{const selected=await new picker.DocumentViewPicker(this.getUIContext().getHostContext() as common.UIAbilityContext).save({newFileNames:['agent-session.json']});if(!selected.length)return;const f=fs.openSync(selected[0],fs.OpenMode.READ_WRITE|fs.OpenMode.TRUNC);try{fs.writeSync(f.fd,JSON.stringify(this.engine!.session()));}finally{fs.closeSync(f.fd);}this.message='会话已导出，不包含模型配置和密钥';}catch(e){this.message='导出失败';}}

 // ───────── 状态读取：每次读取 revision，保证 Engine 变化后界面刷新 ─────────
 eng():Engine|null{return this.revision>=0?this.engine:null;}
 isRunning():boolean{return !!(this.eng()?.running||this.eng()?.compacting);}
 cur():Task|null{return this.eng()?.current??null;}
 curStatus():string{return this.cur()?.status??'';}
 timeline():TimelineItem[]{const e=this.eng();return e?buildTimeline(e.session(),this.folded):[];}
 traceTasks():Task[]{const e=this.eng();return e?e.session().tasks.slice().reverse():[];}
 sessionGroups():SessionGroup[]{const e=this.eng();return e?groupSessions(e.state.sessions,this.query):[];}
 profiles():Profile[]{return this.eng()?.state.profiles??[];}
 fs(n:number):number{return Math.round(n*this.fontScale*2)/2;}
 isOpen(id:string):boolean{return this.openRecords.indexOf(id)>=0;}
 toggleRecord(id:string):void{this.openRecords=this.isOpen(id)?this.openRecords.filter(v=>v!==id):this.openRecords.concat(id);}
 isFolded(id:string):boolean{return id.startsWith('g:')?this.folded.indexOf('open:'+id)<0:this.folded.indexOf(id)>=0;}
 toggleFold(id:string):void{if(id.startsWith('g:')){const key='open:'+id;this.folded=this.isFolded(id)?this.folded.concat(key):this.folded.filter(v=>v!==key);}else this.folded=this.isFolded(id)?this.folded.filter(v=>v!==id):this.folded.concat(id);}
 scaleLevel():number{return Math.min(7,Math.max(0,Math.round((this.fontScale-0.8)/0.05)));}
 scaleName():string{return ['特小','很小','小','偏小','标准','偏大','较大','大'][this.scaleLevel()];}
 setScale(v:number,persist:boolean):void{this.fontScale=Math.round(v*100)/100;const e=this.engine;if(e&&persist){e.state.fontScale=this.fontScale;e.save();}}
 itemKey(it:TimelineItem):string{return it.key+'|'+it.text+'|'+it.status+it.result.length+(this.isOpen(it.id)?'o':'c')+(this.isFolded(it.id)?'f':'u')+(this.isFav(it.id)?'*':'')+(this.usageOpen===it.id?'^':'')+this.fontScale;}
 shorten(text:string,max:number):string{return text.length>max?text.slice(0,max)+'…':text;}
 activeModel():string{const p=this.profiles().find(v=>v.id===this.eng()?.state.activeProfile);return p?p.model:this.model;}
 pageTitle():string{return this.panel==='stats'?'Token 看板':this.panel==='favorites'?'收藏':this.panel==='model'?'设置':this.panel==='extensions'?'扩展能力':(this.eng()?.session().title??'新会话');}
 isChatLike():boolean{return this.panel==='chat'||this.panel==='trace';}
 hasMessages():boolean{return (this.eng()?.session().messages.length??0)>0;}
 canResume():boolean{return !this.isRunning()&&this.curStatus()==='paused';}
 canCancel():boolean{return this.isRunning()||this.curStatus()==='paused';}
 isLive(status:string):boolean{return status==='running'||status==='observing'||status==='waiting'||status==='approval';}
 statusColor():string{const s=this.curStatus();return this.isRunning()?BLUE:INK3;}
 // 0.8.0 底栏数据：当前会话的真实累计；上下文按组成部分估算。
 statusView():StatusView{const e=this.eng();const empty:ContextStats={system:0,tools:0,messages:0,images:0,output:0,total:0,window:0,time:0};if(!e)return {stats:sessionStats({id:'',title:'',messages:[],tasks:[]},0),ctx:empty,running:false,compacting:false,scale:this.fontScale};const s=e.session();return {stats:sessionStats(s,tokenLimit(e.state.tokenBudget)),ctx:e.contextStats(s)??empty,running:e.running,compacting:e.compacting,scale:this.fontScale};}
 footnote():string{const c=this.cur();if(c&&this.isRunning())return '已操作 '+c.calls+' 步';return '';}
 bottomGap():number{return Math.max(2,this.bottomInset*0.15);}
 // 0.8.6 阶段 5：侧栏与设置页底栏沿用旧间距，不跟随输入区下移。
 legacyGap():number{return Math.max(10,this.bottomInset*0.5);}
 isEmptySession(s:Session):boolean{return s.messages.length===0&&s.tasks.length===0;}
 pruneEmpty(keep:string):void{const e=this.engine;if(!e)return;const before=e.state.sessions.length;e.state.sessions=e.state.sessions.filter(v=>v.id===keep||!this.isEmptySession(v));if(e.state.sessions.length!==before)e.save();}
 selectedSession():Session|null{const e=this.eng();return e?(e.state.sessions.find(v=>v.id===e.state.selected)??null):null;}
 newChat():void{this.attachments=[];this.plusOpen=false;this.composerGoal=false;this.slashMode=false;this.slashQuery='';const e=this.eng();if(!e||e.running||e.compacting)return;if(this.isEmptySession(e.session())){this.panel='chat';return;}const s=newSession();e.state.sessions.push(s);e.state.selected=s.id;e.current=null;this.pruneEmpty(s.id);e.save();this.panel='chat';this.follow=true;}
 openSession(s:Session):void{const e=this.eng();if(!e||e.running||e.compacting)return;this.attachments=[];this.plusOpen=false;this.composerGoal=false;this.slashMode=false;this.slashQuery='';e.state.selected=s.id;e.current=s.tasks[s.tasks.length-1]??null;this.pruneEmpty(s.id);e.save();this.panel='chat';this.follow=true;this.scrollToEnd();}
 rowClick(s:Session):void{if(this.selectMode){this.keepScroll(()=>{this.picked=togglePicked(this.picked,s.id);});return;}if(this.renaming===s.id)return;this.openSession(s);}
 startRename():void{const s=this.selectedSession();if(!s)return;this.renameText=s.title;this.renaming=s.id;}
 commitRename():void{const e=this.eng();if(!e||!this.renaming)return;const s=e.state.sessions.find(v=>v.id===this.renaming);const name=this.renameText.trim();this.renaming='';if(s&&name&&name!==s.title){s.title=name;e.save();}}
 togglePinSelected():void{const e=this.eng();const s=this.selectedSession();if(!e||!s)return;s.pinned=!s.pinned;e.save();}
 startMulti():void{const s=this.selectedSession();if(!s)return;this.picked=[s.id];this.selectMode=true;}
 // 0.8.4 A4：侧边栏列表的滚动位置。每次改变选择状态都会重建分组，位置记下来再恢复，避免列表跳走后回不到顶部；进出多选与删除后回到顶部。
 sideScroller:Scroller=new Scroller();
 sideTop():void{setTimeout(()=>{try{this.sideScroller.scrollEdge(Edge.Top);}catch(e){}},30);}
 keepScroll(change:()=>void):void{let y:number=0;try{y=this.sideScroller.currentOffset().yOffset;}catch(e){y=0;}change();setTimeout(()=>{try{this.sideScroller.scrollTo({xOffset:0,yOffset:y});}catch(e){}},30);}
 toggleSelectMode():void{if(this.isRunning()){this.toast('任务运行中，先暂停再整理会话');return;}this.selectMode=!this.selectMode;this.picked=[];this.sideTop();}
 visibleSessionIds():string[]{const ids:string[]=[];this.sessionGroups().forEach((g:SessionGroup)=>{g.items.forEach((s:Session)=>{ids.push(s.id);});});return ids;}
 groupAllPicked(g:SessionGroup):boolean{return g.items.length>0&&g.items.every((s:Session)=>this.picked.indexOf(s.id)>=0);}
 pickGroup(g:SessionGroup):void{this.keepScroll(()=>{this.picked=toggleGroup(this.picked,g.items.map((s:Session)=>s.id));});}
 pickAll():void{const ids:string[]=this.visibleSessionIds();this.keepScroll(()=>{this.picked=this.picked.length>=ids.length&&ids.length>0?[]:ids;});}
 async deleteSessions(ids:string[]):Promise<void>{const e=this.eng();if(!e||!ids.length)return;if(e.running||e.compacting){this.toast('任务运行中，先暂停再删除会话');return;}const plan=bulkPlan(e.state.sessions,ids,e.state.selected);if(!plan.ids.length)return;const r=await this.getUIContext().getPromptAction().showDialog({title:confirmTitle(plan),message:confirmMessage(plan),buttons:[{text:'取消',color:INK2},{text:'删除',color:RED}]});if(r.index!==1)return;const result=afterDelete(e.state.sessions,plan.ids,e.state.selected,()=>newSession());e.state.sessions=result.sessions;if(result.selected!==e.state.selected){e.state.selected=result.selected;const next=e.state.sessions.find((v:Session)=>v.id===result.selected);e.current=next?(next.tasks[next.tasks.length-1]??null):null;}this.selectMode=false;this.picked=[];e.save();this.toast('已删除 '+plan.ids.length+' 个会话');this.sideTop();}
 profileMenu():MenuElement[]{const out:MenuElement[]=[];this.profiles().forEach((p:Profile)=>{out.push({value:(p.id===this.eng()?.state.activeProfile?'✓ ':'    ')+p.title+' · '+p.model,action:()=>{if(this.isRunning())return;this.loadProfile(p.id);if(this.engine){this.engine.state.activeProfile=p.id;this.engine.save();}}});});out.push({value:'    模型设置…',action:()=>{this.settingsGroup='model';this.panel='model';}});return out;}
 async pickImages(photo:boolean):Promise<void>{if(!this.store||this.importingOffice)return;const session=this.engine?.session().id;this.plusOpen=false;this.importingOffice=true;try{const service=new Attachments(this.store.root),ctx=getContext(this) as common.UIAbilityContext,uris=photo?await service.photo(ctx):await service.album(ctx,9-this.attachments.filter(a=>a.kind==='image').length);if(this.engine?.session().id!==session)return;for(const uri of uris){if(this.attachments.filter(a=>a.kind==='image').length>=9)break;this.attachments=this.attachments.concat(await service.compress(uri));}}catch(e){this.message='图片未添加：'+(e as Error).message;}finally{this.importingOffice=false;}}
 removeAttachment(id:string):void{const a=this.attachments.find(v=>v.id===id);if(a&&this.store)new Attachments(this.store.root).remove(a);if(a?.kind==='file'&&this.engine){this.engine.session().fileIds=(this.engine.session().fileIds??[]).filter(v=>v!==id);this.engine.save();}this.attachments=this.attachments.filter(v=>v.id!==id);}
 // 0.8.6 阶段 4（修订）：「＋」与输入框「/」共用的命令菜单。
 @Builder commandPopup(){
  CommandMenu({rows:commandRows(this.slashQuery,this.isRunning(),this.goalDesc()),entries:commandEntries(this.isRunning(),this.slashMode),onPick:(id:string)=>{this.runCommand(id);}})
 }
 // 0.8.6 阶段 4：模型胶囊的就地气泡。根页：模型 / 推理等级；子页：模型列表 / 推理等级四档。每次打开从根页开始。
 @Builder modelPopup(){
  Column({space:2}){
   if(this.modelMenuPage==='root'){
    this.menuLine({label:'模型',value:this.activeModel(),checked:false,arrow:true,back:false,action:()=>{this.modelMenuPage='model';}})
    this.menuLine({label:'推理等级',value:effortLabel(this.effortKey()),checked:false,arrow:true,back:false,action:()=>{this.modelMenuPage='effort';}})
   }else if(this.modelMenuPage==='model'){
    this.menuLine({label:'返回',value:'',checked:false,arrow:false,back:true,action:()=>{this.modelMenuPage='root';}})
    ForEach(this.profiles(),(p:Profile)=>{
     this.menuLine({label:p.title+' · '+p.model,value:'',checked:p.id===this.eng()?.state.activeProfile,arrow:false,back:false,action:()=>{this.pickProfile(p.id);}})
    },(p:Profile)=>p.id+p.title+p.model+(p.id===this.eng()?.state.activeProfile?'*':''))
    this.menuLine({label:'管理模型配置…',value:'',checked:false,arrow:false,back:false,action:()=>{this.modelMenuOpen=false;this.goSettings('model');}})
   }else{
    this.menuLine({label:'返回',value:'',checked:false,arrow:false,back:true,action:()=>{this.modelMenuPage='root';}})
    ForEach(EFFORT_CHOICES,(c:EffortChoice)=>{
     this.menuLine({label:c.label,value:'',checked:c.key===this.effortKey(),arrow:false,back:false,action:()=>{this.pickEffort(c.key);}})
    },(c:EffortChoice)=>c.key+(c.key===this.effortKey()?'*':''))
   }
  }.width(260).padding(8).backgroundColor(WHITE)
 }
 @Builder menuLine(p:MenuLineP){
  Row({space:8}){
   if(p.back){this.icon({res:$r('sys.symbol.chevron_left'),size:12,color:INK3})}
   Text(p.label).fontSize(this.fs(14)).fontColor(INK).layoutWeight(1).maxLines(1).textOverflow({overflow:TextOverflow.Ellipsis})
   if(p.value){Text(p.value).fontSize(this.fs(13)).fontColor(INK3).maxLines(1)}
   if(p.checked){this.icon({res:$r('sys.symbol.checkmark'),size:14,color:BLUE})}
   if(p.arrow){this.icon({res:$r('sys.symbol.chevron_right'),size:12,color:INK3})}
  }.width('100%').height(44).padding({left:12,right:12}).borderRadius(10).onClick(()=>{p.action();})
 }
 // 0.8.6：「⋯」更多菜单。小窗已移到顶栏按钮，不再重复放在这里。
 titleMenu():MenuElement[]{return [{value:'导出当前会话',action:()=>{this.exportChat();}},{value:'收藏最后一条回复',action:()=>{this.favLastReply();}},{value:'清空本会话待办',action:()=>{this.clearTodoAction();}},{value:'目标模式',action:()=>{this.panel='chat';this.enterGoalMode();}},{value:'技能与记忆',action:()=>{this.goSettings('skills');}},{value:'设置',action:()=>{this.goSettings(this.settingsGroup);}}];}
 // 0.8.6 阶段 1：侧栏快捷入口、计划开关、文件胶囊、更多菜单共用的动作；运行中统一提示，不静默失效。
 goPanel(id:string):void{if(this.isRunning()){this.toast('任务运行中，先暂停再切换');return;}this.panel=id;}
 goSettings(group:string):void{if(this.isRunning()){this.toast('任务运行中，先暂停再打开设置');return;}if(group==='memory')this.skillTab='memory';this.settingsGroup=settingsGroupId(group);this.panel='model';}
 // 0.8.6 阶段 2：读取分组时统一映射（memory→skills，mcp→tools，connection→about）。
 settingsKey():string{return settingsGroupId(this.settingsGroup);}
 // 计划开关：与原加号弹窗里的 onPlan 同一处理，不改 session.planning 的语义。
 togglePlanMode():void{try{this.eng()?.togglePlan();}catch(e){this.message=(e as Error).message;}}
 isPlanning():boolean{return !!this.eng()?.session().planning;}
 fileCount():number{const e=this.eng();return e?e.files.list(e.session()).length:0;}
 // 0.8.6 阶段 4：输入栏的「/」命令、/目标 与 /计划 token、模型胶囊就地切换。
 composerChange(v:string):void{this.input=v;if(v.startsWith('/')&&!/\s/.test(v)){this.slashMode=true;this.slashQuery=v.slice(1);this.plusOpen=commandRows(this.slashQuery,this.isRunning(),this.goalDesc()).length>0;}else{this.slashMode=false;this.slashQuery='';this.plusOpen=false;}}
 goalDesc():string{return this.eng()?.session().goal?.objective??'';}
 // 选中命令：先清掉输入框里的「/…」过滤文本，再按运行状态执行；运行中统一提示。
 runCommand(id:string):void{this.plusOpen=false;if(this.input.startsWith('/')){this.input='';}this.slashMode=false;this.slashQuery='';if(this.isRunning()){this.toast('任务运行中，先暂停再操作');return;}if(id==='camera'){this.pickImages(true);}else if(id==='album'){this.pickImages(false);}else if(id==='file'){this.importOffice();}else if(id==='goal'){this.enterGoalMode();}else if(id==='plan'){this.togglePlanMode();}else if(id==='compact'){this.compressContext();}}
 enterGoalMode():void{if(this.isRunning()){this.toast('任务运行中，先暂停再操作');return;}this.composerGoal=true;}
 hasComposerToken():boolean{return this.composerGoal||this.isPlanning();}
 inputPlaceholder():string{if(this.isRunning())return '补充要求，下一步生效';if(this.composerGoal)return '输入目标，智能体将持续执行';if(this.isPlanning())return '描述要完成的任务，先出计划再执行';return this.eng()?.session().suggestion||'发消息或创建任务，/ 调用指令';}
 activeProfile():Profile|undefined{return this.profiles().find((v:Profile)=>v.id===this.eng()?.state.activeProfile);}
 effortKey():string{const p=this.activeProfile();return p?effortOf(p):'high';}
 effortName():string{return effortLabel(this.effortKey());}
 // 模型胶囊里选模型：与原 profileMenu 同一处理（loadProfile + activeProfile + save）。
 pickProfile(id:string):void{if(this.isRunning()){this.toast('任务运行中，先暂停再切换');return;}this.modelMenuOpen=false;this.loadProfile(id);const e=this.engine;if(e){e.state.activeProfile=id;e.save();}}
 // 就地改当前激活 profile 的推理等级：Off → thinking 关闭；其余 → thinking 开启并写入 effort。save() 会触发 revision 刷新。
 pickEffort(key:string):void{if(this.isRunning()){this.toast('任务运行中，先暂停再切换');return;}const p=this.activeProfile();const e=this.engine;if(!p||!e)return;if(key==='off'){p.thinking='disabled';p.effort=undefined;}else{p.thinking='enabled';p.effort=key;}e.save();this.loadProfile(p.id);this.modelMenuOpen=false;}
 // 收藏本会话最后一条已完成的回复（时间线里的 actions 项：id 为任务 id，text 为完整回复）。
 favLastReply():void{const e=this.eng();if(!e)return;const last=buildTimeline(e.session(),this.folded).filter((v:TimelineItem)=>v.kind==='actions').pop();if(!last){this.toast('本会话还没有完成的回复');return;}if(this.isFav(last.id)){this.toast('最后一条回复已收藏');return;}this.toggleFav(last.id,last.text);}
 clearTodoAction():void{const e=this.eng();if(!e)return;if(e.running||e.compacting){this.toast('任务运行中，先暂停再清空待办');return;}if(copyTodos(e.session().todos).length===0){this.toast('本会话没有待办');return;}this.clearTodos();this.toast('已清空待办');}
 // 主按钮的模式：暂停 / 继续 / 发送 / 空闲。运行中输入为空=暂停；已暂停输入为空=继续；有输入时一律走 send()（运行中为补充，已暂停为回答或续跑）。
 mainMode():string{const typed=!!this.input.trim()||this.attachments.length>0;if(this.isRunning())return typed?'send':'pause';if(this.canResume())return typed?'send':'resume';return typed?'send':'idle';}
 mainLabel():string{const m=this.mainMode();if(m==='pause')return '暂停';if(m==='resume')return this.cur()?.replyIncomplete?'继续生成':'继续';if(m==='send')return this.isRunning()?'发送补充':'发送';return '发送';}
 mainIcon():Resource{const m=this.mainMode();if(m==='pause')return $r('sys.symbol.pause_fill');if(m==='resume')return $r('sys.symbol.play_fill');return $r('sys.symbol.arrow_up');}
 mainAction():void{const m=this.mainMode();if(m==='pause'){this.eng()?.pause();}else if(m==='resume'){this.eng()?.start().catch(()=>{this.message='没有可恢复任务';});}else if(m==='send'){this.follow=true;this.send();}}

 openGoal():void{const goal=this.eng()?.session().goal;this.goalText=goal?.objective??'';this.goalCriteria=goal?.criteria.join('\n')??'';this.goalConstraints=goal?.constraints.join('\n')??'';this.panel='goal';}
 async compressContext():Promise<void>{const e=this.eng();if(!e)return;try{if(e.running){await e.compress();this.message='已请求压缩，将在安全轮次边界处理';}else{this.message='正在压缩上下文';await e.compress();this.message=e.session().context?'压缩完成，原始记录保留':'历史较短，无需压缩';}}catch(error){this.message='压缩未完成，原上下文保留：'+(error as Error).message;}}
 toast(text:string):void{try{this.getUIContext().getPromptAction().showToast({message:text,duration:1600});}catch(e){}}
 copyText(text:string):void{try{const data=pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN,text);pasteboard.getSystemPasteboard().setData(data);this.toast('已复制');}catch(e){this.toast('复制失败');}}
 favorites():Favorite[]{return this.eng()?.state.favorites??[];}
 isFav(id:string):boolean{return this.favorites().some((f:Favorite)=>f.id===id);}
 taskOf(id:string):Task|null{return this.eng()?.session().tasks.find((t:Task)=>t.id===id)??null;}
 usageTask():Usage|null{return this.taskOf(this.usageOpen)?.usage??null;}
 usageText(id:string):string{const u=this.taskOf(id)?.usage;return u?formatTokens(u.total):'';}
 hitRate(u:Usage):string{const all=u.cacheRead+u.input;return all>0?(u.cacheRead*100/all).toFixed(1)+'%':'—';}
 toggleFav(taskId:string,reply:string):void{const e=this.eng();if(!e)return;const list=(e.state.favorites??[]).slice();const i=list.findIndex((f:Favorite)=>f.id===taskId);if(i>=0){list.splice(i,1);this.toast('已取消收藏');}else{const s=e.session();const t=s.tasks.find((v:Task)=>v.id===taskId);list.unshift({id:taskId,sessionId:s.id,sessionTitle:s.title,goal:t?t.goal:'',reply:reply,time:Date.now(),usage:t?.usage});this.toast('已收藏');}e.state.favorites=list;e.save();}
 removeFav(id:string):void{const e=this.eng();if(!e)return;e.state.favorites=(e.state.favorites??[]).filter((f:Favorite)=>f.id!==id);e.save();this.toast('已取消收藏');}
 openFavSession(f:Favorite):void{const e=this.eng();const s=e?.state.sessions.find((v:Session)=>v.id===f.sessionId);if(!s){this.toast('原会话已被删除');return;}this.openSession(s);}
 branchFrom(taskId:string):void{const e=this.eng();if(!e||e.running||e.compacting)return;const src=e.session();const ti=src.tasks.findIndex((t:Task)=>t.id===taskId);if(ti<0)return;const next=src.tasks[ti+1];const end=next?taskStart(next):Number.MAX_SAFE_INTEGER;const msgs:ChatEntry[]=JSON.parse(JSON.stringify(src.messages.filter((m:ChatEntry)=>m.time<end))) as ChatEntry[];const tasks:Task[]=JSON.parse(JSON.stringify(src.tasks.slice(0,ti+1))) as Task[];const copy:Session={id:uid(),title:'分支 · '+src.title,messages:msgs,tasks:tasks,fileIds:branchFiles(src,src.tasks[ti]),goal:tasks[tasks.length-1]?.goalSnapshot,plan:tasks[tasks.length-1]?.planSnapshot,touched:Date.now()};e.state.sessions.push(copy);e.state.selected=copy.id;e.current=tasks[tasks.length-1]??null;this.pruneEmpty(copy.id);e.save();this.panel='chat';this.follow=true;this.scrollToEnd();this.toast('已在新会话中分支');}
 ledger():DayUsage[]{return this.eng()?.state.usageDaily??[];}
 statCells():StatCell[]{const e=this.eng();if(!e)return [];const st=computeStats(e.state.sessions,this.ledger(),e.state.longestTaskMs??0,Date.now());return [{value:formatCn(st.total),label:'累计 Token 数'},{value:formatCn(st.peak),label:'单日用量峰值'},{value:formatSpan(st.longest),label:'最长任务用时'},{value:st.bestStreak+' 天',label:'最长连续天数'},{value:st.curStreak+' 天',label:'当前连续天数'}];}
 heatData():HeatWeek[]{return heatWeeks(this.ledger(),Date.now(),52);}
 monthLabels():MonthLabel[]{const weeks=this.heatData();const out:MonthLabel[]=[];weeks.forEach((w:HeatWeek,c:number)=>{if(c===0||w.month!==weeks[c-1].month){out.push({text:w.month+'月',x:c*12});}});if(out.length>1&&out[1].x-out[0].x<48)out.shift();return out;}
 barData():BarView[]{const items:BarItem[]=weekBars(this.ledger(),Date.now(),26,this.statsMode==='total');let max=0;items.forEach((b:BarItem)=>{max=Math.max(max,b.total);});return items.map((b:BarItem)=>{return {label:b.label,total:b.total,h:b.total>0&&max>0?Math.max(3,Math.round(b.total*140/max)):2} as BarView;});}
 modeOptions():ModeOpt[]{return [{key:'day',label:'每天'},{key:'week',label:'每周'},{key:'total',label:'累计总量'}];}
 toolIcon(name:string):Resource{
  if(name==='click')return $r('sys.symbol.hand_point_up_tap_fill_1');
  if(name==='insert_text'||name==='replace_text')return $r('sys.symbol.keyboard');
  if(name==='swipe')return $r('sys.symbol.swipe');
  if(name==='back')return $r('sys.symbol.arrow_left');
  if(name==='home')return $r('sys.symbol.house');
  if(name==='observe')return $r('sys.symbol.eye');
  if(name==='request_confirmation')return $r('sys.symbol.exclamationmark_circle');
  if(name==='skill_load')return $r('sys.symbol.lightbulb');
  return $r('sys.symbol.wrench_and_screwdriver');
 }

 // ───────── 通用小部件 ─────────
 @Builder icon(p:IconP){SymbolGlyph(p.res).fontSize(p.size).fontColor([p.color]).renderingStrategy(SymbolRenderingStrategy.SINGLE)}
 @Builder pill(p:PillP){
  // 0.8.6 阶段 3：外层 44 高作为点击区，内层仍是 36 高胶囊；grow 时等分剩余宽度。
  if(p.grow){
   Row(){Row(){Text(p.label).fontSize(this.fs(14)).fontColor(p.primary?BLUE_DEEP:INK2).maxLines(1)}.width('100%').height(36).justifyContent(FlexAlign.Center).borderRadius(18).backgroundColor(p.primary?BLUE_SOFT:WHITE).border({width:p.primary?0:1,color:LINE}).opacity(p.enabled?1:0.4)}.height(44).layoutWeight(1).justifyContent(FlexAlign.Center).onClick(()=>{if(p.enabled)p.action();})
  }else{
   Row(){Row(){Text(p.label).fontSize(this.fs(14)).fontColor(p.primary?BLUE_DEEP:INK2).maxLines(1)}.height(36).padding({left:16,right:16}).justifyContent(FlexAlign.Center).borderRadius(18).backgroundColor(p.primary?BLUE_SOFT:WHITE).border({width:p.primary?0:1,color:LINE}).opacity(p.enabled?1:0.4)}.height(44).justifyContent(FlexAlign.Center).onClick(()=>{if(p.enabled)p.action();})
  }
 }
 @Builder softChip(p:ChipP){
  Row(){Row({space:5}){this.icon({res:p.res,size:14,color:p.fg});Text(p.label).fontSize(this.fs(13)).fontColor(p.fg)}.padding({left:11,right:12,top:6,bottom:6}).borderRadius(16).backgroundColor(p.bg).border({width:p.bg===WHITE?1:0,color:LINE})}.height(44).onClick(()=>{p.action();})
 }
 @Builder iconButton(p:IconBtnP){
  Row(){Row(){this.icon({res:p.res,size:21,color:p.active?BLUE:INK2})}.width(36).height(36).justifyContent(FlexAlign.Center).borderRadius(18).backgroundColor(p.active?SELECTED:Color.Transparent)}.width(44).height(44).justifyContent(FlexAlign.Center).onClick(()=>{p.action();})
 }
 @Builder field(label:string,value:string,change:(v:string)=>void){
  Column({space:6}){
   Text(label).fontSize(this.fs(13)).fontColor(INK3).alignSelf(ItemAlign.Start)
   TextInput({text:value}).onChange(change).height(44).fontSize(this.fs(15)).fontColor(INK).backgroundColor(WHITE).border({width:1,color:LINE}).borderRadius(10)
  }.width('100%')
 }
 @Builder switchRow(label:string,hint:string,on:boolean,change:(v:boolean)=>void){
  Row(){
   Column({space:1}){Text(label).fontSize(this.fs(15)).fontColor(INK);if(hint)Text(hint).fontSize(this.fs(12)).fontColor(INK3)}.alignItems(HorizontalAlign.Start).layoutWeight(1)
   Toggle({type:ToggleType.Switch,isOn:on}).selectedColor(BLUE).onChange(change)
  }.width('100%').padding({top:4,bottom:4})
 }
 @Builder sectionTitle(text:string){Text(text).fontSize(this.fs(16)).fontWeight(FontWeight.Medium).fontColor(INK).alignSelf(ItemAlign.Start)}
 @Builder dot(p:DotP){Column().width(7).height(7).borderRadius(4).backgroundColor(p.color)}
 // 0.8.6：侧栏快捷入口（图标+文字，选中蓝底）。
 @Builder navTile(p:NavTileP){
  Column({space:4}){
   this.icon({res:p.res,size:20,color:p.active?BLUE_DEEP:INK2})
   Text(p.label).fontSize(this.fs(12)).fontColor(p.active?BLUE_DEEP:INK2).maxLines(1)
  }.layoutWeight(1).height(56).justifyContent(FlexAlign.Center).borderRadius(12).backgroundColor(p.active?SELECTED:WHITE).border({width:1,color:p.active?BLUE_LINE:LINE}).onClick(()=>{p.action();})
 }

 // ───────── 侧栏（DS：搜索 + 按时间分组的会话 + 底部账号） ─────────
 @Builder sidebar(){
  Column(){
   Row({space:10}){
    Image($r('app.media.probe_icon')).width(36).height(36).borderRadius(10)
    Text(APP_NAME).fontSize(this.fs(20)).fontWeight(FontWeight.Bold).fontColor(INK).maxLines(1).layoutWeight(1)
    this.iconButton({res:$r('sys.symbol.close_sidebar'),active:false,action:()=>{this.sidebarOpen=false;}})
   }.width('100%').height(48).padding({left:4}).margin({bottom:6})
   Row({space:8}){
    this.icon({res:$r('sys.symbol.plus_circle'),size:18,color:INK})
    Text('新会话').fontSize(this.fs(15)).fontColor(INK)
   }.width('100%').height(44).justifyContent(FlexAlign.Center).borderRadius(12).backgroundColor(WHITE).border({width:1,color:LINE}).margin({bottom:10}).onClick(()=>{if(this.isRunning()){this.toast('任务运行中，先暂停再新建会话');return;}this.newChat();})
   Row({space:8}){
    this.icon({res:$r('sys.symbol.magnifyingglass'),size:18,color:INK3})
    TextInput({text:this.query,placeholder:'搜索对话内容…'}).onChange((v:string)=>{this.query=v;}).layoutWeight(1).height(42).fontSize(this.fs(15)).fontColor(INK).placeholderColor(INK3).placeholderFont({size:this.fs(15)}).backgroundColor(Color.Transparent).borderRadius(0).padding({left:0,right:0}).caretColor(BLUE)
   if(this.query){Row(){this.icon({res:$r('sys.symbol.xmark'),size:14,color:INK3})}.width(40).height(44).justifyContent(FlexAlign.Center).onClick(()=>{this.query='';})}
   }.width('100%').height(44).padding({left:16,right:12}).borderRadius(22).backgroundColor(WHITE).border({width:1,color:LINE}).margin({bottom:6})
   // 0.8.6：收藏、技能记忆、用量三个入口放在搜索框下面，不再分散在顶栏、头像和列表里。
   Row({space:8}){
    this.navTile({res:$r('sys.symbol.star'),label:'收藏',active:this.panel==='favorites',action:()=>{this.goPanel('favorites');}})
    this.navTile({res:$r('sys.symbol.puzzle'),label:'技能记忆',active:this.panel==='model'&&this.settingsGroup==='skills',action:()=>{this.goSettings('skills');}})
    this.navTile({res:$r('sys.symbol.gauge_with_dots_needle_33percent'),label:'用量',active:this.panel==='stats',action:()=>{this.goPanel('stats');}})
   }.width('100%').margin({bottom:10})
   Scroll(this.sideScroller){
    Column(){
     // 0.8.4.1：真机上从固定的“会话 / 多选”行或收藏行上往下划，列表不会动（手势没有落在滚动区域里），看起来像“回不到顶部”。
     // 这一行也放进滚动区域，固定区域只剩 logo、新会话和搜索框。
     Row(){
      Text(this.selectMode?'选择要删除的会话':'会话').fontSize(this.fs(13)).fontColor(INK3).layoutWeight(1)
      Row({space:4}){this.icon({res:this.selectMode?$r('sys.symbol.checkmark_circle'):$r('sys.symbol.list_bullet'),size:16,color:BLUE});Text(this.selectMode?'完成':'多选').fontSize(this.fs(13)).fontColor(BLUE)}.height(44).padding({left:12,right:12}).onClick(()=>{this.toggleSelectMode();})
     }.width('100%').padding({left:4,right:2})
     if(!this.sessionGroups().length){Text('没有匹配的会话').fontSize(this.fs(14)).fontColor(INK3).padding({left:14,top:20})}
     ForEach(this.sessionGroups(),(g:SessionGroup)=>{
      Row(){
       Text(g.label).fontSize(this.fs(13)).fontColor(INK3).layoutWeight(1)
       if(this.selectMode){Text(this.groupAllPicked(g)?'取消本组':'选择本组').fontSize(this.fs(13)).fontColor(BLUE).padding({left:10,right:6,top:6,bottom:6}).onClick(()=>{this.pickGroup(g);})}
      }.width('100%').padding({left:4,top:16,bottom:6})
      ForEach(g.items,(s:Session)=>{
       Row({space:10}){
        if(this.selectMode){this.icon({res:this.picked.indexOf(s.id)>=0?$r('sys.symbol.checkmark_circle_fill'):$r('sys.symbol.circle'),size:20,color:this.picked.indexOf(s.id)>=0?BLUE:INK3})}
        if(this.renaming===s.id){
         TextInput({text:this.renameText}).onChange((v:string)=>{this.renameText=v;}).onSubmit(()=>{this.commitRename();}).onBlur(()=>{this.commitRename();}).defaultFocus(true).selectAll(true).enterKeyType(EnterKeyType.Done).layoutWeight(1).height(38).fontSize(this.fs(15)).fontColor(INK).backgroundColor(WHITE).border({width:1,color:BLUE}).borderRadius(10)
        }else{
         Text(s.title).fontSize(this.fs(16)).fontColor(s.id===this.eng()?.state.selected&&this.isChatLike()&&!this.selectMode?BLUE_DEEP:INK).maxLines(1).textOverflow({overflow:TextOverflow.Ellipsis}).layoutWeight(1)
        }
        if(s.pinned&&this.renaming!==s.id){this.icon({res:$r('sys.symbol.pin_fill'),size:13,color:INK3})}
        if(s.id===this.eng()?.state.selected&&this.isChatLike()&&!this.selectMode&&this.renaming!==s.id){
         Row(){SymbolGlyph($r('sys.symbol.ellipsis_circle')).fontSize(20).fontColor([INK2]).renderingStrategy(SymbolRenderingStrategy.SINGLE)}.width(44).height(44).justifyContent(FlexAlign.Center).borderRadius(22).bindMenu(this.sessionMenu)
        }
       }.width('100%').constraintSize({minHeight:46}).padding({left:14,right:4,top:1,bottom:1}).borderRadius(12).backgroundColor(s.id===this.eng()?.state.selected&&this.isChatLike()&&!this.selectMode?SELECTED:Color.Transparent).opacity(this.isRunning()&&s.id!==this.eng()?.state.selected?0.5:1).onClick(()=>{this.rowClick(s);})
      },(s:Session)=>s.id+s.title+(s.id===this.eng()?.state.selected?'s':'n')+this.panel+this.fontScale+(s.pinned?'p':'')+(this.renaming===s.id?'r':'')+(this.selectMode?(this.picked.indexOf(s.id)>=0?'y':'n'):''))
     },(g:SessionGroup)=>g.label+g.items.map((s:Session)=>s.id+s.title+(s.pinned?'p':'')).join(',')+(this.eng()?.state.selected??'')+this.panel+this.fontScale+this.renaming+this.selectMode+this.picked.join(','))
    }.width('100%')
   }.layoutWeight(1).width('100%').scrollBar(BarState.Off).align(Alignment.Top).edgeEffect(EdgeEffect.Spring)
   if(this.selectMode){
    Row({space:10}){
     Text('已选 '+this.picked.length+' 项').fontSize(this.fs(14)).fontColor(INK2).layoutWeight(1)
     Text(this.picked.length>=this.visibleSessionIds().length&&this.picked.length>0?'清除':'全选').fontSize(this.fs(14)).fontColor(BLUE).padding({left:10,right:10,top:8,bottom:8}).onClick(()=>{this.pickAll();})
     Text(this.picked.length>0?'删除 '+this.picked.length+' 项':'删除').fontSize(this.fs(14)).fontColor(this.picked.length>0?RED:INK3).padding({left:16,right:16,top:8,bottom:8}).borderRadius(18).border({width:1,color:LINE}).onClick(()=>{this.deleteSessions(this.picked);})
     Text('完成').fontSize(this.fs(14)).fontColor(BLUE_DEEP).padding({left:16,right:16,top:8,bottom:8}).borderRadius(18).backgroundColor(BLUE_SOFT).onClick(()=>{this.toggleSelectMode();})
    }.width('100%').padding({left:6,right:2,top:8,bottom:8}).margin({top:6})
   }else{
     // 0.8.6：底部一行只放「本机连接点 + 当前模型」（点击进模型设置）和「设置」齿轮；头像移除，用量已在侧栏快捷行。
     Row({space:10}){
       // 0.8.6 阶段 4：头像（44 点击区）进用量页；中间两行显示模型与连接状态，点击进模型设置。
       Row(){Image($r('app.media.avatar')).width(40).height(40).borderRadius(20).objectFit(ImageFit.Cover)}.width(44).height(44).justifyContent(FlexAlign.Center).accessibilityText('用量').onClick(()=>{this.goPanel('stats');})
       Column({space:2}){
        Text(this.activeModel()).fontSize(this.fs(15)).fontColor(INK).maxLines(1).textOverflow({overflow:TextOverflow.Ellipsis})
        Row({space:6}){
         this.dot({color:this.ready?GREEN:ORANGE})
         Text(this.ready?'本机已连接':'等待连接').fontSize(this.fs(12)).fontColor(INK3).maxLines(1)
        }
       }.layoutWeight(1).height(44).justifyContent(FlexAlign.Center).alignItems(HorizontalAlign.Start).accessibilityText(this.ready?'本机已连接':'等待连接').onClick(()=>{this.goSettings('model');})
      Row({space:4}){
       this.icon({res:$r('sys.symbol.gearshape'),size:18,color:this.panel==='model'?BLUE_DEEP:INK2})
       Text('设置').fontSize(this.fs(14)).fontColor(this.panel==='model'?BLUE_DEEP:INK2)
      }.height(44).padding({left:12,right:12}).borderRadius(12).backgroundColor(this.panel==='model'?SELECTED:Color.Transparent).accessibilityText('设置').onClick(()=>{this.goSettings(this.settingsGroup);})
     }.width('100%').margin({top:6})
   }
  }.width(SIDEBAR_WIDTH).height('100%').padding({left:14,right:14,top:this.topInset+10,bottom:this.legacyGap()}).backgroundColor(SIDEBAR)
 }

 @Builder menuRow(p:MenuRowP){
  Row({space:14}){
   this.icon({res:p.res,size:20,color:p.color})
   Text(p.label).fontSize(this.fs(16)).fontColor(p.color)
  }.width('100%').height(52).padding({left:18,right:18}).border({width:{bottom:p.last?0:1},color:LINE})
 }
 @Builder sessionMenu(){
  Menu(){
   MenuItem(){this.menuRow({res:$r('sys.symbol.pencil_line'),label:'重命名',color:INK,last:false})}.onClick(()=>{this.startRename();})
   MenuItem(){this.menuRow({res:$r('sys.symbol.pin'),label:this.selectedSession()?.pinned?'取消置顶':'置顶',color:INK,last:false})}.onClick(()=>{this.togglePinSelected();})
   MenuItem(){this.menuRow({res:$r('sys.symbol.list_bullet'),label:'多选',color:INK,last:false})}.onClick(()=>{this.startMulti();})
   MenuItem(){this.menuRow({res:$r('sys.symbol.trash'),label:'删除',color:RED,last:true})}.onClick(()=>{const s=this.selectedSession();if(s)this.deleteSessions([s.id]);})
  }.width(220).radius(16)
 }

 // ───────── 标题栏与标签 ─────────
 // 0.8.6：对话 / 轨迹分段控件内嵌在标题栏里，替换原来独占一行的标签。
 @Builder segItem(label:string,id:string){
  Row(){Text(label).fontSize(this.fs(14)).fontColor(this.panel===id?BLUE_DEEP:INK2).fontWeight(this.panel===id?FontWeight.Medium:FontWeight.Normal)}.height(36).padding({left:14,right:14}).borderRadius(8).backgroundColor(this.panel===id?WHITE:Color.Transparent).onClick(()=>{this.panel=id;if(id==='chat')this.scrollToEnd();})
 }
 @Builder segment(){
  Row({space:2}){
   this.segItem('对话','chat')
   this.segItem('轨迹','trace')
  }.height(42).padding(3).borderRadius(10).backgroundColor(SURFACE)
 }
 @Builder header(){
  Column(){
   Row({space:4}){
    // 侧栏收起时才显示展开按钮（侧栏已开时收起按钮在侧栏顶部）；非聊天页的「返回对话」放在同一位置。
    if(!this.sidebarOpen&&!this.compact()){this.iconButton({res:$r('sys.symbol.open_sidebar'),active:false,action:()=>{this.sidebarOpen=true;}})}
    if(!this.isChatLike()){this.softChip({res:$r('sys.symbol.arrow_left'),label:'返回对话',fg:INK2,bg:WHITE,action:()=>{this.panel='chat';this.scrollToEnd();}})}
    Text(this.pageTitle()).fontSize(this.fs(17)).fontWeight(FontWeight.Medium).fontColor(INK).maxLines(1).textOverflow({overflow:TextOverflow.Ellipsis}).layoutWeight(1).margin({left:6})
    if(this.isChatLike()){this.segment()}
    if(this.isChatLike()){
     // 0.8.6：步数并入状态文字，底栏不再重复显示。
     Row({space:5}){
      if(this.isRunning()){LoadingProgress().width(12).height(12).color(BLUE)}else{this.dot({color:this.statusColor()})}
      Text(statusLabel(this.curStatus())+(this.footnote()?' · '+this.footnote():'')).fontSize(this.fs(12)).fontColor(this.statusColor())
     }.padding({left:6,right:8,top:5,bottom:5}).margin({right:4})
    }
    this.iconButton({res:$r('sys.symbol.rectangle_inset_filled'),active:false,action:()=>{this.enterFloat();}})
    Row(){SymbolGlyph($r('sys.symbol.ellipsis_circle')).fontSize(20).fontColor([INK2]).renderingStrategy(SymbolRenderingStrategy.SINGLE)}.width(44).height(44).justifyContent(FlexAlign.Center).bindMenu(this.titleMenu())
    if(!this.sidebarOpen){this.iconButton({res:$r('sys.symbol.plus_circle'),active:false,action:()=>{this.newChat();}})}
   }.width('100%').height(48)
  }.width('100%').padding({left:12,right:14,top:2}).backgroundColor(WHITE).border({width:{bottom:1},color:LINE})
 }

 @Builder notice(){
  if(this.message){
   Row({space:10}){
    Text(this.shorten(this.message,1200)).fontSize(this.fs(13)).fontColor(INK2).maxLines(8).layoutWeight(1)
    Row(){this.icon({res:$r('sys.symbol.xmark'),size:12,color:INK3})}.width(28).height(28).justifyContent(FlexAlign.Center).onClick(()=>{this.message='';})
   }.width('100%').padding({left:16,right:8,top:6,bottom:6}).backgroundColor(BLUE_SOFT).border({width:{bottom:1},color:BLUE_LINE})
  }
 }

 // ───────── 对话：气泡、富文本，以及 DSH 风格的平铺过程 ─────────
 @Builder rich(text:string,key:string=""){MarkdownView({text:text,fontScale:this.fontScale,cacheKey:key,saveEnabled:true,onSaveCode:(t:string,l:string)=>{this.saveCodeAsFile(t,l);}})}
 @Builder detailBlock(title:string,body:string){
  if(body){
   Column({space:2}){
    Text(title).fontSize(this.fs(11)).fontColor(INK3)
    Text(body).fontSize(this.fs(12)).fontColor(INK2).copyOption(CopyOptions.LocalDevice).width('100%')
   }.alignItems(HorizontalAlign.Start).width('100%')
  }
 }
 // 任务头：「已结束，用时 36分27秒 ⌃」+ 分割线，点击折叠整段过程
 @Builder taskHead(it:TimelineItem){
  Column({space:8}){
   Row({space:6}){
    if(this.isLive(it.status)){LoadingProgress().width(13).height(13).color(BLUE)}
    Text(it.summary).fontSize(this.fs(14)).fontColor(INK3)
    this.icon({res:this.isFolded(it.id)?$r('sys.symbol.chevron_down'):$r('sys.symbol.chevron_up'),size:12,color:INK3})
   }
   Divider().color(LINE).strokeWidth(1)
  }.width('100%').alignItems(HorizontalAlign.Start).margin({top:4}).onClick(()=>{this.toggleFold(it.id);})
 }
 // 工具组头：「⌃ 已执行 3 个操作」
 @Builder groupHead(it:TimelineItem){
  Row({space:6}){
   this.icon({res:this.isFolded(it.id)?$r('sys.symbol.chevron_right'):$r('sys.symbol.chevron_down'),size:11,color:INK3})
   Text(it.summary).fontSize(this.fs(14)).fontColor(INK3)
   if(it.status==='pending'){LoadingProgress().width(12).height(12).color(BLUE)}
  }.width('100%').padding({top:3,bottom:3}).onClick(()=>{this.toggleFold(it.id);})
 }
 @Builder thinkRow(it:TimelineItem){
  Column({space:4}){
   Row({space:7}){
    this.icon({res:$r('sys.symbol.lightbulb'),size:14,color:INK3})
    Text('思考').fontSize(this.fs(14)).fontColor(INK3)
    Text('·').fontSize(this.fs(14)).fontColor(INK3)
    Text(it.summary).fontSize(this.fs(14)).fontColor(INK2).maxLines(this.isOpen(it.id)?1:1).textOverflow({overflow:TextOverflow.Ellipsis}).layoutWeight(1)
   }.width('100%').onClick(()=>{this.toggleRecord(it.id);})
   if(this.isOpen(it.id)){
    Text(it.text).fontSize(this.fs(13)).fontColor(INK2).lineHeight(this.fs(20)).copyOption(CopyOptions.LocalDevice).width('100%').padding({left:12}).border({width:{left:2},color:LINE}).margin({left:7,bottom:2})
   }
  }.width('100%').padding({left:18,top:3,bottom:3})
 }
 @Builder toolRow(it:TimelineItem){
  Column({space:4}){
   Row({space:7}){
    this.icon({res:this.toolIcon(it.name),size:14,color:it.status==='uncertain'?ORANGE:INK3})
    Text(it.label).fontSize(this.fs(14)).fontColor(INK3)
    if(it.summary){Text('·').fontSize(this.fs(14)).fontColor(INK3)}
    Text(it.summary).fontSize(this.fs(14)).fontColor(INK2).maxLines(1).textOverflow({overflow:TextOverflow.Ellipsis}).layoutWeight(1)
    if(it.status==='pending'){LoadingProgress().width(12).height(12).color(BLUE)}
    if(it.status==='success'){Text('✓').fontSize(this.fs(12)).fontColor(INK3)}
    if(it.status==='error'){Text('没成功').fontSize(this.fs(12)).fontColor(INK3)}
    if(it.status==='skipped'){Text('未执行').fontSize(this.fs(12)).fontColor(INK3)}
    if(it.status==='uncertain'){Text('不确定').fontSize(this.fs(12)).fontColor(INK3)}
   }.width('100%').onClick(()=>{this.toggleRecord(it.id);})
   if(this.isOpen(it.id)){
    Column({space:6}){
     if(it.sources?.length){ForEach(it.sources,(source:WebSource)=>{Text(source.title+' · '+source.domain).fontSize(this.fs(13)).fontColor(BLUE).onClick(()=>{const context=this.getUIContext().getHostContext() as common.UIAbilityContext;context.startAbility({action:'ohos.want.action.viewData',uri:source.url}).catch(()=>{this.message='无法打开来源链接';});})},(source:WebSource)=>source.url)}
     this.detailBlock('参数',it.args)
     this.detailBlock('结果',it.result)
     this.detailBlock('动作前观察',it.observation)
    }.width('100%').padding({left:12}).border({width:{left:2},color:LINE}).margin({left:7,bottom:2}).alignItems(HorizontalAlign.Start)
   }
  }.width('100%').padding({left:18,top:3,bottom:3})
 }
 @Builder smallIcon(p:IconBtnP){
  Row(){Row(){this.icon({res:p.res,size:18,color:p.active?GOLD:INK3})}.width(36).height(36).justifyContent(FlexAlign.Center).borderRadius(18)}.width(44).height(44).justifyContent(FlexAlign.Center).onClick(()=>{p.action();})
 }
 @Builder usageRow(p:UsageRowP){
  Row({space:16}){
   Text(p.label).fontSize(this.fs(14)).fontColor(INK3)
   Blank()
   Text(p.value).fontSize(this.fs(14)).fontColor(INK).maxLines(1).textOverflow({overflow:TextOverflow.Ellipsis})
  }.width('100%').padding({top:7,bottom:7})
 }
 @Builder usageBody(u:Usage){
  Column(){
   Row({space:8}){
    this.icon({res:$r('sys.symbol.externaldrive'),size:18,color:INK2})
    Text('本轮用量').fontSize(this.fs(15)).fontColor(INK).layoutWeight(1)
    Text(groupDigits(u.total)+' tok').fontSize(this.fs(15)).fontWeight(FontWeight.Bold).fontColor(INK)
   }.width('100%').padding({bottom:10})
   Divider().color(LINE)
   this.usageRow({label:'提供方 / 模型',value:u.model})
   this.usageRow({label:'缓存命中率',value:this.hitRate(u)})
   this.usageRow({label:'未缓存输入',value:groupDigits(u.input)+' tok'})
   this.usageRow({label:'缓存读取',value:groupDigits(u.cacheRead)+' tok'})
   this.usageRow({label:'缓存写入',value:groupDigits(u.cacheWrite)+' tok'})
   this.usageRow({label:'输出',value:groupDigits(u.output)+' tok'})
   Text('共 '+u.calls+' 次模型调用').fontSize(this.fs(12)).fontColor(INK3).margin({top:6})
  }.width(420).padding(18).alignItems(HorizontalAlign.Start)
 }
 @Builder usagePopup(){
  Column(){
   if(this.usageTask()){this.usageBody(this.usageTask()!)}
  }
 }
 @Builder actionsRow(it:TimelineItem){
  Row({space:2}){
   this.smallIcon({res:$r('sys.symbol.rectangle_on_rectangle'),active:false,action:()=>{this.copyText(it.text);}})
   this.smallIcon({res:this.isFav(it.id)?$r('sys.symbol.star_fill'):$r('sys.symbol.star'),active:this.isFav(it.id),action:()=>{this.toggleFav(it.id,it.text);}})
   this.smallIcon({res:$r('sys.symbol.share'),active:false,action:()=>{this.branchFrom(it.id);}})
   if(this.usageText(it.id)){
    Row({space:6}){
     this.icon({res:$r('sys.symbol.externaldrive'),size:15,color:INK3})
     Text('用量 '+this.usageText(it.id)+' tok').fontSize(this.fs(13)).fontColor(INK3)
    }.height(44).padding({left:10,right:8}).onClick(()=>{this.usageOpen=it.id;}).bindPopup(this.usageOpen===it.id,{builder:this.usagePopup,placement:Placement.Top,popupColor:WHITE,enableArrow:false,radius:16,onStateChange:(e:PopupStateChangeParam)=>{if(!e.isVisible)this.usageOpen='';}})
   }
   Text(formatClock(it.time)).fontSize(this.fs(13)).fontColor(INK3).margin({left:4})
  }.width('100%').padding({top:0,left:2})
 }
 @Builder timelineItem(it:TimelineItem){
  if(it.kind==='screen'){Column({space:5}){Text(it.summary).fontSize(this.fs(12)).fontColor(INK3);Image('file://'+it.result).width(this.isOpen(it.id)?'100%':180).height(this.isOpen(it.id)?420:120).objectFit(ImageFit.Contain).borderRadius(8).onClick(()=>{this.toggleRecord(it.id);})}.alignItems(HorizontalAlign.Start).padding({top:6,bottom:6})}
  else if(it.kind==='user'){
   Text(it.text).fontSize(this.fs(16)).lineHeight(this.fs(25)).fontColor(INK).copyOption(CopyOptions.LocalDevice).padding({left:16,right:16,top:10,bottom:10}).borderRadius(18).backgroundColor(BLUE_SOFT).constraintSize({maxWidth:560}).alignSelf(ItemAlign.End).margin({top:6})
  }else if(it.kind==='assistant'){
   this.rich(it.text,this.isRunning()&&it.text===this.cur()?.progress?it.key:'')
  }else if(it.kind==='taskhead'){
   this.taskHead(it)
  }else if(it.kind==='group'){
   this.groupHead(it)
  }else if(it.kind==='think'){
   this.thinkRow(it)
  }else if(it.kind==='actions'){
   this.actionsRow(it)
  }else if(it.kind==='tool'&&['file_write','file_edit','document_create','document_replace_paragraph','document_append','sheet_create','sheet_update_cells','sheet_append_rows','presentation_create','presentation_replace_paragraph','presentation_append','presentation_delete','presentation_insert_image','pdf_create','image_convert','zip_extract','web_download'].includes(it.name)&&it.status==='success'){
   FileCard({fileId:fileInfo(it.result).fileId,name:fileInfo(it.result).name,bytes:fileInfo(it.result).bytes,fontScale:this.fontScale,onPreview:(id:string)=>{return this.previewFile(id);},onSave:(id:string)=>{this.exportOffice(id);},onDelete:(id:string)=>{return this.deleteFile(id,fileInfo(it.result).name);}})
  }else if(it.kind==='tool'&&['skill_save','skill_set_enabled','skill_delete','skill_rollback','memory_save','memory_forget'].includes(it.name)&&it.status==='success'){
   LearnCard({title:learnInfo(it.name,it.args,it.result).title,detail:it.result,fontScale:this.fontScale,onUndo:()=>{return this.undoLearn(it);}})
  }else if(it.kind==='tool'){
   this.toolRow(it)
  }else{
   Text(this.shorten(it.text,400)).fontSize(this.fs(13)).fontColor(INK3).width('100%').padding({left:2})
  }
 }
 @Builder live(){
  if(this.isRunning()){
   Row({space:8}){
    LoadingProgress().width(16).height(16).color(BLUE)
    Text(statusLabel(this.curStatus())+(this.cur()?.currentAction?' · '+this.cur()!.currentAction:'')).fontSize(this.fs(14)).fontColor(INK3).maxLines(2).layoutWeight(1)
   }.width('100%').padding({left:2,top:2,bottom:2})
  }
 }
 @Builder approval(){
  if(this.eng()?.approval){
   Column({space:10}){
    Text('需要你确认').fontSize(this.fs(13)).fontWeight(FontWeight.Medium).fontColor(BLUE)
    Text(this.eng()!.approval).fontSize(this.fs(15)).fontColor(INK).width('100%')
    if(this.eng()?.approvalScope){Row({space:8}){Checkbox({name:'remember'}).onChange((v:boolean)=>{if(this.engine)this.engine.approvalRemember=v;});Text(this.eng()!.approvalScope).fontSize(this.fs(13)).fontColor(INK2)}}
    // 0.8.6 阶段 3：两个按钮等宽，同意在右。
    Row({space:10}){
     this.pill({label:'拒绝',primary:false,enabled:true,grow:true,action:()=>{this.eng()?.approve(false);}})
     this.pill({label:'同意此操作',primary:true,enabled:true,grow:true,action:()=>{this.eng()?.approve(true);}})
    }.width('100%')
   }.width('100%').padding(14).borderRadius(14).backgroundColor(BLUE_SOFT).border({width:1,color:BLUE_LINE}).alignItems(HorizontalAlign.Start)
  }
 }
 @Builder empty(){
  Column({space:10}){
   Text('今天想完成什么？').fontSize(this.fs(28)).fontWeight(FontWeight.Bold).fontColor(INK)
   Text('我是大肥鱼。想聊点什么，或者有什么事情要我帮忙？').fontSize(this.fs(15)).fontColor(INK3).textAlign(TextAlign.Center)
   Flex({direction:FlexDirection.Row,wrap:FlexWrap.Wrap,justifyContent:FlexAlign.Center}){
    ForEach(STARTERS,(t:string)=>{
     Row(){Text(t).fontSize(this.fs(13)).fontColor(BLUE_DEEP)}.height(40).padding({left:14,right:14}).margin({left:4,right:4,top:4,bottom:4}).borderRadius(20).backgroundColor(BLUE_SOFT).onClick(()=>{this.input=t;})
    },(t:string)=>t+this.fontScale)
   }.width('100%').margin({top:8})
  }.width('100%').padding({left:20,right:20,bottom:30}).alignItems(HorizontalAlign.Center)
 }

 // ───────── 输入框（DS：蓝色浅底胶囊 + 右侧圆形发送） ─────────
 @Builder composer(){
  Column(){
   if(this.attachments.length){AttachmentStrip({items:this.attachments,onRemove:(id:string)=>{this.removeAttachment(id);}})}
   // 0.8.6：待办条移到输入区上沿（仅有内容时出现）。
   TodoBar({items:copyTodos(this.eng()?.session().todos),fontScale:this.fontScale,onClear:()=>{this.clearTodos();}})
   Stack({alignContent:Alignment.TopEnd}){
    Row(){
     // 0.8.6 阶段 4：/计划、/目标 以蓝色前缀 token 显示在输入框内容区左侧；点击 token 或输入为空时按退格即可移除。
     if(this.isPlanning()){Text('/计划').fontSize(this.fs(16)).fontColor(BLUE_DEEP).margin({left:18,top:14,right:4}).onClick(()=>{this.togglePlanMode();})}
     if(this.composerGoal){Text('/目标').fontSize(this.fs(16)).fontColor(BLUE_DEEP).margin({left:this.isPlanning()?0:18,top:14,right:4}).onClick(()=>{this.composerGoal=false;})}
     TextArea({text:this.input,placeholder:this.inputPlaceholder()}).onChange((v:string)=>{this.composerChange(v);}).onKeyEvent((event:KeyEvent)=>{if(event.type!==KeyType.Down)return;if(event.keyCode===KeyCode.KEYCODE_TAB&&!this.input&&this.eng()?.session().suggestion){this.input=this.eng()!.session().suggestion!;event.stopPropagation();return;}if(event.keyCode===KeyCode.KEYCODE_DEL&&!this.input){if(this.composerGoal){this.composerGoal=false;event.stopPropagation();}else if(this.isPlanning()&&!this.isRunning()){this.togglePlanMode();event.stopPropagation();}}}).fontSize(this.fs(16)).fontColor(INK).placeholderColor(INK3).placeholderFont({size:this.fs(16)}).backgroundColor(Color.Transparent).borderRadius(0).padding({left:this.hasComposerToken()?0:18,right:18,top:14,bottom:0}).constraintSize({minHeight:48,maxHeight:150}).layoutWeight(1)
    }.width('100%').alignItems(VerticalAlign.Top)
    // 建议存在且输入为空时，建议已作为 placeholder 显示；这里给一个「采用 Tab」胶囊，点击才填入。
    if(!this.input&&this.eng()?.session().suggestion&&!this.isRunning()){Row(){Text('采用 Tab').fontSize(this.fs(12)).fontColor(INK2).padding({left:10,right:10,top:4,bottom:4}).borderRadius(12).backgroundColor(SURFACE)}.height(44).margin({top:2,right:14}).onClick(()=>{this.input=this.eng()!.session().suggestion!;})}
   }.width('100%')
   Row({space:8}){
    Row(){Row(){SymbolGlyph($r('sys.symbol.plus')).fontSize(19).fontColor([INK2])}.width(36).height(36).justifyContent(FlexAlign.Center).borderRadius(18).backgroundColor(SURFACE)}.width(44).height(44).justifyContent(FlexAlign.Center).onClick(()=>{this.plusOpen=!this.plusOpen;})
    // 0.8.6 阶段 4：工具行（左→右）：＋、文件胶囊（有文件才出现）、弹性空白、模型胶囊、取消（运行中或已暂停）、主按钮。计划开关移到 /计划 token。
    if(this.fileCount()>0){this.softChip({res:$r('sys.symbol.folder'),label:this.fileCount()+' 个文件',fg:BLUE_DEEP,bg:BLUE_SOFT,action:()=>{this.goSettings('data');}})}
    Blank()
    Row(){Row({space:4}){Text(this.activeModel()).fontSize(this.fs(13)).fontColor(INK2).maxLines(1);Text(this.effortName()).fontSize(this.fs(12)).fontColor(INK3);this.icon({res:$r('sys.symbol.chevron_down'),size:11,color:INK3})}.height(36).padding({left:12,right:10}).borderRadius(18).border({width:1,color:LINE})}.height(44).onClick(()=>{if(this.modelMenuOpen){this.modelMenuOpen=false;return;}this.modelMenuPage='root';this.modelMenuOpen=true;}).bindPopup(this.modelMenuOpen,{builder:this.modelPopup,placement:Placement.Top,popupColor:WHITE,enableArrow:false,radius:16,focusable:false,onStateChange:(event:PopupStateChangeParam)=>{if(!event.isVisible)this.modelMenuOpen=false;}})
    if(this.canCancel()){Row(){Text('取消').fontSize(this.fs(14)).fontColor(INK3)}.height(44).padding({left:10,right:10}).onClick(()=>{this.eng()?.pause('用户取消',true);})}
    // 主按钮随状态变：发送 / 暂停 / 发送补充 / 继续。无障碍文字保留「暂停」「继续」「发送」。
    Row(){Row(){SymbolGlyph(this.mainIcon()).fontSize(19).fontColor([WHITE])}.width(36).height(36).justifyContent(FlexAlign.Center).borderRadius(18).backgroundColor(this.mainMode()==='idle'?BLUE_LINE:BLUE)}.width(44).height(44).justifyContent(FlexAlign.Center).accessibilityText(this.mainLabel()).onClick(()=>{this.mainAction();})
   }.width('100%').padding({left:12,right:12,bottom:10,top:6})
  }.width('100%').borderRadius(22).backgroundColor(WHITE).border({width:1,color:LINE}).shadow({radius:16,color:'#14000000',offsetY:3}).bindPopup(this.plusOpen,{builder:this.commandPopup,placement:Placement.TopLeft,offset:{x:0,y:-6},popupColor:WHITE,enableArrow:false,radius:16,focusable:false,onStateChange:(event:PopupStateChangeParam)=>{if(!event.isVisible){this.plusOpen=false;this.slashMode=false;}}})
 }

 // ───────── 页面：对话 / 轨迹 / 设置 / 扩展 ─────────
 @Builder chatPage(){
  Column(){
   this.harnessBar()
   if(!this.hasMessages()){
    Column(){this.empty()}.layoutWeight(1).width('100%').justifyContent(FlexAlign.Center)
   }else{
     Scroll(this.chatScroll){
      Column(){
       Column({space:6}){
        ForEach(this.timeline(),(it:TimelineItem)=>{this.timelineItem(it)},(it:TimelineItem)=>this.itemKey(it))
        this.live()
        if(this.pendingAsk()){AskCard({question:this.pendingAsk()!.question,options:this.pendingAsk()!.options,fontScale:this.fontScale,onPick:(l:string)=>{this.answer(l);}})}

       }.width('100%').constraintSize({maxWidth:CHAT_WIDTH}).alignItems(HorizontalAlign.Start).padding({left:20,right:20,top:14,bottom:14})
      }.width('100%').alignItems(HorizontalAlign.Center)
     }.layoutWeight(1).width('100%').scrollBar(BarState.Off).align(Alignment.Top).onDidScroll(()=>{this.follow=this.chatScroll.isAtEnd();}).onAppear(()=>{this.follow=true;this.scrollToEnd();})
   }
   Column(){Column(){this.composer();StatusBar({view:this.statusView(),onResume:()=>{this.eng()?.start().catch(()=>{this.message='没有可恢复任务';});},onCompress:()=>{this.compressContext();}})}.width('100%').constraintSize({maxWidth:CHAT_WIDTH})}.width('100%').padding({left:20,right:20,top:4,bottom:this.bottomGap()}).alignItems(HorizontalAlign.Center)
  }.layoutWeight(1).width('100%')
 }
 @Builder harnessBar(){
  if(this.eng()?.session().goal||this.eng()?.session().plan||this.eng()?.session().context){
   Row({space:8}){
    if(this.eng()?.session().goal){Text('目标：'+this.shorten(this.eng()!.session().goal!.objective,40)+(this.eng()!.session().goal!.status==='ended'?'（已结束）':'')).fontSize(this.fs(12)).fontColor(BLUE).maxLines(1).layoutWeight(1).onClick(()=>{this.openGoal();})}
    if(this.eng()?.session().plan){Text('计划 · '+this.eng()!.session().plan!.steps.filter(v=>v.status==='completed').length+'/'+this.eng()!.session().plan!.steps.length).fontSize(this.fs(12)).fontColor(BLUE).onClick(()=>{this.panel='plan';})}
    if(this.eng()?.session().context){Text('已压缩 · 约'+formatTokens(this.eng()!.session().context!.after)+' tok').fontSize(this.fs(12)).fontColor(INK3).onClick(()=>{this.panel='context';})}
   }.width('100%').padding({left:20,right:20,top:7,bottom:7}).backgroundColor(BLUE_SOFT)
  }
 }
 @Builder goalPage(){
  Scroll(){
   Column({space:12}){
    this.sectionTitle('当前会话目标')
    Text('要完成什么').fontSize(this.fs(14)).fontColor(INK2)
    TextArea({text:this.goalText,placeholder:'例如：制作学习预算表格和两页汇报PPT'}).onChange((v:string)=>{this.goalText=v;}).height(90).width('100%').backgroundColor(SURFACE)
    Text('完成标准，每行一条').fontSize(this.fs(14)).fontColor(INK2)
    TextArea({text:this.goalCriteria}).onChange((v:string)=>{this.goalCriteria=v;}).height(90).width('100%').backgroundColor(SURFACE)
    Text('约束，每行一条').fontSize(this.fs(14)).fontColor(INK2)
    TextArea({text:this.goalConstraints,placeholder:'例如：原件保留'}).onChange((v:string)=>{this.goalConstraints=v;}).height(90).width('100%').backgroundColor(SURFACE)
    Row({space:10}){
     this.pill({label:'保存目标',primary:true,enabled:!this.isRunning(),action:()=>{try{this.eng()?.setGoal(this.goalText,this.goalCriteria.split('\n'),this.goalConstraints.split('\n'));this.panel='chat';}catch(error){this.message=(error as Error).message;}}})
     this.pill({label:'结束目标',primary:false,enabled:!this.isRunning(),action:()=>{try{this.eng()?.endGoal();this.panel='chat';}catch(error){this.message=(error as Error).message;}}})
     this.pill({label:'返回对话',primary:false,enabled:true,action:()=>{this.panel='chat';}})
    }
   }.width('100%').constraintSize({maxWidth:CHAT_WIDTH}).padding(24).alignItems(HorizontalAlign.Start)
  }.layoutWeight(1).width('100%')
 }
 @Builder planPage(){
  Scroll(){
   Column({space:12}){
    this.sectionTitle('会话计划')
    if(this.eng()?.session().plan){
     this.rich(this.eng()!.session().plan!.text)
     ForEach(this.eng()!.session().plan!.steps,(step:importPlanStep)=>{
      Column({space:4}){Text(step.id+' · '+step.title+' · '+step.status).fontSize(this.fs(14)).fontColor(INK);if(step.evidence){Text(step.evidence).fontSize(this.fs(12)).fontColor(INK3)}}.width('100%').alignItems(HorizontalAlign.Start)
     },(step:importPlanStep)=>step.id+step.status+step.evidence)
     this.pill({label:this.eng()!.session().plan!.status==='draft'?'按此计划开始':'继续计划',primary:true,enabled:!this.isRunning()&&['draft','paused'].includes(this.eng()!.session().plan!.status),action:()=>{this.panel='chat';this.eng()?.beginPlan().catch((error:Error)=>{this.message=error.message;});}})
    }else{Text('进入计划模式后，在聊天中交代目标并形成计划草案').fontSize(this.fs(14)).fontColor(INK3)}
    this.pill({label:'返回对话修改',primary:false,enabled:!this.isRunning(),action:()=>{if(this.eng()){this.eng()!.session().planning=true;this.eng()!.save();}this.panel='chat';}})
   }.width('100%').constraintSize({maxWidth:CHAT_WIDTH}).padding(24).alignItems(HorizontalAlign.Start)
  }.layoutWeight(1).width('100%')
 }
 @Builder contextPage(){
  Scroll(){Column({space:12}){
   this.sectionTitle('上下文摘要')
   if(this.eng()?.session().context){Text('估算 '+formatTokens(this.eng()!.session().context!.before)+' → '+formatTokens(this.eng()!.session().context!.after)+' tok，非提供商精确计数').fontSize(this.fs(13)).fontColor(INK3);Text(this.compactLine()).fontSize(this.fs(13)).fontColor(INK3);this.rich(this.eng()!.session().context!.summary)}
   Text('原始聊天与工具记录仍保存；摘要影响后续发送内容').fontSize(this.fs(13)).fontColor(INK3)
   this.switchRow('回放前缀压缩','关闭后改用 0.8.3 的旧方式压缩，用来对比缓存命中率',this.eng()?.state.compactReplay===true,(v:boolean)=>{const e=this.eng();if(e){e.state.compactReplay=v;e.save();}})
   this.pill({label:'返回对话',primary:false,enabled:true,action:()=>{this.panel='chat';}})
  }.width('100%').constraintSize({maxWidth:CHAT_WIDTH}).padding(24).alignItems(HorizontalAlign.Start)}.layoutWeight(1).width('100%')
 }
 @Builder tracePage(){
  Scroll(){
   Column({space:12}){
    if(!this.traceTasks().length){Text('还没有任务轨迹').fontSize(this.fs(15)).fontColor(INK3).margin({top:60})}
    ForEach(this.traceTasks(),(t:Task)=>{
     Column({space:6}){
      Row({space:10}){
       Text(t.goal).fontSize(this.fs(15)).fontWeight(FontWeight.Medium).fontColor(INK).layoutWeight(1)
       Text(statusLabel(t.status)).fontSize(this.fs(12)).fontColor(t.status==='paused'||t.status==='cancelled'?ORANGE:INK3).padding({left:9,right:9,top:3,bottom:3}).borderRadius(10).border({width:1,color:LINE})
      }.width('100%')
      if(t.reason&&t.status!=='completed'){Text(this.shorten(t.reason,300)).fontSize(this.fs(12)).fontColor(INK3).width('100%')}
      Text('工具调用 '+t.calls+' 次 · 共 '+t.records.length+' 条记录').fontSize(this.fs(12)).fontColor(INK3)
      Divider().color(LINE)
      ForEach(t.records,(r:ToolRecord)=>{this.toolRow(toolItem(r))},(r:ToolRecord)=>r.id+r.status+r.result.length+(this.isOpen(r.id)?'o':'c')+this.fontScale)
     }.width('100%').alignItems(HorizontalAlign.Start).padding(14).borderRadius(14).backgroundColor(WHITE).border({width:1,color:LINE})
    },(t:Task)=>t.id+t.status+t.records.length+t.calls+this.fontScale)
   }.width('100%').constraintSize({maxWidth:CHAT_WIDTH}).padding({left:20,right:20,top:14,bottom:this.bottomGap()+14})
  }.layoutWeight(1).width('100%').scrollBar(BarState.Off).align(Alignment.Top).backgroundColor(WHITE)
 }
 @Builder heatChart(){
  Column({space:6}){
   Row({space:3}){
    ForEach(this.heatData(),(w:HeatWeek)=>{
     Column({space:3}){
      ForEach(w.cells,(c:HeatCell)=>{
       Column().width(9).height(9).borderRadius(2.5).backgroundColor(c.future?Color.Transparent:HEAT[c.level]).onClick(()=>{if(!c.future)this.toast(c.day+' · '+groupDigits(c.total)+' tok');})
      },(c:HeatCell)=>c.day+c.level)
     }
    },(w:HeatWeek)=>w.key+w.cells.map((c:HeatCell)=>c.level).join(''))
   }
   Stack({alignContent:Alignment.TopStart}){
    ForEach(this.monthLabels(),(m:MonthLabel)=>{Text(m.text).fontSize(this.fs(11)).fontColor(INK3).position({x:m.x,y:0})},(m:MonthLabel)=>m.text+m.x)
   }.width('100%').height(this.fs(18))
   Row({space:4}){
    Blank()
    Text('少').fontSize(this.fs(11)).fontColor(INK3)
    ForEach(HEAT,(c:string)=>{Column().width(9).height(9).borderRadius(2.5).backgroundColor(c)},(c:string)=>c)
    Text('多').fontSize(this.fs(11)).fontColor(INK3)
   }.width('100%')
  }.alignItems(HorizontalAlign.Start).width('100%')
 }
 @Builder barChart(){
  Column({space:6}){
   Row({space:4}){
    ForEach(this.barData(),(b:BarView)=>{
     Column(){
      Blank()
      Column().width(18).height(b.h).borderRadius(4).backgroundColor(b.total>0?BLUE:HEAT[0])
     }.height(140).justifyContent(FlexAlign.End).onClick(()=>{this.toast('周起 '+b.label+' · '+groupDigits(b.total)+' tok');})
    },(b:BarView)=>b.label+b.total)
   }.alignItems(VerticalAlign.Bottom)
   Row(){
    Text(this.barData()[0]?.label??'').fontSize(this.fs(11)).fontColor(INK3)
    Blank()
    Text('本周').fontSize(this.fs(11)).fontColor(INK3)
   }.width('100%')
  }.alignItems(HorizontalAlign.Start).width('100%')
 }
 @Builder statsPage(){
  Scroll(){
   Column({space:22}){
    Column({space:8}){
     Image($r('app.media.avatar')).width(96).height(96).borderRadius(48).border({width:1,color:LINE})
     Text(USER_NAME).fontSize(this.fs(26)).fontWeight(FontWeight.Bold).fontColor(INK)
     Text(APP_NAME+' · '+VERSION).fontSize(this.fs(13)).fontColor(INK3)
    }.width('100%').alignItems(HorizontalAlign.Center).padding({top:8})
    Row(){
     ForEach(this.statCells(),(c:StatCell,i:number)=>{
      Column({space:4}){
       Text(c.value).fontSize(this.fs(18)).fontWeight(FontWeight.Medium).fontColor(INK).maxLines(1)
       Text(c.label).fontSize(this.fs(12)).fontColor(INK3).maxLines(1)
      }.layoutWeight(1).alignItems(HorizontalAlign.Center).padding({top:16,bottom:16}).border({width:{left:i>0?1:0},color:LINE})
     },(c:StatCell,i:number)=>c.label+c.value+this.fontScale)
    }.width('100%').borderRadius(16).border({width:1,color:LINE})
    Column({space:14}){
     Row(){
      Text('Token 活动').fontSize(this.fs(16)).fontWeight(FontWeight.Medium).fontColor(INK).layoutWeight(1)
      Row({space:16}){
       ForEach(this.modeOptions(),(m:ModeOpt)=>{
        Text(m.label).fontSize(this.fs(14)).fontColor(this.statsMode===m.key?INK:INK3).fontWeight(this.statsMode===m.key?FontWeight.Medium:FontWeight.Normal).onClick(()=>{this.statsMode=m.key;})
       },(m:ModeOpt)=>m.key+(this.statsMode===m.key?'1':'0')+this.fontScale)
      }
     }.width('100%')
     if(this.statsMode==='day'){this.heatChart()}else{this.barChart()}
    }.width('100%').alignItems(HorizontalAlign.Start)
    Text('Token 数从 0.4.28 起逐次记录，此前的任务没有用量数据；连续天数按“有任务运行”的日期计算；每周与累计图表按周统计，最近 26 周。').fontSize(this.fs(12)).fontColor(INK3).lineHeight(this.fs(18))
   }.width('100%').constraintSize({maxWidth:CHAT_WIDTH}).padding({left:20,right:20,top:14,bottom:this.bottomGap()+14})
  }.layoutWeight(1).width('100%').scrollBar(BarState.Off).align(Alignment.Top).backgroundColor(WHITE)
 }
 @Builder favoritesPage(){
  Scroll(){
   Column({space:12}){
    if(!this.favorites().length){
     Column({space:12}){
      this.icon({res:$r('sys.symbol.star'),size:38,color:INK3})
      Text('还没有收藏').fontSize(this.fs(17)).fontColor(INK)
      Text('点击回复下方的星标，就会收藏到这里').fontSize(this.fs(14)).fontColor(INK3)
     }.width('100%').padding({top:150}).alignItems(HorizontalAlign.Center)
    }
    ForEach(this.favorites(),(f:Favorite)=>{
     Column({space:10}){
      Row({space:8}){
       Text(f.sessionTitle+' · '+formatClock(f.time)).fontSize(this.fs(12)).fontColor(INK3).maxLines(1).textOverflow({overflow:TextOverflow.Ellipsis}).layoutWeight(1)
       Row(){this.icon({res:$r('sys.symbol.star_fill'),size:19,color:GOLD})}.width(34).height(34).justifyContent(FlexAlign.Center).onClick(()=>{this.removeFav(f.id);})
      }.width('100%')
      if(f.goal){Text(f.goal).fontSize(this.fs(15)).fontWeight(FontWeight.Medium).fontColor(INK).maxLines(2).textOverflow({overflow:TextOverflow.Ellipsis}).width('100%')}
      this.rich(f.reply)
      Row({space:10}){
       this.pill({label:'复制',primary:false,enabled:true,action:()=>{this.copyText(f.reply);}})
       this.pill({label:'打开会话',primary:false,enabled:!this.isRunning(),action:()=>{this.openFavSession(f);}})
      }
     }.width('100%').alignItems(HorizontalAlign.Start).padding(16).borderRadius(14).backgroundColor(WHITE).border({width:1,color:LINE})
    },(f:Favorite)=>f.id+f.time+this.fontScale+(this.isRunning()?'r':'i'))
   }.width('100%').constraintSize({maxWidth:CHAT_WIDTH}).padding({left:20,right:20,top:14,bottom:this.bottomGap()+14})
  }.layoutWeight(1).width('100%').scrollBar(BarState.Off).align(Alignment.Top).backgroundColor(WHITE)
 }
 @Builder settingsPage(){SettingsShell({group:this.settingsKey(),compact:this.compact(),onSelect:(id:string)=>{this.settingsGroup=id;},content:()=>{this.settingsContent();}})}
 // 0.8.6 阶段 2：「技能与记忆」⋯ 菜单，「保存示例」收在这里。
 skillMoreMenu():MenuElement[]{return [{value:'保存示例',action:()=>{this.exportExample();}}];}
 // 0.8.6 阶段 2：模型页自带底部固定「保存并使用」，不随滚动消失；用量保持原样；其余分组放进可滚动区。
 @Builder settingsContent(){
 if(this.settingsKey()==='usage'){this.statsPage()}
 else if(this.settingsKey()==='model'){this.settingsModel()}
 else{Scroll(){Column({space:12}){
  if(this.settingsKey()==='general'){this.settingsGeneral()}
  else if(this.settingsKey()==='skills'){this.settingsSkills()}
  else if(this.settingsKey()==='tools'){this.settingsTools()}
  else if(this.settingsKey()==='execution'){this.settingsBudget()}
  else if(this.settingsKey()==='data'){this.settingsData()}
  else if(this.settingsKey()==='about'){this.settingsAbout()}
 }.width('100%').padding(16).alignItems(HorizontalAlign.Start)}.width('100%').layoutWeight(1).scrollBar(BarState.Off).align(Alignment.Top)}
 }
 // 折叠区标题（「高级」「开发者」）：默认折叠，点击整行切换。
 @Builder foldHead(p:FoldP){
  Row({space:6}){
   Text(p.label).fontSize(this.fs(14)).fontColor(INK2).layoutWeight(1)
   this.icon({res:p.open?$r('sys.symbol.chevron_up'):$r('sys.symbol.chevron_down'),size:14,color:INK3})
  }.width('100%').height(44).onClick(()=>{p.action();})
 }
 @Builder settingsGeneral(){
  Column({space:12}){
   Column({space:12}){
    this.sectionTitle('显示')
    Row(){
     Text('字号').fontSize(this.fs(14)).fontColor(INK).layoutWeight(1)
     Text(this.scaleName()+' · '+(this.scaleLevel()+1)+' / 8').fontSize(this.fs(13)).fontColor(BLUE)
    }.width('100%')
    Row({space:12}){
     Text('特小').fontSize(12).fontColor(INK3)
     Slider({value:this.scaleLevel(),min:0,max:7,step:1,style:SliderStyle.OutSet}).showSteps(true).trackThickness(4).selectedColor(BLUE).trackColor(LINE).blockColor(WHITE).layoutWeight(1).onChange((v:number,mode:SliderChangeMode)=>{this.setScale(0.8+Math.round(v)*0.05,mode===SliderChangeMode.End);})
     Text('大').fontSize(12).fontColor(INK3)
    }.width('100%')
    Text('预览：先回到桌面，再点击计算器上的数字 7。').fontSize(this.fs(16)).fontColor(INK).lineHeight(this.fs(25)).padding({left:14,right:14,top:10,bottom:10}).borderRadius(12).border({width:1,color:LINE}).width('100%')
   }.width('100%').padding(16).borderRadius(14).backgroundColor(WHITE).border({width:1,color:LINE}).alignItems(HorizontalAlign.Start)
   Column({space:10}){
    this.sectionTitle('行为')
    this.switchRow('任务结束后回到大肥鱼','操作其他应用的任务结束（含暂停）时自动切回大肥鱼',this.eng()?.state.returnToSelf!==false,(v:boolean)=>{if(this.engine){this.engine.state.returnToSelf=v;this.engine.save();}})
   }.width('100%').padding(16).borderRadius(14).backgroundColor(WHITE).border({width:1,color:LINE}).alignItems(HorizontalAlign.Start)
   Column({space:10}){
    this.sectionTitle('小窗')
    Text('大肥鱼可收成悬浮窗；窗口变窄后会自动切换到紧凑布局。').fontSize(this.fs(13)).fontColor(INK3).width('100%')
    this.pill({label:'切换到小窗',primary:false,enabled:true,action:()=>{this.enterFloat();}})
    this.foldHead({label:'高级：小窗截图策略',open:this.advGeneral,action:()=>{this.advGeneral=!this.advGeneral;}})
    if(this.advGeneral){
     Column({space:6}){
      Text('小窗截图隐形策略（默认 V3；V1/V2 真机不可行，见 FLOAT 文档）').fontSize(this.fs(13)).fontColor(INK3)
      Row({space:8}){
       ForEach(FLOAT_STRATEGIES,(v:string)=>{
        Text(strategyLabel(v)).id('float_strategy_'+v).fontSize(this.fs(13)).fontColor(normalizeStrategy(this.eng()?.state.floatStrategy)===v?BLUE_DEEP:INK2).padding({left:12,right:12,top:6,bottom:6}).borderRadius(16).backgroundColor(normalizeStrategy(this.eng()?.state.floatStrategy)===v?BLUE_SOFT:WHITE).border({width:1,color:LINE}).onClick(()=>{if(this.engine){this.engine.state.floatStrategy=v;this.engine.save();}})
       },(v:string)=>v+normalizeStrategy(this.eng()?.state.floatStrategy)+this.fontScale)
      }
      Text('只在大肥鱼以悬浮窗显示时生效：截图前让小窗隐形，布局中剔除自身节点，点击等注入期间小窗不接收触摸。隐形失败或选“仅灰块遮盖”时，截图中小窗区域涂灰，点到该区域返回 SELF_OVERLAP。').fontSize(this.fs(12)).fontColor(INK3)
     }.width('100%').alignItems(HorizontalAlign.Start)
    }
   }.width('100%').padding(16).borderRadius(14).backgroundColor(WHITE).border({width:1,color:LINE}).alignItems(HorizontalAlign.Start)
  }.width('100%')
 }
 // 模型页：可滚动区 + 底部固定「保存并使用」。原校验逻辑在 saveProfile / 各 onChange 里，未改动。
 @Builder settingsModel(){
  Column(){
   Scroll(){
    Column({space:12}){
     Column({space:10}){
      this.sectionTitle('模型配置')
      Row({space:8}){
       ForEach(this.profiles(),(p:Profile)=>{
        Text(p.title).fontSize(this.fs(14)).fontColor(p.id===this.profileId?BLUE_DEEP:INK2).padding({left:14,right:14,top:6,bottom:6}).borderRadius(16).backgroundColor(p.id===this.profileId?BLUE_SOFT:WHITE).border({width:1,color:p.id===this.profileId?BLUE_SOFT:LINE}).onClick(()=>{this.loadProfile(p.id);})
       },(p:Profile)=>p.id+p.title+(p.id===this.profileId?'a':'b')+this.fontScale)
       Row({space:4}){this.icon({res:$r('sys.symbol.plus'),size:13,color:INK2});Text('新配置').fontSize(this.fs(14)).fontColor(INK2)}.padding({left:12,right:14,top:6,bottom:6}).borderRadius(16).border({width:1,color:LINE}).onClick(()=>{this.profileId=uid();this.protocol='chat-completions';this.title='新模型';this.apiKey='';this.keyConfigured=false;})
      }
      this.field('配置名称',this.title,(v:string)=>{this.title=v;})
      this.field('Base URL（必须以 https:// 开头）',this.baseUrl,(v:string)=>{this.baseUrl=v;})
      Column({space:6}){
       Text('协议').fontSize(this.fs(13)).fontColor(INK3)
       Row({space:8}){ForEach(['chat-completions','messages'],(v:string)=>{Text(v==='messages'?'Messages':'Chat Completions').fontSize(14).fontColor(this.protocol===v?BLUE_DEEP:INK2).padding(10).borderRadius(16).backgroundColor(this.protocol===v?BLUE_SOFT:WHITE).onClick(()=>{this.protocol=v;})})}
      }.width('100%').alignItems(HorizontalAlign.Start)
      this.field('模型',this.model,(v:string)=>{this.model=v;})
      Column({space:6}){
       Row(){
        Text(this.keyConfigured?'API Key · 已加密保存':'API Key · 尚未配置').fontSize(this.fs(13)).fontColor(this.keyConfigured?GREEN:INK3).layoutWeight(1)
        Text('删除此密钥').fontSize(this.fs(13)).fontColor(RED).height(44).padding({left:8,right:4}).onClick(()=>{this.store?.secret('model-'+this.profileId,'').then(()=>{this.keyConfigured=false;this.message='密钥已删除';});})
       }.width('100%')
       TextInput({text:this.apiKey,placeholder:'留空则保留已保存的密钥'}).type(InputType.Password).onChange((v:string)=>{this.apiKey=v;}).height(44).fontSize(this.fs(15)).backgroundColor(WHITE).border({width:1,color:LINE}).borderRadius(10)
      }.width('100%')
      Text('Key 使用系统 HUKS 加密保存。模型任务会向当前接口发送屏幕与上下文。').fontSize(this.fs(12)).fontColor(INK3).width('100%')
     }.width('100%').padding(16).borderRadius(14).backgroundColor(WHITE).border({width:1,color:LINE}).alignItems(HorizontalAlign.Start)
     Column({space:10}){
      this.foldHead({label:'高级：上下文、输出上限、思考强度、图片与工具、密钥自检',open:this.advModel,action:()=>{this.advModel=!this.advModel;}})
      if(this.advModel){
       this.field('上下文窗口',this.contextWindow,(v:string)=>{this.contextWindow=v;})
       this.field('单次输出上限（留空＝自动 '+DEFAULT_OUTPUT_TOKENS+'；端点允许 256–393216）',this.outputTokens,(v:string)=>{this.outputTokens=v;})
       Column({space:6}){
        Text('DeepSeek 思考强度（reasoning_effort，默认 high）').fontSize(this.fs(13)).fontColor(INK3)
        Row({space:8}){
         ForEach(['off','low','high','max'],(v:string)=>{
          Text(v==='off'?'关闭':v).id('effort_'+v).fontSize(this.fs(14)).fontColor((v==='off'?!this.thinking:this.thinking&&this.effort===v)?BLUE_DEEP:INK2).padding({left:14,right:14,top:6,bottom:6}).borderRadius(16).backgroundColor((v==='off'?!this.thinking:this.thinking&&this.effort===v)?BLUE_SOFT:WHITE).border({width:1,color:LINE}).onClick(()=>{if(v==='off')this.thinking=false;else{this.thinking=true;this.effort=v;}})
         },(v:string)=>v+(this.thinking?this.effort:'off')+this.fontScale)
        }
       }.width('100%').alignItems(HorizontalAlign.Start)
       this.switchRow('图片输入','把当前截图发送给模型',this.vision,(v:boolean)=>{this.vision=v;})
       this.switchRow('工具调用','需要模型支持所选协议的工具调用',this.tools,(v:boolean)=>{this.tools=v;})
       this.pill({label:'密钥存储自检',primary:false,enabled:true,action:()=>{this.checkVault();}})
      }
     }.width('100%').padding(16).borderRadius(14).backgroundColor(WHITE).border({width:1,color:LINE}).alignItems(HorizontalAlign.Start)
    }.width('100%').padding(16).alignItems(HorizontalAlign.Start)
   }.layoutWeight(1).width('100%').scrollBar(BarState.Off).align(Alignment.Top)
   Row(){
    this.pill({label:'保存并使用',primary:true,enabled:true,action:()=>{this.saveProfile();}})
   }.width('100%').padding({left:16,right:16,top:10,bottom:this.legacyGap()+10}).backgroundColor(WHITE).border({width:{top:1},color:LINE})
  }.width('100%').layoutWeight(1)
 }
 @Builder settingsSkills(){
  Column({space:12}){
   Column({space:10}){
    Text('直接对大肥鱼说：记住…、学会…、把某技能停用、删除某条记忆。').fontSize(this.fs(13)).fontColor(INK2).width('100%')
    this.pill({label:'去对话里改',primary:true,enabled:true,action:()=>{this.panel='chat';this.input='请帮我管理技能和记忆：';}})
   }.width('100%').padding(16).borderRadius(14).backgroundColor(WHITE).border({width:1,color:LINE}).alignItems(HorizontalAlign.Start)
   Column({space:12}){
    Row({space:8}){
     Text('技能').fontSize(this.fs(14)).fontColor(this.skillTab==='skills'?BLUE_DEEP:INK2).padding({left:16,right:16}).height(44).borderRadius(22).backgroundColor(this.skillTab==='skills'?BLUE_SOFT:WHITE).border({width:1,color:this.skillTab==='skills'?BLUE_SOFT:LINE}).onClick(()=>{this.skillTab='skills';})
     Text('记忆').fontSize(this.fs(14)).fontColor(this.skillTab==='memory'?BLUE_DEEP:INK2).padding({left:16,right:16}).height(44).borderRadius(22).backgroundColor(this.skillTab==='memory'?BLUE_SOFT:WHITE).border({width:1,color:this.skillTab==='memory'?BLUE_SOFT:LINE}).onClick(()=>{this.skillTab='memory';})
     Blank()
     if(this.skillTab==='skills'){
      Row(){SymbolGlyph($r('sys.symbol.ellipsis_circle')).fontSize(20).fontColor([INK2]).renderingStrategy(SymbolRenderingStrategy.SINGLE)}.width(44).height(44).justifyContent(FlexAlign.Center).bindMenu(this.skillMoreMenu())
      this.pill({label:'导入',primary:true,enabled:true,action:()=>{this.importSkill();}})
     }
    }.width('100%')
    if(this.skillTab==='skills'){
     Text('支持 Markdown 或 ZIP 格式导入').fontSize(this.fs(12)).fontColor(INK3).width('100%')
     SkillList({rev:this.skillRev,source:():Skill[]=>this.eng()?.state.skills??[],fontScale:this.fontScale,onToggle:(n:string,v:boolean)=>{this.skillAction(()=>{this.eng()?.skillSetEnabled(n,v);});},onDelete:(n:string)=>{this.skillAction(()=>{this.eng()?.skillDelete(n);});},onRollback:(n:string,v:number)=>{this.skillAction(()=>{this.eng()?.skillRollback(n,v);});},onView:(b:string)=>{this.message=b.slice(0,2000);}})
    }else{
     Text('大肥鱼记住的偏好与事实，跨会话生效，可逐条删除。').fontSize(this.fs(13)).fontColor(INK3).width('100%')
     MemoryList({rev:this.skillRev,source:():Memory[]=>this.eng()?.state.memories??[],fontScale:this.fontScale,onDelete:(k:string)=>{this.skillAction(()=>{this.eng()?.memoryDelete(k);});}})
    }
   }.width('100%').padding(16).borderRadius(14).backgroundColor(WHITE).border({width:1,color:LINE}).alignItems(HorizontalAlign.Start)
  }.width('100%')
 }
 @Builder settingsTools(){
  Column({space:12}){
   Column({space:6}){
    this.sectionTitle('工具')
    Text('关闭后该工具不会提供给模型，改动立即保存。').fontSize(this.fs(12)).fontColor(INK3).width('100%')
    ForEach(this.eng()?.definitions??[],(d:Definition)=>{
     Row(){
      Row({space:10}){
       this.icon({res:this.toolIcon(d.name),size:15,color:INK3})
       Column({space:1}){Text(d.name).fontSize(this.fs(14)).fontColor(INK).maxLines(1).textOverflow({overflow:TextOverflow.Ellipsis}).width('100%');Text(d.source).fontSize(this.fs(11)).fontColor(INK3).maxLines(1).textOverflow({overflow:TextOverflow.Ellipsis}).width('100%');Text(d.description).fontSize(this.fs(12)).fontColor(INK2).maxLines(2).textOverflow({overflow:TextOverflow.Ellipsis}).width('100%')}.alignItems(HorizontalAlign.Start).layoutWeight(1)
      }.layoutWeight(1).margin({right:12})
      Toggle({type:ToggleType.Switch,isOn:d.enabled}).selectedColor(BLUE).onChange((v:boolean)=>{d.enabled=v;const e=this.eng();if(e){const old=e.state.disabledTools??[];e.state.disabledTools=v?old.filter(n=>n!==d.name):old.concat(d.name);e.save();}})
     }.width('100%').padding({top:4,bottom:4})
    },(d:Definition)=>d.name+d.enabled+this.fontScale)
   }.width('100%').padding(16).borderRadius(14).backgroundColor(WHITE).border({width:1,color:LINE}).alignItems(HorizontalAlign.Start)
   Column({space:10}){
    this.sectionTitle('MCP 服务')
    Text('远程工具服务，地址必须以 https:// 开头，添加后自动连接。').fontSize(this.fs(12)).fontColor(INK3).width('100%')
    this.field('服务名称',this.serverTitle,(v:string)=>{this.serverTitle=v;})
    this.field('服务地址（https://）',this.serverUrl,(v:string)=>{this.serverUrl=v;})
    Column({space:6}){
     Text('访问令牌（可选）').fontSize(this.fs(13)).fontColor(INK3)
     TextInput({text:this.token,placeholder:'可选 Bearer Token'}).type(InputType.Password).onChange((v:string)=>{this.token=v;}).height(44).fontSize(this.fs(15)).backgroundColor(WHITE).border({width:1,color:LINE}).borderRadius(10)
    }.width('100%').alignItems(HorizontalAlign.Start)
    this.pill({label:'添加并连接',primary:true,enabled:true,action:()=>{this.addServer();}})
    ForEach(this.eng()?.state.servers??[],(s:McpServer)=>{
     Row({space:8}){
      Text(s.title).fontSize(this.fs(15)).fontColor(INK).layoutWeight(1)
      this.pill({label:s.enabled?'停用':'启用',primary:false,enabled:true,action:()=>{s.enabled=!s.enabled;this.eng()?.save();this.eng()?.refreshMcp().catch(()=>{this.message='连接失败';});}})
      Text('删除').fontSize(this.fs(13)).fontColor(RED).height(44).padding({left:8,right:8}).onClick(()=>{const e=this.eng();if(e){e.state.servers=e.state.servers.filter(v=>v.id!==s.id);this.store?.secret('mcp-'+s.id,'');e.save();e.refreshMcp();}})
     }.width('100%').padding(10).borderRadius(10).border({width:1,color:LINE})
    },(s:McpServer)=>s.id+s.enabled+this.fontScale)
   }.width('100%').padding(16).borderRadius(14).backgroundColor(WHITE).border({width:1,color:LINE}).alignItems(HorizontalAlign.Start)
  }.width('100%')
 }
 @Builder settingsBudget(){
  Column({space:12}){
   Column({space:10}){
    this.sectionTitle('任务预算')
    Text('每段等效用量 = 未缓存输入 + 输出 + 缓存读取 × 0.1（缓存读取按 1/10 计）。').fontSize(this.fs(12)).fontColor(INK3).width('100%')
    Column({space:6}){
     Text('每段操作上限').fontSize(this.fs(13)).fontColor(INK3)
     TextInput({text:String(this.eng()?.state.callBudget??200),placeholder:'每段操作上限，50–500'}).type(InputType.Number).onChange((v:string)=>{const n=Number(v);if(this.engine&&n>=50&&n<=500){this.engine.state.callBudget=Math.round(n);this.engine.save();}}).height(44).fontSize(this.fs(15)).backgroundColor(WHITE).border({width:1,color:LINE}).borderRadius(10)
     Text('50–500 之间有效，超出范围不保存。').fontSize(this.fs(12)).fontColor(INK3)
    }.width('100%').alignItems(HorizontalAlign.Start)
    Column({space:6}){
     Text('每段等效用量（百万）').fontSize(this.fs(13)).fontColor(INK3)
     TextInput({text:String((this.eng()?.state.tokenBudget??DEFAULT_TOKEN_BUDGET)/1000000),placeholder:'每段等效用量（百万），1–20；0 表示不限'}).type(InputType.Number).onChange((v:string)=>{const n=Number(v);if(this.engine&&(n===0||n>=1&&n<=20)){this.engine.state.tokenBudget=Math.round(n*1000000);this.engine.save();}}).height(44).fontSize(this.fs(15)).backgroundColor(WHITE).border({width:1,color:LINE}).borderRadius(10)
     Text('1–20 之间有效；填 0 表示不限。超出范围不保存。').fontSize(this.fs(12)).fontColor(INK3)
    }.width('100%').alignItems(HorizontalAlign.Start)
   }.width('100%').padding(16).borderRadius(14).backgroundColor(WHITE).border({width:1,color:LINE}).alignItems(HorizontalAlign.Start)
   Column({space:10}){
    this.sectionTitle('下载')
    this.field('下载大小上限（MB，1～1000）',String(this.eng()?.state.downloadLimitMB??200),(v:string)=>{const n=Number(v);const e=this.eng();if(e&&Number.isInteger(n)&&n>=1&&n<=1000){e.state.downloadLimitMB=n;e.save();}})
    Text('1–1000 之间的整数有效，超出范围不保存。').fontSize(this.fs(12)).fontColor(INK3).width('100%')
   }.width('100%').padding(16).borderRadius(14).backgroundColor(WHITE).border({width:1,color:LINE}).alignItems(HorizontalAlign.Start)
   Column({space:10}){
    this.sectionTitle('同类授权')
    Text('同类授权仅限当前任务、危险类别和应用；任务结束后清理。').fontSize(this.fs(13)).fontColor(INK3).width('100%')
   }.width('100%').padding(16).borderRadius(14).backgroundColor(WHITE).border({width:1,color:LINE}).alignItems(HorizontalAlign.Start)
  }.width('100%')
 }
 @Builder settingsData(){
  Column({space:12}){
   Column({space:10}){
    this.sectionTitle('本会话文件')
    if(this.fileCount()===0){Text('本会话还没有文件。').fontSize(this.fs(13)).fontColor(INK3).width('100%')}
    ForEach(this.eng()?.files.list(this.eng()!.session())??[],(f:importFileAsset)=>{
     Row({space:8}){
      Text(f.name+(f.kind==='opaque'?' · 只能另存，不能读取':'')).fontSize(this.fs(14)).fontColor(INK).layoutWeight(1).maxLines(2).textOverflow({overflow:TextOverflow.Ellipsis})
      this.pill({label:'另存',primary:false,enabled:true,action:()=>{this.exportOffice(f.id);}})
      Text('删除').fontSize(this.fs(13)).fontColor(RED).height(44).padding({left:8,right:8}).opacity(this.isRunning()?0.4:1).onClick(()=>{if(!this.isRunning())this.deleteFile(f.id,f.name);})
     }.width('100%')
    },(f:importFileAsset)=>f.id)
   }.width('100%').padding(16).borderRadius(14).backgroundColor(WHITE).border({width:1,color:LINE}).alignItems(HorizontalAlign.Start)
   Column({space:10}){
    this.sectionTitle('导出')
    this.pill({label:'导出当前会话',primary:false,enabled:true,action:()=>{this.exportChat();}})
   }.width('100%').padding(16).borderRadius(14).backgroundColor(WHITE).border({width:1,color:LINE}).alignItems(HorizontalAlign.Start)
   Column({space:10}){
    this.sectionTitle('历史截图')
    Text('清理历史截图文件。').fontSize(this.fs(13)).fontColor(INK3).width('100%')
    Text('清理历史截图').fontSize(this.fs(14)).fontColor(RED).height(44).onClick(()=>{this.store?.clearScreens();this.message='历史截图已清理';})
   }.width('100%').padding(16).borderRadius(14).backgroundColor(WHITE).border({width:1,color:LINE}).alignItems(HorizontalAlign.Start)
  }.width('100%')
 }
 @Builder settingsAbout(){
  Column({space:12}){
   Column({space:10}){
    this.sectionTitle('本机连接')
    Row({space:8}){this.dot({color:this.ready?GREEN:ORANGE});Text(this.ready?'已连接本机调试端口 40373':'未连接，可能需要在系统提示中选择信任').fontSize(this.fs(14)).fontColor(INK2)}
    this.pill({label:'本机重连',primary:false,enabled:!this.ready,action:()=>{this.hdc.connect(40373);}})
    if(this.detail){Text(this.detail).fontSize(this.fs(11)).fontColor(INK3).copyOption(CopyOptions.LocalDevice).width('100%')}
   }.width('100%').padding(16).borderRadius(14).backgroundColor(WHITE).border({width:1,color:LINE}).alignItems(HorizontalAlign.Start)
   Column({space:6}){
    this.sectionTitle('版本')
    Text('HarmonyWhale '+VERSION+' · com.harmonyloom.selfhdcprobe').fontSize(16).fontColor(INK)
    Text('独立平板任务 Harness；证据与第三方许可见工程 docs/').fontSize(13).fontColor(INK3)
   }.width('100%').padding(16).borderRadius(14).backgroundColor(WHITE).border({width:1,color:LINE}).alignItems(HorizontalAlign.Start)
   Column({space:10}){
    this.foldHead({label:'开发者',open:this.devAbout,action:()=>{this.devAbout=!this.devAbout;}})
    if(this.devAbout){
     this.pill({label:'执行层测试页',primary:false,enabled:true,action:()=>{router.pushUrl({url:'pages/ExecutionFixture'});}})
     this.pill({label:'联网测试页',primary:false,enabled:true,action:()=>{router.pushUrl({url:'pages/WebSpike'});}})
     this.pill({label:'笔输入探针',primary:false,enabled:true,action:()=>{router.pushUrl({url:'pages/PenProbe'});}})
    }
   }.width('100%').padding(16).borderRadius(14).backgroundColor(WHITE).border({width:1,color:LINE}).alignItems(HorizontalAlign.Start)
  }.width('100%')
 }
 @Builder extensionsPage(){this.settingsPage()}

 build(){
  Stack(){
  PdfSurface()
  if(this.compact()&&this.panel==='chat'){
   Column(){
    Column().width('100%').height(this.topInset)
    CompactChat({text:$input,onUndo:(r:CompactRow)=>{return this.undoManagement(r.name,r.args,r.result);},revision:this.revision,fontScale:this.fontScale,engine:this.engine,attachments:this.attachments,onPhoto:()=>{this.pickImages(true);},onAlbum:()=>{this.pickImages(false);},onFile:()=>{this.importOffice();},onGoal:()=>{this.openGoal();},onRemove:(id:string)=>{this.removeAttachment(id);},onSend:(t:string)=>{this.sendText(t);},onResume:()=>{this.eng()?.start().catch(()=>{this.message='没有可恢复任务';});},onNewChat:()=>{this.newChat();},onSettings:()=>{if(!this.isRunning())this.panel='model';},onTrace:()=>{this.panel='trace';}}).layoutWeight(1)
    if(this.message){Text(this.shorten(this.message,300)).fontSize(this.fs(12)).fontColor(INK2).maxLines(4).width('100%').padding({left:12,right:12,top:4,bottom:4}).backgroundColor(BLUE_SOFT).onClick(()=>{this.message='';})}
   }.width('100%').height('100%').backgroundColor(WHITE)
  }else{
  Row(){
   if(this.sidebarOpen&&!this.compact()){this.sidebar()}
   Column(){
    Column().width('100%').height(this.topInset)
    Column(){
     this.header()
     this.notice()
     if(this.panel==='chat'){this.chatPage()}
     else if(this.panel==='trace'){this.tracePage()}
     else if(this.panel==='stats'){this.statsPage()}
    else if(this.panel==='favorites'){this.favoritesPage()}
     else if(this.panel==='model'){this.settingsPage()}
     else if(this.panel==='goal'){this.goalPage()}
     else if(this.panel==='plan'){this.planPage()}
     else if(this.panel==='context'){this.contextPage()}
     else{this.extensionsPage()}
    }.width('100%').layoutWeight(1).backgroundColor(WHITE).borderRadius({topLeft:this.sidebarOpen?16:0,topRight:0,bottomLeft:this.sidebarOpen?16:0,bottomRight:0}).clip(true)
   }.layoutWeight(1).height('100%').backgroundColor(SIDEBAR)
  }.width('100%').height('100%').backgroundColor(SIDEBAR)
  }
  }.width('100%').height('100%').opacity(this.floatOpacity).expandSafeArea([SafeAreaType.SYSTEM],[SafeAreaEdge.TOP,SafeAreaEdge.BOTTOM]).onAreaChange((o:Area,n:Area)=>{this.areaWidth=Number(n.width);})
 }
}


