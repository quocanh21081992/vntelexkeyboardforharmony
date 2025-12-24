import { UIAbility, Configuration } from '@kit.AbilityKit'
import { window } from '@kit.ArkUI'
import type { BusinessError } from '@kit.BasicServicesKit'


export default class EntryAbility extends UIAbility {
  private windowStage?: window.WindowStage

  onWindowStageCreate(windowStage: window.WindowStage) {
    this.windowStage = windowStage
    try {
      // loadContent returns a Promise in many SDK versions; handle rejection explicitly to satisfy ArkTSCheck
      windowStage.loadContent('pages/Index').catch((err: BusinessError) => {
        console.error(`loadContent failed: ${err.code} ${err.message}`)
      })
    } catch (e) {
      console.error('loadContent failed:', JSON.stringify(e))
    }
  }

  onConfigurationUpdate(newConfig: Configuration): void {
    // avoid "declared but never read" warning while keeping the signature
    void newConfig
    // When system language changes, reload the UI so $r('app.string.*') resolves with the new locale.
    // (Also works for other global config updates.)
    if (!this.windowStage) {
      return
    }
    try {
      this.windowStage.loadContent('pages/Index').catch((err: BusinessError) => {
        console.error(`reload content failed: ${err.code} ${err.message}`)
      })
    } catch (e) {
      console.error('reload content failed:', JSON.stringify(e))
    }
  }
}
