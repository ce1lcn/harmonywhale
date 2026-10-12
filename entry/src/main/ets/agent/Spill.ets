// Portions adapted from DeepSeek Harness packages/spill/spill-policy (src/retention.ts, src/notice.ts).
// Copyright (c) 2026 DeepSeek. Licensed under the MIT License; full notice in docs/THIRD-PARTY.md.
// 0.8.4 B1：超大工具输出存成会话文件，上下文里只放开头和结尾片段、总长度和 fileId。
// 与 DSH 的差别：DSH 按估算 token 预算保留头尾（各占一半）并附“完整结果存放路径”；这里按字符数保留头尾（头多尾少，因为开头通常更重要），
// 取回方式换成大肥鱼的 file_read(fileId, offset, limit)。纯函数，可在 node 测试中直接运行。

// 阈值：16 KB（按字符数，UTF-16 单元；中文一字算一个）。可由 State.spillThreshold 调整。
export const SPILL_THRESHOLD_CHARS:number=16384;
export const SPILL_HEAD_CHARS:number=1500;
export const SPILL_TAIL_CHARS:number=1000;
// 会话上下文里每条工具结果最多放 4000 字（Conversation.ets），预览加提示必须小于它，否则尾部会被再次截掉。
export const SPILL_PREVIEW_MAX:number=3600;
// 这些工具的输出本身就是“分段读取”或必须完整给模型，不转存。
export const SPILL_EXEMPT:string[]=['file_read','get_capabilities','skill_load','sheet_read','sheet_list','presentation_read','finish_task','ask_user','request_confirmation','todo_write'];
// web_fetch 一页的字符数。超过阈值的页面会转存，所以一页可以比 0.8.3 的 12000 字大得多，模型只看头尾预览，要细节再 file_read。
export const WEB_PAGE_CHARS:number=40000;

export function thresholdOf(value?:number):number{return value!==undefined&&Number.isFinite(value)&&value>=4000&&value<=200000?Math.round(value):SPILL_THRESHOLD_CHARS;}
export function shouldSpill(name:string,text:string,threshold:number=SPILL_THRESHOLD_CHARS):boolean{
 if(SPILL_EXEMPT.indexOf(name)>=0)return false;
 return text.length>threshold;
}

// 不在代理对中间切开。
function cutHead(text:string,length:number):string{
 let cut:number=Math.min(text.length,length);
 const last:number=text.charCodeAt(cut-1);
 if(cut<text.length&&last>=0xd800&&last<=0xdbff)cut--;
 return text.slice(0,cut);
}
function cutTail(text:string,length:number):string{
 let cut:number=Math.max(0,text.length-length);
 const first:number=text.charCodeAt(cut);
 if(cut>0&&first>=0xdc00&&first<=0xdfff)cut++;
 return text.slice(cut);
}
// 在换行处收尾，预览更好读；找不到换行就硬切。
function headAtLine(text:string,length:number):string{
 const head:string=cutHead(text,length);
 if(head.length>=text.length)return head;
 const nl:number=head.lastIndexOf('\n');
 return nl>head.length*0.6?head.slice(0,nl):head;
}
function tailAtLine(text:string,length:number):string{
 const tail:string=cutTail(text,length);
 if(tail.length>=text.length)return tail;
 const nl:number=tail.indexOf('\n');
 return nl>=0&&nl<tail.length*0.4?tail.slice(nl+1):tail;
}

export function lineCount(text:string):number{
 if(text.length===0)return 0;
 let n:number=1;
 for(let i=0;i<text.length;i++)if(text.charCodeAt(i)===10)n++;
 if(text.charCodeAt(text.length-1)===10)n--;
 return n;
}

export interface SpillPreview {preview:string;omitted:number;total:number;lines:number;}
// 头 + 省略标记 + 尾。省略的字数写在标记里。
export function headTail(text:string,head:number=SPILL_HEAD_CHARS,tail:number=SPILL_TAIL_CHARS):SpillPreview{
 const total:number=text.length;
 if(total<=head+tail)return {preview:text,omitted:0,total:total,lines:lineCount(text)};
 const a:string=headAtLine(text,head);
 const b:string=tailAtLine(text,tail);
 const omitted:number=Math.max(0,total-a.length-b.length);
 return {preview:a+'\n\n[… 中间省略 '+omitted+' 字 …]\n\n'+b,omitted:omitted,total:total,lines:lineCount(text)};
}

// 给模型的取回提示（对应 DSH 的 "Full formatted result stored at … Use read with offset/limit"）。
export function spillNotice(fileId:string,name:string,p:SpillPreview):string{
 return '（输出共 '+p.total+' 字、'+p.lines+' 行，已省略中间 '+p.omitted+' 字。完整内容已存为会话文件「'+name+'」，fileId='+fileId+'；需要时用 file_read 分段读（offset 为行号，limit 为行数）。）';
}

// 普通工具输出：预览 + 提示。
export function spillResult(text:string,fileId:string,name:string):string{
 const p:SpillPreview=headTail(text);
 return p.preview+'\n\n'+spillNotice(fileId,name,p);
}

// web_fetch：正文放在 JSON 的 text 字段里，转存的是可读的正文（带标题与地址），JSON 保持合法，只把 text 换成预览。
export interface WebPage {notice?:string;title?:string;url?:string;text:string;offset?:number;nextOffset?:number|null;total?:number;spill?:string;}
export function webFileText(page:WebPage):string{
 return (page.title?'# '+page.title+'\n':'')+(page.url?page.url+'\n\n':'')+page.text;
}
export function webSpillResult(page:WebPage,fileId:string,name:string):string{
 const p:SpillPreview=headTail(page.text);
 const out:WebPage={notice:page.notice,title:page.title,url:page.url,text:p.preview,offset:page.offset,nextOffset:page.nextOffset,total:page.total,spill:spillNotice(fileId,name,p)};
 return JSON.stringify(out);
}

// 转存文件名：spill-工具名-时间.txt，工具名只留字母数字下划线。
export function spillFileName(label:string,now:Date):string{
 const safe:string=label.replace(/[^A-Za-z0-9_]/g,'_').slice(0,24);
 const two=(n:number):string=>n<10?'0'+String(n):String(n);
 return 'spill-'+safe+'-'+two(now.getHours())+two(now.getMinutes())+two(now.getSeconds())+'.txt';
}
