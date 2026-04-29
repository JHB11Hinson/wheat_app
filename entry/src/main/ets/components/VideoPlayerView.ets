import { IjkMediaPlayer, OnVideoSizeChangedListener } from "@ohos/ijkplayer";

@Component
export struct VideoPlayerView {
  private mIjkMediaPlayer: IjkMediaPlayer = new IjkMediaPlayer();
  @State aspRatio: number = 16 / 9;

  onTapAction?: () => void;
  // 用于将播放器实例回调给父组件
  onPlayerReady?: (player: IjkMediaPlayer) => void;

  initIjkPlayer(context: object) {
    this.mIjkMediaPlayer.setContext(context, "xcomponentId");
    this.mIjkMediaPlayer.setDebug(true);
    this.mIjkMediaPlayer.native_setup();

    // 只设置视频尺寸监听，用于调整画面比例
    let mOnVideoSizeChangedListener: OnVideoSizeChangedListener = {
      onVideoSizeChanged: (width: number, height: number, sar_num: number, sar_den: number) => {
        if (width > 0 && height > 0) this.aspRatio = width / height;
      }
    }
    this.mIjkMediaPlayer.setOnVideoSizeChangedListener(mOnVideoSizeChangedListener);
    this.mIjkMediaPlayer.setMessageListener();

    // 触发回调，将干净的实例传出去
    if (this.onPlayerReady) {
      this.onPlayerReady(this.mIjkMediaPlayer);
    }
  }

  aboutToDisappear() {
    if (this.mIjkMediaPlayer) {
      this.mIjkMediaPlayer.stop();
      this.mIjkMediaPlayer.release();
    }
  }

  build() {
    Column() {
      XComponent({
        id: 'xcomponentId',
        type: XComponentType.TEXTURE,
        libraryname: 'ijkplayer_napi'
      })
        .onLoad((context: object) => { this.initIjkPlayer(context); })
        .width('100%')
        .aspectRatio(this.aspRatio)
        .backgroundColor(Color.Black)
    }
    .id('videoWrapperId')
    .gesture(
      TapGesture({ count: 1 }).onAction(() => {
        if (this.onTapAction) this.onTapAction();
      })
    )
  }
}