import { MqttAsync, MqttClient, MqttConnectOptions, MqttMessage, MqttPublishOptions } from '@ohos/mqtt';
import { promptAction } from '@kit.ArkUI';

export class MqttService {
  private client: MqttClient | null = null;
  public isConnected: boolean = false;
  private onResultCallback?: (taskId: string, label: string, score: number) => void;

  private onMessageArrived = (err: Error, data: MqttMessage) => {
    if (data && data.topic && data.payload) {
      this.parseResult(data.topic, data.payload);
    }
  }

  async init(ip: string, onResult: (taskId: string, label: string, score: number) => void) {
    this.onResultCallback = onResult;
    try {
      let serverUrl = `tcp://${ip}:1883`;
      let safeClientId = "app_" + new Date().getTime().toString().slice(-8);

      this.client = await MqttAsync.createMqtt({
        url: serverUrl,
        clientId: safeClientId,
        persistenceType: 1
      });

      let connectOptions: MqttConnectOptions = {
        connectTimeout: 30,
        cleanSession: true
      };

      await this.client.connect(connectOptions);
      this.isConnected = true;
      promptAction.showToast({ message: '节点直连成功' });

      this.client.messageArrived(this.onMessageArrived);
      await this.client.subscribe({ topic: "camera/result/#", qos: 1 });
    } catch (e) {
      console.error("MQTT_LOG", "连接失败: ", JSON.stringify(e));
      promptAction.showToast({ message: '节点连接异常' });
    }
  }

  async disconnect() {
    if (this.client && this.isConnected) {
      try {
        await this.client.disconnect();
        this.isConnected = false;
        console.info("MQTT_LOG", "MQTT 已断开");
      } catch (e) {
        console.error("MQTT_LOG", "断开连接失败: ", JSON.stringify(e));
      }
    }
  }

  private parseResult(topic: string, payload: string) {
    let parts = topic.split('/');
    if (parts.length >= 3) {
      let taskId = parts[2];
      try {
        let resultObj = JSON.parse(payload) as Record<string, Object>;
        let labelStr = resultObj['class'] as string;
        let scoreNum = resultObj['score'] as number;
        if (this.onResultCallback) {
          this.onResultCallback(taskId, labelStr, scoreNum);
        }
      } catch (e) {
        console.error("JSON解析失败: ", e);
      }
    }
  }

  async publishImageStream(taskId: string, buffer: ArrayBuffer): Promise<boolean> {
    if (!this.client || !this.isConnected) return false;
    try {
      let pubOptions: MqttPublishOptions = {
        topic: "camera/stream/" + taskId,
        payloadBinary: buffer,
        qos: 1
      };
      await this.client.publish(pubOptions);
      return true;
    } catch (e) {
      return false;
    }
  }
}