import {Snapshot} from './Elements';
// Verified against calculator 16.1.0.115 on a Huawei tablet, 2026-10-05.
// IDs describe application buttons, never UITest keyboard key codes.
const LABELS:string[]=['0','1','2','3','4','5','6','7','8','9','%','.','+','÷','×','−','C','⌫','=','MC','M+','M−','MR'];
export function calculatorLabels(s:Snapshot,app:string,version:number):void{
 if(app!=='com.huawei.hmos.calculator'||version!==160100115)return;
 const ids=s.elements.map(e=>e.id);
 const signature=['id_global_exp','keyCode_12','keyCode_16','keyCode_19','keyCode_20','keyCode_21','keyCode_22'];
 for(let i=0;i<=9;i++)signature.push('keyCode_'+i);
 if(!signature.every(id=>ids.includes(id)))return;
 s.elements.forEach(e=>{const match=/^keyCode_(\d+)$/.exec(e.id);const label=match?LABELS[Number(match[1])]:undefined;if(!e.password&&!e.text&&!e.description.trim()&&label){e.text=label;e.labelSource='calculator-16.1.0.115';}});
}


