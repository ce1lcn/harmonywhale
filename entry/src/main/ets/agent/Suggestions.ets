export interface SuggestedReply {text:string;suggestion:string;}
// Only interpret a complete trailing tag outside a fenced code block.
export function suggestedReply(source:string):SuggestedReply {
 const match=/<next>([^<>\n]{1,120})<\/next>\s*$/.exec(source);
 if(!match)return {text:source,suggestion:''};
 const prefix=source.slice(0,match.index),fences=prefix.match(/^\s*(?:```|~~~)/gm)??[];
 if(fences.length%2)return {text:source,suggestion:''};
 return {text:prefix.trimEnd(),suggestion:match[1].trim().slice(0,30)};
}
