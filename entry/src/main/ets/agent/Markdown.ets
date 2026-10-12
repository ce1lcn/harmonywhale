// Portions Copyright (c) 2026 DeepSeek. MIT; full notice in docs/THIRD-PARTY.md.
// ArkTS rewrite of DSH incremental.ts/plain-text.ts/CodeBlock interaction ideas.
export interface RichSpan {text:string;bold:boolean;code:boolean;italic?:boolean;href?:string;}
export interface RichBlock {kind:string;text:string;spans:RichSpan[];level?:number;marker?:string;language?:string;rows?:string[][];start?:number;}
export function inline(line:string):RichSpan[]{
 const out:RichSpan[]=[];
 line.split(/(`[^`]+`|\*\*.+?\*\*|\*[^*]+\*|\[[^\]]+\]\(https?:\/\/[^\s)]+\))/).forEach((part:string)=>{
  if(!part)return;
  const link=/^\[([^\]]+)\]\((https?:\/\/[^\s)]+)\)$/.exec(part);
  out.push({text:link?link[1]:part.startsWith('**')?part.slice(2,-2):part.startsWith('`')||part.startsWith('*')?part.slice(1,-1):part,bold:part.startsWith('**'),code:part.startsWith('`'),italic:part.startsWith('*')&&!part.startsWith('**'),href:link?link[2]:undefined});
 });return out;
}
function cells(line:string):string[]{return line.trim().replace(/^\|/,'').replace(/\|$/,'').split(/(?<!\\)\|/).map(v=>v.trim().replace(/\\\|/g,'|'));}
export function parseRich(text:string):RichBlock[]{
 const blocks:RichBlock[]=[],lines=text.split('\n');let offset=0;
 for(let i=0;i<lines.length;i++){
  const line=lines[i].replace(/\r$/,''),start=offset;offset+=lines[i].length+1;
  if(!line.trim())continue;
  const fence=/^\s{0,3}(`{3,}|~{3,})([^\s`]*)\s*$/.exec(line);
  if(fence){const code:string[]=[];while(i+1<lines.length){i++;const next=lines[i].replace(/\r$/,'');offset+=lines[i].length+1;if(new RegExp('^\\s{0,3}'+fence[1][0]+'{'+fence[1].length+',}\\s*$').test(next))break;code.push(next);}blocks.push({kind:'code',text:code.join('\n'),spans:[],language:fence[2]||'代码',start:start});continue;}
  if(i+1<lines.length&&line.includes('|')&&/^\s*\|?\s*:?-{3,}:?\s*(?:\|\s*:?-{3,}:?\s*)+\|?\s*$/.test(lines[i+1])){
   const rows:string[][]=[cells(line)];i++;offset+=lines[i].length+1;while(i+1<lines.length&&lines[i+1].trim()&&lines[i+1].includes('|')){i++;rows.push(cells(lines[i]));offset+=lines[i].length+1;}blocks.push({kind:'table',text:rows.map(r=>r.join(' | ')).join('\n'),spans:[],rows:rows,start:start});continue;
  }
  if(/^\s{0,3}(?:-{3,}|\*{3,}|_{3,})\s*$/.test(line)){blocks.push({kind:'rule',text:'',spans:[],start:start});continue;}
  const h=/^\s{0,3}(#{1,6})\s+(.*)$/.exec(line),list=/^(\s*)([-*+•]|\d+[.)])\s+(.*)$/.exec(line),quote=/^\s*>\s?(.*)$/.exec(line);
  const body=h?h[2]:list?list[3]:quote?quote[1]:line;
  blocks.push({kind:h?'h':list?'bullet':quote?'quote':'p',text:body,spans:inline(body),level:h?Math.min(3,h[1].length):list?Math.min(1,Math.floor(list[1].replace(/\t/g,'  ').length/2)):0,marker:list?(/^\d/.test(list[2])?list[2]:'•'):undefined,start:start});
 }return blocks;
}
export class IncrementalMarkdown {
 source:string='';blocks:RichBlock[]=[];
 parse(text:string):RichBlock[]{
  if(text===this.source)return this.blocks;
  if(text.startsWith(this.source)&&this.blocks.length>2){const count=this.blocks.length-2,start=this.blocks[count].start??0;const tail=parseRich(text.slice(start));tail.forEach(b=>b.start=(b.start??0)+start);this.blocks=this.blocks.slice(0,count).concat(tail);}else this.blocks=parseRich(text);
  this.source=text;return this.blocks;
 }
}
// Outer timeline rows are recreated while streaming. Keep bounded parser state
// across native component instances so the frozen prefix remains effective.
const PARSERS:Map<string,IncrementalMarkdown>=new Map();
export function markdownFor(key:string,text:string):RichBlock[]{
 if(!key)return parseRich(text);
 let parser=PARSERS.get(key);
 if(!parser){parser=new IncrementalMarkdown();PARSERS.set(key,parser);if(PARSERS.size>32){const oldest=PARSERS.keys().next().value as string;PARSERS.delete(oldest);}}
 return parser.parse(text);
}
export function plainText(text:string):string{return parseRich(text).map(b=>b.kind==='code'?b.text:b.kind==='table'?(b.rows??[]).map(r=>r.map(c=>inline(c).map(s=>s.text).join('')).join('\t')).join('\n'):b.kind==='rule'?'':(b.marker?b.marker+' ':'')+b.spans.map(s=>s.text).join('')).join('\n');}
