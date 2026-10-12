const fs=require('fs'),vm=require('vm'),assert=require('assert/strict');const ts=require(process.env.HVIGOR_TS||'typescript');
const moduleFixture={exports:{}};vm.runInNewContext(ts.transpileModule(fs.readFileSync('entry/src/main/ets/agent/Drawing.ets','utf8'),{compilerOptions:{module:ts.ModuleKind.CommonJS,target:ts.ScriptTarget.ES2020}}).outputText,{module:moduleFixture,exports:moduleFixture.exports});const D=moduleFixture.exports;
for(const input of ['[]','[[[0,0]]]','[[[0,0],[1001,0]]]','[[[0,0],["2",3]]]','[[[0,0],[null,3]]]'])assert.throws(()=>D.drawingRequest(input));
assert.throws(()=>D.drawingRequest(JSON.stringify(Array.from({length:21},()=>[[0,0],[1,1]]))));assert.throws(()=>D.drawingRequest(JSON.stringify(Array.from({length:8},()=>Array.from({length:200},(_,i)=>[i,i])))));
assert.throws(()=>D.drawingRequest('[[[0,0],[1,1]]]','pen'));assert.throws(()=>D.drawingRequest('[[[0,0],[1,1]]]','finger',Infinity));
const request=D.drawingRequest('[[[300,300],[300.2,300.2],[600,600]]]','finger',300);assert.equal(request.speed,100);const pixels=D.drawingPixels(request,2800,1840,{left:100,top:200,right:2700,bottom:1700});assert.equal(pixels[0].length,2);assert.equal(pixels[0][1].x,1679);
assert.throws(()=>D.drawingPixels(request,2800,1840,{left:1000,top:200,right:2700,bottom:1700}));assert.throws(()=>D.drawingPixels(D.drawingRequest('[[[5,5],[5,5]]]'),2800,1840));
console.log('PASS: drawing limits, finite coordinates, unavailable pen rejection, speed clamp, pixel scaling, whole-path bounds and coalescing. No native injection claimed.');
