import { photoAccessHelper } from '@kit.MediaLibraryKit';
import { promptAction, componentSnapshot } from '@kit.ArkUI';
import { fileIo as fs } from '@kit.CoreFileKit';
import { image } from '@kit.ImageKit';
import { IjkMediaPlayer } from "@ohos/ijkplayer";
import { common } from '@kit.AbilityKit';

import { HistoryItem } from '../models/HistoryItem';
import { ResultCard } from '../components/ResultCard';
import { BottomMenuDialog } from '../components/BottomMenuDialog';
import { VideoPlayerView } from '../components/VideoPlayerView';
import { MqttService } from '../services/MqttService';
import { DatabaseUtils } from '../utils/DatabaseUtils';
import { MdnsDiscovery } from '../utils/MdnsDiscovery';
import { LabelUtils } from '../utils/LabelUtils';


@CustomDialog
struct DateRangeFilterDialog {
  controller?: CustomDialogController;
  @State startDate: Date = new Date();
  @State endDate: Date = new Date();

  // 接收外部传入的初始筛选时间
  initialStartTime?: number;
  initialEndTime?: number;

  onConfirm?: (startTs: number, endTs: number) => void;

  aboutToAppear() {
    // 初始化时恢复筛选状态
    if (this.initialStartTime) {
      this.startDate = new Date(this.initialStartTime);
    }
    if (this.initialEndTime) {
      this.endDate = new Date(this.initialEndTime);
    }
  }

  private formatDate(date: Date): string {
    return `${date.getFullYear()}-${(date.getMonth() + 1).toString().padStart(2, '0')}-${date.getDate().toString().padStart(2, '0')}`;
  }

  build() {
    Column() {
      Text('选择筛选时间段')
        .fontSize(18)
        .fontWeight(FontWeight.Medium)
        .fontColor('#1A1A1A')
        .margin({ top: 24, bottom: 24 })

      Row() {
        // 开始日期按钮
        Text(this.formatDate(this.startDate))
          .fontSize(16)
          .fontColor('#2C3E50')
          .backgroundColor('#F5F7FA')
          .padding({ left: 16, right: 16, top: 12, bottom: 12 })
          .borderRadius(8)
          .onClick(() => {
            DatePickerDialog.show({
              start: new Date("2020-01-01"),
              end: new Date(),
              selected: this.startDate,
              onAccept: (value: DatePickerResult) => {
                let y = value.year ?? new Date().getFullYear();
                let m = value.month ?? new Date().getMonth();
                let d = value.day ?? new Date().getDate();
                this.startDate = new Date(y, m, d);
              }
            });
          })

        Text(' 至 ')
          .fontSize(14)
          .fontColor('#7F8C8D')
          .margin({ left: 8, right: 8 })

        // 结束日期按钮
        Text(this.formatDate(this.endDate))
          .fontSize(16)
          .fontColor('#2C3E50')
          .backgroundColor('#F5F7FA')
          .padding({ left: 16, right: 16, top: 12, bottom: 12 })
          .borderRadius(8)
          .onClick(() => {
            DatePickerDialog.show({
              start: new Date("2020-01-01"),
              end: new Date(),
              selected: this.endDate,
              onAccept: (value: DatePickerResult) => {
                let y = value.year ?? new Date().getFullYear();
                let m = value.month ?? new Date().getMonth();
                let d = value.day ?? new Date().getDate();
                this.endDate = new Date(y, m, d);
              }
            });
          })
      }
      .width('100%')
      .justifyContent(FlexAlign.Center)
      .margin({ bottom: 32 })

      // 底部操作按钮
      Row({ space: 16 }) {
        Button('取消', { type: ButtonType.Capsule })
          .backgroundColor('#E0E0E0')
          .fontColor('#333333')
          .fontSize(16)
          .height(44)
          .layoutWeight(1)
          .onClick(() => this.controller?.close())

        Button('确定', { type: ButtonType.Capsule })
          .backgroundColor('#2E8B57')
          .fontSize(16)
          .height(44)
          .layoutWeight(1)
          .onClick(() => {
            if (this.onConfirm) {
              let start = this.startDate.getTime();
              let end = this.endDate.getTime();
              if (start > end) {
                let temp = start;
                start = end;
                end = temp;
              }

              let startDateObj = new Date(start);
              let endDateObj = new Date(end);
              let startTs = new Date(startDateObj.getFullYear(), startDateObj.getMonth(), startDateObj.getDate(), 0, 0, 0).getTime();
              let endTs = new Date(endDateObj.getFullYear(), endDateObj.getMonth(), endDateObj.getDate(), 23, 59, 59).getTime();

              this.onConfirm(startTs, endTs);
            }
            this.controller?.close();
          })
      }
      .width('100%')
      .padding({ left: 24, right: 24, bottom: 24 })
    }
    .backgroundColor(Color.White)
    .borderRadius(24)
    .width('90%')
  }
}
// ==========================================


@Entry
@Component
struct Index {
  @State historyList: HistoryItem[] = [];
  @State isEditMode: boolean = false;
  @State filterStartTime: number | undefined = undefined;
  @State filterEndTime: number | undefined = undefined;

  private mqttService: MqttService = new MqttService();
  @State isEdgeNodeOnline: boolean = false;
  private ijkPlayer?: IjkMediaPlayer;
  @State currentEdgeIp: string = '';
  @State rtspUrl: string = '';

  dialogController: CustomDialogController = new CustomDialogController({
    builder: BottomMenuDialog({
      onGalleryClick: () => { this.pickPhotoFromGallery(); },
      onCameraClick: () => { this.triggerSnapshot(); }
    }),
    alignment: DialogAlignment.Bottom,
    customStyle: true
  });

  // 日期范围筛选弹窗控制器
  dateRangeDialogController: CustomDialogController | null = null;

  private onMqttResult = (taskId: string, label: string, score: number) => {
    this.handleTaskSuccess(taskId, label, score);
  }

  private onNodeFound = (discoveredIp: string) => {
    promptAction.showToast({ message: `发现边缘节点 IP: ${discoveredIp}` });
    this.isEdgeNodeOnline = true;
    this.currentEdgeIp = discoveredIp;
    this.mqttService.init(discoveredIp, this.onMqttResult);
    this.rtspUrl = `rtsp://${discoveredIp}:8554/mystream`;
    this.startPlayingRtsp();
  }

  private onPlayerReady = (player: IjkMediaPlayer) => {
    this.ijkPlayer = player;
    this.startPlayingRtsp();
  }

  private isPlayerInitialized: boolean = false;

  private startPlayingRtsp() {
    if (!this.ijkPlayer || !this.rtspUrl) return;
    try {
      console.info('IJK_LOG', '准备播放: ' + this.rtspUrl);
      if (this.isPlayerInitialized) {
        this.ijkPlayer.stop();
      }
      this.ijkPlayer.setOption(IjkMediaPlayer.OPT_CATEGORY_PLAYER, "mediacodec", "0");
      this.ijkPlayer.setOption(IjkMediaPlayer.OPT_CATEGORY_FORMAT, "rtsp_transport", "tcp");
      this.ijkPlayer.setOption(IjkMediaPlayer.OPT_CATEGORY_PLAYER, "start-on-prepared", "1");
      this.ijkPlayer.setOption(IjkMediaPlayer.OPT_CATEGORY_PLAYER, "infbuf", "1");
      this.ijkPlayer.setOption(IjkMediaPlayer.OPT_CATEGORY_PLAYER, "packet-buffering", "0");
      this.ijkPlayer.setDataSource(this.rtspUrl);
      this.ijkPlayer.prepareAsync();
      this.isPlayerInitialized = true;
    } catch (e) {
      console.error('IJK_LOG', '播放失败: ', e);
    }
  }

  aboutToAppear() {
    let context = getContext(this) as common.UIAbilityContext;
    DatabaseUtils.initDb(context).then(() => {
      DatabaseUtils.queryAllHistory().then(list => this.historyList = list);
    });
    this.onNodeFound("192.168.137.100");
  }

  aboutToDisappear() {
    MdnsDiscovery.stopDiscovery();
    if (this.mqttService) {
      this.mqttService.disconnect();
    }
    if (this.ijkPlayer && this.isPlayerInitialized) {
      this.ijkPlayer.stop();
      this.ijkPlayer.release();
    }
  }

  refreshHistory() {
    DatabaseUtils.queryAllHistory(this.filterStartTime, this.filterEndTime).then(list => {
      this.historyList = list;
    });
  }

  clearFilter() {
    this.filterStartTime = undefined;
    this.filterEndTime = undefined;
    this.refreshHistory();
    promptAction.showToast({ message: '已显示所有记录' });
  }

  async deleteFailedRecords() {
    await DatabaseUtils.deleteFailedHistory();
    this.refreshHistory();
    promptAction.showToast({ message: '已清理所有识别失败的记录' });
  }

  async deleteSelectedRecords() {
    let selectedIds = this.historyList.filter(item => item.isSelected).map(item => item.taskId);
    if (selectedIds.length === 0) {
      promptAction.showToast({ message: '未选中任何记录' });
      return;
    }
    await DatabaseUtils.deleteHistory(selectedIds);
    this.refreshHistory();
    this.isEditMode = false;
    promptAction.showToast({ message: `成功删除 ${selectedIds.length} 条记录` });
  }

  handleTaskSuccess(taskId: string, englishLabel: string, score: number) {
    let chineseLabel = LabelUtils.getChineseLabel(englishLabel);
    let targetItem = this.historyList.find(item => item.taskId === taskId);
    if (targetItem) {
      targetItem.status = 'success';
      targetItem.label = chineseLabel;
      targetItem.score = score;
      DatabaseUtils.updateHistory(taskId, 'success', chineseLabel, score);
    }
  }

  async triggerSnapshot() {
    if (!this.ijkPlayer) {
      promptAction.showToast({ message: '视频流未就绪' });
      return;
    }
    let timestamp = new Date().getTime();
    let taskId = "snap_" + timestamp.toString();
    let displayUri: string | Resource = $r('app.media.startIcon');
    let bufferToSend: ArrayBuffer | null = null;
    let context = getContext(this) as common.UIAbilityContext;
    let cacheDir = context.cacheDir;
    let filePath = cacheDir + '/' + taskId + '.jpg';

    try {
      let pixelMap = await componentSnapshot.get('videoWrapperId');
      let imagePacker = image.createImagePacker();
      let packOpts: image.PackingOption = { format: "image/jpeg", quality: 80 };
      bufferToSend = await imagePacker.packing(pixelMap, packOpts);
      let file = fs.openSync(filePath, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE);
      fs.writeSync(file.fd, bufferToSend);
      fs.closeSync(file.fd);
      pixelMap.release();
      imagePacker.release();
      displayUri = 'file://' + filePath;
      promptAction.showToast({ message: '截图成功，正在识别...' });
    } catch (err) {
      console.error("截图失败: ", JSON.stringify(err));
      promptAction.showToast({ message: '截图失败' });
      return;
    }

    let newItem = new HistoryItem(taskId, displayUri, true, timestamp);
    DatabaseUtils.insertHistory(newItem).then(() => {
      this.refreshHistory();
    });

    if (bufferToSend) {
      let success = await this.mqttService.publishImageStream(taskId, bufferToSend);
      if (!success) {
        promptAction.showToast({ message: '任务发送失败' });
        newItem.status = 'failed';
        DatabaseUtils.updateHistory(taskId, 'failed');
        this.refreshHistory();
      }
    }
  }

  async pickPhotoFromGallery() {
    try {
      let photoPicker = new photoAccessHelper.PhotoViewPicker();
      let pickOptions: photoAccessHelper.PhotoSelectOptions = {
        MIMEType: photoAccessHelper.PhotoViewMIMETypes.IMAGE_TYPE,
        maxSelectNumber: 1
      };
      let pickResult = await photoPicker.select(pickOptions);
      if (pickResult.photoUris.length > 0) {
        this.createNewTask(pickResult.photoUris[0]);
      }
    } catch (err) {
      console.error('图库选择异常:', err);
    }
  }

  async createNewTask(uri: string) {
    let timestamp = new Date().getTime();
    let taskId = "task_" + timestamp.toString();
    let newItem = new HistoryItem(taskId, uri, false, timestamp);

    DatabaseUtils.insertHistory(newItem).then(() => {
      this.refreshHistory();
    });

    try {
      let file = fs.openSync(uri, fs.OpenMode.READ_ONLY);
      let stat = fs.statSync(file.fd);
      let buffer = new ArrayBuffer(stat.size);
      fs.readSync(file.fd, buffer);
      fs.closeSync(file.fd);
      promptAction.showToast({ message: '图片发送中...' });
      let success = await this.mqttService.publishImageStream(taskId, buffer);
      if (!success) {
        newItem.status = 'failed';
        DatabaseUtils.updateHistory(taskId, 'failed');
        this.refreshHistory();
      }
    } catch (e) {
      newItem.status = 'failed';
      DatabaseUtils.updateHistory(taskId, 'failed');
      this.refreshHistory();
    }
  }

  build() {
    Stack({ alignContent: Alignment.BottomEnd }) {
      Column() {
        // 顶部标题与状态
        Row() {
          Column() {
            Text("麦田病害监测")
              .fontSize(22)
              .fontWeight(FontWeight.Bolder)
              .fontColor('#1A1A1A')
              .margin({ bottom: 6 })
            Row() {
              Circle({ width: 8, height: 8 })
                .fill(this.isEdgeNodeOnline ? '#00C853' : '#F44336')
                .margin({ right: 6 })
              Text(this.isEdgeNodeOnline ? "边缘节点已连接" : "正在搜索节点...")
                .fontSize(12)
                .fontColor('#7F8C8D')
            }
          }
          .alignItems(HorizontalAlign.Start)
        }
        .width('100%')
        .padding({ left: 20, right: 20, top: 16, bottom: 8 })

        // 视频流区域
        Column() {
          Row() {
            Text("实时视频流")
              .fontSize(15)
              .fontWeight(FontWeight.Medium)
              .fontColor('#2C3E50')
            Blank()
            Text("点击画面截图")
              .fontSize(12)
              .fontColor('#3498DB')
              .backgroundColor('#EBF5FB')
              .padding({ left: 8, right: 8, top: 4, bottom: 4 })
              .borderRadius(12)
          }
          .width('100%')
          .padding(16)

          Stack() {
            VideoPlayerView({
              onTapAction: () => { this.triggerSnapshot(); },
              onPlayerReady: this.onPlayerReady
            })
          }
          .width('100%')
          .clip(true)
          .borderRadius({ bottomLeft: 16, bottomRight: 16 })
          .id('videoWrapperId')
        }
        .width('92%')
        .backgroundColor('#FFFFFF')
        .borderRadius(16)
        .margin({ top: 8, bottom: 16 })
        .shadow({ radius: 16, color: 'rgba(0,0,0,0.06)', offsetY: 8 })

        // 历史记录操作栏
        Row() {
          Text("历史记录")
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor('#1A1A1A')
            .layoutWeight(1)

          if (!this.isEditMode) {
            if (this.filterStartTime !== undefined) {
              Text("清除筛选")
                .fontSize(13)
                .fontColor('#3498DB')
                .margin({ right: 12 })
                .onClick(() => this.clearFilter())
            }

            Image($r('app.media.ic_public_calendar'))
              .width(20)
              .height(20)
              .margin({ right: 16 })
              .fillColor('#7F8C8D')
              .onClick(() => {
                // 点击日历时动态创建控制器
                this.dateRangeDialogController = new CustomDialogController({
                  builder: DateRangeFilterDialog({
                    initialStartTime: this.filterStartTime,
                    initialEndTime: this.filterEndTime,
                    onConfirm: (startTs: number, endTs: number) => {
                      this.filterStartTime = startTs;
                      this.filterEndTime = endTs;
                      this.refreshHistory();
                      promptAction.showToast({ message: '筛选应用成功' });
                    }
                  }),
                  alignment: DialogAlignment.Center,
                  customStyle: true
                });
                this.dateRangeDialogController.open();
              })

            Text("清理失败记录")
              .fontSize(14)
              .fontColor('#E74C3C')
              .margin({ right: 16 })
              .onClick(() => this.deleteFailedRecords())
          }

          Text(this.isEditMode ? "取消" : "批量选择")
            .fontSize(14)
            .fontColor('#3498DB')
            .onClick(() => {
              this.isEditMode = !this.isEditMode;
              if (!this.isEditMode) {
                this.historyList.forEach(item => item.isSelected = false);
              }
            })

          if (this.isEditMode) {
            Text("删除选中")
              .fontSize(14)
              .fontColor('#F44336')
              .margin({ left: 16 })
              .onClick(() => this.deleteSelectedRecords())
          }
        }
        .width('100%')
        .padding({ left: 20, right: 20, bottom: 8 })

        List({ space: 16 }) {
          ForEach(this.historyList, (item: HistoryItem) => {
            ListItem() {
              ResultCard({ item: item, isEditMode: this.isEditMode })
            }
          }, (item: HistoryItem) => item.taskId)
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 4, bottom: 100 })
        .layoutWeight(1)
      }
      .width('100%')
      .height('100%')
      .backgroundColor('#F5F7FA')

      Button({ type: ButtonType.Circle, stateEffect: true }) {
        Image($r('app.media.ic_public_upload_filled'))
          .width(24)
          .height(24)
          .fillColor(Color.White)
      }
      .width(60)
      .height(60)
      .backgroundColor('#2E8B57')
      .margin({ right: 24, bottom: 48 })
      .shadow({ radius: 12, color: 'rgba(46, 139, 87, 0.4)', offsetY: 6 })
      .onClick(() => {
        this.dialogController.open();
      })
    }
    .width('100%')
    .height('100%')
  }
}