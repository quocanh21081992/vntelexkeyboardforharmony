@Entry
@Component
struct Privacy {
  private back() {
    try {
      this.getUIContext().getRouter().back()
    } catch (e) {
      console.error('router back failed:', JSON.stringify(e))
    }
  }

  @Builder
  private Section(title: string, body: string) {
    Column() {
      Text(title)
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.text_primary'))
        .textAlign(TextAlign.Start)
        .width('100%')

      Text(body)
        .margin({ top: 8 })
        .fontSize(13)
        .fontColor($r('app.color.text_secondary'))
        .lineHeight(18)
        .textAlign(TextAlign.Start)
        .width('100%')
    }
    .width('100%') // ✅ full width card (không co theo chữ)
    .padding(16)
    .backgroundColor($r('app.color.card_bg'))
    .borderRadius(14)
  }

  build() {
    Column() {
      Row() {
        Text('←')
          .fontSize(20)
          .fontColor($r('app.color.text_primary'))
          .padding({ left: 16, right: 10, top: 12, bottom: 12 })
          .onClick(() => this.back())

        Text('Chính sách & Quyền riêng tư')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))
          .textAlign(TextAlign.Start) // ✅ left
          .layoutWeight(1)

        Blank().width(46)
      }
      .width('100%')

      Scroll() {
        Column({ space: 12 }) {
          this.Section(
            'Dữ liệu người dùng',
            'Chúng tôi không thu thập cũng như sử dụng dữ liệu người dùng dưới bất cứ hình thức nào.'
          )

          Text('Cập nhật lần cuối: 23/12/2025')
            .fontSize(12)
            .fontColor($r('app.color.text_secondary'))
            .width('100%')
            .textAlign(TextAlign.Start) // ✅ left
            .margin({ top: 6, bottom: 18 })
        }
        .width('100%') // ✅ không bị co
        .padding({ left: 16, right: 16, top: 14 })
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.page_bg'))
  }
}
