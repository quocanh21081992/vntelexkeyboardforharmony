// entry/src/main/ets/InputMethodExtensionAbility/pages/Index.ets
import keyboardController from '../model/KeyboardControllerSingleton';
import { KEYBOARD_ROWS_MAIN, KEYBOARD_ROWS_CAPS, KEYBOARD_ROWS_123, KeyData, KeyKind } from './KeyboardKeyData';

class KbStyle {
  bg: string = '#242424';

  padding: number = 2;
  safeBottom: number = 12;

  keyH: number = 44;
  gapX: number = 5;
  gapY: number = 8;
  radius: number = 6;

  keyBg: string = '#2C2C2E';
  keyBgPressed: string = '#3A3A3C';

  keyBgFn: string = '#2A2A2C';
  keyBgFnPressed: string = '#3A3A3C';

  textSize: number = 18;
  textColor: string = '#FFFFFF';

  // space hint
  spaceHint: string = '#FFFFFF';
  spaceHintAlpha: number = 0.18;

  // popup preview
  popupW: number = 36;
  popupH: number = 44;
  popupGap: number = 6;
  popupRadius: number = 10;
  popupBg: string = '#3A3A3C';
  popupText: string = '#FFFFFF';
  popupFont: number = 22;
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
  private s: KbStyle = new KbStyle();

  @State private previewText: string = '';
  // ✅ Shift behavior:
  // - shiftOnce: tap Shift once => uppercase for next letter only
  // - capsOn: double-tap Shift => CapsLock (persist)
  @State private capsOn: boolean = false;
  @State private shiftOnce: boolean = false;
  // ✅ Auto-cap: viết hoa chữ cái đầu tiên của câu / sau dấu kết câu
  @State private autoCapNext: boolean = true;

  // pressed
  @State private pressedKeyId: string = '';

  // popup
  @State private popupVisible: boolean = false;
  @State private popupLabel: string = '';
  @State private popupX: number = 0;
  @State private popupY: number = 0;

  // ✅ layout mode
  @State private isLayout123: boolean = false;

  // double-tap Shift detection
  private lastShiftTapMs: number = 0;
  private SHIFT_DOUBLE_TAP_MS: number = 320;

  private sessionStartCb?: () => void;

  // global root pos for popup coordinate conversion
  private rootGX: number = 0;
  private rootGY: number = 0;

  // cache key areas for popup positioning
  private keyAreas: Map<string, KeyArea> = new Map();

  aboutToAppear() {
    if (!this.sessionStartCb) {
      this.sessionStartCb = () => {
        this.resetUiState();
      };
      keyboardController.addSessionStartListener(this.sessionStartCb);
    }

    // ✅ lần đầu render cũng reset luôn
    this.resetUiState();
  }

  aboutToDisappear() {
    if (this.sessionStartCb) {
      keyboardController.removeSessionStartListener(this.sessionStartCb);
      this.sessionStartCb = undefined;
    }
  }

  private resetUiState(): void {
    // ✅ luôn mở bàn phím ở layout ABC
    this.isLayout123 = false;

    // ✅ reset Shift/Caps
    this.capsOn = false;
    this.shiftOnce = false;
    this.autoCapNext = true;
    // ✅ đầu câu: bật shiftOnce để hiện layout chữ HOA
    this.shiftOnce = true;
    this.lastShiftTapMs = 0;

    // ✅ reset UI transient states
    this.pressedKeyId = '';
    this.hidePopup();

    // sync preview from controller (sau inputStart controller đã reset composing)
    this.previewText = keyboardController.getPreviewText();
  }


  private syncPreview(): void {
    this.previewText = keyboardController.getPreviewText();
  }



  private isLetterChar(ch: string): boolean {
    // ArkTS: không dùng \p{L}, dùng so sánh upper/lower để nhận diện ký tự chữ (kể cả 'đ')
    return ch.length === 1 && (ch.toLowerCase() !== ch.toUpperCase());
  }

  private isFn(k: KeyData): boolean {
    // Spacer không phải phím chức năng
    return k.kind !== KeyKind.Char && k.kind !== KeyKind.Space && k.kind !== KeyKind.Spacer;
  }

  private bgColorOf(k: KeyData): string {
    const pressed: boolean = this.pressedKeyId === k.id;
    if (this.isFn(k)) return pressed ? this.s.keyBgFnPressed : this.s.keyBgFn;
    return pressed ? this.s.keyBgPressed : this.s.keyBg;
  }

  private canShowPopup(k: KeyData): boolean {
    // chỉ popup cho chữ / số / ký tự đặc biệt
    return k.kind === KeyKind.Char;
  }

  private labelOf(k: KeyData): string {
    if (k.kind === KeyKind.Spacer) return '';
    if (k.kind === KeyKind.Char) return k.label;
    if (k.kind === KeyKind.Shift) {
      // user chủ động bấm Shift => tắt auto-cap cho chữ cái kế tiếp (giống bàn phím phổ biến)
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

    // ✅ chuyển layout
    if (k.kind === KeyKind.Num123) {
      this.isLayout123 = true;
      this.capsOn = false;
      this.shiftOnce = false;
      this.lastShiftTapMs = 0;
      this.hidePopup();
      this.pressedKeyId = '';
      return;
    }
    if (k.kind === KeyKind.Abc) {
      this.isLayout123 = false;
      this.capsOn = false;
      // nếu đang ở đầu câu (autoCapNext), bật shiftOnce để hiện layout chữ HOA
      this.shiftOnce = this.autoCapNext;
      this.lastShiftTapMs = 0;
      this.hidePopup();
      this.pressedKeyId = '';
      return;
    }

    if (k.kind === KeyKind.Shift) {
      // ✅ Shift 1 lần => viết hoa 1 chữ (shiftOnce)
      // ✅ Double-tap Shift => CapsLock (capsOn)
      if (!this.isLayout123) {
        const now: number = Date.now();
        const delta: number = now - this.lastShiftTapMs;

        if (delta <= this.SHIFT_DOUBLE_TAP_MS) {
          // double-tap => toggle CapsLock
          this.capsOn = !this.capsOn;
          this.shiftOnce = false;
          this.lastShiftTapMs = 0;
        } else {
          // single tap
          if (this.capsOn) {
            // nếu đang CapsLock, tap 1 cái để tắt
            this.capsOn = false;
            this.shiftOnce = false;
          } else {
            // bật/tắt shiftOnce
            this.shiftOnce = !this.shiftOnce;
          }
          this.lastShiftTapMs = now;
        }
      }
      this.hidePopup();
      this.pressedKeyId = '';
      return;
    }

    if (k.kind === KeyKind.Space) {
      keyboardController.space();
      this.previewText = '';
      setTimeout(() => this.syncPreview(), 0);
      return;
    }

    if (k.kind === KeyKind.Enter) {
      keyboardController.enter();
      // ✅ sau xuống dòng: bắt đầu câu mới
      this.autoCapNext = true;
      if (!this.isLayout123 && !this.capsOn) {
        this.shiftOnce = true;
      }
      this.previewText = '';
      setTimeout(() => this.syncPreview(), 0);
      return;
    }

    let out: string = k.value;

    // ✅ Auto-cap / ShiftOnce / CapsLock: áp dụng trực tiếp lên ký tự gửi xuống TelexEngine
    if (!this.isLayout123) {
      const needUpper: boolean = (this.capsOn || this.shiftOnce || this.autoCapNext);
      if (needUpper && this.isLetterChar(out)) {
        out = out.toUpperCase();
      }
    }

    keyboardController.commitText(out);

    // ✅ Dấu kết câu => chữ cái tiếp theo sẽ tự viết hoa
    if (!this.isLayout123 && (k.value === '.' || k.value === '!' || k.value === '?')) {
      this.autoCapNext = true;
      if (!this.capsOn) {
        this.shiftOnce = true; // hiển thị layout chữ HOA cho ký tự tiếp theo
      }
    }

    // ✅ Tắt shiftOnce sau khi gõ 1 chữ cái; đồng thời tắt autoCapNext sau chữ cái đầu tiên của câu
    if (!this.isLayout123 && this.isLetterChar(k.value)) {
      if (this.autoCapNext) {
        this.autoCapNext = false;
      }
      if (this.shiftOnce && !this.capsOn) {
        this.shiftOnce = false;
      }
    }

    this.syncPreview();
  }

  private lenToNumber(v: Length | undefined): number {
    if (v === undefined) return 0;
    if (typeof v === 'number') return v;

    const s: string = v.toString();
    const m = /(-?\d+(\.\d+)?)/.exec(s);
    return m ? Number(m[1]) : 0;
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

  private hidePopup(): void {
    this.popupVisible = false;
  }

  private handleTouch(k: KeyData, e: TouchEvent): void {
    if (k.kind === KeyKind.Spacer) return;

    if (e.type === TouchType.Down) {
      this.pressedKeyId = k.id;

      this.showPopupForKey(k);

      // commit ngay ở DOWN (trừ Backspace)
      if (k.kind !== KeyKind.Backspace) {
        this.onKey(k);
      } else {
        keyboardController.startBackspaceRepeat();
      }
    } else if (e.type === TouchType.Up || e.type === TouchType.Cancel) {
      if (k.kind === KeyKind.Backspace) {
        keyboardController.stopBackspaceRepeat();
        this.syncPreview();
      }
      this.pressedKeyId = '';
      this.hidePopup();
    }
  }

  @Builder
  private PopupBubble() {
    Column() {
      Text(this.popupLabel)
        .fontSize(this.s.popupFont)
        .fontColor(this.s.popupText)
        .fontWeight(FontWeight.Medium);
    }
    .width(this.s.popupW)
    .height(this.s.popupH)
    .borderRadius(this.s.popupRadius)
    .backgroundColor(this.s.popupBg)
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .position({ x: this.popupX, y: this.popupY })
    .enabled(false);
  }

  @Builder
  private KeyView(k: KeyData) {
    if (k.kind === KeyKind.Spacer) {
      Blank()
        .height(this.s.keyH)
        .margin({ left: this.s.gapX / 2, right: this.s.gapX / 2 })
        .layoutWeight(k.weight);
    } else {
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
      .height(this.s.keyH)
      .margin({ left: this.s.gapX / 2, right: this.s.gapX / 2 })
      .borderRadius(this.s.radius)
      .backgroundColor(this.bgColorOf(k))
      .layoutWeight(k.weight)
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
    return (this.capsOn || this.shiftOnce) ? KEYBOARD_ROWS_CAPS : KEYBOARD_ROWS_MAIN;
  }

  // ✅ ArkUI ForEach diffing: MAIN và CAPS dùng cùng id (q,w,e,...)
  // Nếu key không thay đổi theo mode, UI có thể tái sử dụng node cũ và không cập nhật label.
  private keyModePrefix(): string {
    if (this.isLayout123) return '123';
    return (this.capsOn || this.shiftOnce) ? 'caps' : 'main';
  }

  @Builder
  private PreviewBar() {
    Row() {
      if (this.previewText.length > 0) {
        Text(this.previewText)
          .fontSize(15)
          .fontColor('#FFFFFF')
          .padding({ left: 12, right: 12, top: 6, bottom: 6 })
          .borderRadius(10)
          .backgroundColor('#1F1F1F')
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .offset({ x: 0, y: 0 }); // ✅ nắn lên cho khớp mốc popup "r"
      } else {
        Blank();
      }
    }
    .width('100%')
    .height(this.s.keyH) // ✅ đúng 1 row phím
    .padding({ left: this.s.padding, right: this.s.padding }) // ✅ không top/bottom
    .alignItems(VerticalAlign.Center)
    .justifyContent(FlexAlign.Center);
  }


  @Builder
  private KeyboardBody() {
    Column() {
      if (this.isLayout123) {
        ForEach(KEYBOARD_ROWS_123, (row: Array<KeyData>, ri: number) => {
          Row() {
            ForEach(row, (k: KeyData) => {
              this.KeyView(k);
            }, (k: KeyData) => k.id);
          }
          .width('100%')
          .height(this.s.keyH)
          .margin({ top: ri === 0 ? 0 : this.s.gapY });
        }, (_row: Array<KeyData>, i: number) => 's' + String(i));
      } else {
        ForEach(this.getAbcRows(), (row: Array<KeyData>, ri: number) => {
          Row() {
            ForEach(row, (k: KeyData) => {
              this.KeyView(k);
            }, (k: KeyData) => this.keyModePrefix() + '_' + k.id);
          }
          .width('100%')
          .height(this.s.keyH)
          .margin({ top: ri === 0 ? 0 : this.s.gapY });
        }, (_row: Array<KeyData>, i: number) => this.keyModePrefix() + '_m' + String(i));
      }
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
    })
    .width('100%')
    .height('100%');
  }
}
