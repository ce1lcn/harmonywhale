import {XmlNode,parseXml,descendants,child,textOf,escapeXml} from './OfficeXml';
import {PartReader} from './OfficeFormats';
export interface WordRun {text:string;bold?:boolean;italic?:boolean;}
export interface WordBlock {text?:string;style?:string;runs?:WordRun[];rows?:string[][];}
export interface WordParagraph {id:string;text:string;}
export interface WordRead {paragraphs:WordParagraph[];tables:string[][][];}
const w='http://schemas.openxmlformats.org/wordprocessingml/2006/main';
const rel='http://schemas.openxmlformats.org/package/2006/relationships';
const decl='<?xml version="1.0" encoding="UTF-8" standalone="yes"?>';
function run(r:WordRun):string {if(typeof r.text!=='string'||r.text.length>32000)throw new Error('Word 文本无效或过长');return '<w:r><w:rPr>'+(r.bold?'<w:b/>':'')+(r.italic?'<w:i/>':'')+'</w:rPr><w:t xml:space="preserve">'+escapeXml(r.text)+'</w:t></w:r>';}
export function wordParagraph(b:WordBlock):string {
 const style=b.style??'normal';if(!['normal','title','heading','bullet','number'].includes(style))throw new Error('Word 段落样式无效');
 const props=style==='title'||style==='heading'?'<w:pStyle w:val="'+(style==='title'?'Title':'Heading1')+'"/>':style==='bullet'||style==='number'?'<w:numPr><w:ilvl w:val="0"/><w:numId w:val="'+(style==='bullet'?'1':'2')+'"/></w:numPr>':'';
 const runs=b.runs??[{text:b.text??''} as WordRun];if(!Array.isArray(runs)||runs.length>100)throw new Error('Word 文字分段超限');
 return '<w:p><w:pPr>'+props+'</w:pPr>'+runs.map(r=>run(r)).join('')+'</w:p>';
}
function block(b:WordBlock):string {if(b.rows!==undefined){if(!Array.isArray(b.rows)||!b.rows.length||b.rows.length>200||b.rows.some(r=>!Array.isArray(r)||r.length>30))throw new Error('Word 表格最多200行30列');return '<w:tbl><w:tblPr><w:tblW w:w="0" w:type="auto"/><w:tblBorders>'+['top','left','bottom','right','insideH','insideV'].map(s=>'<w:'+s+' w:val="single" w:sz="4"/>').join('')+'</w:tblBorders></w:tblPr><w:tblGrid>'+'<w:gridCol w:w="2400"/>'.repeat(Math.max(...b.rows.map(r=>r.length)))+'</w:tblGrid>'+b.rows.map(r=>'<w:tr>'+r.map(t=>'<w:tc>'+wordParagraph({text:t})+'</w:tc>').join('')+'</w:tr>').join('')+'</w:tbl>';}return wordParagraph(b);}
export function newWord(blocks:WordBlock[]):Record<string,string> {
 if(!Array.isArray(blocks)||!blocks.length||blocks.length>1000)throw new Error('Word 支持1～1000个段落或表格块');
 const numbering='<w:numbering xmlns:w="'+w+'">'+['bullet','decimal'].map((f,i)=>'<w:abstractNum w:abstractNumId="'+i+'"><w:lvl w:ilvl="0"><w:start w:val="1"/><w:numFmt w:val="'+f+'"/><w:lvlText w:val="'+(i?'%1.':'•')+'"/><w:pPr><w:ind w:left="720" w:hanging="360"/></w:pPr></w:lvl></w:abstractNum><w:num w:numId="'+(i+1)+'"><w:abstractNumId w:val="'+i+'"/></w:num>').join('')+'</w:numbering>';
 return {'[Content_Types].xml':decl+'<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/><Default Extension="xml" ContentType="application/xml"/>'+['document','styles','numbering'].map(n=>'<Override PartName="/word/'+n+'.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.'+(n==='document'?'document.main':n)+'+xml"/>').join('')+'</Types>',
 '_rels/.rels':decl+'<Relationships xmlns="'+rel+'"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/></Relationships>',
 'word/document.xml':decl+'<w:document xmlns:w="'+w+'"><w:body>'+blocks.map(b=>block(b)).join('')+'<w:sectPr><w:pgSz w:w="11906" w:h="16838"/><w:pgMar w:top="1134" w:bottom="1134" w:left="1134" w:right="1134"/></w:sectPr></w:body></w:document>',
 'word/styles.xml':decl+'<w:styles xmlns:w="'+w+'"><w:docDefaults><w:rPrDefault><w:rPr><w:rFonts w:ascii="Arial" w:eastAsia="HarmonyOS Sans"/><w:sz w:val="22"/></w:rPr></w:rPrDefault></w:docDefaults><w:style w:type="paragraph" w:styleId="Title"><w:name w:val="Title"/><w:rPr><w:b/><w:sz w:val="40"/></w:rPr></w:style><w:style w:type="paragraph" w:styleId="Heading1"><w:name w:val="heading 1"/><w:rPr><w:b/><w:sz w:val="30"/></w:rPr></w:style></w:styles>',
 'word/numbering.xml':decl+numbering,
 'word/_rels/document.xml.rels':decl+'<Relationships xmlns="'+rel+'">'+['styles','numbering'].map((n,i)=>'<Relationship Id="rId'+(i+1)+'" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/'+n+'" Target="'+n+'.xml"/>').join('')+'</Relationships>'};
}
function paragraphText(p:XmlNode):string {return descendants(p,'t').map(t=>textOf(t)).join('');}
export function readWord(reader:PartReader):WordRead {const root=parseXml(reader.read('word/document.xml'));if(root.local!=='document'||!child(root,'body'))throw new Error('Word 正文结构无效');return {paragraphs:descendants(root,'p').map((p,i)=>({id:'p'+(i+1),text:paragraphText(p)} as WordParagraph)),tables:descendants(root,'tbl').map(t=>t.children.filter(r=>r.local==='tr').map(r=>r.children.filter(c=>c.local==='tc').map(c=>descendants(c,'p').map(p=>paragraphText(p)).join('\n'))))};}
export function editWord(xml:string,id:string|undefined,text:string,append:boolean):string {if(text.length>32000)throw new Error('Word 段落过长');const root=parseXml(xml);const body=child(root,'body');if(!body)throw new Error('Word 正文缺失');if(append){const at=child(body,'sectPr')?.start??body.innerEnd;return xml.slice(0,at)+wordParagraph({text:text})+xml.slice(at);}if(!/^p[1-9]\d*$/.test(id??''))throw new Error('Word 段落编号无效');const p=descendants(body,'p')[Number(id!.slice(1))-1];if(!p)throw new Error('Word 段落不存在');if(p.name!=='w:p')throw new Error('带其他命名空间前缀的 Word 暂不修改');const props=child(p,'pPr');return xml.slice(0,p.start)+'<w:p>'+(props?xml.slice(props.start,props.end):'')+run({text:text})+'</w:p>'+xml.slice(p.end);}
