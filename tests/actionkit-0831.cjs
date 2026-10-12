// 0.8.3.1 操作工具纯逻辑测试：错误码与 retryable、稳定元素编号、点击命中、滚动计划、按条件等待、自适应稳定、按键映射。
const fs=require('fs'),path=require('path'),vm=require('vm'),assert=require('assert/strict');
const ts=require(process.env.HVIGOR_TS||'typescript');
function load(file){
 const mod={exports:{}};
 const src=ts.transpileModule(fs.readFileSync(path.resolve(file),'utf8'),{compilerOptions:{module:ts.ModuleKind.CommonJS,target:ts.ScriptTarget.ES2020}}).outputText;
 vm.runInNewContext(src,{module:mod,exports:mod.exports,require:(n)=>{if(n.startsWith('.'))return load(path.resolve(path.dirname(file),n+'.ets'));throw new Error('unexpected require '+n);}});
 return mod.exports;
}
const K=load('entry/src/main/ets/agent/ActionKit.ets');
const deq=(actual,expected)=>assert.deepEqual(JSON.parse(JSON.stringify(actual)),expected);
const el=(o)=>Object.assign({elementId:'x',type:'Button',text:'',id:'',description:'',parent:'',bounds:[0,0,10,10],normalizedCenter:[0,0],enabled:true,editable:false,focused:false,password:false,clickable:false,window:'w1'},o);

// ---- 错误码：枚举化，带 retryable；未知码按不可重试处理
assert.match(K.formatError('NOT_FOUND','目标不存在'),/错误码 NOT_FOUND（可重试：是）：目标不存在。建议：/);
assert.match(K.formatError('PARAMETER','坏参数'),/可重试：否/);
assert.equal(K.errorInfo('NO_SUCH_CODE').retryable,false);
for(const code of ['NOT_FOUND','OCCLUDED','NOT_FOREGROUND','TIMEOUT','PERMISSION','SELF_OVERLAP','STALE','DEVICE_OFFLINE']){assert.ok(K.errorCodes().indexOf(code)>=0,'missing code '+code);assert.ok(K.errorInfo(code).advice.length>0);}
assert.equal(K.errorInfo('PERMISSION').retryable,false,'permission needs the user');
assert.equal(K.errorInfo('STALE').retryable,true);

// ---- 稳定元素编号：同一结构得到同一编号；同键重复时唯一
assert.equal(K.fnv1a('abc'),K.fnv1a('abc'));assert.notEqual(K.fnv1a('abc'),K.fnv1a('abd'));assert.match(K.fnv1a('x'),/^[0-9a-f]{8}$/);
const run1=[el({text:'OK',bounds:[0,0,5,5]}),el({text:'OK',bounds:[9,9,15,15]}),el({text:'Cancel',parent:'p'})];
const run2=[el({text:'OK',bounds:[0,0,5,5]}),el({text:'OK',bounds:[9,9,15,15]}),el({text:'Cancel',parent:'p'})];
K.assignStableIds(run1);K.assignStableIds(run2);
deq(run1.map(e=>e.elementId),run2.map(e=>e.elementId));
assert.equal(new Set(run1.map(e=>e.elementId)).size,3,'duplicate keys must still get unique ids');
assert.match(run1[0].elementId,/^h[0-9a-f]{8}$/);
// 文字变化后编号随之变化（不再是历史编号）
const changed=[el({text:'Done',bounds:[0,0,5,5]})];K.assignStableIds(changed);assert.notEqual(changed[0].elementId,run1[0].elementId);

// ---- 点击命中：0–1000 比例坐标；返回最小的可点击文字，否则空白处
const screen=[el({type:'Root',bounds:[0,0,2800,1840]}),el({text:'7',clickable:true,bounds:[100,1000,300,1200]}),el({text:'7-wide',clickable:false,bounds:[0,900,2800,1300]})];
let h=K.hitAt(screen,2800,1840,71,598);assert.equal(h.hit,true);assert.equal(h.label,'7');
h=K.hitAt(screen,2800,1840,900,100);assert.equal(h.hit,false);assert.equal(h.label,'空白处');
// 同一点命中多个有文字元素：可点击优先
h=K.hitAt([el({text:'plain',bounds:[0,0,100,100]}),el({text:'button',clickable:true,bounds:[0,0,400,400]})],1000,1000,50,50);assert.equal(h.label,'button');
assert.equal(K.hitAt([],0,0,1,1).label,'空白处');

// ---- 滚动计划：方向与次数上限
deq(K.scrollPlan('down',2),[{x1:500,y1:750,x2:500,y2:250},{x1:500,y1:750,x2:500,y2:250}]);
assert.equal(K.scrollPlan('up',20).length,8,'maxSwipes capped at 8');
assert.equal(K.scrollPlan('left',1)[0].x1>K.scrollPlan('left',1)[0].x2,true);
assert.equal(K.validScrollDirection('down'),true);assert.equal(K.validScrollDirection('diagonal'),false);

// ---- 按条件等待
const current=[el({text:'保存成功',bounds:[0,0,5,5]}),el({text:'首页',bounds:[0,0,5,5]})];
assert.equal(K.waitSatisfied('textAppears','保存成功','',current),true);
assert.equal(K.waitSatisfied('textAppears','不存在',''  ,current),false);
assert.equal(K.waitSatisfied('textDisappears','不存在','',current),true);
assert.equal(K.waitSatisfied('textDisappears','首页','',current),false);
const base=K.sceneFingerprint([el({text:'首页',normalizedCenter:[1,500]})]);
assert.equal(K.waitSatisfied('screenChanges','',base,[el({text:'设置',normalizedCenter:[1,500]})]),true);
assert.equal(K.waitSatisfied('screenChanges','',base,[el({text:'首页',normalizedCenter:[1,500]})]),false);
assert.equal(K.WAIT_CONDITIONS.indexOf('textAppears')>=0,true);

// ---- 自适应稳定：默认 4 s；覆盖上限 ≤12 s；相邻两次相同即稳定
assert.equal(K.settleCap(undefined),4000);assert.equal(K.settleCap(20000),12000);assert.equal(K.settleCap(100),300);assert.equal(K.settleCap(2500),2500);
assert.equal(K.settled(undefined,'a'),false);assert.equal(K.settled('a','a'),true);assert.equal(K.settled('a','b'),false);
assert.equal(K.SETTLE_INTERVAL_MS,300);

// ---- 按键映射
assert.equal(K.keyCodeOf('enter'),'2054');assert.equal(K.keyCodeOf('backspace'),'2055');assert.equal(K.keyCodeOf('tab'),'2049');assert.equal(K.keyCodeOf('escape'),'2070');assert.equal(K.keyCodeOf('space'),'');
// ---- observe 的 query 与布局预算
const page=[el({text:'设置',clickable:true,bounds:[0,0,5,5]}),el({text:'Wi-Fi 列表',bounds:[0,0,5,5]}),el({type:'Image',bounds:[0,0,5,5]}),el({text:'关于',clickable:true,bounds:[0,0,5,5]})];
deq(K.queryElements(page,'wi-fi').map(e=>e.text),['Wi-Fi 列表']);
assert.equal(K.queryElements(page,'  ').length,4,'blank query returns everything');
assert.equal(K.queryElements(page,'image').length,1,'type matches too');
const picked=K.pickForLayout(page,1000,(e)=>JSON.stringify(e));assert.equal(picked.omitted,0);
// 预算只够一条时，保留可点击的那条，并保持原顺序输出
const tight=K.pickForLayout(page,JSON.stringify(page[0]).length+2,(e)=>JSON.stringify(e));
assert.equal(tight.kept.length,1);assert.equal(tight.kept[0].text,'设置');assert.equal(tight.omitted,3);
const order=K.pickForLayout(page,JSON.stringify(page[0]).length*2+4,(e)=>JSON.stringify(e));deq(order.kept.map(e=>e.text),['设置','关于']);

// ---- 工具定义：新动作存在、参数校验生效、wait_for 只要求 condition，observe 带 query
const REG=load('entry/src/main/ets/agent/Registry.ets');
const TD=load('entry/src/main/ets/agent/ToolDescriptions.ets');
const defs=TD.describeTools(REG.builtins([]));
const byName={};defs.forEach(d=>{byName[d.name]=d;});
for(const n of ['long_press','double_click','drag','scroll','press_key']) assert.ok(byName[n],'missing tool '+n);
deq(byName.scroll.parameters.required,['direction']);
assert.throws(()=>REG.validate(byName.scroll,{direction:'diagonal'}),/取值错误/);
REG.validate(byName.scroll,{direction:'down',maxSwipes:2});
assert.throws(()=>REG.validate(byName.press_key,{key:'space'}),/取值错误/);
REG.validate(byName.press_key,{key:'enter'});
deq(byName.wait_for.parameters.required,['condition']);
assert.ok(byName.observe.parameters.properties.query,'observe takes query');
assert.match(byName.click.description,/命中/);
assert.ok(byName.wait_for.parameters.properties.condition.enum.indexOf('textAppears')>=0);

// ---- 进度行：ask_user 显示问题，其他工具显示短标签，永不出现工具描述
assert.equal(K.progressLabel('ask_user','选哪个颜色？'),'正在询问你：选哪个颜色？');
assert.equal(K.progressLabel('ask_user',''),'正在询问你');
assert.equal(K.progressLabel('ask_user','a'.repeat(100)).length,'正在询问你：'.length+40);
assert.equal(K.progressLabel('click',''),'点击');
assert.equal(K.progressLabel('unknown_tool',''),'执行 unknown_tool');
for(const n of ['ask_user','click','file_write','scroll','request_confirmation']){assert.ok(K.progressLabel(n,'').indexOf('信息不足')<0,'no tool description leaks');}

console.log('actionkit-0831: ok');
