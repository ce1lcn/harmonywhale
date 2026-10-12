import {uid} from './Types';
import {assignStableIds} from './ActionKit';
export interface TreeNode {attributes?:Record<string,string>;children?:TreeNode[];}
export interface Element {labelSource?:string;elementId:string;type:string;text:string;id:string;description:string;parent:string;bounds:number[];normalizedCenter:number[];enabled:boolean;editable:boolean;focused:boolean;password:boolean;clickable:boolean;window:string;}
export interface Snapshot {snapshotId:string;elements:Element[];width:number;height:number;}
export class DeviceError extends Error {code:string;constructor(code:string,message:string){super(message);this.code=code;}}
export function snapshot(tree:TreeNode,width:number,height:number):Snapshot {
 const elements:Element[]=[];
 const visit=(node:TreeNode,parent:string,sensitive:boolean=false):void=>{const a=node.attributes??{};const bounds=(a.bounds??'').match(/-?\d+/g)?.map(v=>Number(v))??[];const password=sensitive||a.password==='true'||a.isPassword==='true';const childLabels:string[]=[];const labels=(n:TreeNode):void=>{if(n.attributes?.password==='true'||n.attributes?.isPassword==='true')return;if(n.attributes?.text)childLabels.push(n.attributes.text);n.children?.forEach(c=>labels(c));};if(a.clickable==='true'&&!password)node.children?.forEach(c=>labels(c));const label=childLabels.join(' ').trim().slice(0,500);const context=[a.id??'',a.type??'',password?'[敏感输入]':a.text??''].join('|');
 if(a.visible==='false')return;
 if(elements.length<240&&bounds.length===4&&bounds[2]>bounds[0]&&bounds[3]>bounds[1]&&(a.text||a.description||a.clickable==='true'||a.editable==='true'||a.scrollable==='true'||/Canvas|XComponent/.test(a.type??''))){
 elements.push({elementId:'e'+(elements.length+1),type:a.type??'',text:password?'[敏感输入]':(a.text?.trim()||label).slice(0,500),id:a.id??'',description:password?'':(a.description??'').trim().slice(0,200),parent:parent,bounds:bounds,normalizedCenter:[Math.round((bounds[0]+bounds[2])*500/width),Math.round((bounds[1]+bounds[3])*500/height)],enabled:a.enabled!=='false',editable:a.editable==='true'||/TextInput|TextArea|EditText/.test(a.type??''),focused:a.focused==='true',password:password,window:a.hostWindowId??'',clickable:a.clickable==='true'});}
 node.children?.forEach(child=>visit(child,context,password));};visit(tree,'');
 // 0.8.3.1：elementId 改为由控件属性派生的稳定编号，场景不变时同一控件编号相同。
 assignStableIds(elements);return {snapshotId:uid(),elements:elements,width:width,height:height};
}
export function relocate(old:Snapshot,current:Snapshot,elementId:string):Element {
 if(old.width!==current.width||old.height!==current.height)throw new DeviceError('STALE','屏幕尺寸变化，请重新观察');
 const target=old.elements.find(e=>e.elementId===elementId);if(!target)throw new DeviceError('NOT_FOUND','快照中不存在该元素');
 const windows=old.elements.map(e=>e.window).filter(w=>w);if(windows.length&&!current.elements.some(e=>e.window&&windows.indexOf(e.window)>=0))throw new DeviceError('STALE','前台窗口变化，请重新观察');
 const matches=current.elements.filter(e=>e.id===target.id&&e.type===target.type&&e.text===target.text&&e.description===target.description&&e.parent===target.parent&&e.window===target.window);
 if(matches.length!==1)throw new DeviceError('AMBIGUOUS','目标消失或匹配不唯一，请重新观察');const found=matches[0];if(!found.enabled)throw new DeviceError('DISABLED','目标不可用');return found;
}
export function layoutOf(s:Snapshot):string{return s.elements.map(e=>JSON.stringify(e)).join('\n');}

export function scene(s:Snapshot):string{return s.elements.filter(e=>e.normalizedCenter[1]>=40).map(e=>[e.id,e.type,e.text,e.description,e.parent,e.window].join('|')).sort().join('\n');}
