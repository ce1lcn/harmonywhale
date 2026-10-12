'use strict';
const REQUIRED={'com.huawei.hmos.filemanager':'HW测试0850','com.tencent.mqq':'cell🍟'};
function scopeCheck(tree,bundles,scope){
 const texts=new Map();
 function walk(n,b){const a=n.attributes||{};b=a.bundleName||b;if(a.text&&b){const list=texts.get(b)||[];list.push(String(a.text));texts.set(b,list)}for(const c of n.children||[])walk(c,b)}walk(tree,'');
 for(const bundle of bundles){const required=REQUIRED[bundle];if(required&&scope!==required)return '需要 --scope '+required;if((required||scope)&&!(texts.get(bundle)||[]).some(t=>t.includes(scope)))return '目标窗口未出现指定范围文字';}
 return '';
}
module.exports={scopeCheck,REQUIRED};
