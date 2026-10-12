const fs=require('fs'),vm=require('vm'),path=require('path'),assert=require('assert/strict');
const ts=require(process.env.HVIGOR_TS||'typescript');
const cache=new Map();let response,seen=[];
const kit={'@kit.NetworkKit':{http:{RequestMethod:{POST:'POST'},HttpDataType:{STRING:1},createHttp:()=>({destroy(){},request:async()=>({responseCode:200,result:JSON.stringify(response),header:{}})})}}};
function load(file){file=path.resolve(file);if(cache.has(file))return cache.get(file);const module={exports:{}};const js=ts.transpileModule(fs.readFileSync(file,'utf8'),{compilerOptions:{module:ts.ModuleKind.CommonJS,target:ts.ScriptTarget.ES2020}}).outputText;vm.runInNewContext(js,{module,exports:module.exports,require:n=>n.startsWith('.')?load(path.resolve(path.dirname(file),n+'.ets')):kit[n],setTimeout,clearTimeout,Number,Math,JSON,RegExp,Object,Promise,Error,Array,String},{});cache.set(file,module.exports);return module.exports;}
(async()=>{
 const {Model,parseUsage}=load('entry/src/main/ets/agent/Model.ets');const T=load('entry/src/main/ets/agent/Types.ets');
 // DeepSeek 字段
 let u=parseUsage({prompt_tokens:1000,completion_tokens:50,total_tokens:1050,prompt_cache_hit_tokens:900,prompt_cache_miss_tokens:100},'api.deepseek.com / deepseek-flash');
 assert.equal(u.input,100);assert.equal(u.cacheRead,900);assert.equal(u.output,50);assert.equal(u.total,1050);assert.equal(u.cacheWrite,0);
 // OpenAI 兼容字段
 u=parseUsage({prompt_tokens:200,completion_tokens:20,prompt_tokens_details:{cached_tokens:150}},'x');assert.equal(u.cacheRead,150);assert.equal(u.input,50);assert.equal(u.total,220);
 assert.equal(parseUsage(undefined,'x'),undefined);assert.equal(parseUsage({},'x'),undefined);
 // 累计
 const sum=T.addUsage(T.addUsage(undefined,{input:1,cacheRead:2,cacheWrite:0,output:3,total:6,calls:1,model:'a'}),{input:10,cacheRead:20,cacheWrite:0,output:30,total:60,calls:1,model:'b'});
 assert.equal(sum.total,66);assert.equal(sum.calls,2);assert.equal(sum.model,'b');
 // 真实请求路径：回调拿到用量，决策里也带用量
 const m=new Model();m.onUsage=x=>seen.push(x);const profile=T.defaults().profiles[0];
 response={choices:[{finish_reason:'stop',message:{content:'好的',tool_calls:[]}}],usage:{prompt_tokens:300,completion_tokens:10,total_tokens:310,prompt_cache_hit_tokens:250,prompt_cache_miss_tokens:50}};
 const d=await m.request(profile,'fixture',[{role:'user',content:'hi'}]);
 assert.equal(seen.length,1);assert.equal(seen[0].model,'api.deepseek.com / deepseek-flash');assert.equal(d.usage.total,310);
 response={choices:[{finish_reason:'stop',message:{content:'无用量',tool_calls:[]}}]};seen=[];await m.request(profile,'fixture',[]);assert.equal(seen.length,0);
 console.log('PASS: usage parsing (DeepSeek / OpenAI fields), accumulation and callback');
})().catch(e=>{console.error(e);process.exitCode=1;});
