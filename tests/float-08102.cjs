// 0.8.1.2 回归：
// 1) 通知发布通道：结束 / 清除后在途的发布一律丢弃（修复真机 0.8.1.1 任务结束后进度通知残留）；
// 2) 确认后弹出菜单被关闭：重放“打开菜单”的那一次点击、按文字重新定位、唯一匹配才点击；任何一步不确定都停下；
// 3) 小窗模式下 launch_app 的提示与自身窗口被收起的检测。
const fs=require('fs'),path=require('path'),vm=require('vm'),assert=require('assert/strict');
const ts=require(process.env.HVIGOR_TS||'typescript');
const imageStub={createImageSource:()=>({getImageInfo:async()=>({size:{width:2800,height:1840}}),createPixelMap:async()=>{throw new Error('无图像解码');},release(){}}),createImagePacker:()=>({release(){}})};
const kit={'@kit.NetworkKit':{http:{RequestMethod:{POST:'POST'},HttpDataType:{STRING:1},createHttp:()=>({on(){},off(){},destroy(){}})}},'@kit.BackgroundTasksKit':{backgroundTaskManager:{requestSuspendDelay:()=>({requestId:1,actualDelayTime:180000}),cancelSuspendDelay(){}}},'@kit.ArkTS':{buffer:{from:(x,e)=>Buffer.from(x,e)},util:{Base64Helper:class{decodeSync(s){return new Uint8Array(Buffer.from(s,'base64'));}encodeToStringSync(b){return Buffer.from(b).toString('base64');}}}},'@kit.CoreFileKit':{fileIo:{OpenMode:{CREATE:1,READ_WRITE:2},openSync:()=>({fd:1}),writeSync(){},closeSync(){}},picker:{}},'@kit.BasicServicesKit':{zlib:{}},'@kit.ImageKit':{image:imageStub},'@kit.AbilityKit':{},'@kit.UniversalKeystoreKit':{},'@kit.CryptoArchitectureKit':{}};
const cache=new Map();function load(file){file=path.resolve(file);if(cache.has(file))return cache.get(file);const module={exports:{}};vm.runInNewContext(ts.transpileModule(fs.readFileSync(file,'utf8'),{compilerOptions:{module:ts.ModuleKind.CommonJS,target:ts.ScriptTarget.ES2020}}).outputText,{module,exports:module.exports,require:n=>n.startsWith('.')?load(path.resolve(path.dirname(file),n+'.ets')):kit[n]??{},setTimeout:(cb,ms)=>(ms??0)>=60000?0:setTimeout(cb,Math.min(ms??0,5)),clearTimeout,queueMicrotask,Uint8Array,ArrayBuffer,Map,Set,Buffer,Date,JSON,Math,Number,Object,Array,String,RegExp,Error,Promise});cache.set(file,module.exports);return module.exports;}
const root='entry/src/main/ets/agent/';
const F=load(root+'FloatPolicy.ets'),T=load(root+'Types.ets'),{Device,SELF_BUNDLE}=load(root+'Device.ets'),{Engine}=load(root+'Engine.ets');
const same=(a,b)=>assert.equal(JSON.stringify(a),JSON.stringify(b));
const tick=(ms=1)=>new Promise(r=>setTimeout(r,ms));

// ---------- 1. 通知发布通道 ----------
async function noticeTests(){
 // sink：build 可手动放行，模拟“创建 WantAgent 要等一会儿”
 function sink(){const log=[];const waiting=[];return {log,waiting,build(id,title,text,buttons,serial){log.push('build:'+id+':'+text);return new Promise(res=>waiting.push(()=>res({id,text})));},async publish(id,req){log.push('publish:'+id+':'+req.text);},async cancel(id){log.push('cancel:'+id);}};}
 // 真机时序复现：进度发布在途（build 未完成）→ 任务结束 cancel → build 完成。0.8.1.1 此时仍会 publish（残留）。
 let s=sink();let ch=new F.NoticeChannel(s);
 let p=ch.publish(8101,'t','第 4 步',false,0);await tick();s.waiting.shift()();await p;same(s.log,['build:8101:第 4 步','publish:8101:第 4 步']);
 s=sink();ch=new F.NoticeChannel(s);p=ch.publish(8101,'t','第 12 步',false,0);await tick();await ch.cancel(8101);s.waiting.shift()();await p;
 same(s.log,['build:8101:第 12 步','cancel:8101'],'结束后在途的发布被丢弃');assert.equal(ch.dropped,1);
 // 结束后新的发布（下一个任务）正常
 const p2=ch.publish(8101,'t','新任务',false,0);await tick();s.waiting.shift()();await p2;assert.equal(s.log[s.log.length-1],'publish:8101:新任务');
 // 两条在途更新乱序完成：只保留最新一条
 s=sink();ch=new F.NoticeChannel(s);const a=ch.publish(8101,'t','A',false,0),b=ch.publish(8101,'t','B',false,0);await tick();s.waiting.pop()();s.waiting.pop()();await Promise.all([a,b]);assert.equal(s.log.filter(v=>v.startsWith('publish')).join(),'publish:8101:B');
 // 不同编号互不影响：清除确认通知不会丢弃进度通知
 s=sink();ch=new F.NoticeChannel(s);const c=ch.publish(8101,'t','进度',false,0);await tick();await ch.cancel(8102);s.waiting.shift()();await c;assert.ok(s.log.includes('publish:8101:进度'));
 // 确认通知同理：同意 / 暂停清除时在途的发布被丢弃
 s=sink();ch=new F.NoticeChannel(s);const d=ch.publish(8102,'t','确认',true,3);await tick();await ch.cancel(8102);s.waiting.shift()();await d;assert.ok(!s.log.some(v=>v.startsWith('publish')));
 // 暂停：先 cancel 再留一条说明（finished(text) = cancel + publish），说明正常发出
 s=sink();ch=new F.NoticeChannel(s);await ch.cancel(8101);const e=ch.publish(8101,'t','已暂停',false,0);await tick();s.waiting.shift()();await e;assert.equal(s.log[s.log.length-1],'publish:8101:已暂停');
}

// ---------- 2. 弹出菜单确认后重放 ----------
const NOTES='com.huawei.hmos.notepad';
const node=(attrs,children=[])=>({attributes:attrs,children});
const DUMP='AbilityRecord ID 1\n main name [EntryAbility]\n bundle name ['+NOTES+']\n state #FOREGROUND\n';
// 备忘录模拟：⋮ 在 [2500,200][2600,300]；点中它弹出菜单（窗口号 30，里面有“删除”“分享”）；菜单打开时点“删除”记 deleted。
function notesDevice(opts={}){
 const st={menu:opts.menuOpen??false,deleted:0,clicks:[],extra:false,dupDelete:false,moreLabel:opts.moreLabel??'更多',reopenDrops:false,menuWin:30,trash:false,ime:false};
 const layout=()=>{const kids=[node({hostWindowId:'20',type:'Text',text:'测试笔记',bounds:'[100,400][600,500]'}),node({hostWindowId:'20',type:'Button',description:st.moreLabel,clickable:'true',bounds:'[2500,200][2600,300]'})];if(st.extra)kids.push(node({hostWindowId:'20',type:'Text',text:'新出现的内容',bounds:'[100,600][600,700]'}));if(st.ime)kids.push(node({hostWindowId:'20',type:'Text',text:'来自剪贴板',bounds:'[900,1100][1500,1200]'}));if(st.trash)kids.push(node({hostWindowId:'20',type:'Button',text:'删除',clickable:'true',bounds:'[1900,200][2000,300]'}));
  const win=node({bundleName:NOTES,hostWindowId:'20',bounds:'[0,0][2800,1840]',type:'root'},kids);const wins=[win];
  if(st.menu){const items=[node({hostWindowId:String(st.menuWin),type:'Button',text:'删除',clickable:'true',bounds:'[2300,320][2600,420]'}),node({hostWindowId:String(st.menuWin),type:'Button',text:'分享',clickable:'true',bounds:'[2300,430][2600,530]'})];if(st.dupDelete)items.push(node({hostWindowId:String(st.menuWin),type:'Button',text:'删除',clickable:'true',bounds:'[2300,540][2600,640]'}));wins.push(node({bundleName:NOTES,hostWindowId:String(st.menuWin),bounds:'[2200,300][2700,700]',type:'root'},items));}
  return node({bounds:'[0,0][2800,1840]'},wins);};
 const issued=[];
 const hdc={ready:true,execute:async cmd=>{issued.push(cmd);if(cmd.startsWith('cat '))return JSON.stringify(layout());if(cmd==='aa dump -l')return DUMP;if(cmd.startsWith('toybox base64'))return Buffer.from('jpeg').toString('base64');if(cmd.startsWith('aa start'))return 'start ability successfully.';
  const m=/^uitest uiInput click (\d+) (\d+)/.exec(cmd);if(m){const x=+m[1],y=+m[2];st.clicks.push([x,y]);const inside=(b)=>x>=b[0]&&x<=b[2]&&y>=b[1]&&y<=b[3];
   if(st.menu&&inside([2300,320,2600,420]))st.deleted++;else if(inside([2500,200,2600,300]))st.menu=!st.menu||false;else if(st.menu&&!inside([2200,300,2700,700]))st.menu=false;}
  if(/^uitest uiInput (keyEvent)/.test(cmd)){st.menu=false;}
  return 'No Error';}};
 const d=new Device(hdc,{root:'/tmp'});d.leaseTarget=async()=>null;d.apps.set(NOTES,'EntryAbility');
 return {d,st,issued};
}
const MORE={x:Math.round(2550*1000/2799),y:Math.round(250*1000/1839)};
async function openMenuAndTarget(f,deleteLabel='删除'){
 const {d,st}=f;await d.observe();                                  // s0：没有菜单
 const t0=await d.actionTarget('click',MORE);await d.execute('click',MORE);assert.equal(st.menu,true);
 const obs=await d.observe();                                         // s1：菜单已打开（模型看到的）
 const del=d.latest.elements.find(e=>e.text===deleteLabel&&e.window===String(st.menuWin));
 const args={snapshotId:d.latest.snapshotId,elementId:del.elementId};
 const target=await d.actionTarget('click_element',args);
 return {args,target,t0};
}
async function menuTests(){
 // A. 正常：同意后菜单被关掉 → 重放打开菜单的点击 → 按文字重新定位 → 点击删除成功（授权只对这一个目标）
 let f=notesDevice();let {args,target}=await openMenuAndTarget(f);assert.equal(target.label,'删除');assert.equal(target.app,NOTES);
 f.st.menu=false;                                                       // 用户点小窗里的“同意”，下层菜单关闭
 const clicksBefore=f.st.clicks.length;f.st.menuWin=31;                 // 重新打开的菜单窗口号会变，不能靠旧编号定位
 const note=await f.d.restoreApproval(target,args,true);
 assert.match(note,/重放.*打开菜单的点击.*「删除」/);assert.equal(f.st.menu,true);assert.equal(f.st.clicks.length-clicksBefore,1,'只重放了一次点击');
 const fresh=await f.d.actionTarget('click_element',args);assert.equal(fresh.label,'删除');assert.equal(fresh.app,NOTES);
 await f.d.execute('click_element',args);assert.equal(f.st.deleted,1,'同意一次即删除成功');
 // A2. 坐标点击（click）同样适用：args.x/y 被改写为新菜单里“删除”的位置
 f=notesDevice();({target}=await openMenuAndTarget(f));const cargs={x:target.snapshot.elements.find(e=>e.elementId===target.elementId).normalizedCenter[0],y:target.snapshot.elements.find(e=>e.elementId===target.elementId).normalizedCenter[1]};
 f.st.menu=false;await f.d.restoreApproval(target,cargs,true);assert.equal(f.st.menu,true);assert.equal((await f.d.actionTarget('click',cargs)).label,'删除');
 // B. 没有关闭：行为与 0.8.1.1 相同（场景一致 → relocate），不重放
 f=notesDevice();({args,target}=await openMenuAndTarget(f));const n1=f.st.clicks.length;assert.equal(await f.d.restoreApproval(target,args,true),'');assert.equal(f.st.clicks.length,n1,'菜单还开着，不点击');
 // B2. 整页因软键盘联想条出现而不一致，但目标本身（同窗口、同标识）还在 → 直接点，不重放
 f=notesDevice();({args,target}=await openMenuAndTarget(f));f.st.ime=true;const nb=f.st.clicks.length;assert.equal(await f.d.restoreApproval(target,args,true),'');assert.equal(f.st.clicks.length,nb,'没有重放点击');
 // C. 上一步不是那次点击（中间还有别的动作，例如按了返回再重新打开别的东西）→ STALE，不重放
 f=notesDevice();({args,target}=await openMenuAndTarget(f));f.st.menu=false;await f.d.execute('back',{});let n=f.st.clicks.length;
 await assert.rejects(()=>f.d.restoreApproval(target,args,true),e=>e.code==='STALE'&&/上一步不是打开该菜单的点击/.test(e.message));assert.equal(f.st.clicks.length,n,'不盲点');
 // D. 被点的控件（⋮）在页面上变了（改了名字）→ STALE，不重放
 f=notesDevice();({args,target}=await openMenuAndTarget(f));f.st.menu=false;f.st.moreLabel='别的按钮';n=f.st.clicks.length;
 await assert.rejects(()=>f.d.restoreApproval(target,args,true),e=>e.code==='STALE'&&/控件已经变了/.test(e.message));assert.equal(f.st.clicks.length,n);
 // D2. 页面上有无关变化（相对时间、联想条等）不影响重放；页面上本来就有同名“删除”图标时，只在重放后新出现的元素里找
 f=notesDevice();f.st.trash=true;({args,target}=await openMenuAndTarget(f));f.st.menu=false;f.st.extra=true;f.st.menuWin=33;
 const note2=await f.d.restoreApproval(target,args,true);assert.match(note2,/重放/);await f.d.execute('click_element',args);assert.equal(f.st.deleted,1,'点的是菜单里的“删除”，不是工具栏的同名图标');
 // E. 上一步点击本身是危险类别（按钮叫“删除全部”）→ 不重放，避免重复危险操作
 f=notesDevice({moreLabel:'删除全部'});({args,target}=await openMenuAndTarget(f));f.st.menu=false;n=f.st.clicks.length;
 await assert.rejects(()=>f.d.restoreApproval(target,args,true),e=>e.code==='STALE'&&/危险/.test(e.message));assert.equal(f.st.clicks.length,n);
 // F. 重新打开菜单后“删除”有两个 → 不唯一，不点
 f=notesDevice();({args,target}=await openMenuAndTarget(f));f.st.menu=false;f.st.dupDelete=true;n=f.st.clicks.length;
 await assert.rejects(()=>f.d.restoreApproval(target,args,true),e=>e.code==='STALE'&&/2 个同名项/.test(e.message));assert.equal(f.st.clicks.length-n,1,'只重放了打开菜单的点击，没有点“删除”');assert.equal(f.st.deleted,0);
 // G. 目标在上一步点击前就已存在（菜单本来就开着）→ 不是这次点击打开的，不重放
 f=notesDevice({menuOpen:true});await f.d.observe();const tg=await f.d.actionTarget('click',MORE);await f.d.execute('click',MORE);// 点 ⋮ 把菜单收起
 f.st.menu=true;await f.d.observe();const del=f.d.latest.elements.find(e=>e.text==='删除');const a2={snapshotId:f.d.latest.snapshotId,elementId:del.elementId};const tt=await f.d.actionTarget('click_element',a2);f.st.menu=false;n=f.st.clicks.length;
 await assert.rejects(()=>f.d.restoreApproval(tt,a2,true),e=>e.code==='STALE');assert.equal(f.st.clicks.length,n);
 // H. 重放后目标不见了 → STALE
 f=notesDevice();({args,target}=await openMenuAndTarget(f,'分享'));f.st.menu=false;f.st.menuWin=30;
 const realExec=f.d.hdc.execute;let hide=false;f.d.hdc.execute=async cmd=>{const r=await realExec(cmd);if(/^uitest uiInput click/.test(cmd))hide=true;return r;};
 f.st.menu=false;// 菜单打开后立刻消失：把 menu 置回 false
 const orig=f.d.readLayout.bind(f.d);f.d.readLayout=async(t)=>{if(hide&&f.st.menu){f.st.menu=false;}return orig(t);};n=f.st.clicks.length;
 await assert.rejects(()=>f.d.restoreApproval(target,args,true),e=>e.code==='STALE'&&/不见了/.test(e.message));
}

// ---------- 3. Engine：确认后重放的说明附在动作结果里；授权不外溢 ----------
async function engineTests(){
 const f=notesDevice();const{d,st}=f;d.overlay=null;
 const state=T.defaults();const engine=new Engine(state,{save(){},secret:async()=>'k'},d,()=>{});engine.foreground=true;
 // 脚本：observe → 点 ⋮ → 点“删除”（需要确认）→ 结束
 let step=0;let del=null;
 engine.model.next=async(profile,key,session,task,observation)=>{step++;
  if(step===1)return {text:'',calls:[{id:'c1',name:'observe',arguments:'{}'}]};
  if(step===2)return {text:'',calls:[{id:'c2',name:'click',arguments:JSON.stringify(MORE)}]};
  if(step===3){const e=d.latest.elements.find(v=>v.text==='删除');return {text:'',calls:[{id:'c3',name:'click_element',arguments:JSON.stringify({snapshotId:d.latest.snapshotId,elementId:e.elementId})}]};}
  return {text:'已删除',calls:[]};};
 // 小窗里确认：模拟用户点“同意”会让菜单关闭
 d.overlay={active:()=>true,beforeCapture:async()=>({strategy:'privacy',hidden:false,masked:false,restoreSelf:false,error:''}),afterCapture:async()=>{},setTouchable:async()=>{},windowRect:()=>[]};
 const run=engine.start('删除测试笔记');
 for(let i=0;i<600&&!engine.approval;i++)await tick();assert.ok(engine.approval,'出现确认：'+JSON.stringify(engine.current.records.map(r=>[r.name,r.status,r.result])));
 assert.match(engine.approval,/删除/);st.menu=false;st.menuWin=31;engine.approve(true);await run;
 assert.equal(engine.current.status,'completed',JSON.stringify(engine.current.records.map(r=>[r.name,r.status,r.result])));assert.equal(st.deleted,1);
 const rec=engine.current.records.find(r=>r.id==='c3');assert.equal(rec.status,'success');assert.match(rec.result,/弹出菜单被关闭了，已重放上一步打开菜单的点击/);
 assert.equal(engine.actionGrants.keys.size,0,'没有勾选“同类不再询问”，授权不外溢');
}

// ---------- 4. 小窗下 launch_app 的收起检测与自动恢复 ----------
async function launchTests(){
 const calc='com.huawei.hmos.calculator';
 const dumpWith=(selfState)=>'AbilityRecord ID 1\n main name [ProbeAbility]\n bundle name ['+SELF_BUNDLE+']\n state #'+selfState+'\nAbilityRecord ID 2\n main name [CalculatorAbility]\n bundle name ['+calc+']\n state #FOREGROUND\n';
 let selfState='FOREGROUND',restorable=true;const issued=[];
 const win=(b,id,x)=>node({bundleName:b,hostWindowId:id,bounds:x,type:'root'},[node({hostWindowId:id,type:'Button',text:b===calc?'7':'大肥鱼按钮',clickable:'true',bounds:'[100,1000][300,1200]'})]);
 const d=new Device({ready:true,execute:async cmd=>{issued.push(cmd);if(cmd.startsWith('cat '))return JSON.stringify(node({bounds:'[0,0][2800,1840]'},[win(calc,'11','[0,0][2800,1840]')]));if(cmd==='aa dump -l')return dumpWith(selfState);if(cmd.startsWith('aa start -b '+SELF_BUNDLE)){if(restorable)selfState='FOREGROUND';return 'start ability successfully.';}if(cmd.startsWith('aa start'))return 'start ability successfully.';if(cmd.startsWith('bm dump'))return '{"versionCode":1}';if(cmd.startsWith('toybox base64'))return Buffer.from('jpeg').toString('base64');return 'No Error';}},{root:'/tmp'});
 d.apps.set(calc,'CalculatorAbility');d.overlay={active:()=>true,beforeCapture:async()=>({strategy:'privacy',hidden:false,masked:true,restoreSelf:false,error:''}),afterCapture:async()=>{},setTouchable:async()=>{},windowRect:()=>[1800,200,2700,1600]};
 // 小窗仍在前台：普通结果，没有收起提示，也不会 aa start 自身
 let out=await d.execute('launch_app',{appId:calc});assert.doesNotMatch(out,/收到了屏幕边缘/);assert.ok(!issued.some(c=>c.startsWith('aa start -b '+SELF_BUNDLE)));
 // 小窗被收到边缘（大肥鱼进入后台）：自动 aa start 自身恢复，结果里说明
 selfState='BACKGROUND';out=await d.execute('launch_app',{appId:calc});assert.match(out,/大肥鱼的小窗被系统收到了屏幕边缘，已自动恢复为小窗/);assert.ok(issued.some(c=>c.startsWith('aa start -b '+SELF_BUNDLE)));assert.equal(selfState,'FOREGROUND');
 // 恢复不成功：提示用户点边缘把手，不反复重试
 selfState='BACKGROUND';restorable=false;const before=issued.filter(c=>c.startsWith('aa start -b '+SELF_BUNDLE)).length;out=await d.execute('launch_app',{appId:calc});assert.match(out,/自动恢复没有成功.*点屏幕边缘的把手/);assert.equal(issued.filter(c=>c.startsWith('aa start -b '+SELF_BUNDLE)).length-before,1,'只尝试一次');
 // 非小窗：不检测
 d.overlay.active=()=>false;selfState='BACKGROUND';out=await d.execute('launch_app',{appId:calc});assert.doesNotMatch(out,/收到了屏幕边缘/);
 // 观察文本里带小窗模式的 launch_app 提示；非小窗没有
 d.overlay.active=()=>true;selfState='FOREGROUND';let obs=await d.observe();assert.match(obs.layout,/小窗模式提示：.*launch_app/);d.overlay.active=()=>false;obs=await d.observe();assert.doesNotMatch(obs.layout,/小窗模式提示/);
 // 纯函数
 assert.equal(F.selfCollapsed(dumpWith('BACKGROUND'),SELF_BUNDLE),true);assert.equal(F.selfCollapsed(dumpWith('FOREGROUND'),SELF_BUNDLE),false);assert.equal(F.selfCollapsed('AbilityRecord ID 2\n bundle name [x]\n state #FOREGROUND\n',SELF_BUNDLE),false,'自身没有记录不算收起');
}

(async()=>{
 await noticeTests();await menuTests();await engineTests();await launchTests();
 console.log('PASS: notice channel drops in-flight publish after cancel, popup-menu replay after approval (unique relocate, no blind click, grant not leaked), launch_app float collapse detection');
})().catch(e=>{console.error(e);process.exit(1);});
