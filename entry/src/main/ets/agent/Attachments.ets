// DSH policy/design adaptation: Copyright (c) 2026 DeepSeek. MIT; see docs/THIRD-PARTY.md.
import {fileIo as fs,fileUri} from '@kit.CoreFileKit';
import {camera,cameraPicker} from '@kit.CameraKit';
import {photoAccessHelper} from '@kit.MediaLibraryKit';
import {image} from '@kit.ImageKit';
import {textRecognition} from '@kit.CoreVisionKit';
import {common} from '@kit.AbilityKit';
import {util} from '@kit.ArkTS';
import {Attachment,uid} from './Types';
export const IMAGE_MAX_BYTES:number=2*1024*1024;
export function imageSize(width:number,height:number):image.Size{if(!Number.isFinite(width)||!Number.isFinite(height)||width<=0||height<=0)throw new Error('图片尺寸无效');const scale=Math.min(1,1302/Math.max(width,height));return {width:Math.max(1,Math.round(width*scale)),height:Math.max(1,Math.round(height*scale))};}
export function attachmentImage(path:string):string{const f=fs.openSync(path,fs.OpenMode.READ_ONLY);try{const n=fs.statSync(f.fd).size;if(n>IMAGE_MAX_BYTES)throw new Error('图片附件超过2MiB');const bytes=new ArrayBuffer(n);if(fs.readSync(f.fd,bytes)!==n)throw new Error('图片附件读取不完整');return new util.Base64Helper().encodeToStringSync(new Uint8Array(bytes));}finally{fs.closeSync(f.fd);}}
export class Attachments {
 root:string;constructor(root:string){this.root=root+'/attachments';if(!fs.accessSync(this.root))fs.mkdirSync(this.root);}
 async photo(context:common.UIAbilityContext):Promise<string[]>{const result=await cameraPicker.pick(context,[cameraPicker.PickerMediaType.PHOTO],{cameraPosition:camera.CameraPosition.CAMERA_POSITION_BACK});return result.resultCode===0&&result.resultUri?[result.resultUri]:[];}
 async album(context:common.UIAbilityContext,count:number):Promise<string[]>{if(count<=0)throw new Error('每条消息最多9张图片');const result=await new photoAccessHelper.PhotoViewPicker().select({MIMEType:photoAccessHelper.PhotoViewMIMETypes.IMAGE_TYPE,maxSelectNumber:Math.min(9,count)});return result.photoUris;}
 async compress(uri:string):Promise<Attachment>{const f=fs.openSync(uri,fs.OpenMode.READ_ONLY);let source:image.ImageSource|null=null,pixels:image.PixelMap|null=null,packer:image.ImagePacker|null=null;
  try{source=image.createImageSource(f.fd);const info=await source.getImageInfo();pixels=await source.createPixelMap({desiredSize:imageSize(info.size.width,info.size.height),desiredPixelFormat:image.PixelMapFormat.RGBA_8888});packer=image.createImagePacker();let bytes:ArrayBuffer=new ArrayBuffer(0);for(const quality of [85,75,60]){bytes=await packer.packing(pixels,{format:'image/jpeg',quality:quality});if(bytes.byteLength<=IMAGE_MAX_BYTES)break;}if(bytes.byteLength>IMAGE_MAX_BYTES)throw new Error('图片压缩后仍超过2MiB，请选择更简单的图片');const id=uid(),path=this.root+'/'+id+'.jpeg';const out=fs.openSync(path,fs.OpenMode.CREATE|fs.OpenMode.READ_WRITE|fs.OpenMode.TRUNC);try{if(fs.writeSync(out.fd,bytes)!==bytes.byteLength)throw new Error('图片保存不完整');fs.fsyncSync(out.fd);}finally{fs.closeSync(out.fd);}return {id:id,name:'图片-'+id+'.jpeg',kind:'image',path:path,bytes:bytes.byteLength};
  }finally{await packer?.release();await pixels?.release();await source?.release();fs.closeSync(f.fd);}}
 async ocr(a:Attachment):Promise<Attachment>{if(a.kind!=='image')return a;const source=image.createImageSource(a.path);let pixels:image.PixelMap|null=null;try{pixels=await source.createPixelMap({desiredPixelFormat:image.PixelMapFormat.RGBA_8888});const result=await textRecognition.recognizeText({pixelMap:pixels});return {id:a.id,name:a.name,kind:a.kind,path:a.path,bytes:a.bytes,ocr:result.value||'（图片未识别到文字；当前模型不支持视觉，不能描述图像内容）'};}finally{await pixels?.release();await source.release();}}
 remove(a:Attachment):void{if(a.kind==='image'&&a.path.startsWith(this.root+'/')&&fs.accessSync(a.path))fs.unlinkSync(a.path);}
}
