// Portions (applyEdit / countOccurrences, 0.8.4) adapted from DeepSeek Harness packages/fs/tool-fs/src/edit.ts. Copyright (c) 2026 DeepSeek. MIT; full notice in docs/THIRD-PARTY.md.
// 0.8.3 通用文本文件：文件名清理、类型白名单、写入校验与行号窗口读取。纯逻辑，不触碰文件系统。
import {DeviceError} from './Elements';

export const TEXT_MAX_BYTES:number=2*1024*1024;
export const READ_DEFAULT_LINES:number=2000;
export const READ_LINE_CHARS:number=2000;
// 0.8.4.1：一次 file_read 的总字数上限与历史里工具结果的上限（16384）对齐，读到的窗口完整进入上下文，不会再被截掉。
export const READ_TOTAL_CHARS:number=15000;
export const TEXT_EXTENSIONS:string[]=['txt','md','json','csv','html','htm','xml','yaml','yml','log','ini','toml','ets','ts','tsx','js','jsx','cjs','mjs','vue','py','java','kt','c','cpp','h','hpp','css','scss','sh','sql','go','rs','swift'];

// 只保留最后一段文件名，去掉路径与控制字符，避免写到会话沙箱之外。
export function cleanName(raw:string):string{
 const base=(raw??'').split('/').pop()!.split('\\').pop()!;
 let out='';
 for(let i=0;i<base.length;i++){
  const code=base.charCodeAt(i);
  if(code<32||code===127)continue;
  const ch=base.charAt(i);
  out+=('<>:"|?*'.indexOf(ch)>=0)?'_':ch;
 }
 out=out.trim();
 while(out.startsWith('.'))out=out.substring(1);
 if(out.length>80){const dot=out.lastIndexOf('.');const ext=dot>0&&out.length-dot<=8?out.substring(dot):'';out=out.substring(0,80-ext.length)+ext;}
 return out;
}

export function extensionOf(name:string):string{const dot=name.lastIndexOf('.');return dot>0?name.substring(dot+1).toLowerCase():'';}

// 返回可写入的最终文件名；无后缀补 .txt，后缀不在白名单则拒绝。
export function prepareTextName(raw:string):string{
 const name=cleanName(raw);
 if(!name)throw new DeviceError('PARAMETER','文件名无效');
 const ext=extensionOf(name);
 if(!ext)return name+'.txt';
 if(TEXT_EXTENSIONS.indexOf(ext)<0)throw new DeviceError('PARAMETER','不支持的文件类型：.'+ext+'，可用 .txt .md .json .csv .html .xml .yaml .log 及常见代码后缀');
 return name;
}

export function utf8Length(text:string):number{
 let n=0;
 for(let i=0;i<text.length;i++){
  const c=text.charCodeAt(i);
  if(c<0x80)n+=1;else if(c<0x800)n+=2;else if(c>=0xd800&&c<=0xdbff&&i+1<text.length){n+=4;i++;}else n+=3;
 }
 return n;
}

// 写入前校验：编码、大小；.json 必须可解析，失败返回 PARAMETER。
export function validateTextWrite(name:string,content:string,encoding:string):void{
 if(encoding!==''&&encoding!=='utf-8')throw new DeviceError('PARAMETER','本版只支持 utf-8 编码');
 if(typeof content!=='string')throw new DeviceError('PARAMETER','内容必须是文本');
 if(utf8Length(content)>TEXT_MAX_BYTES)throw new DeviceError('PARAMETER','单文件不能超过 2 MB');
 if(extensionOf(name)==='json'){
  try{JSON.parse(content);}catch(e){throw new DeviceError('PARAMETER','JSON 不合法，未写入：'+(e as Error).message);}
 }
}

function pad(n:number,width:number):string{let s=String(n);while(s.length<width)s=' '+s;return s;}

export interface LineWindow {text:string;total:number;from:number;to:number;next:number;}

// 按行号窗口读取：offset 从 1 开始，limit 默认 2000、最大 2000；超长行与总字符数有上限。
export function lineWindow(content:string,offset?:number,limit?:number):LineWindow{
 const start=offset??1;
 if(!Number.isInteger(start)||start<1)throw new DeviceError('PARAMETER','offset 必须为从 1 开始的整数');
 const count=limit??READ_DEFAULT_LINES;
 if(!Number.isInteger(count)||count<1)throw new DeviceError('PARAMETER','limit 必须为正整数');
 const lines=content.split(/\r?\n/);
 if(lines.length>1&&lines[lines.length-1]==='')lines.pop();
 const total=lines.length;
 if(total===0)return {text:'（空文件）',total:0,from:0,to:0,next:-1};
 if(start>total)throw new DeviceError('PARAMETER','offset 超过文件末尾（共 '+total+' 行）');
 const max=Math.min(count,READ_DEFAULT_LINES);
 const out:string[]=[];let used=0;let last=start-1;
 for(let i=start-1;i<total&&out.length<max;i++){
  let line=lines[i];
  if(line.length>READ_LINE_CHARS)line=line.substring(0,READ_LINE_CHARS)+' …[本行过长已截断]';
  const row=pad(i+1,6)+'\t'+line;
  if(used+row.length>READ_TOTAL_CHARS&&out.length>0)break;
  out.push(row);used+=row.length;last=i+1;
 }
 const next=last<total?last+1:-1;
 const tail=next>0?'\n[还有未显示的行，使用 offset='+next+' 继续读取]':'';
 return {text:'共 '+total+' 行，显示第 '+start+'–'+last+' 行\n'+out.join('\n')+tail,total:total,from:start,to:last,next:next};
}

export function isTextKind(kind:string):boolean{return kind==='text';}

// ---- 0.8.4 B3 file_edit：按字面量替换（参照 DSH packages/fs/tool-fs/src/edit.ts 的语义：oldString 非空、与 newString 不同、默认必须恰好出现一次）。
// 与 DSH 的差别：错误码用大肥鱼自己的枚举（EDIT_NOT_FOUND / EDIT_AMBIGUOUS），错误文字为中文并带出现次数。
export interface EditResult {text:string;count:number;}
export function countOccurrences(content:string,needle:string):number{
 if(!needle)return 0;
 let n:number=0;let at:number=content.indexOf(needle);
 while(at>=0){n++;at=content.indexOf(needle,at+needle.length);}
 return n;
}
export function applyEdit(content:string,oldString:string,newString:string,replaceAll:boolean):EditResult{
 if(typeof oldString!=='string'||oldString.length===0)throw new DeviceError('PARAMETER','oldString 不能为空');
 if(typeof newString!=='string')throw new DeviceError('PARAMETER','newString 必须是文本（删除请传空字符串）');
 if(oldString===newString)throw new DeviceError('PARAMETER','oldString 与 newString 相同，没有可修改的内容');
 const count:number=countOccurrences(content,oldString);
 if(count===0)throw new DeviceError('EDIT_NOT_FOUND','文件里找不到 oldString（按字面量逐字匹配，包括空白与换行）');
 if(count>1&&!replaceAll)throw new DeviceError('EDIT_AMBIGUOUS','oldString 在文件里出现了 '+count+' 次，不唯一');
 let out:string='';let from:number=0;
 for(let i=0;i<(replaceAll?count:1);i++){
  const at:number=content.indexOf(oldString,from);
  out+=content.slice(from,at)+newString;from=at+oldString.length;
 }
 return {text:out+content.slice(from),count:replaceAll?count:1};
}
