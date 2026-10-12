// Portions adapted from DeepSeek Harness packages/compaction/compaction-basic/src/summarizer.ts (COMPACTION_INSTRUCTION, CHECKPOINT_PREAMBLE, <compacted-summary> framing)
// and packages/compaction/compaction-tool-result-pruner (head/middle/tail pruning). Copyright (c) 2026 DeepSeek. Licensed under the MIT License; full notice in docs/THIRD-PARTY.md.
// 0.8.4 B6：压缩改进的纯逻辑。
//  1. 压缩请求 = 原样回放此前请求的前缀（系统提示 + 工具 + 被压缩的那段历史）+ 末尾一条压缩指令，复用前缀缓存；
//  2. 摘要使用固定的中文五个小节；3. 再次压缩时合并旧摘要（旧摘要用 <compacted-summary> 包着，回放在前缀里）；4. 超大的旧工具结果只保留头尾。
// 与 DSH 的差别：DSH 的小节是英文的八节（主要请求、关键概念、文件、错误与修复、待办、当前工作、下一步、关键上下文），这里按任务书改成中文五节；
// DSH 在压缩触发后才修剪，并把原文留在日志里；大肥鱼没有“日志层”，所以历史工具结果在拼装上下文时就做头尾修剪（原文仍完整保存在会话里），压缩请求和普通请求因此保持同一前缀。
import {Usage} from './Types';

export const SUMMARY_SECTIONS:string[]=['目标','已完成','关键事实与文件','未完成与下一步','用户偏好'];
export const SUMMARY_OPEN_TAG:string='<compacted-summary>';
export const SUMMARY_CLOSE_TAG:string='</compacted-summary>';
// 压缩请求的输出上限：摘要本身约 1500 token；思考开启时 max_tokens 含思考内容，留足余量。
export const COMPACT_OUTPUT_TOKENS:number=16000;

export const COMPACT_INSTRUCTION:string=[
 '你现在是这次对话的压缩引擎。把上面的对话压缩成一份检查点摘要，让另一个模型读了它就能无缝接着做，不丢关键信息。',
 '',
 '严格按下面的 Markdown 结构输出：五个小节一个都不能少，顺序不变；某一节没有内容就写“- （无）”。每节用简短条目，不写大段散文。',
 '',
 '## 目标',
 '- [用户最初和后来调整过的目标与约束；措辞重要的地方原话引用]',
 '',
 '## 已完成',
 '- [已经做完并核实的动作与结果；标明哪些只是“已发出、效果未验证”或“不确定”]',
 '',
 '## 关键事实与文件',
 '- [后面还要用到的事实、数字、应用与页面状态、会话文件（写 fileId 和文件名）、网页来源链接、出过的错与修复]',
 '',
 '## 未完成与下一步',
 '- [用户明确要的、还没做完的事；以及紧接着该做的那一步]',
 '',
 '## 用户偏好',
 '- [用户表达过的偏好、纠正和禁止事项]',
 '',
 '规则：',
 '- 用中文写，保留精确的文件名、fileId、数字、错误文字和应用包名。',
 '- 忠实记录用户的明确指示和纠正。',
 '- 不要提到这次压缩，也不要写“上文”；只输出摘要正文，不要调用任何工具，不要执行任何操作。',
 '- 上文如果已经有一份 '+SUMMARY_OPEN_TAG+' 早期对话摘要，那是上一份检查点：不要原样抄，保留仍然成立的内容、去掉过时的、把新信息合并进同一份五节摘要。',
 '- 历史操作不是待办：已经执行过的动作不要写成需要重做；效果不确定的动作要标明“需先观察核实”。'
].join('\n');

const CHECKPOINT_PREAMBLE:string='这是自动生成的检查点，概括了更早的对话。把它当作已确立的背景，在此基础上接着做，不要重复其中的内容，也不要提及压缩。其中记录的历史动作不重放。';

// 拼进上下文的早期摘要消息（Conversation 在系统提示之后第一条）。
export function summaryMessage(summary:string):string{
 return '早期对话摘要（不重放动作）：'+CHECKPOINT_PREAMBLE+'\n'+SUMMARY_OPEN_TAG+'\n'+summary+'\n'+SUMMARY_CLOSE_TAG;
}

// 把模型输出整理成固定五节：缺的小节补“（无）”，顺序按固定顺序；模型没有按结构输出时，整段放进“关键事实与文件”，不丢信息。
export function normalizeSummary(raw:string):string{
 let text:string=raw.replace(SUMMARY_OPEN_TAG,'').replace(SUMMARY_CLOSE_TAG,'').trim();
 const lines:string[]=text.split('\n');
 const found:Record<string,string[]>={};
 let current:string='';
 let sawHeading:boolean=false;
 lines.forEach((line:string)=>{
  const m=/^#{1,3}\s*(目标|已完成|关键事实与文件|未完成与下一步|用户偏好)\s*[:：]?\s*$/.exec(line.trim());
  if(m){current=m[1];sawHeading=true;if(!found[current])found[current]=[];return;}
  if(current)found[current].push(line);
 });
 if(!sawHeading){
  found['关键事实与文件']=[text];
 }
 const parts:string[]=SUMMARY_SECTIONS.map((name:string)=>{
  const body:string=(found[name]??[]).join('\n').trim();
  return '## '+name+'\n'+(body.length>0?body:'- （无）');
 });
 return parts.join('\n\n');
}

export function hasAllSections(text:string):boolean{
 return SUMMARY_SECTIONS.every((name:string)=>new RegExp('^#{1,3}\\s*'+name+'\\s*$','m').test(text));
}

// 缓存命中率 = 缓存读 /（缓存读 + 未缓存输入 + 缓存写）。没有用量返回 -1。
export function cacheHitRate(u?:Usage):number{
 if(!u)return -1;
 const all:number=u.cacheRead+u.input+u.cacheWrite;
 return all>0?u.cacheRead/all:-1;
}
export function hitText(u?:Usage):string{
 const r:number=cacheHitRate(u);
 if(!u||r<0)return '缓存命中：无数据';
 return '缓存命中 '+(r*100).toFixed(1)+'%（缓存读 '+u.cacheRead+' / 未缓存输入 '+u.input+' / 输出 '+u.output+' tok）';
}

// 0.8.4.1：历史里每条工具结果最多保留的字数。真机 0.8.4 发现：0.8.3 起这个上限是 4000 字，而转存阈值是 16384 字，
// 4000–16384 字之间的结果既被截成头尾、又没有转存成文件，模型拿不到中间内容。两者对齐：不超过 16384 字的结果完整进上下文，超过的由 Spill 转存成会话文件（预览远小于这个上限）。
export const HISTORY_RESULT_LIMIT:number=16384;
// ---- 旧工具结果的头尾修剪（DSH tool-result-pruner：头 + 中间省略标记 + 尾）。limit 内原样返回。
export const PRUNE_HEAD_RATIO:number=0.75;
export const PRUNE_TAIL_RATIO:number=0.2;
export function pruneMiddle(text:string,limit:number):string{
 if(text.length<=limit)return text;
 const head:number=Math.floor(limit*PRUNE_HEAD_RATIO);
 const tail:number=Math.floor(limit*PRUNE_TAIL_RATIO);
 let a:string=text.slice(0,head);
 const last:number=a.charCodeAt(a.length-1);
 if(last>=0xd800&&last<=0xdbff)a=a.slice(0,a.length-1);
 let b:string=text.slice(text.length-tail);
 const first:number=b.charCodeAt(0);
 if(first>=0xdc00&&first<=0xdfff)b=b.slice(1);
 return a+'\n\n[… 工具结果中间省略 '+(text.length-a.length-b.length)+' 字 …]\n\n'+b;
}
