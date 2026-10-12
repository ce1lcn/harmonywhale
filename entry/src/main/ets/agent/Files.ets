import {fileIo as fs,picker} from '@kit.CoreFileKit';
import {zlib} from '@kit.BasicServicesKit';
import {buffer} from '@kit.ArkTS';
import {common} from '@kit.AbilityKit';
import {Store} from './Store';
import {State,Session,FileAsset,Arguments,Observation,uid} from './Types';
import {DeviceError} from './Elements';
import {BinaryPart,inspectOfficeZip,packOffice,safePart} from './OfficeArchive';
import {PartReader,sheets,sheetRead,slides,slideRead,updateSheet,updateSlide,newSheet,CellPatch,CellValue as importCell,GridValue,SlideSpec,invalidateFormulaCache,calculationOnOpen} from './OfficeFormats';
import {newWord,readWord,editWord,WordBlock} from './WordParts';
import {newWorkbook,patchWorkbookSheet,appendWorksheet,WorksheetSpec,WorkbookCell} from './WorkbookParts';
import {appendSlide,removeSlide,insertSlideImage} from './PresentationEdit';
import {newPresentation} from './PresentationParts';
import {parseXml,descendants} from './OfficeXml';
import {prepareTextName,validateTextWrite,lineWindow,extensionOf,applyEdit,TEXT_EXTENSIONS,TEXT_MAX_BYTES} from './TextFiles';
import {PdfBridge,printableHtml} from './PdfBridge';
import {readPdf,imageInfo,convertImage} from './NativeFormats';
import {sniffFile,formatAdvice} from './FileKinds';
import {Download} from './Download';
import {spillFileName} from './Spill';
import {fnv1a} from './ActionKit';
interface FileMeta {fileId:string;name:string;kind:string;verified:boolean;origin:string;callId:string;size:number;sourceId?:string;}
interface Published {fileId:string;name:string;bytes:number;verified:boolean;note:string;}
interface Page {name:string;cells:importCell[];merged:string[];total:number;next:number;truncated:boolean;note:string;}
export class Files {
 epoch:number=0;
 cancel():void{this.epoch++;this.download.cancel();PdfBridge.cancel?.();}
 checkEpoch(epoch:number):void{this.check();if(epoch!==this.epoch)throw new DeviceError('INTERRUPTED','旧文件操作已取消，不发布迟到结果');}
 download:Download=new Download();progress:(bytes:number,total:number)=>void=()=>{};store:Store;state:State;active:()=>boolean=()=>true;mutationCount:number=0;
 constructor(store:Store,state:State){this.store=store;this.state=state;}
 check():void{if(!this.active())throw new DeviceError('INTERRUPTED','文件任务已暂停，未发布结果');}
 // 0.8.3：会话文件 = fileIds ∪ 会话消息中的文件附件 ∪ 会话任务记录里出现的 fileId，避免某一处记录丢失后列表变空。
 list(session:Session):FileAsset[]{
  const ids:string[]=(session.fileIds??[]).slice();
  session.messages.forEach((m)=>{(m.attachments??[]).forEach((a)=>{if(a.kind==='file'&&ids.indexOf(a.id)<0)ids.push(a.id);});});
  session.tasks.forEach((t)=>{t.records.forEach((r)=>{const re=/"fileId":"([^"]+)"/g;let hit:RegExpExecArray|null;while((hit=re.exec(r.result??''))!==null){if(ids.indexOf(hit[1])<0)ids.push(hit[1]);}});});
  const removed:string[]=session.deletedFileIds??[];
  return (this.state.files??[]).filter(f=>ids.indexOf(f.id)>=0&&removed.indexOf(f.id)<0);
 }
 // 0.8.4 A3：删除会话文件。只允许删除本应用沙箱 files/ 与 office/ 下的文件；分支会话仍引用同一文件时，只从本会话移除，文件本体保留。
 // 不提供给模型的工具（file_delete 默认不开放），只有用户在界面上确认后才会调用。
 isSandboxPath(path:string):boolean{const root:string=this.store.root;return path.length>0&&path.indexOf('..')<0&&(path.startsWith(root+'/files/')||path.startsWith(root+'/office/'));}
 referencedElsewhere(session:Session,id:string):boolean{return this.state.sessions.some((s:Session)=>s.id!==session.id&&this.list(s).some((f:FileAsset)=>f.id===id));}
 removeTree(path:string):void{
  if(!fs.accessSync(path))return;
  if(fs.statSync(path).isDirectory()){fs.listFileSync(path).forEach((n:string)=>{this.removeTree(path+'/'+n);});fs.rmdirSync(path);}
  else fs.unlinkSync(path);
 }
 remove(session:Session,id:string):string{
  this.check();
  const asset:FileAsset=this.asset(session,id);
  if(!this.isSandboxPath(asset.path))throw new DeviceError('PARAMETER','只能删除本应用沙箱里的会话文件');
  const shared:boolean=this.referencedElsewhere(session,id);
  if(!shared){
   if(fs.accessSync(asset.path))fs.unlinkSync(asset.path);
   if((asset.kind==='xlsx'||asset.kind==='pptx'||asset.kind==='docx')&&this.isSandboxPath(asset.folder+'/'))this.removeTree(asset.folder);
   this.state.files=(this.state.files??[]).filter((f:FileAsset)=>f.id!==id);
  }
  session.fileIds=(session.fileIds??[]).filter((v:string)=>v!==id);
  if(!session.deletedFileIds)session.deletedFileIds=[];
  if(session.deletedFileIds.indexOf(id)<0)session.deletedFileIds.push(id);
  this.forget(session,id);
  this.mutationCount++;
  return shared?'已从本会话移除「'+asset.name+'」（其他会话仍在使用，文件本体保留）':'已删除「'+asset.name+'」';
 }
 // 0.8.4 B3 file_edit：改前必读。读取时记下内容哈希；修改前核对文件没有在读取之后变化；改完把新内容记为已读（模型知道结果）。
 contentKey(content:string):string{return fnv1a(content)+':'+content.length;}
 markRead(session:Session,id:string,content:string):void{this.observed.set(session.id+'|'+id,this.contentKey(content));}
 writeAtomic(path:string,bytes:Uint8Array):void{this.writeBytes(path+'.tmp',bytes);fs.renameSync(path+'.tmp',path);}
 async editText(session:Session,args:Arguments,callId?:string):Promise<string>{
  this.check();
  const item:FileAsset=this.asset(session,args.fileId);
  if(item.kind!=='text')throw new DeviceError('PARAMETER','file_edit 只能修改文本文件（表格用 sheet_update_cells，PPT 用 presentation_set_text）');
  if(!this.isSandboxPath(item.path))throw new DeviceError('PARAMETER','只能修改本应用沙箱里的会话文件');
  const seen:string|undefined=this.observed.get(session.id+'|'+item.id);
  if(seen===undefined)throw new DeviceError('NOT_READ','这个文件在本会话里还没有用 file_read 读过，不允许修改');
  const content:string=buffer.from(this.readBytes(item.path)).toString('utf8');
  if(seen!==this.contentKey(content))throw new DeviceError('FILE_CHANGED','文件在你读取之后变化了');
  const edit=applyEdit(content,args.oldString??'',args.newString??'',args.replaceAll===true);
  validateTextWrite(item.name,edit.text,'utf-8');
  const bytes:Uint8Array=this.textBytes(edit.text);
  await new Promise<void>(resolve=>setTimeout(resolve,0));this.check();
  const id=uid();const path=this.store.root+'/files/'+id+'.'+extensionOf(item.name);this.writeBytes(path,bytes);
  const back:string=buffer.from(this.readBytes(path)).toString('utf8');
  if(back!==edit.text)throw new DeviceError('FILE_ERROR','写入后读回不一致，请用 file_read 重新读取确认');
  const asset:FileAsset={id:id,name:item.name.replace(/(\.[^.]+)$/,"-修改$1"),kind:"text",path:path,folder:this.store.root+"/files",verified:true,origin:"generated",sourceId:item.id,callId:callId,time:Date.now()};this.state.files!.push(asset);session.fileIds=(session.fileIds??[]).concat(id);this.markRead(session,id,edit.text);
  this.mutationCount++;
  return JSON.stringify({fileId:id,name:asset.name,replaced:edit.count,bytes:bytes.length,verified:true,note:'已按字面量替换 '+edit.count+' 处并读回核对；原件保留；新 fileId 可继续读取或修改。'});
 }
 // file_edit 的“已读”记录（会话 id|fileId → 读取时的内容哈希），删除文件时一并清除。仅在内存中，应用重启后需要重新 file_read。
 observed:Map<string,string>=new Map<string,string>();
 forget(session:Session,id:string):void{this.observed.delete(session.id+'|'+id);}
 asset(session:Session,id:string|undefined):FileAsset {const item=this.list(session).find(f=>f.id===id);if(!item)throw new DeviceError('FILE_NOT_FOUND','文件不存在或不属于当前会话');return item;}
 sizeOf(asset:FileAsset):number{try{return fs.statSync(asset.path).size;}catch(e){return 0;}}
 meta(asset:FileAsset):FileMeta{return {fileId:asset.id,name:asset.name,kind:asset.kind,verified:asset.verified,origin:asset.origin??(asset.sourceId?'派生':'未记录'),callId:asset.callId??'',size:this.sizeOf(asset),sourceId:asset.sourceId} as FileMeta;}
 // file_list 与观察文本：没有文件时给出明确说明，不返回空数组。
 listing(session:Session):string{const items=this.list(session);if(!items.length)return '当前会话没有文件。';return JSON.stringify(items.map(f=>this.meta(f)));}
 readBytes(path:string):Uint8Array {const f=fs.openSync(path,fs.OpenMode.READ_ONLY);try{const size=fs.statSync(f.fd).size;if(size>45*1024*1024)throw new Error('文件超过45MB');const bytes=new ArrayBuffer(size);if(size&&fs.readSync(f.fd,bytes)!==size)throw new Error('文件读取不完整');return new Uint8Array(bytes);}finally{fs.closeSync(f.fd);}}
 writeBytes(path:string,bytes:Uint8Array):void{const f=fs.openSync(path,fs.OpenMode.CREATE|fs.OpenMode.READ_WRITE|fs.OpenMode.TRUNC);try{if(fs.writeSync(f.fd,bytes.buffer)!==bytes.length)throw new Error('文件写入不完整');fs.fsyncSync(f.fd);}finally{fs.closeSync(f.fd);}}
 reader(asset:FileAsset):PartReader {return {read:(path:string)=>{if(!safePart(path))throw new Error('Office路径无效');return this.store.read(asset.folder+'/'+path);},exists:(path:string)=>safePart(path)&&fs.accessSync(asset.folder+'/'+path)};}
 observe(session:Session):Observation {const layout=this.listing(session);return {snapshotId:'files-'+uid(),layout:layout,image:'',width:0,height:0,fingerprint:layout};}
 mkdir(path:string):void{if(!fs.accessSync(path))fs.mkdirSync(path);}
 async unpack(path:string,folder:string,kind:string):Promise<void>{const entries=inspectOfficeZip(this.readBytes(path));if(entries.some(e=>/vbaProject|_xmlsignatures/i.test(e.name)))throw new Error('本版不处理宏或带数字签名的Office文件');this.mkdir(folder);await zlib.decompressFile(path,folder);for(const entry of entries){const target=folder+'/'+entry.name;if(!fs.accessSync(target))throw new Error('Office解压部件缺失');if(fs.statSync(target).isDirectory())continue;if(fs.statSync(target).size!==entry.size)throw new Error('Office解压校验失败');}const r:PartReader={read:(p:string)=>{if(!safePart(p))throw new Error('路径无效');return this.store.read(folder+'/'+p);},exists:(p:string)=>safePart(p)&&fs.accessSync(folder+'/'+p)};if(kind==='xlsx')sheets(r).forEach(s=>sheetRead(r,s.name));else if(kind==='docx')readWord(r);else slides(r).forEach((s,i)=>slideRead(r,i+1));}
 // 导入：选择器返回的文件先落到沙箱。表格/PPT 解包校验；小于 2 MB 的文本文件按 text 处理，其余只能另存。
 async importFromPath(session:Session,name:string,source:string):Promise<FileAsset>{const epoch=this.epoch;
  const ext=extensionOf(name.toLowerCase());
  let kind=ext==='xlsx'?'xlsx':ext==='pptx'?'pptx':ext==='docx'?'docx':'';
  const textKind=!kind&&TEXT_EXTENSIONS.indexOf(ext)>=0;
  const bytes=this.readBytes(source);
  if(sniffFile(bytes,name)==='zip'&&!/\.(apk|hap|app)$/i.test(name)){const names=inspectOfficeZip(bytes).map(e=>e.name);const detected=names.includes('word/document.xml')?'docx':names.includes('xl/workbook.xml')?'xlsx':names.includes('ppt/presentation.xml')?'pptx':'';if(kind&&kind!==detected)throw new DeviceError('FILE_TYPE','文件后缀与OOXML内容不一致');kind=detected;}
  if(textKind&&bytes.length>TEXT_MAX_BYTES)throw new DeviceError('PARAMETER','文本文件超过 2 MB，只能另存');
  const root=this.store.root+'/office';this.mkdir(root);
  const id=uid(),folder=root+'/'+id;
  const sniff=sniffFile(bytes,name);const finalKind=kind||(textKind?'text':sniff==='png'||sniff==='jpeg'||sniff==='pdf'||sniff==='zip'?sniff:'opaque');
  const path=finalKind==='text'?this.store.root+'/files/'+id+'.'+ext:root+'/'+id+'.'+(kind||'bin');
  if(finalKind==='text')this.mkdir(this.store.root+'/files');
  this.writeBytes(path,bytes);
  if(kind)await this.unpack(path,folder,kind);
  this.checkEpoch(epoch);
  const asset:FileAsset={id:id,name:name,kind:finalKind,path:path,folder:folder,verified:!!kind||textKind,origin:'imported',time:Date.now()};
  if(!this.state.files)this.state.files=[];
  this.state.files.push(asset);
  if(!session.fileIds)session.fileIds=[];
  session.fileIds.push(id);
  return asset;
 }
 async import(context:common.UIAbilityContext,session:Session):Promise<FileAsset|null>{const chosen=await new picker.DocumentViewPicker(context).select({maxSelectNumber:1});if(!chosen.length)return null;const uri=chosen[0];const name=decodeURIComponent(uri.split('/').pop()??'文件');return await this.importFromPath(session,name,uri);}
 async export(context:common.UIAbilityContext,session:Session,id:string):Promise<void>{const asset=this.asset(session,id);const chosen=await new picker.DocumentViewPicker(context).save({newFileNames:[asset.name]});if(!chosen.length)return;this.copyFile(asset.path,chosen[0]);}
 copyFile(source:string,dest:string):void{const r=fs.openSync(source,fs.OpenMode.READ_ONLY),w=fs.openSync(dest,fs.OpenMode.CREATE|fs.OpenMode.READ_WRITE|fs.OpenMode.TRUNC);try{let left=fs.statSync(r.fd).size;while(left>0){const data=new ArrayBuffer(Math.min(65536,left));const n=fs.readSync(r.fd,data);if(n<=0)throw new Error('文件读取不完整');if(fs.writeSync(w.fd,data.slice(0,n))!==n)throw new Error('另存写入不完整');left-=n;}fs.fsyncSync(w.fd);}finally{fs.closeSync(r.fd);fs.closeSync(w.fd);}}
 parts(asset:FileAsset):BinaryPart[]{return inspectOfficeZip(this.readBytes(asset.path)).filter(e=>!fs.statSync(asset.folder+'/'+e.name).isDirectory()).map(e=>({name:e.name,data:this.readBytes(asset.folder+'/'+e.name)} as BinaryPart));}
 textBytes(text:string):Uint8Array {const b=buffer.from(text,'utf8');const values:number[]=[];for(let i=0;i<b.length;i++)values.push(b.readUInt8(i));return new Uint8Array(values);}
 replace(parts:BinaryPart[],name:string,text:string):void {const part=parts.find(p=>p.name===name);if(!part)throw new Error('Office部件缺失');part.data=this.textBytes(text);}
 async publish(session:Session,name:string,kind:string,parts:BinaryPart[],source?:FileAsset,callId?:string):Promise<string>{const epoch=this.epoch;this.check();if(!name||name.length>120||/[\\/:\u0000]/.test(name))throw new Error('结果文件名无效');if(!name.toLowerCase().endsWith('.'+kind))name+='.'+kind;const root=this.store.root+'/office';this.mkdir(root);const id=uid(),path=root+'/'+id+'.'+(kind||'bin'),folder=root+'/'+id;await new Promise<void>(resolve=>setTimeout(resolve,0));this.checkEpoch(epoch);const packed=packOffice(parts);this.writeBytes(path,packed);await this.unpack(path,folder,kind);this.checkEpoch(epoch);const asset:FileAsset={id:id,name:name,kind:kind,path:path,folder:folder,verified:true,sourceId:source?.id,origin:'generated',callId:callId,time:Date.now()};if(!this.state.files)this.state.files=[];this.state.files.push(asset);if(!session.fileIds)session.fileIds=[];session.fileIds.push(id);this.mutationCount++;return JSON.stringify({fileId:id,name:name,bytes:packed.length,verified:true,note:'原件保留，结果已另存于应用沙箱；请使用另存按钮导出。'} as Published);}
 // 0.8.3 file_write：新建文本文件并读回比对；不覆盖已有文件。
 async writeText(session:Session,fileName:string,content:string,callId?:string):Promise<string>{const epoch=this.epoch;this.check();const root=this.store.root+'/files';this.mkdir(root);const id=uid();const path=root+'/'+id+'.'+extensionOf(fileName);const bytes=this.textBytes(content);await new Promise<void>(resolve=>setTimeout(resolve,0));this.checkEpoch(epoch);this.writeBytes(path,bytes);const back=buffer.from(this.readBytes(path)).toString('utf8');if(back!==content){throw new DeviceError('FILE_ERROR','写入后读回不一致，已保留原状，请重试');}const asset:FileAsset={id:id,name:fileName,kind:'text',path:path,folder:root,verified:true,origin:'generated',callId:callId,time:Date.now()};if(!this.state.files)this.state.files=[];this.state.files.push(asset);if(!session.fileIds)session.fileIds=[];session.fileIds.push(id);this.mutationCount++;return JSON.stringify({fileId:id,name:fileName,bytes:bytes.length,verified:true,note:'已保存到当前会话：可用 file_read 读取，也可在时间线点开另存。'});}
 // 0.8.4 B1：超大工具输出转存为会话文件（origin='spilled'，普通文本文件，可 file_read）。key 非空时，先删除本会话里同 key 的旧转存文件（如每一步的屏幕布局，只留最新一份）。
 async spillText(session:Session,label:string,content:string,callId?:string,key?:string):Promise<FileAsset>{
  this.check();
  if(key)this.dropSpill(session,key);
  const root:string=this.store.root+'/files';this.mkdir(root);
  const id:string=uid();const name:string=spillFileName(label,new Date());
  const body:string=content.length>600000?content.slice(0,600000)+'\n[转存内容超过 60 万字，后面部分未保存]':content;
  const bytes:Uint8Array=this.textBytes(body);
  const path:string=root+'/'+id+'.txt';
  await new Promise<void>(resolve=>setTimeout(resolve,0));this.check();
  this.writeBytes(path,bytes);
  const asset:FileAsset={id:id,name:name,kind:'text',path:path,folder:root,verified:true,origin:'spilled',callId:callId,time:Date.now(),spillKey:key};
  if(!this.state.files)this.state.files=[];
  this.state.files.push(asset);
  if(!session.fileIds)session.fileIds=[];
  session.fileIds.push(id);
  return asset;
 }
 dropSpill(session:Session,key:string):void{
  const old:FileAsset[]=this.list(session).filter((f:FileAsset)=>f.spillKey===key);
  old.forEach((f:FileAsset)=>{
   try{if(this.isSandboxPath(f.path)&&fs.accessSync(f.path))fs.unlinkSync(f.path);}catch(e){}
   this.state.files=(this.state.files??[]).filter((x:FileAsset)=>x.id!==f.id);
   session.fileIds=(session.fileIds??[]).filter((v:string)=>v!==f.id);
   this.forget(session,f.id);
  });
 }
 // 0.8.3 文件卡片预览：只取前 200 行，表格与 PPT 不在此预览。
 previewText(session:Session,fileId:string):string{const item=this.asset(session,fileId);if(item.kind==='docx')return JSON.stringify(readWord(this.reader(item)),null,2);if(item.kind==='xlsx')return JSON.stringify(sheets(this.reader(item)).map(s=>sheetRead(this.reader(item),s.name)),null,2);if(item.kind==='pptx')return JSON.stringify(slides(this.reader(item)).map((s,i)=>slideRead(this.reader(item),i+1)),null,2);if(item.kind==='pdf')return readPdf(item.path);if(item.kind!=='text')return '文件：'+item.name+'\n大小：'+this.sizeOf(item)+' 字节\n'+formatAdvice(item.kind);const content=buffer.from(this.readBytes(item.path)).toString('utf8');return lineWindow(content,1,200).text;}
 async publishBinary(session:Session,name:string,kind:string,bytes:Uint8Array,source?:FileAsset,callId?:string):Promise<string>{const epoch=this.epoch;this.check();if(!name||name.length>120||/[\\/:\u0000]/.test(name))throw new DeviceError('PARAMETER','文件名无效');const id=uid(),root=this.store.root+'/files';this.mkdir(root);const path=root+'/'+id+'.'+kind;this.writeBytes(path,bytes);try{if(kind==='pdf')readPdf(path);else if(kind==='png'||kind==='jpeg')await imageInfo(path);else if(kind==='zip')inspectOfficeZip(bytes);this.checkEpoch(epoch);const asset:FileAsset={id:id,name:name,kind:kind,path:path,folder:root,verified:true,origin:'generated',sourceId:source?.id,callId:callId,time:Date.now()};if(!this.state.files)this.state.files=[];this.state.files.push(asset);session.fileIds=(session.fileIds??[]).concat(id);this.mutationCount++;return JSON.stringify({fileId:id,name:name,bytes:bytes.length,verified:true});}catch(e){if(fs.accessSync(path))fs.unlinkSync(path);throw e as Error;}}
 async downloadFile(session:Session,args:Arguments,callId?:string):Promise<string>{const epoch=this.epoch;this.check();const root=this.store.root+'/files';this.mkdir(root);const id=uid(),path=root+'/'+id+'.download';const limit=Math.max(1,Math.min(1000,this.state.downloadLimitMB??200))*1024*1024;const result=await this.download.run(args.url??'',path,limit,this.progress);try{this.checkEpoch(epoch);const f=fs.openSync(path,fs.OpenMode.READ_ONLY);const head=new ArrayBuffer(Math.min(512,result.bytes));try{fs.readSync(f.fd,head);}finally{fs.closeSync(f.fd);}let name=args.name??result.url.split('/').pop()?.split('?')[0]??'下载文件';if(!name||name.length>120||/[\\/:\u0000]/.test(name))throw new DeviceError('PARAMETER','下载文件名无效');const detected=sniffFile(new Uint8Array(head),name);const asset:FileAsset={id:id,name:name,kind:'opaque',path:path,folder:root,verified:true,origin:'downloaded',callId:callId,time:Date.now()};if(!this.state.files)this.state.files=[];this.state.files.push(asset);session.fileIds=(session.fileIds??[]).concat(id);this.mutationCount++;return JSON.stringify({fileId:id,name:name,bytes:result.bytes,sha256:result.sha256,type:detected,advice:formatAdvice(detected),note:'仅保存；不打开、安装或执行。请由用户另存。'});}catch(e){if(fs.accessSync(path))fs.unlinkSync(path);throw e as Error;}}
 async execute(name:string,args:Arguments,session:Session,callId?:string):Promise<string>{const epoch=this.epoch;this.check();try{
 if(name==='file_list')return this.listing(session);
 if(name==='web_download')return await this.downloadFile(session,args,callId);
 if(name==='pdf_create'){let content=args.content??'';if(args.fileId){const src=this.asset(session,args.fileId);if(src.kind!=='text')throw new DeviceError('PARAMETER','PDF来源须文本Markdown/HTML文件');content=buffer.from(this.readBytes(src.path)).toString('utf8');}if(!content.trim())throw new DeviceError('PARAMETER','PDF需要非空正文或文本来源');const bytes=await PdfBridge.create(printableHtml(content,args.format??'markdown'));this.checkEpoch(epoch);return await this.publishBinary(session,(args.name??'文档').replace(/\.pdf$/i,'')+'.pdf','pdf',bytes,undefined,callId);}
 if(name==='file_write'){const fileName=prepareTextName(args.name??'');const content=args.content??'';validateTextWrite(fileName,content,args.encoding??'utf-8');return await this.writeText(session,fileName,content,callId);}
 if(name==='sheet_create'){if(!args.rowsJson&&!args.sheetsJson)throw new DeviceError('PARAMETER','需要 rowsJson 或 sheetsJson');const rows=JSON.parse(args.rowsJson??'[[null]]') as GridValue[][];const data=args.sheetsJson?newWorkbook(JSON.parse(args.sheetsJson) as WorksheetSpec[]):newSheet(rows,args.sheet??'Sheet1');return await this.publish(session,args.name??'表格','xlsx',Object.keys(data).map(p=>({name:p,data:this.textBytes(data[p])} as BinaryPart)),undefined,callId);}
 if(name==='presentation_create'){const spec=JSON.parse(args.slidesJson??'') as SlideSpec[];if(!Array.isArray(spec)||spec.some(s=>!s||typeof s.title!=='string'||typeof s.body!=='string'))throw new Error('幻灯片参数无效');const data=newPresentation(spec);return await this.publish(session,args.name??'演示文稿','pptx',Object.keys(data).map(p=>({name:p,data:this.textBytes(data[p])} as BinaryPart)),undefined,callId);}
 if(name==='document_create'){const data=newWord(JSON.parse(args.blocksJson??'') as WordBlock[]);return await this.publish(session,args.name??'文档','docx',Object.keys(data).map(p=>({name:p,data:this.textBytes(data[p])} as BinaryPart)),undefined,callId);}
 if(name==='file_read'){const item=this.asset(session,args.fileId);if(item.kind!=='text')throw new DeviceError('PARAMETER',item.kind==='xlsx'?'表格请用 sheet_read':item.kind==='pptx'?'PPT 请用 presentation_read':'这不是可读文本文件，只能另存');const content=buffer.from(this.readBytes(item.path)).toString('utf8');const shown=lineWindow(content,args.offset,args.limit).text;this.markRead(session,item.id,content);return shown;}
 if(name==='file_edit')return await this.editText(session,args,callId);
 const imageAttachment=session.messages.flatMap(m=>m.attachments??[]).find(a=>a.kind==='image'&&a.id===args.fileId);
 const binary:FileAsset=imageAttachment&&name.startsWith('image_')?{id:imageAttachment.id,name:imageAttachment.name,path:imageAttachment.path,kind:'jpeg',folder:this.store.root,verified:true}:this.asset(session,args.fileId);
 if(name==='file_inspect'){const size=this.sizeOf(binary);const file=fs.openSync(binary.path,fs.OpenMode.READ_ONLY);const head=new ArrayBuffer(Math.min(512,size));try{fs.readSync(file.fd,head);}finally{fs.closeSync(file.fd);}const data=new Uint8Array(head);const type=sniffFile(data,binary.name);return JSON.stringify({fileId:binary.id,name:binary.name,bytes:this.sizeOf(binary),type:type,advice:formatAdvice(type)});}
 if(name==='image_info')return await imageInfo(binary.path);
 if(name==='image_convert'){const format=args.format??'png';const converted=await convertImage(binary.path,format);this.checkEpoch(epoch);return await this.publishBinary(session,(args.name??'图片').replace(/\.(png|jpe?g)$/i,'')+'.'+format,format,converted,binary,callId);}
 if(name==='pdf_read')return readPdf(binary.path,args.page??1);
 if(name==='zip_list')return JSON.stringify(inspectOfficeZip(this.readBytes(binary.path)));
 if(name==='zip_extract'){if(/\.(apk|hap|app)$/i.test(binary.name))throw new DeviceError('PARAMETER','安装包只能保存另存');const entries=inspectOfficeZip(this.readBytes(binary.path));const entry=entries.find(e=>e.name===args.entry);if(!entry||!safePart(entry.name)||!entry.size)throw new DeviceError('PARAMETER','ZIP条目不存在或为空目录');const root=this.store.root+'/office';this.mkdir(root);const folder=root+'/'+uid();this.mkdir(folder);try{await zlib.decompressFile(binary.path,folder);this.checkEpoch(epoch);const target=folder+'/'+entry.name;if(!fs.accessSync(target)||fs.statSync(target).size!==entry.size)throw new DeviceError('FILE_ERROR','提取条目大小不符');const result=await this.importFromPath(session,args.name??entry.name.split('/').pop()!,target);this.check();this.mutationCount++;return JSON.stringify({fileId:result.id,name:result.name,verified:result.verified});}finally{this.removeTree(folder);}}
 const asset=this.asset(session,args.fileId),r=this.reader(asset);
 if(name==='document_read'){if(asset.kind!=='docx')throw new Error('需要Word文件');return JSON.stringify(readWord(r));}
 if(name==='document_replace_paragraph'||name==='document_append'){if(asset.kind!=='docx')throw new Error('需要Word文件');const parts=this.parts(asset);this.replace(parts,'word/document.xml',editWord(r.read('word/document.xml'),args.paragraphId,args.text??'',name==='document_append'));return await this.publish(session,args.name??asset.name.replace(/\.docx$/i,'-修改'),'docx',parts,asset,callId);}
 if(name==='sheet_list'){if(asset.kind!=='xlsx')throw new Error('需要表格文件');return JSON.stringify(sheets(r).map(s=>s.name));}
 if(name==='sheet_read'){if(asset.kind!=='xlsx')throw new Error('需要表格文件');const data=sheetRead(r,args.sheet??'');const offset=args.offset??0;if(!Number.isInteger(offset)||offset<0)throw new Error('分页偏移无效');return JSON.stringify({name:data.name,cells:data.cells.slice(offset,offset+100),merged:data.merged,total:data.cells.length,next:offset+100<data.cells.length?offset+100:-1,truncated:data.truncated,note:data.note} as Page);}
 if(name==='presentation_read'){if(asset.kind!=='pptx')throw new Error('需要PPT文件');if(!Number.isInteger(args.slide??0))throw new Error('页码无效');return JSON.stringify(slideRead(r,args.slide??1));}
 const parts=this.parts(asset);
 if(name==='presentation_append'||name==='presentation_delete'||name==='presentation_insert_image'){if(asset.kind!=='pptx')throw new Error('需要PPT文件');if(name==='presentation_append')appendSlide(parts,r,{title:args.title??'',body:args.text??''},(text:string)=>this.textBytes(text));else if(name==='presentation_delete')removeSlide(parts,r,args.slide??0,(text:string)=>this.textBytes(text));else{const attachment=session.messages.flatMap(m=>m.attachments??[]).find(a=>a.id===args.imageId&&a.kind==='image');const img=attachment??this.asset(session,args.imageId);await imageInfo(img.path);this.checkEpoch(epoch);const bytes=this.readBytes(img.path);const ext=bytes[0]===137?'png':bytes[0]===255&&bytes[1]===216?'jpeg':'';insertSlideImage(parts,r,args.slide??0,bytes,ext,(text:string)=>this.textBytes(text));}return await this.publish(session,args.name??asset.name.replace(/\.pptx$/i,'-修改'),'pptx',parts,asset,callId);}
 if(name==='sheet_update_cells'||name==='sheet_append_rows'){if(asset.kind!=='xlsx')throw new Error('需要表格文件');const info=sheets(r).find(s=>s.name===args.sheet);if(!info)throw new Error('工作表不存在');if(r.exists('xl/calcChain.xml'))throw new Error('此表含计算链，首版暂不修改，请在表格软件删除计算链后另存');const patches=name==='sheet_append_rows'?appendWorksheet(r,args.sheet??'',JSON.parse(args.rowsJson??'') as WorkbookCell[][]):JSON.parse(args.patchesJson??'') as CellPatch[];if(!Array.isArray(patches))throw new Error('修改列表无效');this.replace(parts,info.path,patchWorkbookSheet(r.read(info.path),patches));sheets(r).forEach(s=>{const p=parts.find(p=>p.name===s.path)!;p.data=this.textBytes(invalidateFormulaCache(buffer.from(p.data).toString('utf8')));});this.replace(parts,'xl/workbook.xml',calculationOnOpen(r.read('xl/workbook.xml')));return await this.publish(session,args.name??asset.name.replace(/\.xlsx$/i,'')+'-修改','xlsx',parts,asset,callId);}
 if(name==='presentation_set_text'){if(asset.kind!=='pptx')throw new Error('需要PPT文件');const slide=slideRead(r,args.slide??0);this.replace(parts,slide.path,updateSlide(r.read(slide.path),args.paragraphId??'',args.text??''));return await this.publish(session,args.name??asset.name.replace(/\.pptx$/i,'')+'-修改','pptx',parts,asset,callId);}
 throw new Error('未知文件工具');
 }catch(e){if(e instanceof DeviceError)throw e as Error;throw new DeviceError('FILE_ERROR',(e as Error).message);}}
}
