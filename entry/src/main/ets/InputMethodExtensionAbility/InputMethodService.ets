// entry/src/main/ets/InputMethodExtensionAbility/InputMethodService.ets
import { Want } from '@kit.AbilityKit';
import { InputMethodExtensionAbility } from '@kit.IMEKit';
import keyboardController from './model/KeyboardControllerSingleton';

export default class InputMethodService extends InputMethodExtensionAbility {
  onCreate(want: Want): void {
    // Khởi tạo panel + đăng ký listener inputStart/inputStop trong controller
    keyboardController.onCreate(this.context);
  }

  onDestroy(): void {
    keyboardController.onDestroy();
  }
}
