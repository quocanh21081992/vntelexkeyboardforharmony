// entry/src/main/ets/InputMethodExtensionAbility/pages/Index.ets
import keyboardController from '../model/KeyboardControllerSingleton';
import { KEYBOARD_ROWS, KeyData, KeyKind } from './KeyboardKeyData';

class KbStyle {
  bg: string = '#121212';
  padding: number = 8;

  keyH: number = 48;
  gap: number = 6;
  radius: number = 12;

  keyBg: string = '#2A2A2A';
  keyBgPressed: string = '#3A3A3A';

  keyBgFn: string = '#1F1F1F';
  keyBgFnPressed: string = '#2E2E2E';

  textColor: string = '#EDEDED';
  textSize: number = 18;

  // Spacebar hint bar
  spaceHint: string = '#BDBDBD33';
}

@Entry
@Component
struct Index {
  private s: KbStyle = new KbStyle();

  @State private shiftOn: boolean = false;
  @State private pressedKeyId: string = '';

  private rowIndent(rowIdx: number): number {
    // Indent kiểu Gboard/QWERTY
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
    // fire-and-forget (đỡ vướng async trong UI)
    if (k.kind === KeyKind.Shift) {
      this.shiftOn = !this.shiftOn;
      return;
    }
    if (k.kind === KeyKind.Backspace) {
      keyboardController.backspace();
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

    // one-shot shift
    if (this.shiftOn) this.shiftOn = false;
  }

  private handleTouch(k: KeyData, e: TouchEvent): void {
    if (e.type === TouchType.Down) {
      this.pressedKeyId = k.id;
    } else if (e.type === TouchType.Up) {
      this.pressedKeyId = '';
    } else {
      // một số bản có Cancel, nhưng không phải bản nào cũng expose enum này
      // => không đụng TouchType.Cancel để tránh lỗi compile
    }
  }

  @Builder
  private KeyView(k: KeyData) {
    Stack() {
      if (k.kind === KeyKind.Space) {
        // Spacebar style giống Gboard: 1 thanh mảnh ở giữa
        Row() {
          Blank()
          Stack()
            .height(4)
            .width('55%')
            .borderRadius(999)
            .backgroundColor(this.s.spaceHint);
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
      this.onKey(k);
      this.pressedKeyId = '';
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
    .backgroundColor(this.s.bg)
    .padding(this.s.padding);
  }
}
