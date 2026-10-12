'use strict';
const KEYBOARD='com.huawei.hmos.inputmethod';
function rect(v){const m=/^\[(-?\d+),(-?\d+)\]\[(-?\d+),(-?\d+)\]$/.exec(v||'');if(!m)return null;const r=m.slice(1).map(Number);return r[2]>r[0]&&r[3]>r[1]?r:null;}
function findKeyboardClose(tree){
 const clips=[],toolbars=[];
 function walk(n,bundle=''){const a=n.attributes||{},b=a.bundleName||bundle;
  if(b===KEYBOARD&&a.type==='Image'&&a.id==='clipboardSimpleCloseIcon'&&rect(a.bounds))clips.push({phase:'clipboard',box:rect(a.bounds)});
  if(b===KEYBOARD&&a.id==='downMenu_flex')toolbars.push(n);
  (n.children||[]).forEach(c=>walk(c,b));}walk(tree);
 if(clips.length)return clips.length===1?clips[0]:null;
 const candidates=[];
 for(const toolbar of toolbars){
  for(const child of toolbar.children||[]){const a=child.attributes||{},r=rect(a.bounds);
   if(a.id==='KeyHideKbd'&&a.type==='Stack'&&r)candidates.push({phase:'collapse',box:r});
  }
 }
 return candidates.length===1?candidates[0]:null;
}
module.exports={findKeyboardClose};
