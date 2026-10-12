// Pure address checks. URL canonicalization and DNS resolution are handled by Web.
export function publicAddress(raw:string):boolean {
 const ip=raw.toLowerCase().replace(/^\[|\]$/g,'');
 if(ip.includes('%'))return false;
 if(ip.includes(':')){
  if(ip.startsWith('::ffff:'))return publicAddress(ip.substring(7));
  // Only globally routable unicast IPv6; exclude documentation and transition ranges.
  return /^[23][0-9a-f]{3}:/.test(ip)&&!/^2001:(db8|0|10|20):/.test(ip)&&!ip.startsWith('2002:');
 }
 const parts=ip.split('.');if(parts.length!==4||parts.some(p=>!/^\d{1,3}$/.test(p)||Number(p)>255))return false;
 const a=Number(parts[0]),b=Number(parts[1]),c=Number(parts[2]);
 if(a===0||a===10||a===127||a>=224)return false;
 if(a===169&&b===254||a===172&&b>=16&&b<=31||a===192&&b===168)return false;
 if(a===100&&b>=64&&b<=127||a===198&&(b===18||b===19))return false;
 if(a===192&&b===0||a===198&&b===51&&c===100||a===203&&b===0&&c===113)return false;
 return true;
}
export function checkHost(raw:string):void {
 const host=raw.toLowerCase().replace(/\.$/,'').replace(/^\[|\]$/g,'');
 if(!host||host==='localhost'||host.endsWith('.localhost')||host.endsWith('.local'))throw new Error('WEB_PRIVATE：不访问本机或局域网地址');
 if(host.includes(':')||/^[\d.]+$/.test(host)){if(!publicAddress(host))throw new Error('WEB_PRIVATE：不访问非公网地址');}
}
