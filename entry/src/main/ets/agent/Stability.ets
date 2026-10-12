export interface StabilityReport {samples:number;consecutive:number;elapsedMs:number;readMs:number[];extended:boolean;reason:string;changedFields:string[];}
export function stabilityNote(r:StabilityReport):string{
 const duration=(r.elapsedMs/1000).toFixed(1)+'秒';
 if(r.reason==='STABLE')return '布局稳定：'+r.samples+'次采样，'+duration;
 if(r.reason==='INSUFFICIENT_SAMPLES')return '稳定等待已到期（'+duration+'），有效样本不足；还需重新观察确认';
 if(r.reason==='CONTENT_CHANGING')return '布局仍在变化，已等待'+duration+'；还需重新观察确认';
 return '稳定检查未完成（'+duration+'）：'+r.reason;
}
// Focus/caret and temporary references are not business-state changes. Bounds,
// labels and enabled state remain significant; never normalize the model view.
export function stabilityFingerprint(layout:string):string {
 return layout.split('\n').filter(line=>{try{const n=JSON.parse(line) as Record<string,Object>;const c=n.normalizedCenter as number[];return !c||c[1]>=40;}catch(e){return true;}}).map(line=>{
  try{const n=JSON.parse(line) as Record<string,Object>;const clean:Record<string,Object>={};Object.keys(n).sort().filter(k=>k!=='elementId'&&k!=='focused').forEach(k=>{clean[k]=n[k];});return JSON.stringify(clean);}catch(e){return line;}
 }).join('\n');
}
export class StabilityTracker {
 start:number;last:string='';samples:number=0;consecutive:number=0;durations:number[]=[];fields:string[]=[];
 constructor(start:number){this.start=start;}
 sample(layout:string,now:number,duration:number):void {
  const current=stabilityFingerprint(layout);this.samples++;this.durations.push(duration);
  if(this.samples>1&&current!==this.last){const a=this.last.split('\n'),b=current.split('\n');if(a.length!==b.length&&this.fields.indexOf('elementCount')<0)this.fields.push('elementCount');for(let i=0;i<Math.min(a.length,b.length);i++){try{const left=JSON.parse(a[i]) as Record<string,Object>,right=JSON.parse(b[i]) as Record<string,Object>;Object.keys(right).forEach(k=>{if(JSON.stringify(left[k])!==JSON.stringify(right[k])&&this.fields.indexOf(k)<0)this.fields.push(k);});}catch(e){if(this.fields.indexOf('layout')<0)this.fields.push('layout');}}}
  this.consecutive=current===this.last?this.consecutive+1:1;this.last=current;
 }
 get done():boolean{return this.consecutive>=2;}
 report(now:number,reason?:string):StabilityReport{return {samples:this.samples,consecutive:this.consecutive,elapsedMs:now-this.start,readMs:this.durations,extended:now-this.start>5000,reason:reason??(this.done?'STABLE':this.samples<3?'INSUFFICIENT_SAMPLES':'CONTENT_CHANGING'),changedFields:this.fields};}
}
