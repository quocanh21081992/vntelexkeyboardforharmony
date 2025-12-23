@Entry
@Component
struct About {
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
    .width('100%')
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

        Text('Giới thiệu')
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
          this.Section(
            'Vietnam Keyboard',
            'Vietnam Keyboard là ứng dụng bàn phím tiếng Việt dành cho hệ điều hành Harmony OS 6 của Huawei. Đây là ứng dụng hoàn toàn miễn phí vì cộng đồng Huawei Việt Nam.'
          )

          this.Section(
            'Tính năng chính',
            '- Gõ tiếng Việt Telex (sẽ hỗ trợ VNI trong bản cập nhật kế tiếp).\n' +
              '- Tương thích với các ứng dụng Android chạy giả lập.'
          )

          this.Section(
            'Bản quyền',
            'Vietnam Keyboard được phát triển bởi Anh Dương.\n' +
          'Nếu bạn cảm thấy hài lòng về ứng dụng có thể donate cho mình nhé.\n' +
          'STK: 0778211992\n' +
          'Ngân hàng: MB Bank'
          )

          this.Section(
            'Liên hệ',
            'Mọi ý kiến đóng góp, báo lỗi vui lòng gửi email về: quocanh21081992@gmail.com\nPhiên bản: 1.0.0'
          )

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
