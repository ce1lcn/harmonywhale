// Portions adapted from DeepSeek Harness packages/core/agent-loop/src/tool-calls.ts (rolling bounded pool, exclusive barrier, model-ordered results)
// and packages/core/tools (executionMode). Copyright (c) 2026 DeepSeek. Licensed under the MIT License; full notice in docs/THIRD-PARTY.md.
// 0.8.4 B2：只读工具并行执行的纯逻辑。
// 与 DSH 的差别：DSH 在一个步骤里把连续的并发安全调用放进滚动池（上限 10），遇到独占调用就设屏障；大肥鱼并发上限取 4，
// 且只有“本轮开头连续的并发安全调用”才并行，遇到设备或写入工具后，排在它后面的调用一律串行（和 0.8.3 的“一轮一个变更”规则一致）。
import {DeviceError} from './Elements';
import {WebSource} from './WebTools';

export const PARALLEL_LIMIT:number=4;
// 并发安全的只读工具：不碰设备连接的写操作、不改变会话数据。get_capabilities 只读设备列表，也允许。
export const PARALLEL_SAFE:string[]=['web_search','web_fetch','file_read','file_list','skill_list','skill_load','get_capabilities'];

export function isParallelSafe(name:string):boolean{return PARALLEL_SAFE.indexOf(name)>=0;}

// 取本轮开头连续的并发安全调用（最多 limit 个）。第一个不安全的调用就是屏障：它和后面的调用都不并行。
export function parallelPrefix(names:string[],limit:number=PARALLEL_LIMIT):number{
 let n:number=0;
 while(n<names.length&&n<limit&&isParallelSafe(names[n]))n++;
 return n;
}

// 有界并发：同时最多运行 limit 个，返回的 promise 数组与 jobs 一一对应（结果按原顺序取用，和完成顺序无关）。
export function runLimited<T>(jobs:(()=>Promise<T>)[],limit:number):Promise<T>[]{
 const results:Promise<T>[]=[];
 const resolvers:((value:T)=>void)[]=[];
 const rejecters:((error:Error)=>void)[]=[];
 jobs.forEach((_job:()=>Promise<T>,i:number)=>{
  results.push(new Promise<T>((resolve:(value:T)=>void,reject:(error:Error)=>void)=>{resolvers[i]=resolve;rejecters[i]=reject;}));
 });
 let next:number=0;let running:number=0;
 const pump=():void=>{
  while(running<limit&&next<jobs.length){
   const i:number=next++;running++;
   let p:Promise<T>;
   try{p=jobs[i]();}catch(e){p=Promise.reject(e as Error);}
   p.then((value:T)=>{running--;resolvers[i](value);pump();},(error:Error)=>{running--;rejecters[i](error);pump();});
  }
 };
 pump();
 return results;
}

export interface EarlyRun {promise:Promise<EarlyResult>;ms?:number;}
export interface EarlyResult {output:string;sources:WebSource[];ms:number;}

export const CANCELLED_TEXT:string='已取消：任务已停止，这次调用没有执行';
export function cancelledError():DeviceError{return new DeviceError('INTERRUPTED','已取消');}
