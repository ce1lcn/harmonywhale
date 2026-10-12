// UIAbility lifecycle, shared with the single live task executor.
export class Activity {
 static foreground:boolean=false;
 static changed:((foreground:boolean)=>void)|null=null;
 static set(foreground:boolean):void{Activity.foreground=foreground;Activity.changed?.(foreground);}
}
