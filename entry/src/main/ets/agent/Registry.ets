import {Definition,Schema,Arguments} from './Types';
export function builtins(disabledTools:string[]=[]):Definition[]{const definitions:Definition[]=[];['click','insert_text','replace_text','swipe','back','home','observe','request_confirmation','skill_load'].forEach(name=>{const schema:Schema={type:'object',properties:{},required:[]};if(['click','insert_text','replace_text','swipe'].indexOf(name)>=0){schema.properties.x={type:'number',description:'横坐标 0–1000'};schema.properties.y={type:'number',description:'纵坐标 0–1000'};schema.required=['x','y'];}if(name==='insert_text'||name==='replace_text'||name==='request_confirmation'){schema.properties.text={type:'string',description:'输入文字或需要确认的具体操作'};schema.required.push('text');}if(name==='swipe'){schema.properties.x2={type:'number'};schema.properties.y2={type:'number'};schema.required.push('x2','y2');}if(name==='observe'){schema.properties.query={type:'string',description:'可选：只列出文字、描述、类型或编号包含该词的元素，匹配项不截断'};schema.properties.ocr={type:'boolean',description:'可选：true 表示对截图做端侧文字识别（OCR），把识别出的文字与坐标作为 type=ocr 的元素列出。第三方应用读不到文字时使用'};}if(name==='skill_load'){schema.properties.name={type:'string'};schema.properties.path={type:'string'};schema.required=['name'];}definitions.push({name:name,description:name==='replace_text'?'全选替换输入框内容':name==='insert_text'?'在光标位置插入文字':name==='observe'?'获取最新屏幕和布局':name==='request_confirmation'?'执行敏感操作前请求用户确认':name==='skill_load'?'按名字加载 Skill 或参考资料':name,parameters:schema,source:'平板内置',enabled:(disabledTools??[]).indexOf(name)<0,readOnly:['observe','skill_load'].indexOf(name)>=0});});
 const names=['click_element','insert_element','replace_element','wait_for','launch_app','finish_task'];
 names.forEach(name=>{const parameters:Schema={type:'object',properties:{},required:[]};
 if(name.indexOf('element')>=0||name==='wait_for'){parameters.properties.snapshotId={type:'string'};parameters.properties.elementId={type:'string'};parameters.required=['snapshotId','elementId'];}
 if(name==='insert_element'||name==='replace_element'){parameters.properties.text={type:'string'};parameters.required.push('text');}
 if(name==='wait_for'){parameters.required=['condition'];parameters.properties.targetText={type:'string'};parameters.properties.condition={type:'string',enum:['textAppears','textDisappears','screenChanges','appears','disappears','text']};parameters.properties.text={type:'string'};parameters.properties.timeoutMs={type:'number'};}
 if(name==='launch_app'){parameters.properties.appId={type:'string'};parameters.required=['appId'];}
 if(name==='finish_task'){parameters.properties.outcome={type:'string',enum:['success','blocked','needs_user']};parameters.properties.reply={type:'string'};parameters.properties.snapshotId={type:'string'};parameters.properties.evidence={type:'string'};parameters.required=['outcome','reply'];}
 definitions.push({name:name,description:name==='finish_task'?'明确结束任务并引用最新观察证据':name==='wait_for'?'等待元素出现、消失或文本变化':name==='launch_app'?'启动已发现的应用；appId只传纯包名，例如com.huawei.hmos.calculator，不包含应用名称、空格或[Ability]注释':name==='click_element'?'重新定位并点击有文字或描述的元素；无可读名称的按钮直接使用最新截图坐标 click':name==='insert_element'?'在元素光标处追加输入':'替换元素文本',parameters:parameters,source:'平板内置',enabled:disabledTools.indexOf(name)<0,readOnly:name==='wait_for'||name==='finish_task'});
 });
 // 0.8.3.1 新增动作：长按、双击、拖拽、滚动、按键。坐标同样为 0–1000。
 ['long_press','double_click','drag','scroll','press_key'].forEach(name=>{const schema:Schema={type:'object',properties:{},required:[]};
  if(name==='long_press'||name==='double_click'){schema.properties.x={type:'number',description:'横坐标 0–1000'};schema.properties.y={type:'number',description:'纵坐标 0–1000'};schema.required=['x','y'];}
  if(name==='drag'){schema.properties.x={type:'number',description:'起点横坐标 0–1000'};schema.properties.y={type:'number',description:'起点纵坐标 0–1000'};schema.properties.x2={type:'number',description:'终点横坐标 0–1000'};schema.properties.y2={type:'number',description:'终点纵坐标 0–1000'};schema.required=['x','y','x2','y2'];}
  if(name==='scroll'){schema.properties.direction={type:'string',enum:['up','down','left','right'],description:'内容移动方向：down 为查看下方内容'};schema.properties.untilText={type:'string',description:'可选：出现该文字即停止'};schema.properties.maxSwipes={type:'number',description:'最多滑动次数，1–8，默认3'};schema.required=['direction'];}
  if(name==='press_key'){schema.properties.key={type:'string',enum:['enter','backspace','tab','escape']};schema.required=['key'];}
  definitions.push({name:name,description:name,parameters:schema,source:'平板内置',enabled:disabledTools.indexOf(name)<0,readOnly:false});
 });
const drawing:Schema={type:'object',properties:{},required:['strokesJson']};
 drawing.properties.strokesJson={type:'string',description:'JSON 数组：多笔，每笔为 [[x,y],...]，0–1000屏幕比例坐标；每笔2–200点，最多20笔，总点数1500'};
 drawing.properties.tool={type:'string',enum:['finger'],description:'仅分段手指，不支持电容笔压力'};
 drawing.properties.speed={type:'number',description:'每段移动耗时ms，限幅5–100，默认20'};
 drawing.properties.snapshotId={type:'string',description:'最新观察编号'};drawing.properties.canvasElementId={type:'string',description:'可选Canvas/XComponent元素编号，需同时提供snapshotId，全部点须在边界内'};
 definitions.push({name:'draw_path',description:'在当前画布分段手指绘制路径，每段抬起，无电容笔压力；先确认画笔、手指绘画和画布，优先几何形状，少量绘制后观察验证，不能自动重画不确定笔迹',parameters:drawing,source:'平板内置',enabled:disabledTools.indexOf('draw_path')<0,readOnly:false});return definitions;}
 export function validate(def:Definition,args:Arguments):void {
 if(!args||Array.isArray(args)||typeof args!=='object')throw new Error('参数必须为对象');
 const values=args as Record<string,Object>;
 def.parameters.required.forEach(k=>{if(!Object.keys(values).includes(k))throw new Error('工具缺少必要参数 '+k);});
 if(!def.name.startsWith('mcp_'))Object.keys(values).forEach(k=>{const p=def.parameters.properties[k];if(!p)throw new Error('工具包含未定义参数');if(p.type==='array'?!(Array.isArray(values[k])||typeof values[k]==='string'):typeof values[k]!==p.type)throw new Error('参数类型错误 '+k);if(p.enum&&p.enum.indexOf(values[k] as string)<0)throw new Error('参数取值错误 '+k);});
 }
