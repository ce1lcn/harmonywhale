import {http} from '@kit.NetworkKit';
import {buffer} from '@kit.ArkTS';
import {McpServer,Definition,Schema} from './Types';
interface Annotation {readOnlyHint?:boolean;}
interface RemoteTool {name:string;description?:string;inputSchema:Schema;annotations?:Annotation;}
interface Result {tools?:RemoteTool[];content?:Content[];isError?:boolean;protocolVersion?:string;nextCursor?:string;}
interface Content {type:string;text?:string;}
interface Rpc {jsonrpc:string;id?:number;method?:string;params?:Object;result?:Result;error?:RpcError;}
interface InitParams {protocolVersion:string;capabilities:Record<string,string>;clientInfo:ClientInfo;}
interface ClientInfo {name:string;version:string;}
interface ListParams {cursor?:string;}
interface CallParams {name:string;arguments:Object;}
interface RpcError {code:number;message:string;}
export function rpcBody(raw:string,id:number):Rpc{if(raw.trim().startsWith('{'))return JSON.parse(raw) as Rpc;const events=raw.replace(/\r/g,'').split('\n\n');for(const event of events){const body=event.split('\n').filter(l=>l.startsWith('data:')).map(l=>l.substring(5).trimStart()).join('\n');if(!body)continue;try{const r=JSON.parse(body) as Rpc;if(r.id===id)return r;}catch(e){}}throw new Error('MCP 回复缺少对应 JSON-RPC 结果');}
export class Mcp {
 session:string='';protocol:string='2025-03-26';counter:number=0;active:http.HttpRequest|null=null;remote:RemoteTool[]=[];rejectActive:((error:Error)=>void)|null=null;
 server:McpServer;token:string;constructor(server:McpServer,token:string){this.server=server;this.token=token;}
 cancel():void{this.rejectActive?.(new Error('MCP 已取消'));this.rejectActive=null;this.active?.destroy();this.active=null;}
 async send(method:string,params:Object,notify:boolean=false):Promise<Result>{if(!/^https:\/\/[^\s]+$/.test(this.server.url))throw new Error('MCP 地址需要 HTTPS');const id=++this.counter;const r=http.createHttp();this.active=r;const request:Rpc={jsonrpc:'2.0',method:method,params:params};if(!notify)request.id=id;const header:Record<string,string>={'Content-Type':'application/json','Accept':'application/json, text/event-stream','MCP-Protocol-Version':this.protocol};if(this.token)header.Authorization='Bearer '+this.token;if(this.session)header['Mcp-Session-Id']=this.session;

 try{return await new Promise<Result>((resolve,reject)=>{
  let bytes:number[]=[];let ended=false;let status=0;let settled=false;
  const fail=(error:Error):void=>{if(!settled){settled=true;reject(error);}};
  this.rejectActive=fail;
  const consume=():void=>{if(settled)return;if(status&&(status<200||status>=300)){fail(new Error('MCP HTTP '+status));return;}if(notify){if(ended||status){settled=true;resolve({} as Result);}return;}
   try{const parsed=rpcBody(buffer.from(new Uint8Array(bytes)).toString('utf8'),id);if(parsed.id!==id)throw new Error('MCP 结果 ID 不符');if(parsed.error){fail(new Error('MCP 调用失败 ('+parsed.error.code+')'));return;}if(!parsed.result)throw new Error('MCP 缺少结果');settled=true;resolve(parsed.result);}catch(e){if(ended)fail(new Error('MCP 回复缺少对应 JSON-RPC 结果'));}
  };
  r.on('headersReceive',(value:Object)=>{const headers=value as Record<string,string>;Object.keys(headers).forEach(k=>{if(k.toLowerCase()==='mcp-session-id')this.session=headers[k];});});
  r.on('dataReceive',(data:ArrayBuffer)=>{const chunk=new Uint8Array(data);for(let i=0;i<chunk.length;i++)bytes.push(chunk[i]);if(bytes.length>2*1024*1024){fail(new Error('MCP 回复超过 2 MB'));return;}consume();});
  r.on('dataEnd',()=>{ended=true;consume();});
  r.requestInStream(this.server.url,{method:http.RequestMethod.POST,header:header,extraData:JSON.stringify(request),connectTimeout:10000,readTimeout:60000}).then((code:number)=>{status=code;consume();}).catch(()=>{fail(new Error('MCP 网络请求失败'));});
 });}finally{r.destroy();if(this.active===r){this.active=null;this.rejectActive=null;}}}

 async connect():Promise<Definition[]>{const init=await this.send('initialize',{protocolVersion:this.protocol,capabilities:{} as Record<string,string>,clientInfo:{name:'TabletAgent',version:'0.4.6'}} as InitParams);this.protocol=init.protocolVersion??this.protocol;await this.send('notifications/initialized',{} as Record<string,string>,true);this.remote=[];let cursor:string|undefined=undefined;for(let page=0;page<20;page++){const result:Result=await this.send('tools/list',{cursor:cursor} as ListParams);const discovered:RemoteTool[]=result.tools??[];discovered.forEach((tool:RemoteTool)=>{this.remote.push(tool);});cursor=result.nextCursor;if(!cursor)break;if(page===19)throw new Error('MCP 工具分页超过限制');}return this.remote.map((t,i)=>{return {name:'mcp_'+this.server.id+'_'+i,description:t.description??t.name,parameters:t.inputSchema,source:this.server.title,enabled:true,readOnly:t.annotations?.readOnlyHint===true} as Definition;});}
 async call(index:number,args:Object):Promise<string>{const tool=this.remote[index];if(!tool)throw new Error('MCP 工具不存在');const result=await this.send('tools/call',{name:tool.name,arguments:args} as CallParams);if(result.isError)throw new Error('MCP 工具返回执行错误');return (result.content??[]).map(c=>c.text??'['+c.type+']').join('\n').slice(0,16000);}
}
