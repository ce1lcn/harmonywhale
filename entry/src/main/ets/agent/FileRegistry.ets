import {formatDefinitions} from './FormatRegistry';
import {Definition,Schema,Property} from './Types';
// 0.8.3 通用文本文件：file_write 新建文本文件，file_read 按行号窗口读取。只读写会话沙箱内的文件。
function prop(type:string,description:string):Property{const p:Property={type:type,description:description};return p;}
function fileDef(name:string,description:string,props:Record<string,Property>,required:string[],readOnly:boolean,disabled:string[]):Definition{const schema:Schema={type:'object',properties:props,required:required};const d:Definition={name:name,description:description,parameters:schema,source:'本机文件',enabled:disabled.indexOf(name)<0,readOnly:readOnly};return d;}
function fileTextDefinitions(disabled:string[]):Definition[]{
 const writeProps:Record<string,Property>={};
 writeProps['name']=prop('string','文件名，如 notes.md');
 writeProps['content']=prop('string','文件全文');
 writeProps['encoding']=prop('string','可选，只支持 utf-8');
 const readProps:Record<string,Property>={};
 readProps['fileId']=prop('string','当前会话文件清单中的 fileId');
 readProps['offset']=prop('number','起始行号，从 1 开始，默认 1');
 readProps['limit']=prop('number','读取行数，默认 2000，最多 2000');
 const editProps:Record<string,Property>={};
 editProps['fileId']=prop('string','当前会话文件清单中的 fileId（必须是文本文件，并且本会话已用 file_read 读过）');
 editProps['oldString']=prop('string','要替换的原文，按字面量逐字匹配（含空白与换行），不能为空；必须在文件里恰好出现一次，除非 replaceAll=true');
 editProps['newString']=prop('string','替换后的文字，必须与 oldString 不同；传空字符串表示删除');
 editProps['replaceAll']=prop('boolean','可选，true 时替换文件里全部出现的 oldString，默认 false');
 const out:Definition[]=[];
 out.push(fileDef('file_write','新建一个文本文件保存到当前会话（不覆盖已有文件）。name 为文件名（允许 .txt .md .json .csv .html .xml .yaml .log 及常见代码后缀，无后缀补 .txt）；content 为文本，单文件不超过 2 MB；.json 写入前校验，不合法则不写入并返回 PARAMETER。返回新 fileId。',writeProps,['name','content'],false,disabled));
 out.push(fileDef('file_read','按行号窗口读取当前会话的文本文件。offset 从 1 开始，limit 默认 2000、最多 2000；结果带行号，超出时给出下一个 offset。仅用于 txt/md/json 等文本文件；表格用 sheet_read，PPT 用 presentation_read。',readProps,['fileId'],true,disabled));
 out.push(fileDef('file_edit','修改当前会话里已有的文本文件：把 oldString 按字面量替换成 newString。改前必须先用 file_read 读过这个文件（没读过会被拒绝，读过之后文件被改动也要重读）；oldString 不唯一或找不到会返回明确错误，不唯一时补充前后文，或设 replaceAll=true 全部替换。另存为新 fileId，原件保留，.json 改完仍须是合法 JSON。',editProps,['fileId','oldString','newString'],false,disabled));
 return out;
}
export function fileDefinitions(disabled:string[]):Definition[]{const out:Definition[]=fileTextDefinitions(disabled).concat(formatDefinitions(disabled));const names=['file_list','sheet_list','sheet_read','sheet_create','sheet_update_cells','presentation_read','presentation_create','presentation_set_text'];names.forEach(name=>{const schema:Schema={type:'object',properties:{},required:[]};if(!['file_list','sheet_create','presentation_create'].includes(name)){schema.properties.fileId={type:'string',description:'当前会话文件清单中的fileId'};schema.required.push('fileId');}if(['sheet_read','sheet_update_cells'].includes(name)){schema.properties.sheet={type:'string',description:'sheet_list返回的工作表名称'};schema.required.push('sheet');}if(name==='sheet_read')schema.properties.offset={type:'number',description:'单元格分页偏移，默认0，每次100格'};if(['presentation_read','presentation_set_text'].includes(name)){schema.properties.slide={type:'number',description:'从1开始的页码'};schema.required.push('slide');}if(name==='sheet_create'){schema.properties.sheet={type:'string'};schema.properties.rowsJson={type:'string',description:'JSON二维数组，值仅文本、有限数字、布尔或null；最多500行40列；公式作为普通文本'};schema.properties.sheetsJson={type:'string',description:'可选，JSON数组[{name,rows,widths?,headerBold?}]；rows必须是二维数组，每行也是数组，例[["数量","金额"],[2,15],["合计",{formula:"SUM(B2:B2)"}]]；不能把字符串直接当行。1～20表，每表2000行100列。传此项可不填rowsJson。'};}if(name==='sheet_update_cells'){schema.properties.patchesJson={type:'string',description:'JSON数组，每项{cell:"A1",type:"text|number|boolean|empty",value:"字符串"}，1～100项，type支持formula（不计算缓存）'};schema.required.push('patchesJson');}if(name==='presentation_create'){schema.properties.slidesJson={type:'string',description:'JSON数组，每页{title:"标题",body:"正文，可换行"}，1～20页，标题60字内，正文600字内，基础16:9版式'};schema.required.push('slidesJson');}if(name==='presentation_set_text'){schema.properties.paragraphId={type:'string',description:'presentation_read给出的p编号'};schema.properties.text={type:'string'};schema.required.push('paragraphId','text');}const write=['sheet_create','sheet_update_cells','presentation_create','presentation_set_text'].includes(name);if(write)schema.properties.name={type:'string',description:'结果另存的文件名'};out.push({name:name,description:name==='file_list'?'列出当前会话文件':name==='sheet_list'?'读取工作表名称':name==='sheet_read'?'读取原始单元格内容，公式不重算':name==='sheet_create'?'新建并验证表格':name==='sheet_update_cells'?'修改单元格并另存，原件保留':name==='presentation_read'?'读取PPT指定页的段落文字':name==='presentation_create'?'新建基础文字PPT并验证':'替换PPT指定段落文字并另存',parameters:schema,source:'本机文件',enabled:!disabled.includes(name),readOnly:!write});});return out;}
