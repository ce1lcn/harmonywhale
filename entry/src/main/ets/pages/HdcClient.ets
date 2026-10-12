import {uiTestCommand,uiTestReply} from './UiTestGate';
import { socket } from '@kit.NetworkKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { cryptoFramework } from '@kit.CryptoArchitectureKit';
import { util, buffer } from '@kit.ArkTS';

function bytes(s:string):number[]{const b=buffer.from(s,'utf8');const a:number[]=[];for(let i=0;i<b.length;i++)a.push(b.readUInt8(i));return a;}
function text(a:number[]):string{return buffer.from(a).toString('utf8');}
function vi(n:number):number[]{const a:number[]=[];do{const b=n%128;n=Math.floor(n/128);a.push(b+(n>0?128:0));}while(n>0);return a;}
function str(tag:number,s:string):number[]{const a=bytes(s);return [tag*8+2,...vi(a.length),...a];}
function num(tag:number,n:number):number[]{return [tag*8,...vi(n)];}
function packet(cmd:number,ch:number,p:number[]):ArrayBuffer{
 const q=[...num(1,ch),...num(2,cmd),...num(3,0),...num(4,9)];
 const h=[72,87,0,0,1,0,q.length,Math.floor(p.length/16777216)%256,Math.floor(p.length/65536)%256,Math.floor(p.length/256)%256,p.length%256];
 return new Uint8Array([...h,...q,...p]).buffer;
}
class Reader {
 pos:number=0;
 data:number[];
 constructor(data:number[]){this.data=data;}
 integer():number{let n=0;let m=1;for(let c=0;c<5;c++){if(this.pos>=this.data.length)throw new Error('Truncated varint');const b=this.data[this.pos++];n+=(b%128)*m;if(b<128)return n;m*=128;}throw new Error('Invalid varint');}
 block():number[]{const len=this.integer();if(this.pos+len>this.data.length)throw new Error('Truncated block');const a=this.data.slice(this.pos,this.pos+len);this.pos+=len;return a;}
}
class Pending {
 output:number[]=[];
 timer:number=0;
 failed:boolean=false;
 resolve:(s:string)=>void;
 reject:(e:Error)=>void;
 constructor(resolve:(s:string)=>void,reject:(e:Error)=>void){this.resolve=resolve;this.reject=reject;}
}
export class HdcClient {
 ready:boolean=false;
 connecting:boolean=false;
 private tcp:socket.TCPSocket=socket.constructTCPSocketInstance();
 private rx:number[]=[];
 private keys:cryptoFramework.KeyPair|null=null;
 private signed:boolean=false;
 private channel:number=150;
 private pending:Map<number,Pending>=new Map();
 private generation:number=0;
 private commandEpoch:number=0;
 private log:(s:string)=>void;
 private state:(ready:boolean,connecting:boolean)=>void;
 constructor(log:(s:string)=>void,state:(ready:boolean,connecting:boolean)=>void){this.log=log;this.state=state;}
 private update(r:boolean,c:boolean):void{this.ready=r;this.connecting=c;this.state(r,c);}
 private failPending(reason:string):void{this.pending.forEach((p:Pending)=>{clearTimeout(p.timer);p.reject(new Error(reason));});this.pending.clear();}
 // 停止等待在途命令，保留连接与认证；已经发出的设备动作不承诺撤销。
 cancelCommands():void{this.commandEpoch++;this.failPending('任务已暂停，命令结果不确定');}
 async connect(port:number):Promise<void>{
  if(this.connecting||this.ready)return;
  this.update(false,true);this.rx=[];this.signed=false;
  const generation=++this.generation;
  const tcp=socket.constructTCPSocketInstance();this.tcp=tcp;
  tcp.on('message',(info:socket.SocketMessageInfo)=>{
   if(generation!==this.generation)return;
   try{const chunk=new Uint8Array(info.message);for(let j=0;j<chunk.length;j++)this.rx.push(chunk[j]);this.parse();}
   catch(e){const err=e as Error;this.log('Protocol error: '+err.message);this.close();}
  });
  tcp.on('close',()=>{if(generation!==this.generation)return;this.update(false,false);this.failPending('HDC connection closed');this.log('TCP CLOSED — reconnect');this.generation++;tcp.close().catch(()=>{});});
  tcp.on('error',(err:BusinessError)=>{if(generation!==this.generation)return;this.log('TCP error '+err.code);this.update(false,false);this.failPending('TCP error '+err.code);this.generation++;tcp.close().catch(()=>{});});
  try{
   if(this.keys===null)this.keys=await cryptoFramework.createAsyKeyGenerator('RSA3072').generateKeyPair();
   await tcp.connect({address:{address:'127.0.0.1',port:port,family:1},timeout:3000});
   this.log('APP TCP CONNECT_OK');
   const payload=[...str(1,'OHOS HDC'),...num(2,0),...num(3,Math.floor(Math.random()*2000000000)+1),...str(4,'127.0.0.1:'+port),...str(5,''),...str(6,'Ver: 3.2.0f73c487f8b34a2ba5')];
   await tcp.send({data:packet(1,0,payload)});
   setTimeout(()=>{if(generation===this.generation&&this.connecting){this.log('Authentication timed out');this.close();}},120000);
  }catch(e){const err=e as BusinessError;this.log('Connect failed '+err.code+' '+err.message);this.close();}
 }
 close():void{this.generation++;this.update(false,false);this.failPending('HDC disconnected');this.tcp.close().catch(()=>{});}
 async execute(command:string,timeout:number=30000):Promise<string>{
  if(!command.startsWith('uitest '))return this.executeRaw(command,timeout);
  const epoch=this.commandEpoch,generation=this.generation,end=Date.now()+timeout;
  while(Date.now()<end){
   if(epoch!==this.commandEpoch||generation!==this.generation||!this.ready)throw new Error('UiTest排队已取消，命令未执行');
   const raw=await this.executeRaw(uiTestCommand(command),Math.max(1,end-Date.now()));
   const output=uiTestReply(command,raw);if(epoch!==this.commandEpoch||generation!==this.generation)throw new Error(output===null?'UiTest排队已取消，命令未执行':'UiTest命令已中断，结果未确认');if(output!==null)return output;
   await new Promise<void>(resolve=>setTimeout(resolve,Math.min(80,Math.max(1,end-Date.now()))));
  }
  throw new Error('UiTest排队超时，命令未取得执行回执');
 }
 private async executeRaw(command:string,timeout:number=30000):Promise<string>{
  if(!this.ready)throw new Error('HDC is not authenticated');
  const channel=++this.channel;
  return new Promise<string>((resolve:(s:string)=>void,reject:(e:Error)=>void)=>{
   const p=new Pending(resolve,reject);this.pending.set(channel,p);
   p.timer=setTimeout(()=>{if(this.pending.delete(channel))reject(new Error('Command timeout'));},timeout);
   this.tcp.send({data:packet(1001,channel,[...bytes(command),0])}).catch((err:BusinessError)=>{clearTimeout(p.timer);this.pending.delete(channel);reject(new Error('Command send failed '+err.code));});
  });
 }
 private parse():void{
  while(this.rx.length>=11){
   const a=this.rx;
   if(a[0]!==72||a[1]!==87)throw new Error('Bad HDC magic');
   const hs=a[5]*256+a[6];const ds=a[7]*16777216+a[8]*65536+a[9]*256+a[10];
   if(hs>1024||ds>8*1024*1024)throw new Error('HDC packet too large');
   if(a.length<11+hs+ds)return;
   const p=a.slice(11+hs,11+hs+ds);this.rx=a.slice(11+hs+ds);
   const r=new Reader(a.slice(11,11+hs));let cmd=0;let channel=0;
   while(r.pos<r.data.length){const tag=r.integer();if(tag%8!==0)throw new Error('Unexpected HDC header');const value=r.integer();if(tag===8)channel=value;if(tag===16)cmd=value;}
   if(cmd===1){this.handshake(p);continue;}
   const pending=this.pending.get(channel);
   if(!pending)continue;
   if(cmd===10||cmd===9){
    const content=cmd===9?p.slice(1):p;for(let k=0;k<content.length;k++)pending.output.push(content[k]);
    if(cmd===9)pending.failed=true;
    if(pending.output.length>12*1024*1024){clearTimeout(pending.timer);this.pending.delete(channel);pending.reject(new Error('Command output too large'));}
   }else if(cmd===2){
    clearTimeout(pending.timer);this.pending.delete(channel);
    const output=text(pending.output);if(pending.failed)pending.reject(new Error(output.substring(0,400)));else pending.resolve(output);
   }
  }
 }
 private handshake(p:number[]):void{
  const r=new Reader(p);let auth=-1;let sid=0;let challenge:number[]=[];
  while(r.pos<r.data.length){const tag=r.integer();if(tag%8===0){const n=r.integer();if(tag===16)auth=n;if(tag===24)sid=n;}else if(tag%8===2){const block=r.block();if(tag===42)challenge=block;}else throw new Error('Unsupported handshake wire');}
  if(auth===2||auth===3){this.authenticate(auth,sid,challenge).catch((e:Error)=>{this.log('Authentication failed: '+e.message);this.close();});}
  if(auth===4&&this.signed){const status=text(challenge);if(status.indexOf('SUCCESS')>=0){this.update(true,false);this.log('AUTH SUCCESS');}else{this.log('Awaiting device trust');}}
 }
 private async authenticate(kind:number,sid:number,challenge:number[]):Promise<void>{
  if(this.keys===null)throw new Error('Missing session key');
  const b64=new util.Base64Helper();let response='';
  if(kind===3){const body=b64.encodeToStringSync(this.keys.pubKey.getEncoded().data);let lines='';for(let j=0;j<body.length;j+=64)lines+=body.substring(j,j+64)+'\n';response='MatePad-SelfHdcProbe\f-----BEGIN PUBLIC KEY-----\n'+lines+'-----END PUBLIC KEY-----\n';this.log('Confirm one-time trust on tablet');}
  else{const signer=cryptoFramework.createSign('RSA3072|PKCS1|NoHash|OnlySign');await signer.init(this.keys.priKey);const signature=await signer.sign({data:new Uint8Array(challenge)});response=b64.encodeToStringSync(signature.data);this.signed=true;}
  await this.tcp.send({data:packet(1,0,[...str(1,'OHOS HDC'),...num(2,kind),...num(3,sid),...str(4,''),...str(5,response),...str(6,'Ver: 3.2.0f73c487f8b34a2ba5')])});
 }
}
