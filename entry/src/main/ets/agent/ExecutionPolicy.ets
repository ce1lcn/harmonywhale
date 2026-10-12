// Portions Copyright (c) 2026 DeepSeek. MIT; full notice in docs/THIRD-PARTY.md.
import {Usage,Profile} from './Types';
export function callLimit(value?:number):number{return Number.isFinite(value)?Math.min(500,Math.max(50,Math.round(value!))):200;}
// 0.8.0.2：默认每段 2000 万等效用量（可设 1M–20M，0 为不限）。
export const DEFAULT_TOKEN_BUDGET:number=20000000;
export function tokenLimit(value?:number):number{return value===0?0:Number.isFinite(value)?Math.min(20000000,Math.max(1000000,Math.round(value!))):DEFAULT_TOKEN_BUDGET;}
// 0.8.0：预算按“等效用量”计：未缓存输入 + 输出 + 缓存读取 × 0.1。缓存命中不再按全价计入。
export const CACHE_READ_WEIGHT:number=0.1;
export function costTokens(u?:Usage):number{if(!u)return 0;return Math.round((u.input||0)+(u.output||0)+(u.cacheRead||0)*CACHE_READ_WEIGHT);}
// 旧版 budgetBase 按 usage.total 记录；按当时总量占比折算成等效用量口径。
export function migrateBudgetBase(base:number,u?:Usage):number{if(!u||!u.total||base<=0)return 0;if(base>=u.total)return costTokens(u);return Math.round(costTokens(u)*base/u.total);}
export function budgetState(used:number,base:number,limit:number):string{if(!limit)return '';const spent=Math.max(0,used-base);return spent>=limit?'exhausted':spent>=limit*0.8?'warning':'';}
// 0.8.0.2：对齐 DSH（deepseek-harness packages/llm/llm-deepseek/src/defaults.ts@5badb15）：上下文 1,000,000，单次输出 256,000。
// DeepSeek /chat/completions 官方文档：max_tokens 允许 1–393216（384K），且输入+输出不超过模型上下文。
export const DEFAULT_CONTEXT_WINDOW:number=1000000;
export const DEFAULT_OUTPUT_TOKENS:number=256000;
export const MAX_OUTPUT_TOKENS:number=393216;
// 自动档：256000；仅当上下文窗口被调得很小时按窗口的 1/2 收缩，避免预留输出把窗口占满。
export function outputLimit(p:Profile):number{if(p.outputTokens&&p.outputTokens>0)return p.outputTokens;return Math.max(1024,Math.min(DEFAULT_OUTPUT_TOKENS,Math.floor((p.contextWindow||DEFAULT_CONTEXT_WINDOW)/2)));}
// 思考强度：off 对应 thinking=disabled；low/high/max 走 reasoning_effort（默认 high）。
export function effortOf(p:Profile):string{if(p.thinking!=='enabled')return 'off';return p.effort==='low'||p.effort==='max'?p.effort:'high';}
// 遇 length 且没有未完成工具调用时，自动续写的最多次数；第 3 次才暂停。
export const AUTO_CONTINUE_LIMIT:number=2;
// 网络/429/5xx 且未收到正文时的退避：1 s、4 s；429 的 Retry-After 上限 20 s。
export const RETRY_DELAYS:number[]=[500,1000,2000,4000,10000];
export function compactThreshold(window:number,output:number):number{return Math.floor(Math.min(0.8*window,window-output-65536));}
export function compactTailBudget(window:number,output:number):number{return Math.max(2048,Math.floor((window-output)*0.16));}
export const RETRY_AFTER_CAP:number=20000;
export function retryableStatus(code:number):boolean{return code===429||code>=500&&code<=504;}
export function retryAfterMs(value:string|undefined,now:number):number{if(!value)return 0;const v=value.trim();if(/^\d+(\.\d+)?$/.test(v))return Math.min(RETRY_AFTER_CAP,Math.max(0,Math.round(Number(v)*1000)));const t=Date.parse(v);return Number.isFinite(t)?Math.min(RETRY_AFTER_CAP,Math.max(0,t-now)):0;}
export function retryDelay(attempt:number,status:number,retryAfter:number):number{if(status===429&&retryAfter>0)return Math.min(RETRY_AFTER_CAP,retryAfter);return Math.min(10000,Math.round(RETRY_DELAYS[Math.min(attempt,RETRY_DELAYS.length-1)]*(0.9+Math.random()*0.2)));}
// 后台额度：到期前 10 秒回到前台。
export const LEASE_RETURN_MARGIN:number=10000;
// 0.8.4 A1：全屏操作其他应用时，在有效期末尾不足 LEASE_RENEW_LEAD 的安全步骤边界（或模型思考期间），短暂回到大肥鱼再回到目标应用，换一个新的短时租约。
// 每个任务最多续租 LEASE_RENEW_MAX 次（防止失控消耗系统的每日后台配额）；前后台切换最多各等 LEASE_RENEW_WAIT_MS。
export const LEASE_RENEW_LEAD:number=60000;
export const LEASE_RENEW_MAX:number=30;
export const LEASE_RENEW_WAIT_MS:number=5000;
export function isResume(text:string):boolean{return /^(继续|接着来|继续吧|继续执行|go\s+on|resume)[。！!\s]*$/i.test(text.trim());}
export class ScreenProgress {
 unchanged:number=0;warned:boolean=false;
 sample(before:string,after:string):string{if(before!==after){this.unchanged=0;this.warned=false;return '';}this.unchanged++;if(this.unchanged>=8)return 'stop';if(this.unchanged===3||this.unchanged===5)return 'warning';return '';}
}

// ---- 0.8.4 B5：每个工具单独的时限（毫秒）。0 表示不设时限（等用户回答或确认的工具、远程 MCP 工具）。
// 思路取自 DSH packages/guard/timeout-policy：工具声明自己的 timeoutMs，超时后取消该工具并返回 TIMEOUT，不拖住整个任务。
// 数字依据：网页 Web.request 自带 15 s 超时，搜索可能先试博查再回退 Bing，所以 30 s；布局读取 + 截图通常 2–4 s，OCR 再加 1–3 s，所以 20 s / OCR 30 s；
// wait_for 按调用参数（默认 10 s，最多 30 s）再加 5 s 余量；get_capabilities 首次要对每个包执行 bm dump -n（0.8.3 实测约 1 分钟以上），所以 3 分钟。
export const TIMEOUT_WAIT_SLACK_MS:number=5000;
export function toolTimeout(name:string,ocr:boolean=false,timeoutMs?:number):number{
 if(name==='web_download')return 150000;
 if(name==='skill_delete'||name==='skill_set_enabled')return 0;
 if(name.startsWith('document_')||name.startsWith('pdf_')||name.startsWith('zip_')||name.startsWith('image_'))return 45000;
 if(name==='web_search'||name==='web_fetch')return 30000;
 if(name==='observe')return ocr?30000:20000;
 if(name==='wait_for'){const t:number=timeoutMs!==undefined&&Number.isFinite(timeoutMs)?Math.max(0,Math.min(30000,timeoutMs)):10000;return t+TIMEOUT_WAIT_SLACK_MS;}
 if(['click','long_press','double_click','drag','swipe','press_key','back','home','insert_text','replace_text'].indexOf(name)>=0)return 20000;
 if(['scroll','launch_app','click_element','insert_element','replace_element'].indexOf(name)>=0)return 30000;
 if(name==='draw_path')return 120000;
 if(name==='get_capabilities')return 180000;
 if(name.startsWith('file_')||name.startsWith('sheet_')||name.startsWith('presentation_'))return 30000;
 if(['skill_load','skill_list','skill_save','memory_save','memory_forget','clipboard_write','todo_write'].indexOf(name)>=0)return 10000;
 return 0;
}
