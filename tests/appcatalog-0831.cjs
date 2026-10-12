// 0.8.3.1 应用目录真机核对样例：`bm dump -a -l` 的 JSON 解析、名称优先级、`bm dump -n` 的启动 Ability、兜底路径。
// 样例取自 2026-10-08 平板 本机平板 的真实输出（节选）。
const fs=require('fs'),path=require('path'),vm=require('vm'),assert=require('assert/strict');
const ts=require(process.env.HVIGOR_TS||'typescript');
const file=path.resolve('entry/src/main/ets/agent/AppCatalog.ets');
const mod={exports:{}};
vm.runInNewContext(ts.transpileModule(fs.readFileSync(file,'utf8'),{compilerOptions:{module:ts.ModuleKind.CommonJS,target:ts.ScriptTarget.ES2020}}).outputText,{module:mod,exports:mod.exports});
const AC=mod.exports;
const deq=(actual,expected)=>assert.deepEqual(JSON.parse(JSON.stringify(actual)),expected);

// 真机样例（节选）：前两行为 bm 的 JSON 数组，中间夹杂一条带 $string 资源引用的标签。
const realList='[\n    {\n        "bundleName": "cn.wps.office.hap",\n        "label": "WPS Office"\n    },\n    {\n        "bundleName": "com.harmonyloom.schedule",\n        "label": "ClassCount"\n    },\n    {\n        "bundleName": "com.harmonyloom.selfhdcprobe",\n        "label": "HarmonyWhale"\n    },\n    {\n        "bundleName": "com.example.unresolved",\n        "label": "$string:app_name"\n    }\n]\n';
deq(AC.parseBundleListJson(realList),[
 {bundle:'cn.wps.office.hap',label:'WPS Office'},
 {bundle:'com.harmonyloom.schedule',label:'ClassCount'},
 {bundle:'com.harmonyloom.selfhdcprobe',label:'HarmonyWhale'},
 {bundle:'com.example.unresolved',label:''},
]);

// 输出前后夹杂文字时只取 JSON 部分；重复包名只保留一条；非法包名丢弃。
deq(AC.parseBundleListJson('some banner\n'+realList+'\ntrailer ]'),JSON.parse(JSON.stringify(AC.parseBundleListJson(realList))));
deq(AC.parseBundleListJson('[{"bundleName":"a.b","label":"A"},{"bundleName":"a.b","label":"A2"},{"bundleName":"bad token","label":"X"}]'),[{bundle:'a.b',label:'A'}]);

// 无法解析或为空时返回空数组，调用方据此回退到 bm dump -a。
deq(AC.parseBundleListJson(''),[]);
deq(AC.parseBundleListJson('[not json]'),[]);
deq(AC.parseBundleListJson('ID: 100:\n\tcn.wps.office.hap\n'),[]);

// bm dump -n 的真机字段：label 为未解析的 $string 引用（不作名称），mainAbility 为启动 Ability。
const realInfo='{\n "applicationInfo": {"label": "$string:app_name"},\n "hapModuleInfos": [{"label": "$string:EntryAbility_label"}],\n "label": "",\n "mainAbility": "ProbeAbility",\n "mainEntry": "entry"\n}';
const info=AC.parseBundleInfo(realInfo,'com.harmonyloom.selfhdcprobe');
assert.equal(info.ability,'ProbeAbility');
assert.equal(info.label,'');

// 名称优先级由 Device 决定：-a -l 的名称覆盖 -n 的（空）名称，启动 Ability 来自 -n。
const named=AC.parseBundleListJson(realList);
const merged=named.map((n)=>({bundle:n.bundle,label:n.label.length>0?n.label:'',ability:n.bundle==='com.harmonyloom.selfhdcprobe'?'ProbeAbility':''}));
assert.equal(merged.find((m)=>m.bundle==='com.harmonyloom.selfhdcprobe').label,'HarmonyWhale');
assert.equal(merged.find((m)=>m.bundle==='com.harmonyloom.selfhdcprobe').ability,'ProbeAbility');
assert.equal(merged.find((m)=>m.bundle==='com.example.unresolved').label,'');

// 真机核对：mainAbility 为完整类名时，启动用短名（aa start -a CalculatorAbility 已验证可启动）。
const calcInfo=AC.parseBundleInfo('{"bundleName":"com.huawei.hmos.calculator","mainAbility":"com.huawei.hmos.calculator.CalculatorAbility","label":""}','com.huawei.hmos.calculator');
assert.equal(calcInfo.ability,'CalculatorAbility');
assert.equal(AC.parseBundleInfo('"mainAbility": "EntryAbility"','x.y.z').ability,'EntryAbility');

console.log('appcatalog-0831: ok');
