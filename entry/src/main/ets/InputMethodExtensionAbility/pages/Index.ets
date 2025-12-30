// entry/src/main/ets/InputMethodExtensionAbility/pages/Index.ets
import keyboardController from '../model/KeyboardControllerSingleton';
import {
  KEYBOARD_ROWS_MAIN,
  KEYBOARD_ROWS_MAIN_NUM,
  KEYBOARD_ROWS_CAPS,
  KEYBOARD_ROWS_CAPS_NUM,
  KEYBOARD_ROWS_123,
  KEYBOARD_ROWS_123_MORE,
  KeyData,
  KeyKind
} from './KeyboardKeyData';

import { BusinessError, commonEventManager } from '@kit.BasicServicesKit';
import vibrator from '@ohos.vibrator';
import {
  readKeyboardHeightVp,
  DEFAULT_KEYBOARD_HEIGHT_VP,
  clampKeyboardHeightVp,
  readNumberRowEnabled,
  writeNumberRowEnabled,
  DEFAULT_NUMBER_ROW_ENABLED,
  readHapticEnabled,
  writeHapticEnabled,
  readHapticIntensity,
  writeHapticIntensity,
  DEFAULT_HAPTIC_ENABLED,
  DEFAULT_HAPTIC_INTENSITY
} from '../model/SettingsStore';

interface RebuildPayload {
  heightVp?: number;
  inputMethod?: string;
  numberRowEnabled?: boolean;
  hapticEnabled?: boolean;
  hapticIntensity?: number;
}

// ---- Haptic helper types (avoid any/unknown for arkts-no-any-unknown) ----
interface RawFdLike {
  fd: number;
  offset: number;
  length: number;
}

interface ResourceManagerLike {
  getRawFdSync(name: string): RawFdLike;
  // Some HarmonyOS SDKs expose closeRawFdSync; keep optional to satisfy ArkTSCheck
  closeRawFdSync?(rawFd: RawFdLike): void;
}

interface HostContextLike {
  resourceManager?: ResourceManagerLike;
}


const EVENT_REBUILD_KEYBOARD: string = 'com.quoca.vntelexkeyboard.REBUILD';

class KbStyle {
  bg: ResourceColor = $r('app.color.kb_bg');

  padding: number = 2;
  safeBottom: number = 12;

  keyH: number = 44;
  gapX: number = 5;
  gapY: number = 8;
  radius: number = 6;

  keyBg: ResourceColor = $r('app.color.kb_key_bg');
  keyBgPressed: ResourceColor = $r('app.color.kb_key_bg_pressed');

  keyBgFn: ResourceColor = $r('app.color.kb_key_fn_bg');
  keyBgFnPressed: ResourceColor = $r('app.color.kb_key_fn_bg_pressed');

  textSize: number = 18;
  textColor: ResourceColor = $r('app.color.kb_text_primary');

  // space hint
  spaceHint: ResourceColor = $r('app.color.kb_space_hint');
  spaceHintAlpha: number = 0.18;

  // popup preview
  popupW: number = 30;
  popupH: number = 34;
  popupGap: number = 6;
  popupRadius: number = 10;
  popupBg: ResourceColor = $r('app.color.kb_popup_bg');
  popupText: ResourceColor = $r('app.color.kb_popup_text');
  popupFont: number = 18;

  // preview bubble
  previewBubbleBg: ResourceColor = $r('app.color.kb_preview_bubble_bg');
  previewText: ResourceColor = $r('app.color.kb_preview_text');
  previewFont: number = 15;

  bubbleBorder: ResourceColor = $r('app.color.kb_bubble_border');
}

class KeyArea {
  gx: number = 0;
  gy: number = 0;
  w: number = 0;
  h: number = 0;
}

@Entry
@Component
struct Index {
  @State private s: KbStyle = new KbStyle();

  @State private previewText: string = '';
  @State private capsOn: boolean = false;
  @State private shiftOnce: boolean = false;
  @State private autoCapNext: boolean = true;
  @State private lastWasSentencePunc: boolean = false;

  @State private pressedKeyId: string = '';

  // Haptic (vibration on key press)
  private hapticEnabled: boolean = DEFAULT_HAPTIC_ENABLED;
  private hapticIntensity: number = DEFAULT_HAPTIC_INTENSITY;
  private hapticBucketValue: number = 60;

  @State private popupVisible: boolean = false;
  @State private popupLabel: string = '';
  @State private popupX: number = 0;
  @State private popupY: number = 0;

  @State private isLayout123: boolean = false;
  @State private isLayoutMore: boolean = false;

  // ✅ Setting: show number row on ABC layout
  @State private numberRowEnabled: boolean = DEFAULT_NUMBER_ROW_ENABLED;

  // ✅ Foldable / cover screen correction
  @State private panelScale: number = 1.0;
  private wantedTotalVp: number = 0;

  // ✅ Keep the last configured content height (PreviewBar + KeyboardBody) in vp.
  // Used to compute dynamic row spacing for layouts with fewer rows (e.g. 123).

  private lastShiftTapMs: number = 0;
  private SHIFT_DOUBLE_TAP_MS: number = 320;

  private sessionStartCb?: () => void;

  private ceSubscriber?: commonEventManager.CommonEventSubscriber;

  private rootGX: number = 0;
  private rootGY: number = 0;

  private keyAreas: Map<string, KeyArea> = new Map();

  aboutToAppear() {
    this.loadHeightSetting();
    this.loadNumberRowSetting();
    this.loadHapticSetting();
    this.setupRebuildSubscriber();

    if (!this.sessionStartCb) {
      this.sessionStartCb = () => {
        this.resetUiState();
      };
      keyboardController.addSessionStartListener(this.sessionStartCb);
    }

    this.resetUiState();
  }

  private loadNumberRowSetting(): void {
    try {
      const ctx: object = this.getUIContext().getHostContext() as object;
      readNumberRowEnabled(ctx).then((on: boolean) => {
        this.numberRowEnabled = !!on;
      }).catch(() => {
        this.numberRowEnabled = DEFAULT_NUMBER_ROW_ENABLED;
      });
    } catch {
      this.numberRowEnabled = DEFAULT_NUMBER_ROW_ENABLED;
    }
  }

  aboutToDisappear() {
    this.teardownRebuildSubscriber();

    if (this.sessionStartCb) {
      keyboardController.removeSessionStartListener(this.sessionStartCb);
      this.sessionStartCb = undefined;
    }
  }
  private loadHapticSetting(): void {
    try {
      const ctx: object = this.getUIContext().getHostContext() as object;
      Promise.all([
        readHapticEnabled(ctx).catch(() => DEFAULT_HAPTIC_ENABLED),
        readHapticIntensity(ctx).catch(() => DEFAULT_HAPTIC_INTENSITY)
      ]).then((vals: Array<boolean | number>) => {
        const en: boolean = vals[0] as boolean;
        const it: number = vals[1] as number;
        this.applyHapticSetting(!!en, Number.isFinite(it) ? (it as number) : DEFAULT_HAPTIC_INTENSITY, false);
      }).catch(() => {
        this.applyHapticSetting(DEFAULT_HAPTIC_ENABLED, DEFAULT_HAPTIC_INTENSITY, false);
      });
    } catch {
      this.applyHapticSetting(DEFAULT_HAPTIC_ENABLED, DEFAULT_HAPTIC_INTENSITY, false);
    }
  }

  private applyHapticSetting(enabled: boolean, intensity: number, persist: boolean): void {
    this.hapticEnabled = !!enabled;
    this.hapticIntensity = Math.round(intensity);
    if (!Number.isFinite(this.hapticIntensity)) this.hapticIntensity = DEFAULT_HAPTIC_INTENSITY;
    if (this.hapticIntensity < 0) this.hapticIntensity = 0;
    if (this.hapticIntensity > 100) this.hapticIntensity = 100;

    this.hapticBucketValue = this.getHapticBucket(this.hapticIntensity);

    if (persist) {
      try {
        const ctx: object = this.getUIContext().getHostContext() as object;
        writeHapticEnabled(ctx, this.hapticEnabled).then(() => { /* ignore */ }).catch(() => { /* ignore */ });
        writeHapticIntensity(ctx, this.hapticIntensity).then(() => { /* ignore */ }).catch(() => { /* ignore */ });
      } catch {
        // ignore
      }
    }
  }

  private getHapticBucket(intensity: number): number {
    // Map 0..100 → 0 or {10,20,...,100} for selecting rawfile haptic configs.
    if (!this.hapticEnabled) return 0;
    if (intensity <= 0) return 0;
    let b: number = Math.round(intensity / 10) * 10;
    if (b < 10) b = 10;
    if (b > 100) b = 100;
    return b;
  }

  private tryHaptic(): void {
    if (!this.hapticEnabled) return;
    if (this.hapticBucketValue <= 0) return;

    const fileName: string = `haptic_key_${this.hapticBucketValue}.json`;

    try {
      const ctx = this.getUIContext().getHostContext();
      if (!ctx) return;

      const rm = ctx.resourceManager;
      if (!rm) return;

      const rawFd = rm.getRawFdSync(fileName);

      // Try custom haptic file first.
      vibrator.startVibration(
        { type: 'file', hapticFd: { fd: rawFd.fd, offset: rawFd.offset, length: rawFd.length } },
        { id: 0, usage: 'unknown' }
      ).catch(() => {
        // Fallback: time vibration (some devices/versions may reject custom JSON).
        const duration: number = Math.max(5, Math.min(25, Math.round(5 + (this.hapticBucketValue * 0.2))));
        vibrator.startVibration({ type: 'time', duration }, { id: 0, usage: 'unknown' }).catch(() => {});
      });

      // SDK của bạn đang dùng closeRawFdSync(string)
      try {
        rm.closeRawFdSync(fileName);
      } catch {
        // ignore
      }
    } catch {
      // ignore
    }
  }

  private setupRebuildSubscriber(): void {
    if (this.ceSubscriber) return;

    try {
      const info: commonEventManager.CommonEventSubscribeInfo = { events: [EVENT_REBUILD_KEYBOARD] };

      commonEventManager.createSubscriber(info).then((subscriber: commonEventManager.CommonEventSubscriber) => {
        this.ceSubscriber = subscriber;

        commonEventManager.subscribe(subscriber, (err: BusinessError, data: commonEventManager.CommonEventData) => {
          if (err) return;

          const raw: string = String(data.data ?? '');
          let nextHeightVp: number | undefined = undefined;
          let nextInputMethod: string | undefined = undefined;
          let nextNumberRow: boolean | undefined = undefined;

          let nextHapticEnabled: boolean | undefined = undefined;
          let nextHapticIntensity: number | undefined = undefined;
          // Newer payload: JSON { heightVp, inputMethod, numberRowEnabled }
          const t: string = raw.trim();
          if (t.startsWith('{') && t.endsWith('}')) {
            try {
              const obj = JSON.parse(t) as RebuildPayload;
              if (typeof obj.heightVp === 'number' && Number.isFinite(obj.heightVp)) {
                nextHeightVp = obj.heightVp;
              }
              if (typeof obj.inputMethod === 'string') {
                const m: string = obj.inputMethod.toLowerCase();
                if (m === 'vni' || m === 'telex') nextInputMethod = m;
              }
              if (typeof obj.numberRowEnabled === 'boolean') {
                nextNumberRow = obj.numberRowEnabled;
              }
              if (typeof obj.hapticEnabled === 'boolean') {
                nextHapticEnabled = obj.hapticEnabled;
              }
              if (typeof obj.hapticIntensity === 'number' && Number.isFinite(obj.hapticIntensity)) {
                nextHapticIntensity = obj.hapticIntensity;
              }
            } catch {
              // ignore
            }
          }

          // Backward payload: plain number
          if (nextHeightVp === undefined) {
            const n: number = Number(raw);
            if (Number.isFinite(n)) nextHeightVp = n;
          }

          const hVp: number = clampKeyboardHeightVp(nextHeightVp !== undefined ? nextHeightVp : DEFAULT_KEYBOARD_HEIGHT_VP);


          // remember wanted total for foldable correction
          this.wantedTotalVp = hVp + this.s.safeBottom;

          // apply settings
          try { keyboardController.applyKeyboardHeightVp(hVp); } catch { /* ignore */ }
          if (nextInputMethod) {
            try { keyboardController.applyInputMethod(nextInputMethod === 'vni' ? 'vni' : 'telex'); } catch { /* ignore */ }
          }

          if (nextNumberRow !== undefined) {
            this.numberRowEnabled = !!nextNumberRow;
            // Persist in IME process so next session uses it.
            try {
              const ctx: object = this.getUIContext().getHostContext() as object;
              writeNumberRowEnabled(ctx, this.numberRowEnabled).then(() => { /* ignore */ }).catch(() => { /* ignore */ });
            } catch {
              // ignore
            }
          }

          if (nextHapticEnabled !== undefined || nextHapticIntensity !== undefined) {
            const en: boolean = (nextHapticEnabled !== undefined) ? nextHapticEnabled : this.hapticEnabled;
            const it: number = (nextHapticIntensity !== undefined) ? nextHapticIntensity : this.hapticIntensity;
            this.applyHapticSetting(!!en, it, false);
          }

          // rebuild UI scale
          this.applyScaleFromContentHeightVp(hVp);

          // reset UI state
          this.resetUiState();
        });
      }).catch(() => {
        // ignore
      });
    } catch {
      // ignore
    }
  }

  private teardownRebuildSubscriber(): void {
    const sub: commonEventManager.CommonEventSubscriber | undefined = this.ceSubscriber;
    if (!sub) return;

    try {
      commonEventManager.unsubscribe(sub, (_err: BusinessError) => { /* ignore */ });
    } catch {
      // ignore
    } finally {
      this.ceSubscriber = undefined;
    }
  }

  private loadHeightSetting(): void {
    try {
      const ctx: object = this.getUIContext().getHostContext() as object;
      readKeyboardHeightVp(ctx).then((hVp: number) => {
        const safe: number = clampKeyboardHeightVp(hVp);
        this.wantedTotalVp = safe + this.s.safeBottom;
        this.applyScaleFromContentHeightVp(safe);
      }).catch(() => {
        this.wantedTotalVp = DEFAULT_KEYBOARD_HEIGHT_VP + this.s.safeBottom;
        this.applyScaleFromContentHeightVp(DEFAULT_KEYBOARD_HEIGHT_VP);
      });
    } catch {
      this.wantedTotalVp = DEFAULT_KEYBOARD_HEIGHT_VP + this.s.safeBottom;
      this.applyScaleFromContentHeightVp(DEFAULT_KEYBOARD_HEIGHT_VP);
    }
  }

  private applyScaleFromContentHeightVp(heightVp: number): void {
    // DEFAULT_KEYBOARD_HEIGHT_VP is tuned for ABC without the number row (4 rows).
    // When enabling the 1–0 number row we add one more row, so we shrink scale to
    // avoid clipping the bottom row (space/enter).
    const extraRowBaseVp: number = 44 + 8; // keyH + gapY at scale=1
    const base: number = DEFAULT_KEYBOARD_HEIGHT_VP + (this.numberRowEnabled ? extraRowBaseVp : 0);
    const rawScale: number = base > 0 ? (heightVp / base) : 1;
    const scale0: number = Math.max(0.70, Math.min(1.40, rawScale));

    // ✅ apply correction from actual panel height (foldable/cover)
    const scale: number = Math.max(0.70, Math.min(1.40, scale0 * this.panelScale));

    const clampScaled = (v: number, minV: number, maxV: number): number => {
      const n: number = Math.round(v * scale);
      if (n < minV) return minV;
      if (n > maxV) return maxV;
      return n;
    };

    const next: KbStyle = new KbStyle();
    next.keyH = clampScaled(44, 36, 64);
    next.gapY = clampScaled(8, 6, 16);
    next.gapX = clampScaled(5, 4, 12);
    next.radius = clampScaled(6, 6, 14);
    next.textSize = clampScaled(18, 16, 26);
    next.previewFont = clampScaled(15, 13, 22);

    next.popupW = clampScaled(30, 28, 48);
    next.popupH = clampScaled(34, 30, 54);
    next.popupGap = clampScaled(6, 4, 12);
    next.popupRadius = clampScaled(10, 8, 18);
    next.popupFont = clampScaled(18, 16, 28);

    next.safeBottom = this.s.safeBottom;
    next.padding = this.s.padding;

    this.s = next;
  }

  private resetUiState(): void {
    this.isLayout123 = false;
    this.isLayoutMore = false;

    this.capsOn = false;
    this.shiftOnce = false;
    this.autoCapNext = true;
    this.lastWasSentencePunc = false;

    this.shiftOnce = true;
    this.lastShiftTapMs = 0;

    this.pressedKeyId = '';
    this.hidePopup();

    this.previewText = keyboardController.getPreviewText();
  }

  private syncPreview(): void {
    this.previewText = keyboardController.getPreviewText();
  }

  private isLetterChar(ch: string): boolean {
    return ch.length === 1 && (ch.toLowerCase() !== ch.toUpperCase());
  }

  private isFn(k: KeyData): boolean {
    return k.kind !== KeyKind.Char && k.kind !== KeyKind.Space && k.kind !== KeyKind.Spacer;
  }

  private bgColorOf(k: KeyData): ResourceColor {
    const pressed: boolean = this.pressedKeyId === k.id;
    if (this.isFn(k)) return pressed ? this.s.keyBgFnPressed : this.s.keyBgFn;
    return pressed ? this.s.keyBgPressed : this.s.keyBg;
  }

  private canShowPopup(k: KeyData): boolean {
    return k.kind === KeyKind.Char;
  }

  private labelOf(k: KeyData): string {
    if (k.kind === KeyKind.Spacer) return '';
    if (k.kind === KeyKind.Char) return k.label;

    if (k.kind === KeyKind.Shift) {
      if (this.isLayout123) return k.label;
      this.autoCapNext = false;
      if (this.capsOn) return '⇪';
      if (this.shiftOnce) return '⇧•';
      return '⇧';
    }

    if (k.kind === KeyKind.Backspace) return '⌫';
    if (k.kind === KeyKind.Enter) return '⏎';
    if (k.kind === KeyKind.Num123) return '123';
    if (k.kind === KeyKind.Abc) return 'ABC';
    if (k.kind === KeyKind.Space) return '';

    return k.label;
  }

  private onKey(k: KeyData): void {
    if (k.kind === KeyKind.Spacer) return;

    if (k.kind === KeyKind.Num123) {
      this.isLayout123 = true;
      this.isLayoutMore = false;
      this.capsOn = false;
      this.shiftOnce = false;
      this.lastShiftTapMs = 0;
      this.hidePopup();
      this.pressedKeyId = '';
      return;
    }

    if (k.kind === KeyKind.Abc) {
      this.isLayout123 = false;
      this.isLayoutMore = false;
      this.capsOn = false;
      this.shiftOnce = this.autoCapNext;
      this.lastShiftTapMs = 0;
      this.hidePopup();
      this.pressedKeyId = '';
      return;
    }

    if (k.kind === KeyKind.Shift) {
      if (this.isLayout123) {
        this.isLayoutMore = true;
        this.hidePopup();
        this.pressedKeyId = '';
        return;
      }

      const now: number = Date.now();
      const delta: number = now - this.lastShiftTapMs;

      if (delta <= this.SHIFT_DOUBLE_TAP_MS) {
        this.capsOn = !this.capsOn;
        this.shiftOnce = false;
        this.lastShiftTapMs = 0;
      } else {
        if (this.capsOn) {
          this.capsOn = false;
          this.shiftOnce = false;
        } else {
          this.shiftOnce = !this.shiftOnce;
        }
        this.lastShiftTapMs = now;
      }

      this.hidePopup();
      this.pressedKeyId = '';
      return;
    }

    if (k.kind === KeyKind.Space) {
      keyboardController.space();

      if (this.lastWasSentencePunc) {
        this.autoCapNext = true;
        if (!this.isLayout123 && !this.capsOn) {
          this.shiftOnce = true;
        }
      }
      this.lastWasSentencePunc = false;

      this.previewText = '';
      setTimeout(() => this.syncPreview(), 0);
      return;
    }

    if (k.kind === KeyKind.Enter) {
      keyboardController.enter();
      this.autoCapNext = true;
      if (!this.isLayout123 && !this.capsOn) {
        this.shiftOnce = true;
      }
      this.previewText = '';
      setTimeout(() => this.syncPreview(), 0);
      return;
    }

    let out: string = k.value;

    if (!this.isLayout123) {
      const needUpper: boolean = (this.capsOn || this.shiftOnce || this.autoCapNext);
      if (needUpper && this.isLetterChar(out)) {
        out = out.toUpperCase();
      }
    }

    keyboardController.commitText(out);

    if (out === '.' || out === '!' || out === '?') {
      this.lastWasSentencePunc = true;
      this.autoCapNext = false;
    } else {
      this.lastWasSentencePunc = false;
      this.autoCapNext = false;
    }

    if (this.shiftOnce && !this.capsOn) {
      this.shiftOnce = false;
    }

    this.previewText = keyboardController.getPreviewText();
  }

  private hidePopup(): void {
    this.popupVisible = false;
  }

  private showPopupForKey(k: KeyData): void {
    if (!this.canShowPopup(k)) return;

    const area: KeyArea | undefined = this.keyAreas.get(k.id);
    if (!area) return;

    const localX: number = area.gx - this.rootGX;
    const localY: number = area.gy - this.rootGY;

    const bubbleLeft: number = (localX + area.w / 2) - (this.s.popupW / 2);
    const bubbleTop: number = localY - this.s.popupH - this.s.popupGap;

    this.popupLabel = this.labelOf(k);
    this.popupX = bubbleLeft;
    this.popupY = bubbleTop;
    this.popupVisible = true;
  }

  private lenToNumber(v: Length | undefined): number {
    if (v === undefined) return 0;
    if (typeof v === 'number') return v;

    const s: string = String(v);
    const m = s.match(/-?\d+(\.\d+)?/);
    if (m && m[0]) return Number(m[0]);
    return 0;
  }

  private handleTouch(k: KeyData, e: TouchEvent): void {
    if (k.kind === KeyKind.Spacer) return;

    if (e.type === TouchType.Down) {
      this.pressedKeyId = k.id;
      this.showPopupForKey(k);
      this.tryHaptic();

      if (k.kind !== KeyKind.Backspace) {
        this.onKey(k);
      } else {
        this.lastWasSentencePunc = false;
        keyboardController.startBackspaceRepeat();
      }
    } else if (e.type === TouchType.Up || e.type === TouchType.Cancel) {
      if (k.kind === KeyKind.Backspace) {
        keyboardController.stopBackspaceRepeat();
        this.previewText = keyboardController.getPreviewText();
      }
      this.pressedKeyId = '';
      this.hidePopup();
    }
  }

  @Builder
  private PopupBubble() {
    Stack() {
      Text(this.popupLabel)
        .fontSize(this.s.popupFont)
        .fontColor(this.s.popupText)
        .fontWeight(FontWeight.Medium);
    }
    .width(this.s.popupW)
    .height(this.s.popupH)
    .borderRadius(this.s.popupRadius)
    .backgroundColor(this.s.popupBg)
    .border({ width: 0 })
    .position({ x: this.popupX, y: this.popupY })
    .enabled(false);
  }

  @Builder
  private KeyView(k: KeyData, rowH: number, padTop: number, padBottom: number) {
    if (k.kind === KeyKind.Spacer) {
      // Spacer should also occupy a full "hit cell" so there is no dead zone.
      // We keep visual spacing via padding (not margin) so touches never fall into gaps.
      Stack() {}
      .height(rowH)
      .layoutWeight(k.weight)
      .padding({
        left: this.s.gapX / 2,
        right: this.s.gapX / 2,
        top: padTop,
        bottom: padBottom
      });
    } else {
      // Outer container = hit area (no margin), inner = visual key (with padding gap).
      Stack() {
        Stack() {
          if (k.kind === KeyKind.Space) {
            Row() {
              Blank();
              Stack()
                .height(4)
                .width('55%')
                .borderRadius(999)
                .backgroundColor(this.s.spaceHint)
                .opacity(this.s.spaceHintAlpha);
              Blank();
            }
            .width('100%')
            .height('100%')
            .alignItems(VerticalAlign.Center)
            .justifyContent(FlexAlign.Center);
          } else {
            Text(this.labelOf(k))
              .fontSize(this.s.textSize)
              .fontColor(this.s.textColor)
              .fontWeight(this.isFn(k) ? FontWeight.Medium : FontWeight.Regular);
          }
        }
        .width('100%')
        .height('100%')
        .borderRadius(this.s.radius)
        .backgroundColor(this.bgColorOf(k));
      }
      .height(rowH)
      .layoutWeight(k.weight)
      // Visual gap is created via padding INSIDE the hit area.
      .padding({
        left: this.s.gapX / 2,
        right: this.s.gapX / 2,
        top: padTop,
        bottom: padBottom
      })
      .onAreaChange((_: Area, area: Area) => {
        const a: KeyArea = new KeyArea();
        a.gx = this.lenToNumber(area.globalPosition?.x);
        a.gy = this.lenToNumber(area.globalPosition?.y);
        a.w = this.lenToNumber(area.width);
        a.h = this.lenToNumber(area.height);
        this.keyAreas.set(k.id, a);
      })
      .onTouch((e: TouchEvent) => this.handleTouch(k, e));
    }
  }

  private getAbcRows(): Array<Array<KeyData>> {
    const caps: boolean = (this.capsOn || this.shiftOnce);
    if (this.numberRowEnabled) {
      return caps ? KEYBOARD_ROWS_CAPS_NUM : KEYBOARD_ROWS_MAIN_NUM;
    }
    return caps ? KEYBOARD_ROWS_CAPS : KEYBOARD_ROWS_MAIN;
  }

  private keyModePrefix(): string {
    return (this.capsOn || this.shiftOnce) ? 'caps' : 'main';
  }

  private effectiveGapY(_rowsCount: number): number {
    // Keep row spacing consistent with ABC layout.
    return this.s.gapY;
  }

  private keyboardBodyTargetHeight(): number {
    // Target height of the keyboard body area (excluding PreviewBar),
    // based on the current ABC layout (with/without number row).
    const baseRows: number = this.getAbcRows().length;
    if (baseRows <= 0) return 0;
    return baseRows * this.s.keyH + (baseRows - 1) * this.s.gapY;
  }

  private rowHeightForIndex(ri: number, rowsCount: number): number {
    if (rowsCount <= 0) return this.s.keyH;
    // Keep the bottom row (space/enter row) the same height as ABC.
    if (ri === rowsCount - 1) return this.s.keyH;

    const topCount: number = Math.max(1, rowsCount - 1);
    const target: number = this.keyboardBodyTargetHeight();
    const gapTotal: number = Math.max(0, (rowsCount - 1) * this.s.gapY);
    const remain: number = Math.max(0, target - this.s.keyH - gapTotal);
    const h: number = Math.floor(remain / topCount);

    // Never shrink below the normal key height.
    return Math.max(this.s.keyH, h);
  }



  private rowCellHeight(ri: number, rowsCount: number): number {
    const visualH: number = this.rowHeightForIndex(ri, rowsCount);
    // Add gapY as extra hit height on every row except the last to preserve overall height.
    return visualH + (ri < rowsCount - 1 ? this.s.gapY : 0);
  }

  private rowPadTop(ri: number): number {
    // Split vertical gap across rows so there is no dead zone between them.
    return ri === 0 ? 0 : this.s.gapY / 2;
  }

  private rowPadBottom(ri: number, rowsCount: number): number {
    return ri < rowsCount - 1 ? this.s.gapY / 2 : 0;
  }

  @Builder
  private PreviewBar() {
    Row() {
      if (this.previewText.length > 0) {
        Text(this.previewText)
          .fontSize(this.s.previewFont)
          .fontColor(this.s.previewText)
          .padding({ left: 12, right: 12, top: 6, bottom: 6 })
          .borderRadius(10)
          .backgroundColor(this.s.previewBubbleBg)
          .border({ width: 0 })
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .offset({ x: 0, y: 0 });
      } else {
        Blank();
      }
    }
    .width('100%')
    .height(this.s.keyH)
    .padding({ left: this.s.padding, right: this.s.padding })
    .alignItems(VerticalAlign.Center)
    .justifyContent(FlexAlign.Center);
  }

  private currentRows(): Array<Array<KeyData>> {
    if (this.isLayout123) {
      return this.isLayoutMore ? KEYBOARD_ROWS_123_MORE : KEYBOARD_ROWS_123;
    }
    return this.getAbcRows();
  }

  private currentRowCount(): number {
    return this.currentRows().length;
  }


  @Builder
  private KeyboardBody() {
    Column() {
      ForEach(
        this.currentRows(),
        (row: Array<KeyData>, ri: number) => {
          Row() {
            ForEach(
              row,
              (k: KeyData) => {
                this.KeyView(k,
                  this.rowCellHeight(ri, this.currentRowCount()),
                  this.rowPadTop(ri),
                  this.rowPadBottom(ri, this.currentRowCount())
                );
              },
              (k: KeyData) => {
                // Make keys stable across toggles to avoid row-reuse glitches.
                if (this.isLayout123) return (this.isLayoutMore ? 'm' : 's') + '_' + k.id;
                return this.keyModePrefix() + '_' + (this.numberRowEnabled ? 'nr1_' : 'nr0_') + k.id;
              }
            );
          }
          .width('100%')
          .height(this.rowCellHeight(ri, this.currentRowCount()))
          // IMPORTANT: don't use margin between rows; it creates dead touch zones.
          // Row spacing is now represented by each key's vertical padding (gapY/2).
          ;
        },
        (_row: Array<KeyData>, i: number) => {
          if (this.isLayout123) return (this.isLayoutMore ? 'm' : 's') + '_m' + String(i);
          // Include numberRowEnabled so toggling it won't reuse wrong rows (fix duplicated bottom row).
          return this.keyModePrefix() + '_' + (this.numberRowEnabled ? 'nr1' : 'nr0') + '_m' + String(i);
        }
      );
    }
    .width('100%')
    .padding({ left: this.s.padding, right: this.s.padding });
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      Column() {
        this.PreviewBar();
        this.KeyboardBody();
        Blank().height(this.s.safeBottom);
      }
      .width('100%')
      .height('100%')
      .backgroundColor(this.s.bg);

      if (this.popupVisible) {
        this.PopupBubble();
      }
    }
    .onAreaChange((_: Area, area: Area) => {
      this.rootGX = this.lenToNumber(area.globalPosition?.x);
      this.rootGY = this.lenToNumber(area.globalPosition?.y);

      // ✅ actual panel height correction
      const actualH: number = this.lenToNumber(area.height);
      if (this.wantedTotalVp > 0 && actualH > 0) {
        const corr: number = actualH / this.wantedTotalVp;
        const next: number = Math.max(0.70, Math.min(1.40, corr));

        if (Math.abs(next - this.panelScale) > 0.03) {
          this.panelScale = next;

          const targetContent: number = (this.wantedTotalVp - this.s.safeBottom) > 0
            ? (this.wantedTotalVp - this.s.safeBottom)
            : DEFAULT_KEYBOARD_HEIGHT_VP;

          this.applyScaleFromContentHeightVp(targetContent);
        }
      } else {
        this.panelScale = 1.0;
      }
    })
    .width('100%')
    .height(this.keyboardBodyTargetHeight())
    .height('100%');
  }
}