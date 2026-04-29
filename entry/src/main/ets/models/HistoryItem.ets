@Observed
export class HistoryItem {
  taskId: string;
  imageUri: string | Resource;
  status: 'pending' | 'success' | 'failed';
  label: string;
  score: number;
  isSnapshot: boolean;
  timestamp: number;
  isSelected: boolean;
  cachedAdvice?: string;

  constructor(taskId: string, imageUri: string | Resource, isSnapshot: boolean = false, timestamp?: number) {
    this.taskId = taskId;
    this.imageUri = imageUri;
    this.status = 'pending';
    this.label = '';
    this.score = 0;
    this.isSnapshot = isSnapshot;
    this.timestamp = timestamp || new Date().getTime();
    this.isSelected = false;
  }
}