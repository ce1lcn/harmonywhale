// 0.8.3 已安装应用目录。0.8.3.1 真机核对后的取数方式：
// 1. `bm dump -a -l` 输出 JSON 数组 [{"bundleName":…,"label":…}]，label 已是解析后的应用名（优先使用）；
// 2. `bm dump -n <包名>` 取启动 Ability（mainAbility），其 label 是未解析的 `$string:` 引用，不用于名称；
// 3. `bm dump -a`（纯文本包名列表）仅作兜底，名称为空。
// 纯解析与缓存差分，命令由 Device 执行。

export const BUNDLE_RE:RegExp=/^[A-Za-z][A-Za-z0-9_]*(?:\.[A-Za-z0-9_]+)+$/;
export const CATALOG_TTL_MS:number=30*60*1000;
export const CATALOG_FETCH_LIMIT:number=120;

export interface BundleInfo {bundle:string;label:string;ability:string;}
export interface InstalledApps {list:BundleInfo[];note:string;}
export interface BundleLabel {bundle:string;label:string;}
interface RawBundleLabel {bundleName?:string;label?:string;}

// 解析 `bm dump -a -l` 的 JSON 数组。输出前后若有多余文字，从第一个 [ 起，依次尝试从末尾往前的 ]，取第一个能解析的片段。
// 无法解析时返回空数组，由调用方回退到 `bm dump -a`。
export function parseBundleListJson(raw:string):BundleLabel[]{
 const start:number=raw.indexOf('[');
 if(start<0)return [];
 let data:RawBundleLabel[]=[];
 let parsed:boolean=false;
 let end:number=raw.lastIndexOf(']');
 while(!parsed&&end>start){
  try{data=JSON.parse(raw.slice(start,end+1)) as RawBundleLabel[];parsed=true;}catch(e){end=raw.lastIndexOf(']',end-1);}
 }
 if(!parsed)return [];
 const out:BundleLabel[]=[];
 data.forEach((item:RawBundleLabel)=>{
  if(!item)return;
  const bundle:string=item.bundleName??'';
  if(!BUNDLE_RE.test(bundle)||out.some((o:BundleLabel)=>o.bundle===bundle))return;
  const label:string=(item.label??'').trim();
  out.push({bundle:bundle,label:label.startsWith('$')?'':label});
 });
 return out;
}

// 从 `bm dump -a` 文本里取出符合包名形式的记号，去重保持原顺序。
export function parseBundleList(raw:string):string[]{
 const out:string[]=[];
 raw.split(/[\s,;:"'\[\]{}()=|]+/).forEach((token:string)=>{if(BUNDLE_RE.test(token)&&out.indexOf(token)<0)out.push(token);});
 return out;
}

function firstMatch(raw:string,patterns:RegExp[]):string{
 for(let i=0;i<patterns.length;i++){const m=patterns[i].exec(raw);if(m&&m[1]&&m[1].trim())return m[1].trim();}
 return '';
}

// 从 `bm dump -n` 文本里取名称与启动 Ability。资源引用（$string:…）无法在此解析，名称留空，由布局文字兜底。
export function parseBundleInfo(raw:string,bundle:string):BundleInfo{
 const label=firstMatch(raw,[/"?label"?\s*[:=]\s*"([^"\n]*)"/i,/"?label"?\s*[:=]\s*([^\s,"\n}]+)/i]);
 // 真机核对：mainAbility 可能是完整类名（如 com.huawei.hmos.calculator.CalculatorAbility），aa start -a 只接受短名，取最后一段。
 const fullAbility=firstMatch(raw,[/"?mainAbility"?\s*[:=]\s*"?([A-Za-z_][A-Za-z0-9_.]*)"?/i,/"?abilityName"?\s*[:=]\s*"?([A-Za-z_][A-Za-z0-9_.]*)"?/i]);
 const ability:string=fullAbility.indexOf('.')>=0?fullAbility.slice(fullAbility.lastIndexOf('.')+1):fullAbility;
 return {bundle:bundle,label:label.startsWith('$')?'':label,ability:ability};
}

export interface BundleDiff {added:string[];removed:string[];}
export function diffBundles(previous:string[],next:string[]):BundleDiff{
 return {added:next.filter(b=>previous.indexOf(b)<0),removed:previous.filter(b=>next.indexOf(b)<0)};
}

// 缓存容器：记录包名列表与各包信息。刷新时只对新增包取详情，移除包直接丢弃。
export class AppCatalogCache {
 bundles:string[]=[];infos:BundleInfo[]=[];updatedAt:number=0;
 // 0.8.4 A5：`bm dump -a -l` 里每个包的名称。详情（启动 Ability）每次最多取 CATALOG_FETCH_LIMIT 个，没取到详情的包仍要出现在列表里。
 labels:Record<string,string>={};
 fresh(now:number):boolean{return this.updatedAt>0&&now-this.updatedAt<CATALOG_TTL_MS;}
 // 返回需要执行 `bm dump -n` 的包名（已有详情的不再重复取）。
 planFetch(bundles:string[]):string[]{
  const known=this.infos.map(i=>i.bundle);
  return bundles.filter(b=>known.indexOf(b)<0).slice(0,CATALOG_FETCH_LIMIT);
 }
 commit(bundles:string[],fetched:BundleInfo[],now:number):void{
  const kept=this.infos.filter(i=>bundles.indexOf(i.bundle)>=0);
  fetched.forEach(f=>{if(bundles.indexOf(f.bundle)>=0&&kept.every(k=>k.bundle!==f.bundle))kept.push(f);});
  this.infos=kept;this.bundles=bundles.slice();this.updatedAt=now;
 }
 list():BundleInfo[]{return this.infos.slice().sort((a,b)=>a.bundle<b.bundle?-1:a.bundle>b.bundle?1:0);}
 // 全部包：有详情的带启动 Ability，没有详情的 ability 为空（launch_app 时再用 bm dump -n 查询）。
 listAll():BundleInfo[]{
  const out:BundleInfo[]=this.infos.slice();
  this.bundles.forEach((b:string)=>{if(!out.some((i:BundleInfo)=>i.bundle===b))out.push({bundle:b,label:this.labels[b]??'',ability:''});});
  return out.sort((a:BundleInfo,b:BundleInfo)=>a.bundle<b.bundle?-1:a.bundle>b.bundle?1:0);
 }
}
