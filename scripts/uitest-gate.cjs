'use strict';
const BUSY='__HW_UITEST_BUSY_08513__',READY='__HW_UITEST_READY_08513__';
function command(text){const script='exec 0>/data/local/tmp/harmonywhale-uitest.lock; if ! flock -n 0; then printf "%s\\n" '+BUSY+'; exit 0; fi; printf "%s\\n" '+READY+'; ('+text+') 0<&-';return "sh -c '"+script.replace(/'/g,"'\\''")+"'";}
function reply(text,raw){raw=raw.trim();if(raw===BUSY)return null;if(!raw.startsWith(READY))throw Error('UiTest互斥协议失败，操作结果未确认');const out=raw.slice(READY.length).trim();if(text.startsWith('uitest dumpLayout')&&!out.includes('DumpLayout saved to:'))throw Error('UiTest布局读取失败：'+out.slice(0,240));if(text.startsWith('uitest uiInput')&&!/No Error/i.test(out))throw Error('UiTest操作结果未确认：'+out.slice(0,240));return out;}
function execute(text,run,timeout=40000){if(!text.startsWith('uitest '))return run(text,timeout);const end=Date.now()+timeout;while(Date.now()<end){const out=reply(text,run(command(text),Math.max(1,end-Date.now())));if(out!==null)return out;Atomics.wait(new Int32Array(new SharedArrayBuffer(4)),0,0,80);}throw Error('UiTest排队超时，命令未取得执行回执');}
module.exports={BUSY,READY,command,reply,execute};
