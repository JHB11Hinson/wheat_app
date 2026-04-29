import { promptAction } from '@kit.ArkUI';
import { HistoryItem } from '../models/HistoryItem';
import { DeepSeekUtils } from '../utils/DeepSeekUtils';
import { DeepSeekAdviceDialog } from './DeepSeekAdviceDialog';

@Component
export struct ResultCard {
  @ObjectLink item: HistoryItem;
  @Prop isEditMode: boolean = false;

  // AI 治理建议相关状态
  @State currentAdvice: string = '';
  @State isAdviceLoading: boolean = false;

  // 弹窗控制器
  dialogController: CustomDialogController = new CustomDialogController({
    builder: DeepSeekAdviceDialog({
      label: this.item.label,
      adviceText: $currentAdvice,
      isLoading: $isAdviceLoading,
      onReAsk: () => { this.fetchAdvice(true); } // 强制重新获取
    }),
    alignment: DialogAlignment.Center,
    customStyle: true
  });

  // 获取 AI 建议逻辑
  async fetchAdvice(forceRefresh: boolean = false) {
    // 首次获取或未强制刷新时，命中缓存直接返回
    if (!forceRefresh && this.item.cachedAdvice) {
      this.currentAdvice = this.item.cachedAdvice;
      return;
    }

    this.isAdviceLoading = true;
    this.currentAdvice = ''; // 清空上一条记录以便显示 Loading

    // 调用 API
    let result = await DeepSeekUtils.getPestAdvice(this.item.label);

    this.currentAdvice = result;
    this.item.cachedAdvice = result; // 缓存到实例中
    this.isAdviceLoading = false;
  }

  // 长按事件处理
  handleLongPress() {
    if (this.isEditMode) return; // 编辑模式下不触发长按操作

    if (this.item.status !== 'success' || !this.item.label) {
      promptAction.showToast({ message: '请等待识别成功后再获取治理建议' });
      return;
    }

    this.dialogController.open();
    this.fetchAdvice(false); // 触发请求（非强制，会优先读缓存）
  }

  // 根据分数获取对应文字颜色
  private getScoreColor(): string {
    if (this.item.score > 0.8) return '#F44336';
    if (this.item.score > 0.5) return '#FF9800';
    return '#4CAF50';
  }

  // 格式化时间戳
  private formatTime(timestamp: number): string {
    let date = new Date(timestamp);
    let year = date.getFullYear();
    let month = (date.getMonth() + 1).toString().padStart(2, '0');
    let day = date.getDate().toString().padStart(2, '0');
    let hours = date.getHours().toString().padStart(2, '0');
    let mins = date.getMinutes().toString().padStart(2, '0');
    return `${year}-${month}-${day} ${hours}:${mins}`;
  }

  build() {
    Row() {
      // 编辑模式下的多选框
      if (this.isEditMode) {
        // 修复：移除 name 和 group 防止冲突，禁用事件冒泡
        Checkbox()
          .select(this.item.isSelected)
          .selectedColor('#2E8B57')
          .hitTestBehavior(HitTestMode.None) // 禁用单选框自己的点击事件，交由外层 Row 处理
          .margin({ right: 12 })
          .animation({ duration: 200, curve: Curve.EaseInOut })
      }

      // 左侧图片
      Image(this.item.imageUri)
        .width(84)
        .height(84)
        .borderRadius(12)
        .objectFit(ImageFit.Cover)
        .backgroundColor('#F0F2F5')
        .border({ width: 1, color: 'rgba(0,0,0,0.05)' })

      // 右侧信息栏
      Column() {
        Row() {
          Text(this.formatTime(this.item.timestamp))
            .fontSize(12)
            .fontColor('#8C929D')
            .fontFamily('Monospace')

          Blank()

          // 状态标签
          if (this.item.status === 'pending') {
            Row() {
              LoadingProgress().width(12).height(12).margin({ right: 4 }).color('#2E8B57')
              Text("识别中").fontSize(11).fontColor('#2E8B57')
            }
            .padding({ left: 6, right: 8, top: 4, bottom: 4 })
            .backgroundColor('#E8F5E9')
            .borderRadius(12)
          } else if (this.item.status === 'success') {
            Text("成功")
              .fontSize(11)
              .fontColor('#FFFFFF')
              .padding({ left: 8, right: 8, top: 4, bottom: 4 })
              .backgroundColor('#2E8B57')
              .borderRadius(12)
          } else {
            Text("失败")
              .fontSize(11)
              .fontColor('#FFFFFF')
              .padding({ left: 8, right: 8, top: 4, bottom: 4 })
              .backgroundColor('#F44336')
              .borderRadius(12)
          }
        }
        .width('100%')
        .margin({ bottom: 8 })

        // 识别结果与详情
        if (this.item.status === 'success') {
          Text(this.item.label)
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor('#2C3E50')
            .margin({ bottom: 6 })
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          Row() {
            Text("置信度: ")
              .fontSize(13)
              .fontColor('#7F8C8D')
            Text((this.item.score * 100).toFixed(1) + "%")
              .fontSize(16)
              .fontWeight(FontWeight.Medium)
              .fontColor(this.getScoreColor())
          }
        } else if (this.item.status === 'pending') {
          Text("等待边缘节点返回...")
            .fontSize(14)
            .fontColor('#95A5A6')
            .margin({ top: 8 })
        } else {
          Text("任务执行失败")
            .fontSize(14)
            .fontColor('#E74C3C')
            .margin({ top: 8 })
        }
      }
      .alignItems(HorizontalAlign.Start)
      .justifyContent(FlexAlign.Center)
      .margin({ left: 16 })
      .layoutWeight(1)
      .height(84)
    }
    .width('100%')
    .padding(16)
    .backgroundColor(this.item.isSelected && this.isEditMode ? '#F0FDF4' : '#FFFFFF')
    .borderRadius(16)
    .shadow({ radius: 12, color: 'rgba(0,0,0,0.04)', offsetY: 4 })
    .onClick(() => {
      // 统一由外层处理选中事件
      if (this.isEditMode) {
        this.item.isSelected = !this.item.isSelected;
      }
    })
    .gesture(
      LongPressGesture({ repeat: false })
        .onAction(() => {
          this.handleLongPress();
        })
    )
    .animation({ duration: 250, curve: Curve.FastOutSlowIn })
  }
}