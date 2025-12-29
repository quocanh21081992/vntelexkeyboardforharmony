// entry/src/main/ets/pages/Index.ets
// Home page (Entry). Chạm vào từng mục để mở trang tương ứng.

@Entry
@Component
struct Index {
  private go(url: string): void {
    try {
      this.getUIContext().getRouter().pushUrl({ url })
    } catch (e) {
      console.error('router push failed: ' + JSON.stringify(e))
    }
  }

  @Builder
  private MenuItem(title: string, desc: string, url: string) {
    Row() {
      Column() {
        Text(title)
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_primary'))
          .width('100%')
          .textAlign(TextAlign.Start)

        Text(desc)
          .margin({ top: 8 })
          .fontSize(13)
          .fontColor($r('app.color.text_secondary'))
          .lineHeight(18)
          .width('100%')
          .textAlign(TextAlign.Start)
      }
      .layoutWeight(1)

      Text('›')
        .fontSize(22)
        .fontColor($r('app.color.text_secondary'))
        .margin({ left: 12 })
    }
    .width('100%')
    .padding(16)
    .backgroundColor($r('app.color.card_bg'))
    .borderRadius(14)
    .onClick(() => {
      this.go(url)
    })
  }

  build() {
    Column({ space: 12 }) {
      Text('Vietnam Keyboard')
        .fontSize(22)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_primary'))
        .width('100%')
        .textAlign(TextAlign.Start)

      Text('Bàn phím tiếng Việt hỗ trợ Telex và VNI. Bạn có thể chỉnh kiểu gõ và độ cao bàn phím trong phần Cài đặt.')
        .fontSize(13)
        .fontColor($r('app.color.text_secondary'))
        .lineHeight(18)
        .width('100%')
        .textAlign(TextAlign.Start)

      Blank().height(4)

      this.MenuItem(
        'Cài đặt',
        'Chọn kiểu gõ (Telex/VNI), điều chỉnh độ cao bàn phím và các tuỳ chọn khác.',
        'pages/Settings'
      )

      this.MenuItem(
        'Chính sách quyền riêng tư',
        'Xem nội dung privacy policy để submit lên AppGallery.',
        'pages/Privacy'
      )

      this.MenuItem(
        'Giới thiệu',
        'Thông tin phiên bản và liên hệ.',
        'pages/About'
      )

      Blank().height(16)
    }
    .width('100%')
    .height('100%')
    .padding(16)
    .backgroundColor($r('app.color.page_bg'))
  }
}
