import {DeviceError} from './Elements';
export class PdfBridge {
 static render:((html:string)=>Promise<Uint8Array>)|null=null;
 static cancel:(()=>void)|null=null;
 static async create(html:string):Promise<Uint8Array>{if(!PdfBridge.render)throw new DeviceError('PDF_UNAVAILABLE','PDF 渲染组件尚未就绪');return await PdfBridge.render(html);}
}
export function printableHtml(content:string,format:string):string {
 if(!['html','markdown'].includes(format))throw new DeviceError('PARAMETER','PDF format 只能为 html 或 markdown');
 if(content.length>500000)throw new DeviceError('PARAMETER','PDF 正文最多50万字');
 // 不让第三方 HTML 加载外部资源、脚本或本地文件。仅支持文字与基础块级排版。
 const esc=(s:string):string=>s.replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;');
 let body='';if(format==='html')body=content.replace(/<(script|style|iframe|object|embed)[\s\S]*?<\/\1\s*>/gi,'').replace(/<[^>]*>/g,(tag:string)=>/^<\/?(?:h[1-6]|p|br|ul|ol|li|table|thead|tbody|tr|th|td|strong|b|em|i|pre|code|blockquote)\s*\/?\s*>$/i.test(tag)?tag:'');
 else body=content.split('\n').map(line=>{const h=/^(#{1,6})\s+(.+)$/.exec(line);if(h)return '<h'+h[1].length+'>'+esc(h[2])+'</h'+h[1].length+'>';if(/^[-*]\s/.test(line))return '<p>• '+esc(line.slice(2))+'</p>';return '<p>'+esc(line)+'</p>';}).join('');
 return '<!doctype html><html><head><meta charset="utf-8"><meta http-equiv="Content-Security-Policy" content="default-src \'none\'; style-src \'unsafe-inline\'; font-src \'none\'; img-src \'none\'"><style>body{font-family:sans-serif;font-size:12pt;line-height:1.6;color:#172033}table{border-collapse:collapse;width:100%}td,th{border:1px solid #aaa;padding:6px}pre{white-space:pre-wrap}p{white-space:pre-wrap;overflow-wrap:anywhere}h1,h2,h3{break-after:avoid}tr{break-inside:avoid}</style></head><body>'+body+'</body></html>';
}
