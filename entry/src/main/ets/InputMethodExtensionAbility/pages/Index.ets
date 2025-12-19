// entry/src/main/ets/InputMethodExtensionAbility/pages/Index.ets
import keyboardController from '../model/KeyboardControllerSingleton';
import { KEYBOARD_ROWS, KeyData, KeyKind } from './KeyboardKeyData';

class KbStyle {
  // Màu nền bạn yêu cầu (pick từ ảnh): #242424
  bg: string = '#242424';

  padding: number = 8;
  safeBottom: number = 12; // phải khớp KEYBOARD_SAFE_BOTTOM_VP trong KeyboardController.ets

  keyH: number = 48;
  gap: number = 6;
  radius: number = 12;

  // Key colors (giữ gần giống dark keyboard)
  keyBg: string = '#2C2C2E';
  keyBgPressed: string = '#3A3A3C';

  keyBgFn: string = '#2A2A2C';
  keyBgFnPressed: string = '#3A3A3C';

  textColor: string = '#EDEDED';
  textSize: number = 18;

  // Thanh hint trong spacebar (màu hơi ngả vàng như ảnh)
  spaceHint: string = '#B9B100';
  spaceHintAlpha: number = 0.55;
}

@Entry
@Component
struct Index {
  private s: KbStyle = new KbStyle();

  @State private shiftOn: boolean = false;
  @State private pressedKeyId: string = '';

  private rowIndent(rowIdx: number): number {
    if (rowIdx === 1) return 14;
    if (rowIdx === 2) return 6;
    return 0;
  }

  private isFn(k: KeyData): boolean {
    return k.kind !== KeyKind.Char;
  }

  private labelOf(k: KeyData): string {
    if (k.kind === KeyKind.Char) return this.shiftOn ? k.label.toUpperCase() : k.label;
    if (k.kind === KeyKind.Shift) return '⇧';
    if (k.kind === KeyKind.Backspace) return '⌫';
    if (k.kind === KeyKind.Enter) return '⏎';
    if (k.kind === KeyKind.Space) return '';
    return k.label;
  }

  private bgColorOf(k: KeyData): string {
    const pressed: boolean = (this.pressedKeyId === k.id);
    if (this.isFn(k)) {
      return pressed ? this.s.keyBgFnPressed : this.s.keyBgFn;
    }
    return pressed ? this.s.keyBgPressed : this.s.keyBg;
  }

  private onKey(k: KeyData): void {
    if (k.kind === KeyKind.Shift) {
      this.shiftOn = !this.shiftOn;
      return;
    }
    if (k.kind === KeyKind.Space) {
      keyboardController.space();
      return;
    }
    if (k.kind === KeyKind.Enter) {
      keyboardController.enter();
      return;
    }

    const out: string = this.shiftOn ? k.value.toUpperCase() : k.value;
    keyboardController.commitText(out);

    if (this.shiftOn) this.shiftOn = false;
  }

  private handleTouch(k: KeyData, e: TouchEvent): void {
    if (e.type === TouchType.Down) {
      this.pressedKeyId = k.id;

      // Giữ Backspace để xóa liên tục
      if (k.kind === KeyKind.Backspace) {
        keyboardController.startBackspaceRepeat();
      }
    } else if (e.type === TouchType.Up || e.type === TouchType.Cancel) {
      this.pressedKeyId = '';

      if (k.kind === KeyKind.Backspace) {
        keyboardController.stopBackspaceRepeat();
      }
    }
  }

  @Builder
  private KeyView(k: KeyData) {
    Stack() {
      if (k.kind === KeyKind.Space) {
        // Spacebar: có hint bar ở giữa
        Row() {
          Blank()
          Stack()
            .height(4)
            .width('55%')
            .borderRadius(999)
            .backgroundColor(this.s.spaceHint)
            .opacity(this.s.spaceHintAlpha);
          Blank()
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
    .margin({ left: this.s.gap / 2, right: this.s.gap / 2 })
    .borderRadius(this.s.radius)
    .backgroundColor(this.bgColorOf(k))
    .onTouch((e: TouchEvent) => {
      this.handleTouch(k, e);
    })
    .onClick(() => {
      // Backspace đã xử lý bằng onTouch (Down/Up) để hỗ trợ giữ-xóa-liên-tục,
      // tránh bị xóa 2 lần khi tap.
      if (k.kind !== KeyKind.Backspace) {
        this.onKey(k);
        this.pressedKeyId = '';
      }
    })
    .layoutWeight(k.weight);
  }

  build() {
    Column() {
      ForEach(KEYBOARD_ROWS, (row: Array<KeyData>, rowIdx: number) => {
        Row() {
          ForEach(row, (k: KeyData) => {
            this.KeyView(k);
          }, (k: KeyData) => k.id);
        }
        .width('100%')
        .justifyContent(FlexAlign.SpaceBetween)
        .padding({ left: this.rowIndent(rowIdx), right: this.rowIndent(rowIdx) })
        .margin({ top: rowIdx === 0 ? 2 : this.s.gap });
      }, (_: Array<KeyData>, idx: number) => String(idx));
    }
    .width('100%')
    .height('100%') // quan trọng để nền phủ toàn panel
    .backgroundColor(this.s.bg)
    .padding({
      left: this.s.padding,
      right: this.s.padding,
      top: this.s.padding,
      bottom: this.s.padding + this.s.safeBottom
    });
  }
}
