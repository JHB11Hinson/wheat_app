// 统一定义病害类别中英文对照表
const WheatDiseaseDict: Record<string, string> = {
  "crown and root rot": "冠根腐病",
  "healthy wheat": "健康小麦",
  "leaf rust": "叶锈病",
  "powdery mildew": "白粉病",
  "wheat aphids": "小麦蚜虫",
  "wheat loose smut": "小麦散黑穗病",
  "wheat red spider": "小麦红蜘蛛",
  "wheat take-all": "小麦全蚀病",
  "wheat cyst nematode": "小麦胞囊线虫病",
  "wheat scab": "小麦赤霉病",
  "wheat stalk rot": "小麦茎腐病",
  "wheat sharp eyespot": "小麦纹枯病"
};

export class LabelUtils {
  /**
   * 将英文分类标签转换为中文
   * @param englishLabel 边缘端返回的英文标签
   * @returns 对应的中文标签，如果未匹配则返回原字符串
   */
  static getChineseLabel(englishLabel: string): string {
    if (!englishLabel) {
      return "未知类别";
    }
    // 统一转换为小写并去除首尾空格，增加匹配容错率
    let key = englishLabel.trim().toLowerCase();
    return WheatDiseaseDict[key] || englishLabel;
  }
}