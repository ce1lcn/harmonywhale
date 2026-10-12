import {http,connection} from '@kit.NetworkKit';
import {url} from '@kit.ArkTS';
import {fileIo as fs} from '@kit.CoreFileKit';
import {cryptoFramework} from '@kit.CryptoArchitectureKit';
import {checkHost,publicAddress} from './WebPolicy';
import {headerValue} from './Web';
import {DeviceError} from './Elements';
export interface DownloadResult {url:string;bytes:number;sha256:string;}
export class Download {
 generation:number=0;request:http.HttpRequest|null=null;abort:((error:Error)=>void)|null=null;
 cancel(){this.generation++;this.request?.destroy();this.abort?.(new Error('下载已取消'));}
 async run(input:string,path:string,maxBytes:number,progress:(bytes:number,total:number)=>void):Promise<DownloadResult>{
  const generation=this.generation;let current=input;const check=():void=>{if(generation!==this.generation)throw new DeviceError('INTERRUPTED','下载已取消');};
  try{for(let hop=0;hop<=5;hop++){
   check();const target=new url.URL(current);if(!['http:','https:'].includes(target.protocol)||target.username||target.password)throw new DeviceError('WEB_URL','只允许无凭据的HTTP/HTTPS公网地址');checkHost(target.hostname);
   let timer:number=0;const addresses=await Promise.race([connection.getAddressesByNameWithOptions(target.hostname.replace(/^\[|\]$/g,'')),new Promise<connection.NetAddress[]>((_resolve,reject)=>{timer=setTimeout(()=>reject(new DeviceError('WEB_TIMEOUT','下载DNS超时')),10000);})]).finally(()=>clearTimeout(timer));check();if(!addresses.length||addresses.some(a=>!publicAddress(a.address)))throw new DeviceError('WEB_PRIVATE','下载域名解析到非公网地址');
   const request=http.createHttp();this.request=request;const f=fs.openSync(path,fs.OpenMode.CREATE|fs.OpenMode.READ_WRITE|fs.OpenMode.TRUNC);let headers:Record<string,string>={};let received=0;let failure:Error|null=null;let deadline:number=0;let abort:(error:Error)=>void=()=>{};
   const stopped=new Promise<number>((_resolve,reject)=>{abort=reject;this.abort=abort;deadline=setTimeout(()=>{failure=new Error('WEB_TIMEOUT：下载超过120秒');request.destroy();reject(failure);},120000);});
   request.on('headersReceive',(h:Object)=>{headers=h as Record<string,string>;const size=Number(headerValue(headers,'content-length'));if(Number.isFinite(size)&&size>maxBytes){failure=new Error('FILE_LIMIT：下载文件超过设置上限');request.destroy();abort(failure);}});
   request.on('dataReceive',(data:ArrayBuffer)=>{try{check();if(failure)return;if(headerValue(headers,'location'))return;received+=data.byteLength;if(received>maxBytes)throw new DeviceError('FILE_LIMIT','下载文件超过设置上限');if(fs.writeSync(f.fd,data)!==data.byteLength)throw new DeviceError('FILE_ERROR','下载写入不完整');progress(received,Number(headerValue(headers,'content-length'))||0);}catch(e){failure=e as Error;request.destroy();abort(failure);}});
   let status=0;try{try{status=await Promise.race([request.requestInStream(target.href,{method:http.RequestMethod.GET,header:{'Accept':'*/*','Accept-Encoding':'identity'},maxRedirects:0,usingCache:false,connectTimeout:15000,readTimeout:30000}),stopped]);}catch(e){const n=e as Record<string,Object>;if(n['code']!==2300047)throw e as Error;await new Promise<void>(resolve=>setTimeout(resolve,100));check();if(!headerValue(headers,'location'))throw e as Error;}check();if(failure)throw failure as Error;fs.fsyncSync(f.fd);}finally{clearTimeout(deadline);if(this.abort===abort)this.abort=null;request.destroy();if(this.request===request)this.request=null;fs.closeSync(f.fd);}
   const location=headerValue(headers,'location');if(location&&(status===0||[301,302,303,307,308].includes(status))){if(hop===5)throw new DeviceError('WEB_REDIRECT','下载重定向超过5次');current=new url.URL(location,target.href).href;continue;}
   if(status<200||status>=300)throw new DeviceError('WEB_HTTP','下载返回HTTP '+status);const expected=Number(headerValue(headers,'content-length'));if(expected>0&&received!==expected)throw new DeviceError('FILE_ERROR','下载大小与响应头不一致');
   const md=cryptoFramework.createMd('SHA256');const r=fs.openSync(path,fs.OpenMode.READ_ONLY);try{let read=0;while(read<received){check();const b=new ArrayBuffer(Math.min(65536,received-read));const count=fs.readSync(r.fd,b);if(count<=0)throw new DeviceError('FILE_ERROR','下载校验读取失败');await md.update({data:new Uint8Array(b.slice(0,count))});read+=count;}const hash=await md.digest();check();return {url:target.href,bytes:received,sha256:Array.from(hash.data).map(v=>v.toString(16).padStart(2,'0')).join('')};}finally{fs.closeSync(r.fd);}
  }throw new DeviceError('WEB_REDIRECT','下载重定向失败');}catch(e){if(fs.accessSync(path))fs.unlinkSync(path);throw e as Error;}
 }
}
