// 真机点击守卫：电脑端测试对平板的点击、滑动、输入，都必须经由本脚本。
// 每次操作前先读布局，坐标所在位置的所有窗口都属于白名单应用才执行，否则拒绝并退出码 2。
// 桌面、通知中心、系统弹窗一律不点；打开应用请用 `aa start`，不要点桌面图标。
// 用法：
// 文件管理每次 --scope HW测试0850；QQ 每次 --scope cell🍟。scope 必须来自目标应用窗口，不能用大肥鱼窗口文字代替。
//   node scripts/safe-tap.cjs click x y [--text 期望文字]
//   node scripts/safe-tap.cjs doubleclick|longclick x y [--text 期望文字]
//   node scripts/safe-tap.cjs swipe|drag x1 y1 x2 y2 [速度px/s]
//   node scripts/safe-tap.cjs input x y 文字
//   node scripts/safe-tap.cjs key Back|Home|Enter|...   （Home 直接放行，其余要求屏幕中心为白名单应用）
//   node scripts/safe-tap.cjs where x y                  （只查询该点属于哪个应用、什么控件，不操作）
//   node scripts/safe-tap.cjs front                      （只输出屏幕各处窗口包名、不输出文字；safe=true 表示只有白名单应用或桌面）
//   node scripts/safe-tap.cjs float                      （全屏大肥鱼 → 系统悬浮窗：点顶部「•••」再点「切换悬浮窗」）
//   node scripts/safe-tap.cjs trust                    （只点 HDC 调试信任弹窗的「信任」，不点「始终信任」）
'use strict';
const {execFileSync}=require('child_process');
const fs=require('fs'),path=require('path');
const HDC=process.env.HDC_PATH||'hdc';
const TARGET=process.env.HDC_TARGET||'';
// 0.8.5 唯一授权扩展：bm dump -a -l 2026-10-11 实测；不加其他包。
const ALLOW=['com.harmonyloom.selfhdcprobe','com.huawei.hmos.calculator','com.huawei.hmos.notepad','com.huawei.hmos.browser','cn.wps.office.hap','com.huawei.hmos.filemanager','com.tencent.mqq'];
const {scopeCheck}=require('./safe-scope.cjs');
const {findKeyboardClose}=require('./keyboard-close.cjs');
const {maximizeTarget}=require('./self-window.cjs');
// 输入法仅接受专门的关闭控件操作（用户2026-10-12授权）；普通点击仍拒绝键盘。
const KEYBOARD='com.huawei.hmos.inputmethod';
const LOG=path.join(__dirname,'..','artifacts','safe-tap-log.txt');

const uiTestGate=require('./uitest-gate.cjs');
function sh(cmd){return uiTestGate.execute(cmd,(wire,timeout)=>execFileSync(HDC,['-t',TARGET,'shell',wire],{encoding:'utf8',timeout,maxBuffer:16*1024*1024}));}
function log(line){fs.appendFileSync(LOG,new Date().toISOString()+' '+line+'\n','utf8');}
function bounds(b){const m=/\[(-?\d+),(-?\d+)\]\[(-?\d+),(-?\d+)\]/.exec(b||'');return m?m.slice(1).map(Number):null;}
function inside(r,x,y){return r&&x>=r[0]&&x<r[2]&&y>=r[1]&&y<r[3];}

function readLayout(){
 sh('uitest dumpLayout -p /data/local/tmp/safe-tap.json');
 const raw=sh('cat /data/local/tmp/safe-tap.json');
 return JSON.parse(raw.slice(raw.indexOf('{')));
}
// 找出覆盖该点的所有窗口包名，以及该点上最深的控件文字
function probe(tree,x,y){
 const bundles=new Set();let texts=[];
 const walk=(n,bundle)=>{const a=n.attributes||{};const b=a.bundleName||bundle;const r=bounds(a.bounds);
  if(a.bundleName&&r&&!inside(r,x,y))return; // 窗口不覆盖该点，整棵跳过
  if(r&&inside(r,x,y)){if(b)bundles.add(b);if(a.text)texts.push(String(a.text));}
  for(const c of n.children||[])walk(c,b);};
 walk(tree,'');
 return {bundles:[...bundles],texts};
}
function check(tree,x,y,expect){
 const p=probe(tree,x,y);
 const bad=p.bundles.filter(b=>!ALLOW.includes(b));
 if(!p.bundles.length)return {ok:false,why:'该点没有任何窗口',p};
 if(bad.length)return {ok:false,why:'该点属于非白名单应用：'+bad.join(','),p};
 const scoped=scopeCheck(tree,p.bundles,scope);if(scoped)return {ok:false,why:scoped,p};
 if(expect&&!p.texts.some(t=>t.includes(expect)))return {ok:false,why:'该点没有期望文字「'+expect+'」',p};
 return {ok:true,p};
}
function refuse(desc,r){log('拒绝 '+desc+' '+r.why);console.error('拒绝：'+r.why+'（该点窗口：'+(r.p.bundles.join(',')||'无')+'）');process.exit(2);}

const args=process.argv.slice(2);const op=(args[0]||'').toLowerCase();
let scope='';const si=args.indexOf('--scope');if(si>=0){scope=args[si+1]||'';if(!scope)throw new Error('缺少范围文字');args.splice(si,2);}
let expect='';const ti=args.indexOf('--text');if(ti>=0){expect=args[ti+1]||'';args.splice(ti,2);}
const n=i=>{const v=Number(args[i]);if(!Number.isFinite(v))throw new Error('坐标无效：'+args[i]);return Math.round(v);};
try{
 if(op==='maximize'){
  const target=maximizeTarget(readLayout());if(!target)throw new Error('未能唯一定位大肥鱼小窗的最大化按钮，或有其他应用/键盘遮挡');
  const x=Math.round((target[0]+target[2])/2),y=Math.round((target[1]+target[3])/2);
  sh('uitest uiInput click '+x+' '+y);log('执行大肥鱼 maximize '+x+','+y);console.log('已点击大肥鱼窗口最大化');process.exit(0);
 }
 if(op==='keyboard-close'){
  const tree=readLayout();const close=findKeyboardClose(tree),hit=close?.box;let self=false;const strangers=new Set();
  const walk=(node,bundle='')=>{const a=node.attributes||{},b=a.bundleName||bundle;
   if(a.bundleName&&!ALLOW.includes(b)&&b!==KEYBOARD&&b!=='com.ohos.sceneboard')strangers.add(b);
   if(b==='com.harmonyloom.selfhdcprobe')self=true;
   (node.children||[]).forEach(c=>walk(c,b));};walk(tree);
  if(!self||strangers.size||!hit)throw new Error('关闭键盘前置条件不满足：必须有大肥鱼、无其他应用并唯一定位输入法关闭控件');
  const x=Math.round((hit[0]+hit[2])/2),y=Math.round((hit[1]+hit[3])/2),p=probe(tree,x,y);
  if(!p.bundles.includes(KEYBOARD)||p.bundles.some(b=>b!==KEYBOARD&&b!=='com.ohos.sceneboard'))throw new Error('关闭控件位置被其他应用覆盖');
  sh('uitest uiInput click '+x+' '+y);log('执行用户授权 keyboard-close '+close.phase+' '+x+','+y);console.log(JSON.stringify({phase:close.phase,point:[x,y],next:'重新观察，禁止盲点第二次'}));process.exit(0);
 }
 if(op==='key'){
  const key=args[1];if(!key)throw new Error('缺少按键名');
  const keyTree=readLayout();const keyPoint=probe(keyTree,1400,920);const scoped=scopeCheck(keyTree,keyPoint.bundles.filter(b=>ALLOW.includes(b)),scope);if(scoped)refuse('key '+key,{why:scoped,p:keyPoint});
  if(key!=='Home'){const p=keyPoint;const bad=p.bundles.filter(b=>!ALLOW.includes(b)&&b!==KEYBOARD);if(!p.bundles.length||bad.length)refuse('key '+key,{why:'屏幕中心属于非白名单应用：'+bad.join(','),p});}
  sh('uitest uiInput keyEvent '+key);log('执行 key '+key);console.log('已执行 key '+key);process.exit(0);
 }
 if(op==='trust'){
  // 用户 2026-10-09 授权点击 HDC 调试信任弹窗的「信任」（不是「始终信任」）。
  // 只点文字恰好为「信任」的控件，且同一窗口内必须出现「指纹」「调试」「是否信任」等字样，否则拒绝。
  const tree=readLayout();let hit=null;
  const walk=(n,win)=>{const a=n.attributes||{};const w=win||(a.bundleName?n:null); // 取最外层窗口节点，避免每个节点都带 bundleName 时只看到按钮自身
   if(String(a.text||'')==='信任'&&!hit){const texts=[];const collect=m=>{const t=(m.attributes||{}).text;if(t)texts.push(String(t));(m.children||[]).forEach(collect);};collect(w||tree);
    if(texts.some(t=>t.includes('指纹')||t.includes('调试')||t.includes('信任此设备')||t.includes('是否信任')))hit=bounds(a.bounds);}
   (n.children||[]).forEach(c=>walk(c,w));};
  walk(tree,null);
  if(!hit){
   // 只输出含「信任」二字的短按钮文字（≤8 字），便于确认弹窗按钮的真实文字，不输出其他内容。
   const labels=[];const scan=m=>{const t=String((m.attributes||{}).text||'');if(t.includes('信任')&&t.length<=8)labels.push(t);(m.children||[]).forEach(scan);};scan(tree);
   if(labels.length)console.error('含「信任」的短文字：'+JSON.stringify(labels));
   log('拒绝 trust 未找到 HDC 信任弹窗');console.error('拒绝：没有找到 HDC 信任弹窗的「信任」按钮');process.exit(2);}
  const x=Math.round((hit[0]+hit[2])/2),y=Math.round((hit[1]+hit[3])/2);
  sh('uitest uiInput click '+x+' '+y);log('执行 trust '+x+','+y);console.log('已点击「信任」 '+x+','+y);process.exit(0);
 }
 if(op==='float'){
  // 把全屏的大肥鱼切成系统悬浮窗：点窗口顶部「•••」控制条，再点菜单里的「切换悬浮窗」。
  // 只在屏幕中心是大肥鱼时执行；控制条和菜单项都按位置与文字精确匹配，找不到就拒绝。
  let tree=readLayout();
  if(!probe(tree,1400,920).bundles.every(b=>b==='com.harmonyloom.selfhdcprobe')){log('拒绝 float 中心不是大肥鱼');console.error('拒绝：屏幕中心不是全屏的大肥鱼');process.exit(2);}
  let handle=null;
  const findHandle=(n,b)=>{const a=n.attributes||{};b=a.bundleName||b;const r=bounds(a.bounds);
   if(!handle&&b==='com.ohos.sceneboard'&&a.type==='Button'&&r&&r[1]<80&&r[3]<80&&r[0]>1200&&r[2]<1600)handle=r;
   (n.children||[]).forEach(c=>findHandle(c,b));};
  findHandle(tree,'');
  if(!handle){log('拒绝 float 未找到窗口控制条');console.error('拒绝：没有找到窗口顶部的「•••」控制条');process.exit(2);}
  sh('uitest uiInput click '+Math.round((handle[0]+handle[2])/2)+' '+Math.round((handle[1]+handle[3])/2));log('执行 float 点控制条');
  execFileSync('powershell',['-NoProfile','-Command','Start-Sleep -Milliseconds 1200']);
  tree=readLayout();let item=null;
  const findItem=(n,b)=>{const a=n.attributes||{};b=a.bundleName||b;const r=bounds(a.bounds);
   if(!item&&b==='com.ohos.sceneboard'&&String(a.text||'')==='切换悬浮窗'&&r)item=r;(n.children||[]).forEach(c=>findItem(c,b));};
  findItem(tree,'');
  if(!item){log('拒绝 float 菜单里没有「切换悬浮窗」');console.error('拒绝：菜单里没有「切换悬浮窗」，菜单仍开着，可用 key Back 关闭');process.exit(2);}
  sh('uitest uiInput click '+Math.round((item[0]+item[2])/2)+' '+Math.round((item[1]+item[3])/2));log('执行 float 切换悬浮窗');console.log('已切换悬浮窗');process.exit(0);
 }
 if(op==='front'){
  // 只输出屏幕中心与四角内侧覆盖的窗口包名，不输出任何文字，用于判断前台而不读取用户内容。
  const tree=readLayout();const pts=[[1400,920],[300,300],[2500,300],[300,1600],[2500,1600]];
  const out=pts.map(([x,y])=>({point:x+','+y,bundles:probe(tree,x,y).bundles}));
  // 空白点（布局里没有节点覆盖）不算危险；只要出现非白名单包名就 safe=false，且至少一处是白名单应用。
  // 全是桌面也算安全（可以 aa start 打开应用），但 desktop=true 提醒：若大肥鱼任务在跑，说明模型跑到了桌面，要立刻暂停。
  // 另外列出所有窗口包名；selfVisible 表示屏幕上有大肥鱼窗口（包括角落里的悬浮窗）。
  const wins=[];const listWin=n=>{const a=n.attributes||{};if(a.bundleName){wins.push(a.bundleName);return;}(n.children||[]).forEach(listWin);};listWin(tree);
  const selfVisible=wins.includes('com.harmonyloom.selfhdcprobe');
  const strangers=[...new Set(wins.filter(b=>!ALLOW.includes(b)&&b!=='com.ohos.sceneboard'&&b!==KEYBOARD))];
  const desktop=!selfVisible&&out.every(o=>o.bundles.every(b=>b==='com.ohos.sceneboard'));
  const scopeError=scopeCheck(tree,[...new Set(wins.filter(b=>b==='com.huawei.hmos.filemanager'||b==='com.tencent.mqq'))],scope);
  const safe=!scopeError&&strangers.length===0&&out.some(o=>o.bundles.length>0)&&out.every(o=>o.bundles.every(b=>ALLOW.includes(b)||b==='com.ohos.sceneboard'||b===KEYBOARD));
  console.log(JSON.stringify({safe,desktop,selfVisible,strangers,scopeError,points:out}));process.exit(0);
 }
 if(op==='where'){const tree=readLayout(),p=probe(tree,n(1),n(2));const scoped=scopeCheck(tree,p.bundles,scope);if(scoped)refuse('where',{why:scoped,p});console.log(JSON.stringify({bundles:p.bundles,texts:p.texts.slice(-3)}));process.exit(0);}
 const tree=readLayout();
 if(['click','doubleclick','longclick'].includes(op)){
  const x=n(1),y=n(2);const r=check(tree,x,y,expect);const desc=op+' '+x+','+y;if(!r.ok)refuse(desc,r);
  const cmd={click:'click',doubleclick:'doubleClick',longclick:'longClick'}[op];
  sh('uitest uiInput '+cmd+' '+x+' '+y);log('执行 '+desc+' 于 '+r.p.bundles.join(','));console.log('已执行 '+desc);process.exit(0);
 }
 if(op==='swipe'||op==='drag'){
  const x1=n(1),y1=n(2),x2=n(3),y2=n(4);const v=args[5]?n(5):2000;const desc=op+' '+x1+','+y1+'->'+x2+','+y2;
  for(const [x,y] of [[x1,y1],[x2,y2]]){const r=check(tree,x,y,'');if(!r.ok)refuse(desc,r);}
  sh('uitest uiInput '+op+' '+x1+' '+y1+' '+x2+' '+y2+' '+v);log('执行 '+desc);console.log('已执行 '+desc);process.exit(0);
 }
 if(op==='input'){
  const x=n(1),y=n(2);const text=args.slice(3).join(' ');if(!text)throw new Error('缺少文字');
  const r=check(tree,x,y,expect);const desc='input '+x+','+y;if(!r.ok)refuse(desc,r);
  sh('uitest uiInput inputText '+x+' '+y+' '+JSON.stringify(text));log('执行 '+desc+' 长度'+text.length);console.log('已执行 '+desc);process.exit(0);
 }
 throw new Error('未知操作：'+op);
}catch(e){console.error('出错：'+e.message);process.exit(1);}
