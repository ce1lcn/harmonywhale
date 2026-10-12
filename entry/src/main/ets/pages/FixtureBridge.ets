// Only the manually opened isolated acceptance page uses this bridge.
// It submits ordinary goals; no command execution or model bypass is exposed.
export class FixtureBridge {static sample:((phase:string,active:()=>boolean)=>Promise<string>)|null=null;static run:((goal:string)=>void)|null=null;}
