import {fileIo as fs} from '@kit.CoreFileKit';
import {util,buffer} from '@kit.ArkTS';
import {cryptoFramework} from '@kit.CryptoArchitectureKit';
import {huks} from '@kit.UniversalKeystoreKit';
import {BusinessError} from '@kit.BasicServicesKit';
import {State,defaults,Usage} from './Types';
import {migrateBudgetBase,DEFAULT_CONTEXT_WINDOW} from './ExecutionPolicy';
interface Secret {nonce:number[];cipher:number[];}
export class Store {
 root:string; constructor(root:string){this.root=root;}
 read(path:string,maxBytes:number=8*1024*1024):string{const f=fs.openSync(path,fs.OpenMode.READ_ONLY);try{const size=fs.statSync(f.fd).size;if(size>maxBytes)throw new Error('文件过大');const data=new Uint8Array(size);let used=0;while(used<size){const chunk=new ArrayBuffer(Math.min(128*1024,size-used));const count=fs.readSync(f.fd,chunk);if(count<=0||count>chunk.byteLength)throw new Error('文件读取不完整');data.set(new Uint8Array(chunk,0,count),used);used+=count;}return buffer.from(data.buffer).toString('utf8');}finally{fs.closeSync(f.fd);}}
 write(path:string,value:string):void{const f=fs.openSync(path+'.tmp',fs.OpenMode.CREATE|fs.OpenMode.READ_WRITE|fs.OpenMode.TRUNC);try{fs.writeSync(f.fd,value);fs.fsyncSync(f.fd);}finally{fs.closeSync(f.fd);}fs.renameSync(path+'.tmp',path);}
 load():State{const path=this.root+'/agent.json';if(!fs.accessSync(path))return defaults();const s=JSON.parse(this.read(path,64*1024*1024)) as State;(s.profiles??[]).forEach(p=>{if(p.baseUrl.replace(/\/+$/,'')==='https://api.deepseek.com'&&p.model==='deepseek-flash'&&p.contextWindow===32768)p.contextWindow=262144;});
  /* 0.8.0.2 一次性迁移：旧默认值升级为新默认，用户明确设置的其他值保留。262144 与 4096 是旧默认，无法区分是否手动设置，按旧默认升级（记录于验收文档）。 */
  if((s.configVersion??0)<8002){(s.profiles??[]).forEach(p=>{const official=/^https:\/\/api\.deepseek\.com\/?$/.test(p.baseUrl.trim());if(official&&(p.contextWindow===262144||p.contextWindow===32768))p.contextWindow=DEFAULT_CONTEXT_WINDOW;if(p.outputTokens===4096)p.outputTokens=undefined;if(p.thinking==='enabled'&&!p.effort)p.effort='high';});if(s.tokenBudget===5000000)s.tokenBudget=undefined;s.configVersion=8002;}if((s.compactConfigVersion??0)<8500){s.compactReplay=false;s.compactConfigVersion=8500;}s.sessions.forEach(session=>{if(session.plan?.status==='running')session.plan.status='paused';session.tasks.forEach(task=>{if(task.budgetBase!==undefined&&task.budgetUnit!=='cost'){task.budgetBase=migrateBudgetBase(task.budgetBase,task.usage);task.budgetUnit='cost';}if(['running','observing','waiting','approval'].indexOf(task.status)>=0){task.status='paused';task.reason='应用已重新启动，请重新观察后继续';}task.records.forEach(r=>{if(r.status==='pending')r.status='uncertain';});});});return s;}
 save(state:State):void{this.write(this.root+'/agent.json',JSON.stringify(state));}
 parameters(purpose:number):huks.HuksParam[]{return [{tag:huks.HuksTag.HUKS_TAG_ALGORITHM,value:huks.HuksKeyAlg.HUKS_ALG_AES},{tag:huks.HuksTag.HUKS_TAG_KEY_SIZE,value:256},{tag:huks.HuksTag.HUKS_TAG_PURPOSE,value:purpose},{tag:huks.HuksTag.HUKS_TAG_BLOCK_MODE,value:huks.HuksCipherMode.HUKS_MODE_GCM},{tag:huks.HuksTag.HUKS_TAG_PADDING,value:huks.HuksKeyPadding.HUKS_PADDING_NONE}];}
 async secret(id:string,value?:string):Promise<string>{if(!/^[a-zA-Z0-9_-]+$/.test(id))throw new Error('密钥标识无效');const path=this.root+'/secret-'+id+'.json';const alias='tablet-agent-v1';const enc=huks.HuksKeyPurpose.HUKS_KEY_PURPOSE_ENCRYPT;const dec=huks.HuksKeyPurpose.HUKS_KEY_PURPOSE_DECRYPT;
  let exists=false;
  try{exists=await huks.isKeyItemExist(alias,{properties:[]});}catch(e){if((e as BusinessError).code!==12000011)throw new Error('HUKS 检查失败 ('+(e as BusinessError).code+')');}
  if(!exists)await huks.generateKeyItem(alias,{properties:this.parameters(enc|dec)});
  if(value===''){if(fs.accessSync(path))fs.unlinkSync(path);return '';}
  if(value===undefined&&!fs.accessSync(path))return '';
  const old=value===undefined?JSON.parse(this.read(path)) as Secret:null;
  const nonce=old?new Uint8Array(old.nonce):cryptoFramework.createRandom().generateRandomSync(12).data;
  const encoded=buffer.from(value??'','utf8');const plain:number[]=[];for(let i=0;i<encoded.length;i++)plain.push(encoded.readUInt8(i));const data=old?new Uint8Array(old.cipher):new Uint8Array(plain);
  const props=this.parameters(old?dec:enc);props.push({tag:huks.HuksTag.HUKS_TAG_NONCE,value:nonce},{tag:huks.HuksTag.HUKS_TAG_ASSOCIATED_DATA,value:new Uint8Array([84,65])});
  let payload=data;if(old){props.push({tag:huks.HuksTag.HUKS_TAG_AE_TAG,value:data.slice(-16)});payload=data.slice(0,-16);}
  const handle=await huks.initSession(alias,{properties:props});const result=await huks.finishSession(handle.handle,{properties:props,inData:payload});if(!result.outData)throw new Error('密钥加解密失败');
  if(old)return buffer.from(result.outData).toString('utf8');
  this.write(path,JSON.stringify({nonce:Array.from(nonce),cipher:Array.from(result.outData)} as Secret));return value??'';
 }
 taskUsage(id:string,usage:Usage):void{try{const dir=this.root+'/artifacts';if(!fs.accessSync(dir))fs.mkdirSync(dir);this.write(dir+'/usage-'+id+'.json',JSON.stringify(usage));}catch(e){/* Usage remains persisted in the task if the extra artifact cannot be written. */}}
 clearScreens():void{fs.listFileSync(this.root).filter(n=>n.startsWith('screen-')).forEach(n=>fs.unlinkSync(this.root+'/'+n));}
}
