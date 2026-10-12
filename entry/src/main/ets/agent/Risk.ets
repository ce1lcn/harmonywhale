export function riskOf(label:string,app:string):string|null {
 const navigation=label.replace(/[,，、\s\d]/g,'');
 if(/^(最近删除|已删除|回收站|垃圾箱)+$/.test(navigation))return null;
 if(/恢复出厂|格式化/.test(label))return '重置数据';
 if(/支付|付款|购买|提交订单|转账/.test(label))return '付款购买';
 if(/卸载|安装/.test(label))return '安装卸载';
 if(/删除|清空|(?:^|[_\-.])(?:delete|remove|erase|clear_all)(?:$|[_\-.])/i.test(label))return '删除数据';
 if(/发送/.test(label))return '发送消息';
 if(/安全设置|系统设置/.test(label))return '修改设置';
 return null;
}
export function grantKey(taskId:string,category:string,app:string):string{return taskId+'|'+category+'|'+app;}
export function appTitle(app:string):string{if(/calculator/i.test(app))return '计算器';if(/notepad|notes/i.test(app))return '备忘录';if(app==='com.huawei.hmos.hicreate')return '天生会画';if(app==='com.harmonyloom.selfhdcprobe'||app==='大肥鱼')return '大肥鱼';return app;}
export class ActionGrants {
 keys:Set<string>=new Set();
 allows(taskId:string,category:string,app:string):boolean{return this.keys.has(grantKey(taskId,category,app));}
 add(taskId:string,category:string,app:string):void{this.keys.add(grantKey(taskId,category,app));}
 clear():void{this.keys.clear();}
}
export function mcpGrantKey(sessionId:string,serverId:string,url:string):string{return 'mcp:'+JSON.stringify([sessionId,serverId,url]);}
