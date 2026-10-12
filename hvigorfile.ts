import { appTasks } from '@ohos/hvigor-ohos-plugin';
const buildSecrets = require('./scripts/build-secrets.cjs');
buildSecrets.generate(__dirname, process.env.HARMONY_SEARCH_SECRETS);

export default {
    system: appTasks,  /* Built-in plugin of Hvigor. It cannot be modified. */
    plugins:[]         /* Custom plugin to extend the functionality of Hvigor. */
}
