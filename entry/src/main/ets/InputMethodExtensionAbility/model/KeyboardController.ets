// entry/src/main/ets/InputMethodExtensionAbility/model/KeyboardController.ets
import inputMethodEngine from '@ohos.inputMethodEngine';
import type InputMethodExtensionContext from '@ohos.InputMethodExtensionContext';
import display from '@ohos.display';

const UI_PAGE: string = 'InputMethodExtensionAbility/pages/Index';
const KEYBOARD_HEIGHT: number = 320; // bạn có thể đổi 280/360 tùy máy

export class KeyboardController {
  private panel?: inputMethodEngine.Panel;
  private textInputClient?: inputMethodEngine.TextInputClient;

  private pendingShow: boolean = false;

  onCreate(context: InputMethodExtensionContext): void {
    const ime = inputMethodEngine.getInputMethodAbility();
    if (!ime) return;

    this.initPanel(context, ime);

    ime.on('inputStart',
      (_kbCtrl: inputMethodEngine.KeyboardController, client: inputMethodEngine.TextInputClient) => {
        this.textInputClient = client;

        if (this.panel) {
          this.panel.show();
        } else {
          this.pendingShow = true;
        }
      });

    ime.on('inputStop', () => {
      this.textInputClient = undefined;
      this.pendingShow = false;
      this.panel?.hide();
    });
  }

  onDestroy(): void {
    this.pendingShow = false;
    try { this.panel?.hide(); } catch (_) {}
    this.panel = undefined;
    this.textInputClient = undefined;
  }

  private async initPanel(
    context: InputMethodExtensionContext,
    ime: inputMethodEngine.InputMethodAbility
  ): Promise<void> {
    const panelInfo: inputMethodEngine.PanelInfo = {
      type: inputMethodEngine.PanelType.SOFT_KEYBOARD,
      flag: inputMethodEngine.PanelFlag.FLG_FIXED
    };

    try {
      const panel: inputMethodEngine.Panel = await ime.createPanel(context, panelInfo);

      // 1) resize panel để tránh rect height = 1
      const d: display.Display = display.getDefaultDisplaySync();
      await panel.resize(d.width, KEYBOARD_HEIGHT);

      // 2) load UI
      panel.setUiContent(UI_PAGE, null);

      this.panel = panel;

      // 3) show sau khi init xong
      if (this.pendingShow) {
        this.pendingShow = false;
        panel.show();
      }
    } catch (_) {
      // nếu muốn debug sâu: log error ở đây
    }
  }

  async commitText(text: string): Promise<void> {
    const client = this.textInputClient;
    if (!client) return;
    try { await client.insertText(text); } catch (_) {}
  }

  async backspace(): Promise<void> {
    const client = this.textInputClient;
    if (!client) return;
    try { await client.deleteForward(1); } catch (_) {}
  }

  async enter(): Promise<void> {
    await this.commitText('\n');
  }

  async space(): Promise<void> {
    await this.commitText(' ');
  }
}
