@CustomDialog
export struct BottomMenuDialog {
  controller?: CustomDialogController;
  onGalleryClick?: () => void;
  onCameraClick?: () => void;

  build() {
    Column() {
      Text('选择病害图片来源')
        .fontSize(18)
        .fontWeight(FontWeight.Medium)
        .fontColor('#1A1A1A')
        .margin({ top: 24, bottom: 20 })

      Row({ space: 16 }) {
        Button('相册上传', { type: ButtonType.Capsule })
          .backgroundColor('#2E8B57')
          .fontSize(16)
          .height(48)
          .layoutWeight(1)
          .onClick(() => {
            this.controller?.close();
            if (this.onGalleryClick) this.onGalleryClick();
          })

        Button('快捷抓拍', { type: ButtonType.Capsule })
          .backgroundColor('#2E8B57')
          .fontSize(16)
          .height(48)
          .layoutWeight(1)
          .onClick(() => {
            this.controller?.close();
            if (this.onCameraClick) this.onCameraClick();
          })
      }
      .padding({ left: 24, right: 24, bottom: 32 })
      .width('100%')
    }
    .backgroundColor(Color.White)
    .borderRadius({ topLeft: 24, topRight: 24 })
    .width('100%')
  }
}