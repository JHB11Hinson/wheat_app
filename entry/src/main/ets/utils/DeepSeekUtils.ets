import http from '@ohos.net.http';

interface ChatMessage {
  role: string;
  content: string;
}

interface ThinkingConfig {
  type: string;
}

interface DeepSeekRequest {
  model: string;
  messages: ChatMessage[];
  thinking: ThinkingConfig;
  reasoning_effort: string;
  stream: boolean;
}


interface ResponseMessage {
  role: string;
  content: string;
}

interface ResponseChoice {
  index: number;
  message: ResponseMessage;
  finish_reason: string;
}

// 这是最外层的返回体结构
interface DeepSeekResponse {
  id: string;
  object: string;
  created: number;
  model: string;
  choices: ResponseChoice[];
}


export class DeepSeekUtils {
  private static readonly API_KEY = 'sk-cc16f17e561c4bb9837add27f71972d1';
  private static readonly API_URL = 'https://api.deepseek.com/chat/completions';

  static async getPestAdvice(pestLabel: string): Promise<string> {
    if (!pestLabel) return '未知的病虫害，无法提供建议。';

    let httpRequest = http.createHttp();
    let promptText = `你是一个专业的农业植保专家。请针对病虫害“${pestLabel}”给出简明的治理建议和可能的形成原因，不要给出MarkDown格式的文本，自然文本即可。`;

    let requestBody: DeepSeekRequest = {
      model: "deepseek-v4-flash",
      messages: [
        { role: "system", content: "You are a helpful agricultural assistant." } as ChatMessage,
        { role: "user", content: promptText } as ChatMessage
      ],
      thinking: { type: "enabled" } as ThinkingConfig,
      reasoning_effort: "high",
      stream: false
    };

    try {
      let response = await httpRequest.request(DeepSeekUtils.API_URL, {
        method: http.RequestMethod.POST,
        header: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${DeepSeekUtils.API_KEY}`
        },
        extraData: JSON.stringify(requestBody),
        readTimeout: 30000,
        connectTimeout: 30000
      });

      if (response.responseCode === 200) {
        let resData = JSON.parse(response.result as string) as DeepSeekResponse;

        if (resData.choices && resData.choices.length > 0) {
          return resData.choices[0].message.content;
        }
      }
      return `获取建议失败 (HTTP ${response.responseCode})，请重试。`;
    } catch (error) {
      // JSON.stringify 可以处理 Error 对象，不需要强转
      console.error('DeepSeek_LOG', `请求异常: ${JSON.stringify(error)}`);
      return '网络请求失败，请检查网络连接。';
    } finally {
      httpRequest.destroy();
    }
  }
}