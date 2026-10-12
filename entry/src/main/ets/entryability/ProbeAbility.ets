import {Activity} from '../agent/Activity';
import { UIAbility, Want, AbilityConstant } from '@kit.AbilityKit';
import { FloatWindow } from '../pages/FloatWindow';
import { NotifyBridge } from '../agent/FloatPolicy';
import { APPROVAL_PARAM, APPROVAL_SERIAL } from '../pages/Notifier';
import { window } from '@kit.ArkUI';
export default class ProbeAbility extends UIAbility {
 onForeground():void{Activity.set(true);}
 onBackground():void{Activity.set(false);}
 // 0.8.1：通知上的“同意 / 拒绝”按钮带参数回到这里，只认当前这次确认的序号。
 onNewWant(want: Want, launchParam: AbilityConstant.LaunchParam): void {
  const action = want.parameters?.[APPROVAL_PARAM];
  const serial = want.parameters?.[APPROVAL_SERIAL];
  if ((action === 'yes' || action === 'no') && typeof serial === 'number') NotifyBridge.dispatch(action as string, serial as number);
 }
 // 沉浸布局：内容铺满整个窗口，系统栏区域由页面按实测高度留出内边距。
 publishInsets(main: window.Window): void {
  try {
   const ui = main.getUIContext();
   const top = main.getWindowAvoidArea(window.AvoidAreaType.TYPE_SYSTEM).topRect.height;
   const bottom = main.getWindowAvoidArea(window.AvoidAreaType.TYPE_NAVIGATION_INDICATOR).bottomRect.height;
   AppStorage.setOrCreate('topInset', ui.px2vp(top));
   AppStorage.setOrCreate('bottomInset', ui.px2vp(bottom));
  } catch (e) {
   AppStorage.setOrCreate('topInset', 0);
   AppStorage.setOrCreate('bottomInset', 0);
  }
 }
 onWindowStageCreate(stage: window.WindowStage): void {
  stage.loadContent('pages/Index', () => {
   const main = stage.getMainWindowSync();
   main.setWindowBackgroundColor('#FFFFFF');
   FloatWindow.attach(main, (px: number) => main.getUIContext().px2vp(px));
   main.setWindowSystemBarProperties({statusBarColor: '#00000000', navigationBarColor: '#00000000', statusBarContentColor: '#1D2129', navigationBarContentColor: '#1D2129'});
   main.setWindowLayoutFullScreen(true).then(() => {
    this.publishInsets(main);
    main.on('avoidAreaChange', () => { this.publishInsets(main); });
   }).catch(() => { this.publishInsets(main); });
  });
 }
}
