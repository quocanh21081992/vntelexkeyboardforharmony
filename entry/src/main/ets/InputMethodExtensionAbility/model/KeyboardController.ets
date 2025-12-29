import inputMethodEngine from '@ohos.inputMethodEngine';
import type InputMethodExtensionContext from '@ohos.InputMethodExtensionContext';
import display from '@ohos.display';

import { TelexEngine, TelexActionKind, TelexResult } from './TelexEngine';
import { VniEngine } from './VniEngine';
import {
  readKeyboardHeightVp,
  writeKeyboardHeightVp,
  readInputMethod,
  writeInputMethod,
  type InputMethodType,
  DEFAULT_KEYBOARD_HEIGHT_VP,
  MIN_KEYBOARD_HEIGHT_VP,
  MAX_KEYBOARD_HEIGHT_VP
} from './SettingsStore';

const UI_PAGE: string = 'InputMethodExtensionAbility/pages/Index';

// ---- Height tuning (vp) ----
// Content height can be customized from the app settings; safe bottom keeps a small gap above gesture area.
const KEYBOARD_SAFE_BOTTOM_VP: number = 12;

class PanelSize {
  widthPx: number = 0;
  heightPx: number = 0;
}

class PanelInfoImpl implements inputMethodEngine.PanelInfo {
  type: inputMethodEngine.PanelType = inputMethodEngine.PanelType.SOFT_KEYBOARD;
  flag: inputMethodEngine.PanelFlag = inputMethodEngine.PanelFlag.FLG_FIXED;
}

function getPanelSizePx(totalHeightVp: number): PanelSize {
  const s: PanelSize = new PanelSize();
  try {
    const d: display.Display = display.getDefaultDisplaySync();
    const vpr: number = d.densityPixels > 0 ? d.densityPixels : 1;
    s.widthPx = d.width;
    s.heightPx = Math.max(1, Math.round(totalHeightVp * vpr));
    return s;
  } catch {
    s.widthPx = 1080;
    s.heightPx = 720;
    return s;
  }
}

async function getKeyboardContentHeightVp(context: InputMethodExtensionContext): Promise<number> {
  try {
    // Read from shared preferences written by the app settings page.
    return await readKeyboardHeightVp(context as never);
  } catch {
    return DEFAULT_KEYBOARD_HEIGHT_VP;
  }
}

export class KeyboardController {
  private panel?: inputMethodEngine.Panel;
  private textInputClient?: inputMethodEngine.InputClient;
  private pendingShow: boolean = false;

  // Save context for later refresh (e.g., when settings change).
  private ctxObj?: object;


  // ===== UI listeners (Index.ets) =====
  private sessionStartListeners: Array<() => void> = [];

  addSessionStartListener(cb: () => void): void {
    for (let i = 0; i < this.sessionStartListeners.length; i++) {
      if (this.sessionStartListeners[i] === cb) return;
    }
    this.sessionStartListeners.push(cb);
  }

  removeSessionStartListener(cb: () => void): void {
    const next: Array<() => void> = [];
    for (let i = 0; i < this.sessionStartListeners.length; i++) {
      const fn = this.sessionStartListeners[i];
      if (fn !== cb) next.push(fn);
    }
    this.sessionStartListeners = next;
  }

  private notifySessionStart(): void {
    for (let i = 0; i < this.sessionStartListeners.length; i++) {
      try {
        this.sessionStartListeners[i]();
      } catch (e) {
        // ignore
      }
    }
  }

  // ===== Buffer mode (for Android VM compatibility) =====
  private readonly bufferMode: boolean = true;

  // ===== IME mode =====
  private inputMethod: InputMethodType = 'telex';

  // ===== Composing/buffer =====
  private composingWord: string = '';
  // IMPORTANT: KHÔNG readonly để có thể "reset" bằng cách tạo instance mới
  private telex: TelexEngine = new TelexEngine(true, false);
  private vni: VniEngine = new VniEngine();

  // ===== Backspace hold-to-repeat =====
  private backspaceHolding: boolean = false;
  private backspaceDelayTimerId: number = 0;
  private backspaceRepeatTimerId: number = 0;

  private readonly backspaceInitialDelayMs: number = 350;
  private readonly backspaceRepeatIntervalMs: number = 55;

  // ✅ FIX WARN: Function may throw exceptions
  private setTimeoutId(handler: () => void, delayMs: number): number {
    try {
      return setTimeout(handler, delayMs) as number;
    } catch {
      return 0;
    }
  }

  // ✅ FIX WARN: Function may throw exceptions
  private setIntervalId(handler: () => void, intervalMs: number): number {
    try {
      return setInterval(handler, intervalMs) as number;
    } catch {
      return 0;
    }
  }

  // ===== UI Preview API =====
  getPreviewText(): string {
    return this.composingWord;
  }

  onCreate(context: InputMethodExtensionContext): void {
    this.ctxObj = context as object;
    const ime: inputMethodEngine.InputMethodAbility = inputMethodEngine.getInputMethodAbility();
    if (!ime) return;

    this.initPanel(context, ime);

    ime.on('inputStart',
      (_kbCtrl: inputMethodEngine.KeyboardController, client: inputMethodEngine.InputClient) => {
        this.textInputClient = client;
        this.resetComposing();

        // Apply latest height setting each time the session starts.
        // (Settings may be changed from the main app process.)
        this.refreshPanelHeightFromSettings();

        // Apply latest input method setting as well.
        this.refreshInputMethodFromSettings();

        this.notifySessionStart();

        if (this.panel) {
          this.panel.show();
        } else {
          this.pendingShow = true;
        }
      });

    ime.on('inputStop', () => {
      this.stopBackspaceRepeat();
      this.resetComposing();
      this.textInputClient = undefined;
      this.pendingShow = false;
      this.panel?.hide();
    });
  }

  onDestroy(): void {
    this.stopBackspaceRepeat();
    this.resetComposing();
    this.pendingShow = false;
    try { this.panel?.hide(); } catch { /* ignore */ }
    this.panel = undefined;
    this.textInputClient = undefined;
  }

  private resetTelex(): void {
    // ✅ thay cho telex.reset()
    this.telex = new TelexEngine(true, false);
  }

  private resetVni(): void {
    // VNI engine is stateless, but recreate to keep behavior consistent.
    this.vni = new VniEngine();
  }

  private resetEngines(): void {
    this.resetTelex();
    this.resetVni();
  }

  private resetComposing(): void {
    this.composingWord = '';
    this.resetEngines();
  }

  // Called by UI rebuild event or when reading settings.
  applyInputMethod(method: InputMethodType): void {
    const next: InputMethodType = (method === 'vni') ? 'vni' : 'telex';
    if (this.inputMethod === next) return;
    this.inputMethod = next;
    // clear composing buffer when switching engine
    this.resetComposing();

    const ctx: object | undefined = this.ctxObj;
    if (ctx) {
      // persist to IME preferences so next session uses it
      try { writeInputMethod(ctx as never, next).then(() => { /* ignore */ }).catch(() => { /* ignore */ }); } catch { /* ignore */ }
    }
  }

  private refreshInputMethodFromSettings(): void {
    const ctx: object | undefined = this.ctxObj;
    if (!ctx) return;
    readInputMethod(ctx as never).then((m: InputMethodType) => {
      this.inputMethod = (m === 'vni') ? 'vni' : 'telex';
    }).catch(() => {
      this.inputMethod = 'telex';
    });
  }

  private async initPanel(
    context: InputMethodExtensionContext,
    ime: inputMethodEngine.InputMethodAbility
  ): Promise<void> {
    const panelInfo: PanelInfoImpl = new PanelInfoImpl();
    try {
      const panel: inputMethodEngine.Panel = await ime.createPanel(context, panelInfo);

      const contentVp: number = await getKeyboardContentHeightVp(context);
      const totalVp: number = contentVp + KEYBOARD_SAFE_BOTTOM_VP;
      const size: PanelSize = getPanelSizePx(totalVp);
      await panel.resize(size.widthPx, size.heightPx);

      panel.setUiContent(UI_PAGE, null);
      this.panel = panel;

      if (this.pendingShow) {
        this.pendingShow = false;
        panel.show();
      }
    } catch {
      // ignore
    }
  }

  // Re-read setting and resize the IME panel.
  // This is called on every input session start and can also be triggered by UI observers.

  // Apply a new keyboard content height (vp), persist in IME process, and resize panel immediately.
  async applyKeyboardHeightVp(heightVp: number): Promise<void> {
    const panel: inputMethodEngine.Panel | undefined = this.panel;
    const ctx: object | undefined = this.ctxObj;
    if (!panel || !ctx) return;

    // Clamp to safe range
    const clamped: number = Math.max(MIN_KEYBOARD_HEIGHT_VP, Math.min(MAX_KEYBOARD_HEIGHT_VP, heightVp));
    try {
      await writeKeyboardHeightVp(ctx as never, clamped);
    } catch {
      // ignore
    }

    const totalVp: number = clamped + KEYBOARD_SAFE_BOTTOM_VP;
    const size: PanelSize = getPanelSizePx(totalVp);
    try {
      await panel.resize(size.widthPx, size.heightPx);
    } catch {
      // ignore
    }
  }

  async refreshPanelHeightFromSettings(): Promise<void> {
    const panel: inputMethodEngine.Panel | undefined = this.panel;
    const ctx: object | undefined = this.ctxObj;
    if (!panel || !ctx) return;

    let contentVp: number = DEFAULT_KEYBOARD_HEIGHT_VP;
    try {
      contentVp = await readKeyboardHeightVp(ctx as never);
    } catch {
      contentVp = DEFAULT_KEYBOARD_HEIGHT_VP;
    }

    const totalVp: number = contentVp + KEYBOARD_SAFE_BOTTOM_VP;
    const size: PanelSize = getPanelSizePx(totalVp);
    try {
      await panel.resize(size.widthPx, size.heightPx);
    } catch {
      // ignore
    }
  }

  private async insertTextSafe(text: string): Promise<void> {
    const client: inputMethodEngine.InputClient | undefined = this.textInputClient;
    if (!client) return;

    try {
      await client.insertText(text);
    } catch {
      // ignore
    }
  }

  private async deleteBeforeCursorOneByOne(count: number): Promise<void> {
    const client: inputMethodEngine.InputClient | undefined = this.textInputClient;
    if (!client) return;
    if (count <= 0) return;

    for (let i: number = 0; i < count; i++) {
      try {
        await client.deleteForward(1);
      } catch {
        break;
      }
    }
  }

  private isAsciiLetter(ch: string): boolean {
    if (ch.length !== 1) return false;
    const c: number = ch.charCodeAt(0);
    return (c >= 65 && c <= 90) || (c >= 97 && c <= 122);
  }

  private isVniAccentDigit(ch: string): boolean {
    if (ch.length !== 1) return false;
    const c: number = ch.charCodeAt(0);
    return c >= 49 && c <= 57; // '1'..'9'
  }

  /**
   * ✅ FIX QUAN TRỌNG CHO ANDROID VM:
   * - Clear buffer NGAY LẬP TỨC (sync)
   * - Chỉ insertText() 1 lần duy nhất: buf + tail
   */
  private async commitBufferAndTailSingleInsert(tail: string): Promise<void> {
    const buf: string = this.composingWord;

    // clear ngay để UI preview trống tức thì
    this.composingWord = '';

    const payload: string = buf + tail;
    if (payload.length === 0) return;

    await this.insertTextSafe(payload);
  }

  /**
   * Enter handling:
   * - flush composingWord
   * - sendKeyFunction(enterKeyType) cho ô search/done/go...
   * - fallback: newline nếu enterKeyType là NONE/UNSPECIFIED hoặc lỗi
   */
  private async performEnterAction(): Promise<void> {
    const client: inputMethodEngine.InputClient | undefined = this.textInputClient;
    if (!client) {
      this.resetComposing();
      return;
    }

    // 1) flush từ telex đang compose (nếu có)
    if (this.composingWord.length > 0) {
      await this.commitBufferAndTailSingleInsert('');
      this.resetEngines();
    } else {
      this.resetEngines();
    }

    // 2) lấy enterKeyType để bấm đúng "Done/Search/Go/Next..."
    try {
      const editorAttribute: inputMethodEngine.EditorAttribute = await client.getEditorAttribute();
      const enterKeyType: number = editorAttribute.enterKeyType as number;

      // NONE/UNSPECIFIED -> xuống dòng
      if (enterKeyType === 0 || enterKeyType === 1) {
        await this.insertTextSafe('\n');
        this.resetComposing();
        return;
      }

      await client.sendKeyFunction(enterKeyType);
      this.resetComposing();
      return;
    } catch {
      // ignore
    }

    // 3) fallback: DONE (6) -> nếu không được thì newline
    try {
      await client.sendKeyFunction(6);
      this.resetComposing();
      return;
    } catch {
      // ignore
    }

    await this.insertTextSafe('\n');
    this.resetComposing();
  }

  /**
   * Buffer mode:
   * - letters: Telex apply only in composingWord (no insert to app)
   * - space/enter: commit composingWord + delimiter in ONE insert
   * - non-letters: commit composingWord + that char in ONE insert
   */
  async commitText(text: string): Promise<void> {
    const client: inputMethodEngine.InputClient | undefined = this.textInputClient;

    // boundary: thêm '.' ',' giống space/enter để khi mất client không kẹt preview
    if (this.bufferMode && (text === ' ' || text === '\n' || text === '.' || text === ',')) {
      if (!client) {
        this.resetComposing();
        return;
      }
      await this.commitBufferAndTailSingleInsert(text);
      return;
    }

    if (!client) return;

    // ---- buffer mode ----
    if (this.bufferMode) {
      if (text.length !== 1) {
        await this.commitBufferAndTailSingleInsert(text);
        return;
      }

      if (this.inputMethod === 'telex') {
        // Not letter => commit buffer + char (ONE insert)
        if (!this.isAsciiLetter(text)) {
          await this.commitBufferAndTailSingleInsert(text);
          return;
        }

        // letter => apply telex to buffer only
        const r: TelexResult = this.telex.apply(this.composingWord, text);
        if (r.kind === TelexActionKind.Replace) {
          this.composingWord = r.newWord; // oo -> ô in buffer
          return;
        }
        this.composingWord = this.composingWord + text;
        return;
      }

      // ---- VNI mode ----
      if (!(this.isAsciiLetter(text) || this.isVniAccentDigit(text))) {
        // punctuation/symbol => commit buffer + char
        await this.commitBufferAndTailSingleInsert(text);
        return;
      }

      const r: TelexResult = this.vni.apply(this.composingWord, text);
      if (r.kind === TelexActionKind.Replace) {
        this.composingWord = r.newWord;
        return;
      }
      // Insert: may differ from input (e.g. digit not applicable)
      this.composingWord = this.composingWord + r.text;
      return;
    }

    // ---- legacy mode ----
    if (text === ' ' || text === '\n') {
      this.resetComposing();
      await this.insertTextSafe(text);
      return;
    }

    if (text.length !== 1) {
      this.resetComposing();
      await this.insertTextSafe(text);
      return;
    }

    const r = this.telex.apply(this.composingWord, text);
    if (r.kind === TelexActionKind.Replace) {
      await this.deleteBeforeCursorOneByOne(this.composingWord.length);
      await this.insertTextSafe(r.newWord);
      this.composingWord = r.newWord;
      return;
    }

    await this.insertTextSafe(text);
    this.composingWord = this.composingWord + text;
  }

  startBackspaceRepeat(): void {
    if (!this.textInputClient) return;
    if (this.backspaceHolding) return;

    this.backspaceHolding = true;
    this.clearBackspaceTimers();

    this.backspace();

    this.backspaceDelayTimerId = this.setTimeoutId(() => {
      if (!this.backspaceHolding) return;

      this.backspaceRepeatTimerId = this.setIntervalId(() => {
        if (!this.backspaceHolding) return;
        this.backspace();
      }, this.backspaceRepeatIntervalMs);

    }, this.backspaceInitialDelayMs);
  }

  stopBackspaceRepeat(): void {
    this.backspaceHolding = false;
    this.clearBackspaceTimers();
  }

  private clearBackspaceTimers(): void {
    if (this.backspaceDelayTimerId !== 0) {
      try { clearTimeout(this.backspaceDelayTimerId); } catch { /* ignore */ }
      this.backspaceDelayTimerId = 0;
    }
    if (this.backspaceRepeatTimerId !== 0) {
      try { clearInterval(this.backspaceRepeatTimerId); } catch { /* ignore */ }
      this.backspaceRepeatTimerId = 0;
    }
  }

  async backspace(): Promise<void> {
    const client: inputMethodEngine.InputClient | undefined = this.textInputClient;
    if (!client) return;

    if (this.bufferMode) {
      if (this.composingWord.length > 0) {
        this.composingWord = this.composingWord.slice(0, this.composingWord.length - 1);
        // reset engine instance để state sạch cho lần gõ tiếp
        this.resetEngines();
        return;
      }
    }

    try {
      await client.deleteForward(1);
    } catch {
      // ignore
    }
  }

  async enter(): Promise<void> {
    await this.performEnterAction();
  }

  async space(): Promise<void> {
    await this.commitText(' ');
  }
}

const keyboardController = new KeyboardController();
export default keyboardController;
