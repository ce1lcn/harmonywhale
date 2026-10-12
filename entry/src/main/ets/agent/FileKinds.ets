export function sniffFile(bytes:Uint8Array,name:string):string {
 if(/\.(apk|hap|app|exe|dll)$/i.test(name))return 'installer';
 if(bytes[0]===0x89&&bytes[1]===0x50&&bytes[2]===0x4e&&bytes[3]===0x47)return 'png';
 if(bytes[0]===0xff&&bytes[1]===0xd8&&bytes[2]===0xff)return 'jpeg';
 if(bytes[0]===0x25&&bytes[1]===0x50&&bytes[2]===0x44&&bytes[3]===0x46&&bytes[4]===0x2d)return 'pdf';
 if(bytes[0]===0x50&&bytes[1]===0x4b&&bytes[2]===3&&bytes[3]===4)return 'zip';
 if(bytes[0]===0x7f&&bytes[1]===0x45&&bytes[2]===0x4c&&bytes[3]===0x46)return 'executable';
 if(bytes[0]===0x4d&&bytes[1]===0x5a)return 'executable';
 if(bytes[0]===0xd0&&bytes[1]===0xcf&&bytes[2]===0x11&&bytes[3]===0xe0)return 'legacy-office';
 if(/\.(apk|hap|app|exe|dll)$/i.test(name))return 'installer';
 if(!bytes.some(v=>v===0||v<9||v>13&&v<32))return 'text';return 'unknown';
}
export function formatAdvice(kind:string):string {if(kind==='pdf')return '可按页读取文本；扫描页需转图片识别；可另存。';if(kind==='zip')return '可列目录或提取指定安全条目；安装包只可保存另存。';if(kind==='png'||kind==='jpeg')return '可查看尺寸、转换 JPEG/PNG 或文字识别。';if(kind==='legacy-office')return '旧版 Office 格式暂不能编辑，保留原件，可另存并用 WPS 打开后转为 OOXML。';if(kind==='installer'||kind==='executable')return '只保存和另存，不自动打开、安装或执行。';return '按文件头识别；不支持的格式保留原件，只能另存。';}
