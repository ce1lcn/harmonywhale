// Portions Copyright (c) 2026 DeepSeek. MIT; full notice in docs/THIRD-PARTY.md.
// Protocol mapping rewritten for ArkTS. Endpoint/fields checked against DeepSeek official API docs.
import {buffer} from '@kit.ArkTS';
import {Profile,Usage,Call,Schema,Decision,ThinkingBlock} from './Types';
import {Message,FunctionTool} from './Model';
import {outputLimit,effortOf} from './ExecutionPolicy';
export interface ContentBlock {type:string;text?:string;thinking?:string;signature?:string;id?:string;name?:string;input?:Object;tool_use_id?:string;content?:string;source?:ImageSource;}
interface ImageSource {type:string;media_type:string;data:string;}
interface Tool {name:string;description:string;input_schema:Schema;}
interface Msg {role:string;content:ContentBlock[];}
interface Thinking {type:string;}
interface Effort {effort:string;}
export interface MessagesRequest {model:string;system:string;messages:Msg[];tools?:Tool[];max_tokens:number;stream:boolean;thinking?:Thinking;output_config?:Effort;}
export function messagesEndpoint(base:string):string{let v=base.replace(/\/+$/,'');if(v.endsWith('/messages'))return v;if(/^https:\/\/api\.deepseek\.com(?:\/v1)?$/.test(v))v='https://api.deepseek.com/anthropic';return v+(v.endsWith('/v1')?'/messages':'/v1/messages');}
export function messagesBody(p:Profile,messages:Message[],tools?:FunctionTool[]):MessagesRequest {
 const system:string[]=[],history:Msg[]=[];
 messages.forEach(m=>{
  if(m.role==='system'){system.push(typeof m.content==='string'?m.content:'');return;}
  const blocks:ContentBlock[]=[];
  if(m.role==='tool')blocks.push({type:'tool_result',tool_use_id:m.tool_call_id,content:typeof m.content==='string'?m.content:''});
  else{
   if(m.role==='assistant'&&p.thinking==='enabled')(m.thinkingBlocks??[]).forEach(b=>blocks.push({type:'thinking',thinking:b.thinking,signature:b.signature}));
   if(typeof m.content==='string'){if(m.content)blocks.push({type:'text',text:m.content});}else if(Array.isArray(m.content))m.content.forEach(part=>{if(part.type==='text')blocks.push({type:'text',text:part.text??''});else if(part.image_url){const image=/^data:(image\/(?:jpeg|png|gif|webp));base64,(.+)$/.exec(part.image_url.url);if(!image)throw new Error('Messages 图片必须为支持格式的内联base64');blocks.push({type:'image',source:{type:'base64',media_type:image[1],data:image[2]}});}});
   (m.tool_calls??[]).forEach(c=>blocks.push({type:'tool_use',id:c.id,name:c.function.name,input:JSON.parse(c.function.arguments) as Object}));
  }
  if(!blocks.length)return;
  const role=m.role==='assistant'?'assistant':'user',prior=history[history.length-1];if(prior&&prior.role===role)prior.content.push(...blocks);else history.push({role:role,content:blocks});
 });
 const body:MessagesRequest={model:p.model,system:system.join('\n'),messages:history,max_tokens:outputLimit(p),stream:false};
 if(tools?.length)body.tools=tools.map(t=>({name:t.function.name,description:t.function.description,input_schema:t.function.parameters} as Tool));
 body.thinking={type:p.thinking==='enabled'?'enabled':'disabled'};if(p.thinking==='enabled')body.output_config={effort:effortOf(p)};return body;
}
export interface MessagesUsage {input_tokens?:number;output_tokens?:number;cache_read_input_tokens?:number;cache_creation_input_tokens?:number;}
export function messagesUsage(u:MessagesUsage|undefined,label:string):Usage|undefined{if(!u)return undefined;const n=(v:number|undefined):number=>Number.isFinite(v)&&v!>0?v!:0;const input=n(u.input_tokens),output=n(u.output_tokens),read=n(u.cache_read_input_tokens),write=n(u.cache_creation_input_tokens);if(!(input+output+read+write))return undefined;return {input:input,output:output,cacheRead:read,cacheWrite:write,total:input+output+read+write,calls:1,model:label};}
interface Envelope {content?:ContentBlock[];stop_reason?:string;usage?:MessagesUsage;error?:Object;}
export function parseMessages(source:string,label:string):Decision{const e=JSON.parse(source) as Envelope;if(e.error)throw new Error('Messages 返回错误');const blocks=e.content??[],thinking:ThinkingBlock[]=[],calls:Call[]=[];let text='',reasoning='';blocks.forEach(b=>{if(b.type==='text')text+=b.text??'';if(b.type==='thinking'){reasoning+=b.thinking??'';thinking.push({thinking:b.thinking??'',signature:b.signature??''});}if(b.type==='tool_use'){if(!b.id||!b.name)throw new Error('Messages 工具调用未完整返回');calls.push({id:b.id,name:b.name,arguments:JSON.stringify(b.input??{})});}});const incomplete=e.stop_reason==='max_tokens';return {text:text,calls:incomplete?[]:calls,providerReasoning:reasoning,thinkingBlocks:thinking,incomplete:incomplete,partialCalls:incomplete&&calls.length>0,finishReason:e.stop_reason,usage:messagesUsage(e.usage,label)};}
interface Delta {type?:string;text?:string;thinking?:string;signature?:string;partial_json?:string;stop_reason?:string;}
interface Event {type:string;index?:number;content_block?:ContentBlock;delta?:Delta;message?:Envelope;usage?:MessagesUsage;error?:Object;}
interface PartialBlock {block:ContentBlock;json:string;}
export class MessagesStream {
 bytes:number[]=[];offset:number=0;text:string='';reasoning:string='';calls:Call[]=[];thinkingBlocks:ThinkingBlock[]=[];finish:string='';done:boolean=false;usage:MessagesUsage|undefined=undefined;blocks:PartialBlock[]=[];
 feed(data:ArrayBuffer,onText:(text:string)=>void):void{const chunk=new Uint8Array(data);for(let i=0;i<chunk.length;i++)this.bytes.push(chunk[i]);if(this.bytes.length>4*1024*1024)throw new Error('模型流式回复超过4MB');const source=buffer.from(new Uint8Array(this.bytes)).toString('utf8');let end=source.indexOf('\n',this.offset);while(end>=0){const line=source.slice(this.offset,end).trim();this.offset=end+1;if(line.startsWith('data:'))this.consume(line.slice(5).trim(),onText);end=source.indexOf('\n',this.offset);}}
 consume(value:string,onText:(text:string)=>void):void{if(!value)return;const e=JSON.parse(value) as Event;if(e.type==='error')throw new Error('Messages 流式错误');if(e.type==='message_start')this.usage=e.message?.usage;if(e.type==='message_stop')this.done=true;if(e.usage)this.usage={input_tokens:e.usage.input_tokens??this.usage?.input_tokens,output_tokens:e.usage.output_tokens??this.usage?.output_tokens,cache_read_input_tokens:e.usage.cache_read_input_tokens??this.usage?.cache_read_input_tokens,cache_creation_input_tokens:e.usage.cache_creation_input_tokens??this.usage?.cache_creation_input_tokens};
  if(e.type==='message_delta'&&e.delta?.stop_reason)this.finish=e.delta.stop_reason==='tool_use'?'tool_calls':e.delta.stop_reason==='max_tokens'?'length':e.delta.stop_reason;
  if(e.type==='content_block_start'){if(!Number.isInteger(e.index)||e.index!<0||e.index!>127||!e.content_block)throw new Error('Messages 内容编号无效');this.blocks[e.index!]={block:e.content_block,json:''};if(e.content_block.type==='text'&&e.content_block.text){this.text+=e.content_block.text;onText(this.text);}if(e.content_block.type==='thinking')this.reasoning+=e.content_block.thinking??'';if(e.content_block.type==='tool_use')this.calls.push({id:e.content_block.id??'',name:e.content_block.name??'',arguments:''});}
  if(e.type==='content_block_delta'){const b=this.blocks[e.index??-1];if(!b||!e.delta)throw new Error('Messages 内容块缺失');const d=e.delta;if(d.type==='text_delta'){b.block.text=(b.block.text??'')+(d.text??'');this.text+=d.text??'';onText(this.text);}else if(d.type==='thinking_delta'){b.block.thinking=(b.block.thinking??'')+(d.thinking??'');this.reasoning+=d.thinking??'';}else if(d.type==='signature_delta')b.block.signature=(b.block.signature??'')+(d.signature??'');else if(d.type==='input_json_delta')b.json+=d.partial_json??'';}
 }
 validatedCalls():Call[]{this.thinkingBlocks=this.blocks.filter(b=>b?.block.type==='thinking').map(b=>({thinking:b.block.thinking??'',signature:b.block.signature??''} as ThinkingBlock));if(!this.done||this.finish!=='tool_calls')return [];return this.blocks.filter(b=>b?.block.type==='tool_use').map(b=>{if(!b.block.id||!b.block.name)throw new Error('Messages 工具调用未完整返回');const args=b.json||JSON.stringify(b.block.input??{});JSON.parse(args);return {id:b.block.id!,name:b.block.name!,arguments:args} as Call;});}
}
