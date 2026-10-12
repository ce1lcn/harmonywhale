import {buffer} from '@kit.ArkTS';
import {webview} from '@kit.ArkWeb';
import {PdfBridge} from '../agent/PdfBridge';
@Component
export struct PdfSurface {
 controller:webview.WebviewController=new webview.WebviewController();
 pending:boolean=false;serial:number=0;timer:number=0;pageUrl:string='';pageToken:string='';printing:boolean=false;
 resolve:((data:Uint8Array)=>void)|null=null;reject:((error:Error)=>void)|null=null;
 aboutToDisappear():void{this.stop();PdfBridge.render=null;PdfBridge.cancel=null;}
 stop():void{this.serial++;this.pending=false;this.printing=false;clearTimeout(this.timer);this.reject?.(new Error('PDF_CANCELLED：PDF 生成已取消'));this.reject=null;this.resolve=null;}
 attach():void{PdfBridge.cancel=():void=>this.stop();PdfBridge.render=(html:string)=>new Promise<Uint8Array>((resolve,reject)=>{if(this.pending){reject(new Error('PDF_BUSY：已有PDF在生成'));return;}this.pending=true;this.printing=false;this.serial++;this.pageUrl='https://harmonywhale.invalid/pdf/'+this.serial;this.pageToken='whalePdf'+Date.now().toString(36)+this.serial;this.resolve=resolve;this.reject=reject;this.timer=setTimeout(():void=>this.stop(),30000);try{this.controller.loadData('<!--'+this.pageToken+'-->'+html,'text/html','utf-8',this.pageUrl,this.pageUrl);}catch(e){this.stop();}});}
 matches(pageUrl:string):boolean{if(pageUrl===this.pageUrl)return true;if(!pageUrl.startsWith('data:'))return false;const comma=pageUrl.indexOf(',');if(comma<0)return false;const prefix=pageUrl.slice(comma+1,comma+8193);try{return pageUrl.slice(0,comma).toLowerCase().includes(';base64')?buffer.from(prefix,'base64').toString('utf8').includes(this.pageToken):prefix.includes(this.pageToken);}catch(e){return false;}}
 async ready(pageUrl:string):Promise<void>{if(!this.pending||this.printing||!this.matches(pageUrl))return;this.printing=true;const serial=this.serial;try{const result=await this.controller.createPdf({width:8.27,height:11.69,marginTop:0.5,marginBottom:0.5,marginLeft:0.5,marginRight:0.5,shouldPrintBackground:true});if(serial!==this.serial||!this.pending)return;clearTimeout(this.timer);this.pending=false;this.resolve?.(result.pdfArrayBuffer());this.resolve=null;this.reject=null;}catch(e){if(serial===this.serial){clearTimeout(this.timer);this.pending=false;this.reject?.(e as Error);this.resolve=null;this.reject=null;}}}
 build(){Web({src:'about:blank',controller:this.controller}).javaScriptAccess(false).fileAccess(false).onlineImageAccess(false).onControllerAttached(()=>this.attach()).onPageEnd((event)=>{this.ready(event.url);}).width(794).height(1123).opacity(0).hitTestBehavior(HitTestMode.None).accessibilityLevel('no')}
}
