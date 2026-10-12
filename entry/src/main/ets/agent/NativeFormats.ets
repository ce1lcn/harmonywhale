import {pdfService} from '@kit.PDFKit';
import {image} from '@kit.ImageKit';
import {fileIo as fs} from '@kit.CoreFileKit';
import {DeviceError} from './Elements';
export function readPdf(path:string,page:number=1):string {const doc=new pdfService.PdfDocument();try{if(doc.loadDocument(path)!==pdfService.ParseResult.PARSE_SUCCESS)throw new DeviceError('PDF_INVALID','PDF解析失败，可能加密或损坏');const count=doc.getPageCount();if(!Number.isInteger(page)||page<1||page>count)throw new DeviceError('PARAMETER','PDF页码不存在');const p=doc.getPage(page-1);try{const text=p.getTextContent();return JSON.stringify({page:page,pages:count,text:text,note:text?'原始页面文本；不含图片和水印':'此页没有可提取文本，可先转图片后OCR'});}finally{p.release();}}finally{doc.releaseDocument();}}
export async function imageInfo(path:string):Promise<string>{
 const f=fs.openSync(path,fs.OpenMode.READ_ONLY);let source:image.ImageSource|null=null;
 try{source=image.createImageSource(f.fd);const info=await source.getImageInfo();return JSON.stringify({width:info.size.width,height:info.size.height,format:info.mimeType});}
 finally{try{source?.release();}finally{fs.closeSync(f.fd);}}
}
export async function convertImage(path:string,format:string):Promise<Uint8Array>{
 if(!['png','jpeg'].includes(format))throw new DeviceError('PARAMETER','仅支持 png 或 jpeg');
 const f=fs.openSync(path,fs.OpenMode.READ_ONLY);let source:image.ImageSource|null=null,pixels:image.PixelMap|null=null,packer:image.ImagePacker|null=null;
 try{source=image.createImageSource(f.fd);packer=image.createImagePacker();const info=await source.getImageInfo();if(info.size.width*info.size.height>20000000)throw new DeviceError('FILE_LIMIT','图片最多2000万像素');pixels=await source.createPixelMap({desiredPixelFormat:image.PixelMapFormat.RGBA_8888});return new Uint8Array(await packer.packing(pixels,{format:'image/'+format,quality:90}));}
 finally{try{pixels?.release();}finally{try{packer?.release();}finally{try{source?.release();}finally{fs.closeSync(f.fd);}}}}
}
