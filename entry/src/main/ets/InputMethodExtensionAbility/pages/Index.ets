// entry/src/main/ets/InputMethodExtensionAbility/pages/Index.ets
import keyboardController from '../model/KeyboardControllerSingleton';
import { KEYBOARD_ROWS, KeyData, KeyKind } from './KeyboardKeyData';

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

  textColor: string = '#EDEDED';
  textSize: number = 18;

  spaceHint: string = '#B9B100';
  spaceHintAlpha: number = 0.55;

  // Preview bar
  previewBg: string = '#1F1F1F';
  previewTextColor: string = '#EDEDED';
  previewHintColor: string = '#9A9A9A';
  previewH: number = 24;
  previewRadius: number = 6;

  // Popup bubble (key preview)
  popupBg: string = '#3A3A3C';
  popupText: string = '#FFFFFF';
  popupRadius: number = 6;
  popupFont: number = 18;

  popupW: number = 44;
  popupH: number = 44;
  popupGap: number = 6;
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

  @State private shiftOn: boolean = false;
  @State private pressedKeyId: string = '';

  @State private previewText: string = '';
  private previewTimerId: number = 0;

  // ===== popup overlay state =====
  @State private popupVisible: boolean = false;
  @State private popupLabel: string = '';
  @State private popupX: number = 0;
  @State private popupY: number = 0;

  private rootGX: number = 0;
  private rootGY: number = 0;

  private keyAreas: Map<string, KeyArea> = new Map<string, KeyArea>();

  // ✅ FIX: nhận Length | undefined
  private lenToNumber(v?: Length): number {
    if (v === undefined || v === null) return 0;

    if (typeof v === 'number') return v;

    if (typeof v === 'string') {
      const n: number = parseFloat(v);
      return isNaN(n) ? 0 : n;
    }

    // Resource… fallback
    return 0;
  }

  private syncPreview(): void {
    const t: string = keyboardController.getPreviewText();
    if (t !== this.previewText) this.previewText = t;
  }

  aboutToAppear(): void {
    this.previewTimerId = setInterval(() => this.syncPreview(), 80) as number;
    this.syncPreview();
  }

  aboutToDisappear(): void {
    if (this.previewTimerId !== 0) {
      try { clearInterval(this.previewTimerId); } catch { /* ignore */ }
      this.previewTimerId = 0;
    }
  }

  private rowIndent(rowIdx: number): number {
    if (rowIdx === 2) return 14;
    if (rowIdx === 3) return 6;
    return 0;
  }

  private isFn(k: KeyData): boolean {
    return k.kind !== KeyKind.Char;
  }

  private canShowPopup(k: KeyData): boolean {
    // ✅ chỉ popup cho chữ/số/ký tự đặc biệt
    return k.kind === KeyKind.Char;
  }

  private labelOf(k: KeyData): string {
    if (k.kind === KeyKind.Char) return this.shiftOn ? k.label.toUpperCase() : k.label;
    if (k.kind === KeyKind.Shift) return '⇧';
    if (k.kind === KeyKind.Backspace) return '⌫';
    if (k.kind === KeyKind.Enter) return '⏎';
    if (k.kind === KeyKind.Space) return '␠';
    if (k.kind === KeyKind.Num123) return '123';
    return k.label;
  }

  private bgColorOf(k: KeyData): string {
    const pressed: boolean = (this.pressedKeyId === k.id);
    if (this.isFn(k)) return pressed ? this.s.keyBgFnPressed : this.s.keyBgFn;
    return pressed ? this.s.keyBgPressed : this.s.keyBg;
  }

  private onKey(k: KeyData): void {
    if (k.kind === KeyKind.Shift) {
      this.shiftOn = !this.shiftOn;
      return;
    }

    if (k.kind === KeyKind.Num123) {
      // TODO: layout số sau
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
      this.previewText = '';
      setTimeout(() => this.syncPreview(), 0);
      return;
    }

    const out: string = this.shiftOn ? k.value.toUpperCase() : k.value;
    keyboardController.commitText(out);

    this.syncPreview();
    if (this.shiftOn) this.shiftOn = false;
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
    if (e.type === TouchType.Down) {
      this.pressedKeyId = k.id;

      this.showPopupForKey(k);

      if (k.kind === KeyKind.Backspace) {
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
    // ✅ FIX: dùng optional chaining => Length | undefined
    .onAreaChange((_: Area, area: Area) => {
      const a: KeyArea = new KeyArea();
      a.gx = this.lenToNumber(area.globalPosition?.x);
      a.gy = this.lenToNumber(area.globalPosition?.y);
      a.w = this.lenToNumber(area.width);
      a.h = this.lenToNumber(area.height);
      this.keyAreas.set(k.id, a);
    })
    .onTouch((e: TouchEvent) => this.handleTouch(k, e))
    .onClick(() => {
      if (k.kind !== KeyKind.Backspace) this.onKey(k);
    });
  }

  @Builder
  private PreviewBar() {
    Stack() {
      if (this.previewText.length > 0) {
        Text(this.previewText)
          .fontSize(15)
          .fontColor(this.s.previewTextColor)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .padding({ left: 10, right: 10 });
      } else {
        Text('Bảng gõ tạm')
          .fontSize(12)
          .fontColor(this.s.previewHintColor)
          .padding({ left: 10, right: 10 });
      }
    }
    .height(this.s.previewH)
    .width('100%')
    .borderRadius(this.s.previewRadius)
    .backgroundColor(this.s.previewBg)
    .margin({ bottom: this.s.gapY });
  }

  build() {
    Stack() {
      Column() {
        this.PreviewBar();

        ForEach(KEYBOARD_ROWS, (row: Array<KeyData>, rowIdx: number) => {
          Row() {
            ForEach(row, (k: KeyData) => {
              this.KeyView(k);
            }, (k: KeyData) => k.id);
          }
          .width('100%')
          .justifyContent(FlexAlign.SpaceBetween)
          .padding({ left: this.rowIndent(rowIdx), right: this.rowIndent(rowIdx) })
          .margin({ top: rowIdx === 0 ? 0 : this.s.gapY });
        }, (_row: Array<KeyData>, idx: number) => String(idx));
      }
      .width('100%')
      .height('100%')
      .backgroundColor(this.s.bg)
      .padding({
        left: this.s.padding,
        right: this.s.padding,
        top: this.s.padding,
        bottom: this.s.padding + this.s.safeBottom
      });

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
