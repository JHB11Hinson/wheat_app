import relationalStore from '@ohos.data.relationalStore';
import { HistoryItem } from '../models/HistoryItem';

const STORE_CONFIG: relationalStore.StoreConfig = {
  name: 'WheatDiseaseHistory.db',
  securityLevel: relationalStore.SecurityLevel.S1
};

const TABLE_NAME = 'HISTORY_TABLE';
const SQL_CREATE_TABLE = `CREATE TABLE IF NOT EXISTS ${TABLE_NAME} (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  taskId TEXT NOT NULL,
  imageUri TEXT NOT NULL,
  status TEXT NOT NULL,
  label TEXT,
  score REAL,
  isSnapshot INTEGER,
  timestamp INTEGER
)`;

let rdbStore: relationalStore.RdbStore | null = null;

export class DatabaseUtils {
  static async initDb(context: Context): Promise<void> {
    try {
      rdbStore = await relationalStore.getRdbStore(context, STORE_CONFIG);
      await rdbStore.executeSql(SQL_CREATE_TABLE);
      console.info('DB_LOG', '数据库初始化成功');
    } catch (err) {
      console.error('DB_LOG', `数据库初始化失败 : ${JSON.stringify(err)}`);
    }
  }

  static async insertHistory(item: HistoryItem): Promise<void> {
    if (!rdbStore) return;
    const valueBucket: relationalStore.ValuesBucket = {
      taskId: item.taskId,
      imageUri: typeof item.imageUri === 'string' ? item.imageUri : '',
      status: item.status,
      label: item.label,
      score: item.score,
      isSnapshot: item.isSnapshot ? 1 : 0,
      timestamp: item.timestamp // 存入时间戳
    };
    try {
      await rdbStore.insert(TABLE_NAME, valueBucket);
      console.info('DB_LOG', `插入数据成功 : ${item.taskId}`);
    } catch (err) {
      console.error('DB_LOG', `插入数据失败 : ${JSON.stringify(err)}`);
    }
  }

  static async updateHistory(taskId: string, status: string, label: string = '', score: number = 0): Promise<void> {
    if (!rdbStore) return;
    const valueBucket: relationalStore.ValuesBucket = {
      status: status,
      label: label,
      score: score
    };
    let predicates = new relationalStore.RdbPredicates(TABLE_NAME);
    predicates.equalTo('taskId', taskId);
    try {
      await rdbStore.update(valueBucket, predicates);
      console.info('DB_LOG', `更新数据成功 : ${taskId}`);
    } catch (err) {
      console.error('DB_LOG', `更新数据失败 : ${JSON.stringify(err)}`);
    }
  }

  // 支持传入时间范围进行查询过滤
  static async queryAllHistory(startTime?: number, endTime?: number): Promise<HistoryItem[]> {
    if (!rdbStore) return [];
    let predicates = new relationalStore.RdbPredicates(TABLE_NAME);

    // 如果传入了时间范围，则增加 between 过滤
    if (startTime && endTime) {
      predicates.between('timestamp', startTime, endTime);
    }

    // 按时间倒序排列，最新的在前面
    predicates.orderByDesc('timestamp');

    let list: HistoryItem[] = [];
    try {
      let resultSet = await rdbStore.query(predicates, ['taskId', 'imageUri', 'status', 'label', 'score', 'isSnapshot', 'timestamp']);
      while (resultSet.goToNextRow()) {
        let taskId = resultSet.getString(resultSet.getColumnIndex('taskId'));
        let imageUri = resultSet.getString(resultSet.getColumnIndex('imageUri'));
        let status = resultSet.getString(resultSet.getColumnIndex('status')) as 'pending' | 'success' | 'failed';
        let label = resultSet.getString(resultSet.getColumnIndex('label'));
        let score = resultSet.getDouble(resultSet.getColumnIndex('score'));
        let isSnapshot = resultSet.getLong(resultSet.getColumnIndex('isSnapshot')) === 1;
        let timestamp = resultSet.getLong(resultSet.getColumnIndex('timestamp'));

        let item = new HistoryItem(taskId, imageUri, isSnapshot, timestamp);
        item.status = status;
        item.label = label;
        item.score = score;
        list.push(item);
      }
      resultSet.close();
    } catch (err) {
      console.error('DB_LOG', `查询历史记录失败 : ${JSON.stringify(err)}`);
    }
    return list;
  }

  // 根据 taskId 列表批量删除
  static async deleteHistory(taskIds: string[]): Promise<void> {
    if (!rdbStore || taskIds.length === 0) return;
    let predicates = new relationalStore.RdbPredicates(TABLE_NAME);
    predicates.in('taskId', taskIds);
    try {
      await rdbStore.delete(predicates);
      console.info('DB_LOG', `批量删除成功，共 ${taskIds.length} 条`);
    } catch (err) {
      console.error('DB_LOG', `批量删除失败 : ${JSON.stringify(err)}`);
    }
  }

  // 一键删除所有状态为 failed 的记录
  static async deleteFailedHistory(): Promise<void> {
    if (!rdbStore) return;
    let predicates = new relationalStore.RdbPredicates(TABLE_NAME);
    predicates.equalTo('status', 'failed');
    try {
      await rdbStore.delete(predicates);
      console.info('DB_LOG', `清除所有失败记录成功`);
    } catch (err) {
      console.error('DB_LOG', `清除失败记录失败 : ${JSON.stringify(err)}`);
    }
  }
}