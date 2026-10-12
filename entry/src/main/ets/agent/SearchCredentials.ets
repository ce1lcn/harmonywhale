import {BOCHA_KEY,SEARCH_SEED} from './BuildSecrets';
import {Store} from './Store';
export async function searchCredential(store:Store):Promise<string>{
 const marker=store.root+'/search-seed.json';let previous='';try{previous=store.read(marker);}catch(e){}
 if(BOCHA_KEY&&previous!==SEARCH_SEED){await store.secret('search-bocha',BOCHA_KEY);store.write(marker,SEARCH_SEED);}
 return await store.secret('search-bocha');
}
