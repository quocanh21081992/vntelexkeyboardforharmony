import inputMethodEngine from '@ohos.inputMethodEngine';
import type InputMethodExtensionContext from '@ohos.InputMethodExtensionContext';
import display from '@ohos.display';

const UI_PAGE: string = 'InputMethodExtensionAbility/pages/Index';

// ---- Height tuning (vp) ----
// Với layout 4 hàng phím (keyH=48, padding=8, gap=6...) thì ~228vp là đủ.
// Safe bottom để giống bàn phím gốc (khu vực home indicator).
const KEYBOARD_CONTENT_HEIGHT_VP: number = 228;
const KEYBOARD_SAFE_BOTTOM_VP: number = 12; // chỉnh 10~16 để khớp máy bạn
const KEYBOARD_TOTAL_HEIGHT_VP: number = KEYBOARD_CONTENT_HEIGHT_VP + KEYBOARD_SAFE_BOTTOM_VP;

// ---- ArkTS: avoid object-literal-as-types / untyped obj-literals ----
class PanelSize {
  widthPx: number = 0;
  heightPx: number = 0;
}

class PanelInfoImpl implements inputMethodEngine.PanelInfo {
  type: inputMethodEngine.PanelType = inputMethodEngine.PanelType.SOFT_KEYBOARD;
  flag: inputMethodEngine.PanelFlag = inputMethodEngine.PanelFlag.FLG_FIXED;
}

function getPanelSizePx(): PanelSize {
  const s: PanelSize = new PanelSize();

  // getDefaultDisplaySync() có thể throw -> bắt buộc try/catch
  try {
    const d: display.Display = display.getDefaultDisplaySync();

    // densityPixels thường chính là VPR (log của bạn: 3.375)
    const vpr: number = d.densityPixels > 0 ? d.densityPixels : 1;

    s.widthPx = d.width;
    s.heightPx = Math.max(1, Math.round(KEYBOARD_TOTAL_HEIGHT_VP * vpr));
    return s;
  } catch {
    // fallback an toàn nếu không lấy được display
    s.widthPx = 1080;
    s.heightPx = 720;
    return s;
  }
}

export class KeyboardController {
  private panel?: inputMethodEngine.Panel;
  private textInputClient?: inputMethodEngine.TextInputClient;
  private pendingShow: boolean = false;

  onCreate(context: InputMethodExtensionContext): void {
    const ime: inputMethodEngine.InputMethodAbility = inputMethodEngine.getInputMethodAbility();
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
    try {
      this.panel?.hide();
    } catch {
      // ignore
    }
    this.panel = undefined;
    this.textInputClient = undefined;
  }

  private async initPanel(
    context: InputMethodExtensionContext,
    ime: inputMethodEngine.InputMethodAbility
  ): Promise<void> {
    const panelInfo: PanelInfoImpl = new PanelInfoImpl();

    try {
      const panel: inputMethodEngine.Panel = await ime.createPanel(context, panelInfo);

      const size: PanelSize = getPanelSizePx();
      await panel.resize(size.widthPx, size.heightPx);

      panel.setUiContent(UI_PAGE, null);

      this.panel = panel;

      if (this.pendingShow) {
        this.pendingShow = false;
        panel.show();
      }
    } catch {
      // nếu muốn debug thì bạn log ở đây, còn không thì bỏ qua
    }
  }

  async commitText(text: string): Promise<void> {
    const client: inputMethodEngine.TextInputClient | undefined = this.textInputClient;
    if (!client) return;

    try {
      await client.insertText(text);
    } catch {
      // ignore
    }
  }

  async backspace(): Promise<void> {
    const client: inputMethodEngine.TextInputClient | undefined = this.textInputClient;
    if (!client) return;

    // Backspace = xóa ký tự trước con trỏ (deleteForward)
    try {
      await client.deleteForward(1);
    } catch {
      // ignore
    }
  }

  async enter(): Promise<void> {
    await this.commitText('\n');
  }

  async space(): Promise<void> {
    await this.commitText(' ');
  }
}
