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

  private shiftOn: boolean = false;

  // pressed
  @State private pressedKeyId: string = '';

  // popup
  @State private popupVisible: boolean = false;
  @State private popupLabel: string = '';
  @State private popupX: number = 0;
  @State private popupY: number = 0;

  // global root pos for popup coordinate conversion
  private rootGX: number = 0;
  private rootGY: number = 0;

  // cache key areas for popup positioning
  private keyAreas: Map<string, KeyArea> = new Map();

  aboutToAppear() {
    this.previewText = keyboardController.getPreviewText();
  }

  private syncPreview(): void {
    this.previewText = keyboardController.getPreviewText();
  }

  private isFn(k: KeyData): boolean {
    return k.kind !== KeyKind.Char && k.kind !== KeyKind.Space;
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
    if (k.kind === KeyKind.Char) return this.shiftOn ? k.label.toUpperCase() : k.label;
    if (k.kind === KeyKind.Shift) return '⇧';
    if (k.kind === KeyKind.Backspace) return '⌫';
    if (k.kind === KeyKind.Enter) return '⏎';
    if (k.kind === KeyKind.Num123) return '123';
    if (k.kind === KeyKind.Space) return '';
    return k.label;
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
    if (e.type === TouchType.Down) {
      this.pressedKeyId = k.id;

      this.showPopupForKey(k);

      // ✅ Commit ngay ở DOWN (trừ Backspace) để tránh ClickRecognizer bị reject
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

  @Builder
  private PreviewBar() {
    Stack() {
      if (this.previewText.length > 0) {
        Text(this.previewText)
          .fontSize(15)
          .fontColor('#FFFFFF')
          .padding({ left: 12, right: 12, top: 8, bottom: 8 })
          .borderRadius(10)
          .backgroundColor('#1F1F1F')
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis });
      } else {
        // ✅ FIX: Blank chỉ được dùng trong Row/Column/Flex
        Row() { Blank().height(32) }.width('100%');
      }
    }
    .width('100%')
    .padding({ left: this.s.padding, right: this.s.padding, top: 6, bottom: 6 });
  }

  @Builder
  private KeyboardBody() {
    Column() {
      ForEach(KEYBOARD_ROWS, (row: Array<KeyData>, ri: number) => {
        Row() {
          ForEach(row, (k: KeyData) => {
            this.KeyView(k);
          }, (k: KeyData) => k.id);
        }
        .width('100%')
        .height(this.s.keyH)
        .margin({ top: ri === 0 ? 0 : this.s.gapY });
      }, (_row: Array<KeyData>, i: number) => String(i));
    }
    .width('100%')
    .padding({ left: this.s.padding, right: this.s.padding });
  }

  build() {
    Stack() {
      Column() {
        this.PreviewBar();
        this.KeyboardBody();
        Blank().height(this.s.safeBottom);
      }
      .width('100%')
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
