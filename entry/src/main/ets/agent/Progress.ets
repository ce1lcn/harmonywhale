// Compare content rather than status-bar clock ticks. Never alter the observation
// presented to the model; this normalization is only for loop detection.
export function stableFingerprint(layout:string):string {
 return layout.split('\n').filter(line=>{
  try {
   const node=JSON.parse(line) as Record<string,Object>;
   const center=node.normalizedCenter as number[];
   // The native status bar splits its clock into separate digit and ':' nodes.
   if(center?.length===2&&center[1]<40)return false;
  }catch(e){}
  return true;
 }).join('\n').replace(/"text":"\d{1,2}:\d{2}(?::\d{2})?"/g,'"text":"<clock>"');
}
// Portions Copyright (c) 2026 DeepSeek. MIT; see docs/THIRD-PARTY.md.
export class ProgressGuard {
 signatures:string[]=[];note:string='';
 check(signature:string):void {
  this.note='';this.signatures.push(signature);this.signatures=this.signatures.slice(-32);
  const n=this.signatures.length;
  for(let period=1;period<=4;period++){
   let repeats=1;
   while((repeats+1)*period<=n){let same=true;for(let i=0;i<period;i++)if(this.signatures[n-1-i]!==this.signatures[n-1-i-repeats*period])same=false;if(!same)break;repeats++;}
   if(repeats>=8)throw new Error('我先停一下：操作重复八次仍没有进展。说“继续”我会重新看屏幕。');
   if(repeats===3||repeats===5)this.note='同样的操作已重复'+repeats+'次，请检查实际结果，换一种方法，避免继续重复。';
   if(repeats>1)return;
  }
 }
}
