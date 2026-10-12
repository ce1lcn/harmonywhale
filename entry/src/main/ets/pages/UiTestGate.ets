// UiTest CLI clients share a broadcast reply channel. Lock only fixed internal
// UiTest commands; a BUSY reply means the command has not started.
export const UITEST_BUSY='__HW_UITEST_BUSY_08513__';
export const UITEST_READY='__HW_UITEST_READY_08513__';
export function uiTestCommand(command:string):string{
 const script='exec 0>/data/local/tmp/harmonywhale-uitest.lock; if ! flock -n 0; then printf "%s\\n" '+UITEST_BUSY+'; exit 0; fi; printf "%s\\n" '+UITEST_READY+'; ('+command+') 0<&-';
 return "sh -c '"+script.replace(/'/g,"'\\''")+"'";
}
export function uiTestReply(command:string,reply:string):string|null{
 const raw=reply.trim();if(raw===UITEST_BUSY)return null;
 if(!raw.startsWith(UITEST_READY))throw new Error('UiTest互斥协议失败，操作结果未确认');
 const output=raw.substring(UITEST_READY.length).trim();
 if(command.startsWith('uitest dumpLayout')&&!output.includes('DumpLayout saved to:'))throw new Error('UiTest布局读取失败：'+output.substring(0,240));
 if(command.startsWith('uitest uiInput')&&!/No Error/i.test(output))throw new Error('UiTest操作结果未确认：'+output.substring(0,240));
 return output;
}
