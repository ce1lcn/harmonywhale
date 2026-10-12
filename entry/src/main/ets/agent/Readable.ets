export interface ReadablePage {title:string;text:string;blocked:boolean;}
export function entities(value:string):string {
 return value.replace(/&#(x[0-9a-f]+|\d+);?/gi,(_all:string,n:string)=>{const code=n[0].toLowerCase()==='x'?parseInt(n.substring(1),16):Number(n);return code>0&&code<=0x10ffff?String.fromCodePoint(code):'';})
 .replace(/&nbsp;/gi,' ').replace(/&lt;/gi,'<').replace(/&gt;/gi,'>').replace(/&quot;/gi,'"').replace(/&apos;|&#39;/gi,"'").replace(/&amp;/gi,'&');
}
export function textOf(html:string):string {
 return entities(html.replace(/<h([1-6])\b[^>]*>([\s\S]*?)<\/h\1>/gi,(_all:string,n:string,body:string)=>'\n\n'+'#'.repeat(Number(n))+' '+body+'\n\n')
 .replace(/<li\b[^>]*>/gi,'\n- ').replace(/<br\s*\/?\s*>/gi,'\n').replace(/<\/(?:p|div|section|article|main|ul|ol|tr)>/gi,'\n\n').replace(/<[^>]+>/g,''))
 .replace(/\r\n?/g,'\n').replace(/[\t \u00a0]+/g,' ').replace(/ *\n */g,'\n').replace(/\n{3,}/g,'\n\n').trim();
}
export function readable(input:string):ReadablePage {
 const title=textOf(/<title\b[^>]*>([\s\S]*?)<\/title>/i.exec(input)?.[1]??'');
 const html=input.replace(/<!--[\s\S]*?-->/g,'').replace(/<(script|style|nav|header|footer|aside|form)\b[^>]*>[\s\S]*?<\/\1\s*>/gi,'');
 let body=/<article\b[^>]*>([\s\S]*?)<\/article>/i.exec(html)?.[1]??/<main\b[^>]*>([\s\S]*?)<\/main>/i.exec(html)?.[1]??'';
 if(!body){
  // Stack tracks nested blocks, avoiding a regex that stops at the first inner </div>.
  const tags=/<\/?(div|section|td)\b[^>]*>/gi;const stack:number[]=[];let best='',score=0;let match:RegExpExecArray|null;
  while((match=tags.exec(html))!==null){if(match[0][1]!=='/')stack.push(tags.lastIndex);else if(stack.length){const start=stack.pop()!;const part=html.substring(start,match.index);const plain=textOf(part);const links=part.match(/<a\b/gi)?.length??0;const blocks=part.match(/<(?:p|li)\b/gi)?.length??0;const quality=plain.length/(1+links*0.5)+blocks*20;if(plain.length>=80&&quality>score){score=quality;best=part;}}}
  body=best||html;
 }
 const text=textOf(body);
 const blocked=/验证码|访问过于频繁|安全验证|verify you are human|captcha|unusual traffic|enable javascript and cookies/i.test(title+'\n'+text.substring(0,1200))&&text.length<6000;
 return {title:title,text:text,blocked:blocked};
}
