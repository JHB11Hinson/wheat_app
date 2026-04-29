@CustomDialog
export struct DeepSeekAdviceDialog {
  controller?: CustomDialogController;
  @Prop label: string;
  @Link adviceText: string;
  @Link isLoading: boolean;
  onReAsk?: () => void;

  build() {
    Column() {
      Text(`AI 诊疗: ${this.label}`)
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .fontColor('#1A1A1A')
        .margin({ top: 24, bottom: 16 })

      if (this.isLoading) {
        Column() {
          LoadingProgress().width(48).height(48).color('#2E8B57').margin({ bottom: 12 })
          Text("深度思考并生成治理方案中...").fontSize(14).fontColor('#7F8C8D')
        }
        .height(180)
        .justifyContent(FlexAlign.Center)
      } else {
        Scroll() {
          Text(this.adviceText)
            .fontSize(15)
            .fontColor('#333333')
            .lineHeight(24)
            .padding({ left: 16, right: 16 })
        }
        .height(250)
        .width('100%')
        .align(Alignment.TopStart)
      }

      Row({ space: 16 }) {
        Button('关闭', { type: ButtonType.Capsule })
          .backgroundColor('#F5F7FA')
          .fontColor('#2C3E50')
          .fontSize(16)
          .height(44)
          .layoutWeight(1)
          .onClick(() => this.controller?.close())

        Button('重新询问', { type: ButtonType.Capsule })
          .backgroundColor('#2E8B57')
          .fontSize(16)
          .height(44)
          .layoutWeight(1)
          .enabled(!this.isLoading) // 加载中时禁用
          .onClick(() => {
            if (this.onReAsk) this.onReAsk();
          })
      }
      .width('100%')
      .padding({ left: 24, right: 24, top: 16, bottom: 24 })
    }
    .backgroundColor(Color.White)
    .borderRadius(24)
    .width('90%')
  }
}