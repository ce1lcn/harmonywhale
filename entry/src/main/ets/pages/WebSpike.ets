import {common} from '@kit.AbilityKit';
import {router} from '@kit.ArkUI';
import {Store} from '../agent/Store';
import {Web} from '../agent/Web';
import {readable} from '../agent/Readable';
import {bingResults,SearchHit} from '../agent/SearchResults';
import {buffer} from '@kit.ArkTS';
interface Candidate {name:string;url:string;body?:string;}
interface SpikeResult {name:string;url:string;status:number;elapsedMs:number;bytes:number;charset:string;redirects:number;title:string;characters:number;sample:string;blocked:boolean;error:string;searchResults?:SearchHit[];}
interface SpikeReport {time:number;version:string;runtime:string;credentials:string;results:SpikeResult[];}
@Entry
@Component
struct WebSpike {
 @State progress:string='等待开始';
 @State running:boolean=false;
 web:Web=new Web();
 serial:number=0;
 aboutToDisappear():void{this.web.cancel();}
 async start():Promise<void>{
  if(this.running)return;this.running=true;const serial=++this.serial;
  const store=new Store((this.getUIContext().getHostContext() as common.UIAbilityContext).filesDir);
  const report:SpikeReport={time:Date.now(),version:'0.7.8.6',runtime:'HarmonyOS NetworkKit（平板应用内请求，无电脑网络代理）',credentials:'未提供搜索API凭据；API样例仅验证可达性与鉴权响应',results:[]};
  const candidates:Candidate[]=[
   {name:'bocha',url:'https://api.bochaai.com/v1/web-search',body:'{"query":"杭州天气","freshness":"noLimit","summary":true,"count":6}'},
   {name:'bocha-cn',url:'https://api.bocha.cn/v1/web-search',body:'{"query":"杭州天气","summary":true,"count":6}'},
   {name:'zhipu',url:'https://open.bigmodel.cn/api/paas/v4/web_search',body:'{"search_query":"杭州天气","search_engine":"search_std","count":6}'},
   {name:'bing',url:'https://cn.bing.com/search?q='+encodeURIComponent('杭州天气')},
   {name:'news-portal',url:'https://finance.sina.com.cn/?forceLanding=true'},
   {name:'news-gbk',url:'https://finance.sina.com.cn/head/finance20101001pm.shtml'},
   {name:'zhihu',url:'https://www.zhihu.com/question/19556620'},
   {name:'government',url:'https://www.moe.gov.cn/jyb_xwfb/xw_zt/moe_357/2026/2026_zt03/baogao/202603/t20260314_1430876.html'},
   {name:'encyclopedia',url:'https://baike.baidu.com/item/'+encodeURIComponent('鸿蒙')},
   {name:'wechat',url:'https://mp.weixin.qq.com/s/XOTTxujtAId1vNXuwWOe2w'},
   {name:'private-loopback',url:'http://127.0.0.1:40373/'},
   {name:'private-host',url:'http://localhost:40373/'}
  ];
  try{
   for(let i=0;i<candidates.length;i++){
    if(!this.running||serial!==this.serial)break;const c=candidates[i];this.progress='请求 '+(i+1)+'/'+candidates.length+'：'+c.name;const start=Date.now();
    const item:SpikeResult={name:c.name,url:c.url,status:0,elapsedMs:0,bytes:0,charset:'',redirects:0,title:'',characters:0,sample:'',blocked:false,error:''};
    try{const r=await this.web.request(c.url,c.body);const page=readable(r.text);item.url=r.url;item.status=r.status;item.elapsedMs=r.elapsedMs;item.bytes=r.bytes;item.charset=r.charset;item.redirects=r.redirects;item.title=page.title;item.characters=page.text.length;item.sample=page.text.substring(0,1000);item.blocked=page.blocked;if(c.name==='bing')item.searchResults=bingResults(r.text,6,(value:string)=>buffer.from(value.replace(/-/g,'+').replace(/_/g,'/'),'base64').toString('utf8'));store.write(store.root+'/web-spike-'+c.name+'.html',r.text);}catch(e){item.error=(e as Error).message;item.elapsedMs=Date.now()-start;}
    if(serial!==this.serial)break;report.results.push(item);store.write(store.root+'/web-spike-078.json',JSON.stringify(report));
   }
   if(serial===this.serial)this.progress='测试结束：'+report.results.length+' 项；记录已保存（鉴权失败不代表搜索成功）';
  }catch(e){if(serial===this.serial)this.progress='记录失败：'+(e as Error).message;}finally{if(serial===this.serial)this.running=false;}
 }
 build(){Scroll(){Column({space:20}){
  Text('联网可达性测试').fontSize(24)
  Text('应用内请求；不会读取模型 Key 或其他应用凭据。').fontSize(16)
  Text(this.progress).fontSize(16)
  Button('开始联网测试').enabled(!this.running).onClick(()=>{this.start();})
  Button('取消联网测试').enabled(this.running).onClick(()=>{this.serial++;this.running=false;this.web.cancel();this.progress='已取消，不再发起后续请求';})
  Button('返回').onClick(()=>{this.serial++;this.web.cancel();this.running=false;router.back();})
 }.padding({top:60,bottom:40}).width('100%')}.width('100%').height('100%').backgroundColor('#FFFFFF')}
}
