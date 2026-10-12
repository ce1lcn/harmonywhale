import {TreeNode} from './Elements';
export interface ReadSample {elapsedMs:number;ok:boolean;error:string;}
export interface ReadReport {phase:string;elapsedMs:number;samples:ReadSample[];}
// Fixed, read-only native transport contrast; never exposes a shell tool to the model.
export async function readOnlyProbe(phase:string,execute:(cmd:string,timeout:number)=>Promise<string>,active:()=>boolean,now:()=>number=()=>Date.now(),delay:(ms:number)=>Promise<void>=(ms:number)=>new Promise<void>(resolve=>setTimeout(resolve,ms))):Promise<ReadReport>{
 if(phase!=='with-checks'&&phase!=='without-checks')throw new Error('未知对照组');
 const began=now(),end=began+30000,samples:ReadSample[]=[];
 while(active()&&now()<end){
  const start=now();let ok=false,error='';
  try{
   await execute('uitest dumpLayout -p /data/local/tmp/readonly-0850.json',Math.min(8000,Math.max(1,end-now())));
   if(!active()||now()>=end)break;
   const raw=await execute('cat /data/local/tmp/readonly-0850.json',Math.min(8000,Math.max(1,end-now())));
   const tree=JSON.parse(raw) as TreeNode;
   let fixture=false;
   const walk=(node:TreeNode,bundle:string=''):void=>{const a=node.attributes??{};const app=a.bundleName??bundle;if(app==='com.harmonyloom.selfhdcprobe'&&(a.text==='执行层测试页'||a.id==='fixture_input'))fixture=true;node.children?.forEach(c=>walk(c,app));};walk(tree);
   if(!fixture){error='SCOPE_CHANGED';}else ok=true;
  }catch(e){error=(e as Error).message.includes('JSON')?'INVALID_JSON':'READ_FAILED';}
  samples.push({elapsedMs:now()-start,ok:ok,error:error});
  if(error==='SCOPE_CHANGED')break;
  if(active()&&now()<end)await delay(Math.min(500,end-now()));
 }
 return {phase:phase,elapsedMs:now()-began,samples:samples};
}
