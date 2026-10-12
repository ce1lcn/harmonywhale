import {buffer} from '@kit.ArkTS';
import {Call} from './Types';
interface FragmentFunction {name?:string;arguments?:string;}
interface Fragment {index:number;id?:string;function?:FragmentFunction;}
interface Delta {content?:string;reasoning_content?:string;tool_calls?:Fragment[];}
interface StreamChoice {delta:Delta;finish_reason?:string|null;}
export interface StreamUsage {prompt_tokens?:number;completion_tokens?:number;total_tokens?:number;prompt_cache_hit_tokens?:number;prompt_cache_miss_tokens?:number;}
interface StreamEnvelope {choices?:StreamChoice[];usage?:StreamUsage;error?:Object;}
// Decode the accumulated bytes: only complete SSE lines are consumed, including across UTF-8 boundaries.
export class ReplyStream {
 bytes:number[]=[];offset:number=0;text:string='';reasoning:string='';calls:Call[]=[];finish:string='';done:boolean=false;usage:StreamUsage|undefined=undefined;
 feed(data:ArrayBuffer,onText:(text:string)=>void):void {
  const chunk=new Uint8Array(data);for(let i=0;i<chunk.length;i++)this.bytes.push(chunk[i]);
  if(this.bytes.length>4*1024*1024)throw new Error('模型流式回复超过4MB，已保留收到的正文');
  const source=buffer.from(new Uint8Array(this.bytes)).toString('utf8');let end=source.indexOf('\n',this.offset);
  while(end>=0){const line=source.slice(this.offset,end).trim();this.offset=end+1;if(line.startsWith('data:'))this.consume(line.slice(5).trim(),onText);end=source.indexOf('\n',this.offset);}
 }
 consume(value:string,onText:(text:string)=>void):void {
  if(value==='[DONE]'){this.done=true;return;}if(!value)return;
  const event=JSON.parse(value) as StreamEnvelope;if(event.error)throw new Error('模型返回流式错误，已保留收到的正文');if(event.usage)this.usage=event.usage;
  const choice=event.choices?.[0];if(!choice)return;const delta=choice.delta;
  if(typeof delta?.content==='string'){this.text+=delta.content;onText(this.text);}
  if(typeof delta?.reasoning_content==='string')this.reasoning+=delta.reasoning_content;
  (delta?.tool_calls??[]).forEach(f=>{if(!Number.isInteger(f.index)||f.index<0||f.index>15)throw new Error('流式工具编号无效');let c=this.calls[f.index];if(!c){c={id:'',name:'',arguments:''};this.calls[f.index]=c;}if(f.id)c.id+=f.id;if(f.function?.name)c.name+=f.function.name;if(f.function?.arguments)c.arguments+=f.function.arguments;});
  if(choice.finish_reason)this.finish=choice.finish_reason;
 }
 validatedCalls():Call[]{if(!this.done||this.finish!=='tool_calls')return [];for(let i=0;i<this.calls.length;i++){const c=this.calls[i];if(!c||!c.id||!c.name)throw new Error('工具调用未完整返回');}return this.calls;}
}
