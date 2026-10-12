'use strict';
function rect(s){const m=/^\[(-?\d+),(-?\d+)\]\[(-?\d+),(-?\d+)\]$/.exec(s||'');if(!m)return null;const r=m.slice(1).map(Number);return r[2]>r[0]&&r[3]>r[1]?r:null;}
function maximizeTarget(tree){
 const apps=[],buttons=[];let forbidden=false;
 function walk(n,bundle=''){const a=n.attributes||{},b=a.bundleName||bundle,r=rect(a.bounds);
  if(a.bundleName&&b!=='com.harmonyloom.selfhdcprobe'&&b!=='com.ohos.sceneboard')forbidden=true;
  if(b==='com.harmonyloom.selfhdcprobe'&&a.id==='ContainerModalStack'&&r)apps.push(r);
  if(b==='com.ohos.sceneboard'&&a.id==='floatingButtonMaximize'&&a.type==='Button'&&r)buttons.push(r);
  (n.children||[]).forEach(c=>walk(c,b));}walk(tree);
 if(forbidden||apps.length!==1)return null;const app=apps[0];
 const matches=buttons.filter(r=>r[0]>=app[0]&&r[2]<=app[2]&&r[3]<=app[1]&&app[1]-r[1]<=110&&r[2]-r[0]<=100&&r[3]-r[1]<=100);
 return matches.length===1?matches[0]:null;
}
module.exports={maximizeTarget};
