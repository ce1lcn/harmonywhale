import {http,connection} from '@kit.NetworkKit';
import {url,util} from '@kit.ArkTS';
import {publicAddress,checkHost} from './WebPolicy';
export interface WebResponse {url:string;status:number;text:string;bytes:number;charset:string;elapsedMs:number;redirects:number;}
interface RequestScope {cancelled:boolean;request?:http.HttpRequest;}
interface NativeError {code?:number;message:string;}
export function headerValue(headers:Record<string,string>,name:string):string {const key=Object.keys(headers).find(k=>k.toLowerCase()===name);return key?String(headers[key]):'';}
export function decodeWeb(data:ArrayBuffer,contentType:string):string[]{
 const bytes=new Uint8Array(data);let charset=/charset\s*=\s*["']?([\w-]+)/i.exec(contentType)?.[1]??'';
 if(!charset){let ascii='';for(let i=0;i<Math.min(8192,bytes.length);i++)ascii+=bytes[i]<128?String.fromCharCode(bytes[i]):' ';charset=/<meta[^>]+charset\s*=\s*["']?([\w-]+)/i.exec(ascii)?.[1]??'utf-8';}
 if(/^(gb2312|gb18030|gbk)$/i.test(charset))charset='gbk';
 if(!/^(utf-8|utf8|gbk|big5|iso-8859-1|windows-1252|utf-16le|utf-16be)$/i.test(charset))throw new Error('WEB_ENCODING：不支持网页编码 '+charset);
 return [util.TextDecoder.create(charset).decodeToString(bytes),charset];
}
export class Web {
 generation:number=0;waiters:Set<(reason:Error)=>void>=new Set();
 cancel():void{this.generation++;this.waiters.forEach(reject=>reject(new Error('WEB_CANCELLED：联网已取消')));this.waiters.clear();}
 async request(input:string,body?:string,token:string=''):Promise<WebResponse>{
  const scope:RequestScope={cancelled:false};let timer:number=0;let cancel:(reason:Error)=>void=()=>{};
  const stopped=new Promise<WebResponse>((_resolve,reject)=>{cancel=(reason:Error)=>{scope.cancelled=true;scope.request?.destroy();reject(reason);};this.waiters.add(cancel);timer=setTimeout(()=>cancel(new Error('WEB_TIMEOUT：联网超过15秒')),15000);});
  try{return await Promise.race([this.perform(input,body,scope,token),stopped]);}finally{clearTimeout(timer);this.waiters.delete(cancel);}
 }
 async perform(input:string,body:string|undefined,scope:RequestScope,token:string=''):Promise<WebResponse>{
  const generation=this.generation,started=Date.now();const deadline=started+15000;
  const check=():void=>{if(scope.cancelled||generation!==this.generation)throw new Error('WEB_CANCELLED：联网已取消');if(Date.now()>=deadline)throw new Error('WEB_TIMEOUT：联网超过15秒');};
  let current=input;
  for(let hop=0;hop<=5;hop++){
   check();const target=new url.URL(current);if(target.protocol!=='http:'&&target.protocol!=='https:')throw new Error('WEB_URL：只支持 HTTP/HTTPS');
   if(target.username||target.password)throw new Error('WEB_URL：地址不能包含凭据');checkHost(target.hostname);
   let timer:number=0;
   try{
    const addresses=await Promise.race([connection.getAddressesByNameWithOptions(target.hostname.replace(/^\[|\]$/g,'')),new Promise<connection.NetAddress[]>((_resolve,reject)=>{timer=setTimeout(()=>reject(new Error('WEB_TIMEOUT：DNS超时')),Math.max(1,deadline-Date.now()));})]);
    check();if(!addresses.length||addresses.some(a=>!publicAddress(a.address)))throw new Error('WEB_PRIVATE：域名解析到非公网地址');
   }finally{clearTimeout(timer);}
   check();const request=http.createHttp();scope.request=request;let received:Record<string,string>={};
   request.on('headersReceive',(header:Object)=>{received=header as Record<string,string>;});
   try{
    const headers:Record<string,string>={};headers['User-Agent']='Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 Chrome/131.0 Mobile Safari/537.36';headers['Accept']='text/html,application/json;q=0.9,*/*;q=0.5';if(body!==undefined)headers['Content-Type']='application/json';if(token){if(target.href!=='https://api.bochaai.com/v1/web-search'||body===undefined)throw new Error('WEB_AUTH：凭据仅用于固定搜索API');headers['Authorization']='Bearer '+token;}
    // On this device MAXREDIRS=0 prevents following redirects but reports error 2300047.
    // The response-header event is asynchronous; obtain Location without raising MAXREDIRS.
    let response:http.HttpResponse;
    try{response=await request.request(target.href,{method:body===undefined?http.RequestMethod.GET:http.RequestMethod.POST,header:headers,extraData:body,expectDataType:http.HttpDataType.ARRAY_BUFFER,connectTimeout:Math.max(1,deadline-Date.now()),readTimeout:Math.max(1,deadline-Date.now()),maxLimit:2*1024*1024,maxRedirects:0,usingCache:false});}
    catch(e){const failure=e as NativeError;if(failure.code===2300047){await new Promise<void>(resolve=>setTimeout(resolve,100));check();const location=headerValue(received,'location');if(!location)throw new Error('WEB_REDIRECT：系统未提供重定向地址');if(hop===5)throw new Error('WEB_REDIRECT：重定向超过5次');if(body!==undefined)throw new Error('WEB_REDIRECT：搜索请求不跟随重定向');current=new url.URL(location,target.href).href;continue;}throw new Error(failure.message);}
    check();const responseHeaders=response.header as Record<string,string>;
    if([301,302,303,307,308].indexOf(response.responseCode)>=0){if(hop===5)throw new Error('WEB_REDIRECT：重定向超过5次');const location=headerValue(responseHeaders,'location');if(!location)throw new Error('WEB_REDIRECT：缺少重定向地址');if(body!==undefined)throw new Error('WEB_REDIRECT：搜索请求不跟随重定向');current=new url.URL(location,target.href).href;continue;}
    const data=response.result as ArrayBuffer;if(!(data instanceof ArrayBuffer))throw new Error('WEB_FORMAT：网页没有返回字节数据');if(data.byteLength>2*1024*1024)throw new Error('WEB_SIZE：网页超过2MB');
    const decoded=decodeWeb(data,headerValue(responseHeaders,'content-type'));
    return {url:target.href,status:response.responseCode,text:decoded[0],bytes:data.byteLength,charset:decoded[1],elapsedMs:Date.now()-started,redirects:hop};
   }finally{request.destroy();if(scope.request===request)scope.request=undefined;}
  }
  throw new Error('WEB_REDIRECT：重定向失败');
 }
}
