// 0.8.3：识别“工具调用被写成正文文字”。只做检测与剔除，绝不解析或执行正文中的调用。
// 代码块（围栏）与行内代码中的示例不算；只有正文里出现的调用样式才判定为泄漏。

export interface ToolTextResult {leaked:boolean;cleaned:string;marker:string;}

interface Span {start:number;end:number;}
interface Fence {start:number;ch:string;len:number;}
interface Hit {index:number;marker:string;}

const XML_MARKER_SOURCE:string='<\\s*(tool_calls?|function_calls?|invoke|tool_code)\\b';

function escapeName(name:string):string{return name.replace(/[^A-Za-z0-9_]/g,'');}

// 围栏代码块：``` 或 ~~~，关闭需同字符且不短于开启；未关闭则到文末都算代码（截断的代码也不误判）。
function fenceSpans(text:string):Span[]{
 const spans:Span[]=[];
 let pos:number=0;
 let open:Fence|null=null;
 while(pos<=text.length){
  let eol:number=text.indexOf('\n',pos);
  if(eol<0)eol=text.length;
  const line:string=text.substring(pos,eol);
  if(open===null){
   const m=/^ {0,3}(`{3,}|~{3,})/.exec(line);
   if(m!==null){const f:Fence={start:pos,ch:m[1].charAt(0),len:m[1].length};open=f;}
  }else{
   const m=/^ {0,3}(`{3,}|~{3,})[ \t]*\r?$/.exec(line);
   if(m!==null&&m[1].charAt(0)===open.ch&&m[1].length>=open.len){const s:Span={start:open.start,end:eol};spans.push(s);open=null;}
  }
  if(eol>=text.length)break;
  pos=eol+1;
 }
 if(open!==null){const s:Span={start:open.start,end:text.length};spans.push(s);}
 return spans;
}

function inlineSpans(text:string,fences:Span[]):Span[]{
 const spans:Span[]=[];
 const re:RegExp=/`[^`\n]+`/g;
 let m:RegExpExecArray|null=re.exec(text);
 while(m!==null){
  const start:number=m.index;
  let inFence:boolean=false;
  for(let i=0;i<fences.length;i++){if(start>=fences[i].start&&start<fences[i].end)inFence=true;}
  if(!inFence){const s:Span={start:start,end:start+m[0].length};spans.push(s);}
  m=re.exec(text);
 }
 return spans;
}

function protectedAt(index:number,spans:Span[]):boolean{
 for(let i=0;i<spans.length;i++){if(index>=spans[i].start&&index<spans[i].end)return true;}
 return false;
}

// 检测正文中的调用样式；toolNames 为当前已注册工具名，用于识别 JSON / 函数调用写法。
export function toolTextGuard(text:string,toolNames:string[]):ToolTextResult{
 const source:string=text??'';
 if(source.length===0){const empty:ToolTextResult={leaked:false,cleaned:source,marker:''};return empty;}
 const fences:Span[]=fenceSpans(source);
 const inline:Span[]=inlineSpans(source,fences);
 const guarded:Span[]=fences.concat(inline);
 const hits:Hit[]=[];
 const xml=new RegExp(XML_MARKER_SOURCE,'gi');
 let m:RegExpExecArray|null=xml.exec(source);
 while(m!==null){
  if(!protectedAt(m.index,guarded)){const h:Hit={index:m.index,marker:'<'+m[1]};hits.push(h);}
  m=xml.exec(source);
 }
 const names:string[]=toolNames.map(n=>escapeName(n)).filter(n=>n.length>0);
 if(names.length>0){
  const alt:string=names.join('|');
  const jsonCall=new RegExp('^[ \\t]*\\{[ \\t]*"(?:name|tool|tool_name|function)"[ \\t]*:[ \\t]*"('+alt+')"','');
  const fnCall=new RegExp('^[ \\t]*('+alt+')[ \\t]*\\([ \\t]*(\\{|\\)|"|\')','');
  let pos:number=0;
  while(pos<=source.length){
   let eol:number=source.indexOf('\n',pos);
   if(eol<0)eol=source.length;
   if(!protectedAt(pos,guarded)){
    const line:string=source.substring(pos,eol);
    if(jsonCall.test(line)){const h:Hit={index:pos,marker:'JSON 工具调用'};hits.push(h);}
    else if(fnCall.test(line)){const h:Hit={index:pos,marker:'函数式工具调用'};hits.push(h);}
   }
   if(eol>=source.length)break;
   pos=eol+1;
  }
 }
 if(hits.length===0){const none:ToolTextResult={leaked:false,cleaned:source,marker:''};return none;}
 let first:Hit=hits[0];
 for(let i=1;i<hits.length;i++){if(hits[i].index<first.index)first=hits[i];}
 const result:ToolTextResult={leaked:true,cleaned:source.substring(0,first.index).replace(/\s+$/,''),marker:first.marker};
 return result;
}
