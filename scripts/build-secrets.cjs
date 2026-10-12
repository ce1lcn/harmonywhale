// Input stays outside the project; never print its contents.
const fs=require('fs'),path=require('path'),crypto=require('crypto');
function generate(root,input){
 const output=path.join(root,'entry/src/main/ets/agent/BuildSecrets.ets');
 let key='';
 if(input){const absolute=path.resolve(input),relative=path.relative(root,absolute);if(!relative.startsWith('..')&&!path.isAbsolute(relative))throw new Error('Search secrets must be outside the project');
  const JSON5=require(process.env.HVIGOR_JSON5||'json5');
  const config=JSON5.parse(fs.readFileSync(absolute,'utf8'));if(config.bochaKey!==undefined&&typeof config.bochaKey!=='string')throw new Error('bochaKey must be a string');key=(config.bochaKey??'').trim();if(/[\r\n]/.test(key))throw new Error('Invalid search credential');
 }
 const seed=key?crypto.createHash('sha256').update(key).digest('hex'):'';
 const JSON5=require(process.env.HVIGOR_JSON5||'json5');
 const version=JSON5.parse(fs.readFileSync(path.join(root,'AppScope/app.json5'),'utf8')).app.versionName;
 const code='// Generated locally. Do not publish source or log values.\nexport const APP_VERSION:string='+JSON.stringify(version)+';\nexport const BOCHA_KEY:string='+JSON.stringify(key)+';\nexport const SEARCH_SEED:string='+JSON.stringify(seed)+';\n';
 if(!fs.existsSync(output)||fs.readFileSync(output,'utf8')!==code)fs.writeFileSync(output,code,'utf8');
}
module.exports={generate};
if(require.main===module)generate(path.resolve(__dirname,'..'),process.env.HARMONY_SEARCH_SECRETS);
