// entry/src/main/ets/pages/Index.ets
import router from '@ohos.router'
import inputMethod from '@ohos.inputMethod'
import { common, Want } from '@kit.AbilityKit'
import type { BusinessError } from '@kit.BasicServicesKit'

class InputMethodInfo {
  packageName: string = ''
}

interface InputMethodSettingApi {
  getInputMethods(enable: boolean): Promise<Array<InputMethodInfo>>
}

@Entry
@Component
struct Index {
  @State imeActivated: boolean = false
  @State checkingIme: boolean = false

  aboutToAppear(): void {
    this.refreshImeStatus()
  }

  onPageShow(): void {
    this.refreshImeStatus()
  }

  private async refreshImeStatus(): Promise<void> {
    if (this.checkingIme) {
      return
    }
    this.checkingIme = true
    try {
      const ctx: common.UIAbilityContext = getContext(this) as common.UIAbilityContext
      const myBundle: string = ctx.abilityInfo.bundleName

      const setting: InputMethodSettingApi = inputMethod.getSetting() as InputMethodSettingApi
      const list: Array<InputMethodInfo> = await setting.getInputMethods(true)

      let activated: boolean = false
      for (let i = 0; i < list.length; i++) {
        if (list[i].packageName === myBundle) {
          activated = true
          break
        }
      }
      this.imeActivated = activated
    } catch (e) {
      this.imeActivated = false
    } finally {
      this.checkingIme = false
    }
  }

  private openSystemSettings(): void {
    const ctx: common.UIAbilityContext = getContext(this) as common.UIAbilityContext

    const wantMain: Want = {
      bundleName: 'com.huawei.hmos.settings',
      abilityName: 'com.huawei.hmos.settings.MainAbility'
    }

    try {
      ctx.startAbility(wantMain).catch((err: BusinessError) => {
        console.error(`Open settings failed: ${err.code} ${err.message}`)
      })
    } catch (e) {
      console.error('Open settings exception: ' + JSON.stringify(e))
    }
  }

  private go(url: string): void {
    try {
      // pushUrl returns a Promise in many SDK versions; handle rejection explicitly to satisfy ArkTSCheck
      router.pushUrl({ url }).catch((err: BusinessError) => {
        console.error(`pushUrl failed: ${err.code} ${err.message}`)
      })
    } catch (e) {
      console.error('pushUrl exception: ' + JSON.stringify(e))
    }
  }

  @Builder
  private MenuItem(title: ResourceStr, desc: ResourceStr, url: string) {
    Row() {
      Column() {
        Text(title)
          .fontSize(18)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_primary'))
          .width('100%')
          .textAlign(TextAlign.Start)

        Text(desc)
          .fontSize(14)
          .fontColor($r('app.color.text_secondary'))
          .margin({ top: 6 })
          .width('100%')
          .textAlign(TextAlign.Start)
      }
      .layoutWeight(1)

      Text('›')
        .fontSize(20)
        .fontColor($r('app.color.text_secondary'))
        .margin({ left: 10 })
    }
    .width('100%')
    .padding(14)
    .borderRadius(12)
    .backgroundColor($r('app.color.card_bg'))
    .onClick(() => this.go(url))
  }

  build() {
    Column() {
      Text($r('app.string.app_title'))
        .width('100%')
        .textAlign(TextAlign.Center)
        .fontSize(24)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_primary'))
        .margin({ top: 6, bottom: 14 })

      Column({ space: 12 }) {
        this.MenuItem($r('app.string.menu_privacy_title'), $r('app.string.menu_privacy_desc'), 'pages/Privacy')
        this.MenuItem($r('app.string.menu_about_title'), $r('app.string.menu_about_desc'), 'pages/About')
      }
      .width('100%')

      Blank().layoutWeight(1)

      if (this.imeActivated) {
        Button($r('app.string.btn_keyboard_activated'))
          .width('100%')
          .enabled(false)
          .margin({ bottom: 10 })
      } else {
        Button(this.checkingIme ? $r('app.string.btn_checking') : $r('app.string.btn_open_settings'))
          .width('100%')
          .enabled(!this.checkingIme)
          .margin({ bottom: 10 })
          .onClick(() => this.openSystemSettings())
      }
    }
    .width('100%')
    .height('100%')
    .padding(16)
    .backgroundColor($r('app.color.page_bg'))
    .alignItems(HorizontalAlign.Start)
  }
}
