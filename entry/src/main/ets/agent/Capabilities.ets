// 0.8.3 get_capabilities 的文本组装：工具清单、已安装可启动应用、屏幕、网络、当前时间。纯函数。
import {BundleInfo} from './AppCatalog';

export interface CapabilityInput {tools:string[];apps:BundleInfo[];appsNote:string;width:number;height:number;network:string;now:Date;}

function pad2(n:number):string{return n<10?'0'+n:String(n);}

export function localTimeText(now:Date):string{
 return now.getFullYear()+'-'+pad2(now.getMonth()+1)+'-'+pad2(now.getDate())+' '+pad2(now.getHours())+':'+pad2(now.getMinutes())+'（本机时区，UTC'+(now.getTimezoneOffset()<=0?'+':'-')+pad2(Math.floor(Math.abs(now.getTimezoneOffset())/60))+'）';
}

export function orientationText(width:number,height:number):string{
 if(!(width>0)||!(height>0))return '未知';
 return (width>=height?'横屏':'竖屏')+' '+width+'×'+height;
}

// 大肥鱼自己的包名与名称。模型曾因列表里写的是 HarmonyWhale 而回答“大肥鱼不在应用列表里”，所以单独标注。
export const SELF_APP_BUNDLE:string='com.harmonyloom.selfhdcprobe';
export const SELF_APP_LABEL:string='HarmonyWhale（大肥鱼自己）';
// 0.8.4 A5：应用列表上限放宽到 400，足以容纳 bm dump -a -l 的全部包（真机 198 个）；0.8.3 的 120 个上限是截断（详情取数与显示各有一个 120 上限）。
export const APP_LIST_LIMIT:number=400;

export function appLine(a:BundleInfo):string{
 const isSelf:boolean=a.bundle===SELF_APP_BUNDLE;
 const label:string=isSelf?SELF_APP_LABEL:(a.label||'（名称未知）');
 return '- '+label+'  '+a.bundle+(a.ability?'  ['+a.ability+']':'');
}

export function capabilitiesText(input:CapabilityInput):string{
 const lines:string[]=[];
 lines.push('工具：'+(input.tools.length?input.tools.join('、'):'无'));
 lines.push('屏幕：'+orientationText(input.width,input.height));
 lines.push('网络：'+input.network);
 lines.push('时间：'+localTimeText(input.now));
 lines.push('你自己：大肥鱼（HarmonyWhale），包名 '+SELF_APP_BUNDLE+'。它就在下面的应用列表里；需要回到大肥鱼时 launch_app 这个包名。');
 const apps:BundleInfo[]=input.apps.some((a:BundleInfo)=>a.bundle===SELF_APP_BUNDLE)?input.apps.slice():input.apps.concat([{bundle:SELF_APP_BUNDLE,label:'HarmonyWhale',ability:'ProbeAbility'} as BundleInfo]);
 lines.push('已安装应用（'+apps.length+' 个；'+input.appsNote+'；列表含系统服务与没有桌面入口的包；没有 [启动入口] 的包启动时会自动查询）：');
 const shown:BundleInfo[]=apps.slice(0,APP_LIST_LIMIT);
 shown.forEach((a:BundleInfo)=>{lines.push(appLine(a));});
 if(apps.length>shown.length)lines.push('…另有 '+(apps.length-shown.length)+' 个未列出');
 return lines.join('\n');
}
