// entry/src/main/ets/pages/Settings.ets
import type { common } from '@kit.AbilityKit'
import type { BusinessError } from '@kit.BasicServicesKit'
import { commonEventManager } from '@kit.BasicServicesKit'

import {
  readKeyboardHeightVp,
  writeKeyboardHeightVp,
  bumpKeyboardReloadSeq,
  readInputMethod,
  writeInputMethod,
  type InputMethodType,
  DEFAULT_KEYBOARD_HEIGHT_VP,
  MIN_KEYBOARD_HEIGHT_VP,
  MAX_KEYBOARD_HEIGHT_VP
} from './SettingsStore'

const EVENT_REBUILD_KEYBOARD: string = 'com.quoca.vntelexkeyboard.REBUILD';

@Entry
@Component
struct Settings {
  @State private heightText: string = ''
  @State private inputMethod: InputMethodType = 'telex'
  @State private loading: boolean = true
  @State private saving: boolean = false
  @State private errorText: string = ''

  private methodLabel(m: InputMethodType): string {
    return m === 'vni' ? 'VNI' : 'Telex'
  }

  private back(): void {
    try {
      this.getUIContext().getRouter().back()
    } catch (e) {
      console.error('router back failed: ' + JSON.stringify(e))
    }
  }

  aboutToAppear(): void {
    this.load()
  }

  private load(): void {
    this.loading = true
    this.errorText = ''
    try {
      // getContext() is deprecated (API 18+). Use UIContext.getHostContext() instead.
      const ctx: common.UIAbilityContext = this.getUIContext().getHostContext() as common.UIAbilityContext
      Promise.all([
        readKeyboardHeightVp(ctx).catch(() => DEFAULT_KEYBOARD_HEIGHT_VP),
        readInputMethod(ctx).catch(() => 'telex' as InputMethodType)
      ]).then((vals: Array<number | InputMethodType>) => {
        const h: number = vals[0] as number
        const m: InputMethodType = vals[1] as InputMethodType
        this.heightText = String(h)
        this.inputMethod = m
        this.loading = false
      }).catch((_e: BusinessError) => {
        this.heightText = String(DEFAULT_KEYBOARD_HEIGHT_VP)
        this.inputMethod = 'telex'
        this.loading = false
      })
    } catch (e) {
      this.heightText = String(DEFAULT_KEYBOARD_HEIGHT_VP)
      this.inputMethod = 'telex'
      this.loading = false
    }
  }

  private showToast(message: string): void {
    try {
      this.getUIContext().getPromptAction().showToast({ message })
    } catch {
      // ignore
    }
  }

  private parseHeight(): number | undefined {
    const raw: string = this.heightText.trim()
    if (raw.length === 0) return undefined
    const n: number = Number(raw)
    if (!Number.isFinite(n)) return undefined
    return Math.round(n)
  }

  private getHeightForRebuild(): number {
    const n: number | undefined = this.parseHeight()
    if (n === undefined || !Number.isFinite(n)) return DEFAULT_KEYBOARD_HEIGHT_VP
    if (n < MIN_KEYBOARD_HEIGHT_VP) return MIN_KEYBOARD_HEIGHT_VP
    if (n > MAX_KEYBOARD_HEIGHT_VP) return MAX_KEYBOARD_HEIGHT_VP
    return n
  }

  private onPickInputMethod(m: InputMethodType): void {
    this.inputMethod = m
    try {
      const ctx: common.UIAbilityContext = this.getUIContext().getHostContext() as common.UIAbilityContext
      writeInputMethod(ctx, m).then(() => { /* ignore */ }).catch(() => { /* ignore */ })
      // Keep same behavior as height changes: bump seq + rebuild keyboard.
      bumpKeyboardReloadSeq(ctx).then(() => { /* ignore */ }).catch(() => { /* ignore */ })
    } catch {
      // ignore
    }
    const hVp: number = this.getHeightForRebuild()
    this.publishRebuild(hVp, m)
  }

  @Builder
  private InputMethodMenu() {
    Menu() {
      MenuItem({ content: 'Telex' })
        .onClick(() => this.onPickInputMethod('telex'))
      MenuItem({ content: 'VNI' })
        .onClick(() => this.onPickInputMethod('vni'))
    }
  }

  private publishRebuild(heightVp: number, method: InputMethodType): void {
    try {
      const payload: string = JSON.stringify({ heightVp: heightVp, inputMethod: method })
      commonEventManager.publish(EVENT_REBUILD_KEYBOARD, { data: payload }, (_err?: BusinessError) => {
        // ignore
      })
    } catch {
      // ignore
    }
  }

  private save(): void {
    if (this.saving || this.loading) return

    const n: number | undefined = this.parseHeight()
    if (n === undefined) {
      this.errorText = 'Vui lòng nhập số hợp lệ.'
      return
    }

    if (n < MIN_KEYBOARD_HEIGHT_VP || n > MAX_KEYBOARD_HEIGHT_VP) {
      this.errorText = `Độ cao phải trong khoảng ${MIN_KEYBOARD_HEIGHT_VP}–${MAX_KEYBOARD_HEIGHT_VP} vp.`
      return
    }

    this.errorText = ''
    this.saving = true

    try {
      // getContext() is deprecated (API 18+). Use UIContext.getHostContext() instead.
      const ctx: common.UIAbilityContext = this.getUIContext().getHostContext() as common.UIAbilityContext
      writeKeyboardHeightVp(ctx, n).then(() => {
        // ✅ (Tuỳ chọn) bump seq để debug/log dễ hơn, không cần nút riêng nữa
        try {
          bumpKeyboardReloadSeq(ctx).then(() => { /* ignore */ }).catch(() => { /* ignore */ })
        } catch {
          // ignore
        }

        // Persist input method (for UIAbility pref). Keyboard will also persist it after rebuild.
        try {
          writeInputMethod(ctx, this.inputMethod).then(() => { /* ignore */ }).catch(() => { /* ignore */ })
        } catch {
          // ignore
        }

        // ✅ GỘP REBUILD VÀO NÚT LƯU
        this.publishRebuild(n, this.inputMethod)

        this.saving = false
        this.showToast('Đã lưu cài đặt.')
      }).catch((_e: BusinessError) => {
        this.saving = false
        this.showToast('Lưu thất bại. Vui lòng thử lại.')
      })
    } catch (e) {
      this.saving = false
      this.showToast('Lưu thất bại. Vui lòng thử lại.')
    }
  }

  private resetToDefault(): void {
    this.heightText = String(DEFAULT_KEYBOARD_HEIGHT_VP)
    this.errorText = ''
  }

  build() {
    Column() {
      // Header
      Row() {
        Text('←')
          .fontSize(20)
          .fontColor($r('app.color.text_primary'))
          .padding({ left: 16, right: 10, top: 12, bottom: 12 })
          .onClick(() => this.back())

        Text($r('app.string.settings_header'))
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))
          .textAlign(TextAlign.Start)
          .layoutWeight(1)

        Blank().width(46)
      }
      .width('100%')

      Scroll() {
        Column({ space: 12 }) {
          // Card
          Column() {
            // Input method
            Text('Kiểu gõ')
              .fontSize(16)
              .fontWeight(FontWeight.Medium)
              .fontColor($r('app.color.text_primary'))
              .width('100%')
              .textAlign(TextAlign.Start)

            Row() {
              Button(this.methodLabel(this.inputMethod))
                .layoutWeight(1)
                .height(44)
                .borderRadius(10)
                .backgroundColor($r('app.color.page_bg'))
                .bindMenu(this.InputMethodMenu)
            }
            .width('100%')
            .margin({ top: 12 })

            Divider().margin({ top: 16, bottom: 16 })

            Text($r('app.string.settings_keyboard_height_title'))
              .fontSize(16)
              .fontWeight(FontWeight.Medium)
              .fontColor($r('app.color.text_primary'))
              .width('100%')
              .textAlign(TextAlign.Start)

            Text($r('app.string.settings_keyboard_height_desc'))
              .margin({ top: 8 })
              .fontSize(13)
              .fontColor($r('app.color.text_secondary'))
              .lineHeight(18)
              .width('100%')
              .textAlign(TextAlign.Start)

            Row() {
              TextInput({ text: this.heightText, placeholder: String(DEFAULT_KEYBOARD_HEIGHT_VP) })
                .type(InputType.Number)
                .onChange((v: string) => {
                  this.heightText = v
                  this.errorText = ''
                })
                .layoutWeight(1)
                .height(44)
                .padding({ left: 12, right: 12 })
                .borderRadius(10)
                .backgroundColor($r('app.color.page_bg'))

              Text('vp')
                .fontSize(14)
                .fontColor($r('app.color.text_secondary'))
                .margin({ left: 10 })
            }
            .width('100%')
            .margin({ top: 12 })

            if (this.errorText.length > 0) {
              Text(this.errorText)
                .margin({ top: 10 })
                .fontSize(12)
                .fontColor($r('app.color.text_secondary'))
                .width('100%')
                .textAlign(TextAlign.Start)
            }

            Row({ space: 10 }) {
              Button($r('app.string.settings_reset'))
                .layoutWeight(1)
                .onClick(() => this.resetToDefault())

              Button(this.saving ? $r('app.string.settings_saving') : $r('app.string.settings_save'))
                .layoutWeight(1)
                .enabled(!this.loading && !this.saving)
                .onClick(() => this.save())
            }
            .width('100%')
            .margin({ top: 14 })

            // ✅ Đã bỏ nút Rebuild riêng để gọn UI
          }
          .width('100%')
          .padding(16)
          .backgroundColor($r('app.color.card_bg'))
          .borderRadius(14)

          Column() {
            Text($r('app.string.settings_note_title'))
              .fontSize(16)
              .fontWeight(FontWeight.Medium)
              .fontColor($r('app.color.text_primary'))
              .width('100%')
              .textAlign(TextAlign.Start)

            Text($r('app.string.settings_note_body'))
              .margin({ top: 8 })
              .fontSize(13)
              .fontColor($r('app.color.text_secondary'))
              .lineHeight(18)
              .width('100%')
              .textAlign(TextAlign.Start)
          }
          .width('100%')
          .padding(16)
          .backgroundColor($r('app.color.card_bg'))
          .borderRadius(14)

          Blank().height(18)
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 14 })
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.page_bg'))
  }
}
