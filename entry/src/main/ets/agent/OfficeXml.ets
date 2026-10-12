export class XmlNode {
 name:string;attrs:Record<string,string>={};children:XmlNode[]=[];text:string='';start:number=0;end:number=0;innerStart:number=0;innerEnd:number=0;
 constructor(name:string){this.name=name;}
 get local():string{return this.name.split(':').pop()??this.name;}
}
export function escapeXml(value:string):string {if(/[\u0000-\u0008\u000b\u000c\u000e-\u001f]/.test(value))throw new Error('文本含XML不支持的控制字符');return value.replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;').replace(/"/g,'&quot;').replace(/'/g,'&apos;');}
export function unescapeXml(value:string):string {if(/&(?![^;\s&]+;)/.test(value))throw new Error('XML实体未结束');return value.replace(/&([^;\s]+);/g,(all:string,entity:string)=>{if(entity==='amp')return '&';if(entity==='lt')return '<';if(entity==='gt')return '>';if(entity==='quot')return '"';if(entity==='apos')return "'";if(/^#(?:x[0-9a-f]+|\d+)$/i.test(entity)){const n=entity[1].toLowerCase()==='x'?parseInt(entity.slice(2),16):Number(entity.slice(1));if(!Number.isInteger(n)||n<1||n>0x10ffff||(n>=0xd800&&n<=0xdfff)||n<32&&![9,10,13].includes(n))throw new Error('XML字符引用无效');return String.fromCodePoint(n);}throw new Error('XML实体不支持');});}
export function parseXml(source:string):XmlNode {
 if(source.length>5*1024*1024||/<!DOCTYPE|<!ENTITY/i.test(source))throw new Error('XML过大或包含不支持的声明');
 const root=new XmlNode('#document');const stack:XmlNode[]=[root];let p=0,count=0;
 while(p<source.length){const begin=source.indexOf('<',p);if(begin<0){stack[stack.length-1].text+=unescapeXml(source.slice(p));break;}stack[stack.length-1].text+=unescapeXml(source.slice(p,begin));
  if(source.startsWith('<!--',begin)){const end=source.indexOf('-->',begin+4);if(end<0)throw new Error('XML注释未结束');p=end+3;continue;}
  if(source.startsWith('<![CDATA[',begin)){const end=source.indexOf(']]>',begin+9);if(end<0)throw new Error('XML CDATA未结束');stack[stack.length-1].text+=source.slice(begin+9,end);p=end+3;continue;}
  if(source.startsWith('<?',begin)){const end=source.indexOf('?>',begin+2);if(end<0)throw new Error('XML声明未结束');p=end+2;continue;}
  let end=begin+1,quote='';for(;end<source.length;end++){const ch=source[end];if(quote){if(ch===quote)quote='';}else if(ch==='"'||ch==="'")quote=ch;else if(ch==='>')break;}
  if(end>=source.length)throw new Error('XML标签未结束');const tag=source.slice(begin+1,end).trim();p=end+1;
  if(tag.startsWith('/')){if(stack.length===1||stack[stack.length-1].name!==tag.slice(1).trim())throw new Error('XML标签不匹配');const node=stack.pop()!;node.innerEnd=begin;node.end=p;continue;}
  const match=/^([\w:.-]+)([\s\S]*?)\/?$/.exec(tag);if(!match||tag.startsWith('!'))throw new Error('XML标签无效');const node=new XmlNode(match[1]);node.start=begin;node.innerStart=p;const attrs=match[2].trim();let position=0;
  while(position<attrs.length){const attr=/^\s*([\w:.-]+)\s*=\s*(["'])([\s\S]*?)\2/.exec(attrs.slice(position));if(!attr)throw new Error('XML属性无效');if(node.attrs[attr[1]]!==undefined)throw new Error('XML属性重复');node.attrs[attr[1]]=unescapeXml(attr[3]);position+=attr[0].length;}
  stack[stack.length-1].children.push(node);if(++count>100000||stack.length>64)throw new Error('XML结构超限');if(tag.endsWith('/')){node.end=p;node.innerEnd=p;}else stack.push(node);
 }
 if(stack.length!==1||root.children.length!==1||root.text.trim())throw new Error('XML文档结构无效');return root.children[0];
}
export function descendants(node:XmlNode,name:string):XmlNode[]{const out:XmlNode[]=[];const visit=(n:XmlNode):void=>{if(n.local===name)out.push(n);n.children.forEach(c=>visit(c));};visit(node);return out;}
export function textOf(node:XmlNode):string{return node.text+node.children.map(c=>textOf(c)).join('');}
export function child(node:XmlNode,name:string):XmlNode|undefined{return node.children.find(c=>c.local===name);}
