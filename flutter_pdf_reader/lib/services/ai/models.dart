/// AI 供应商类型
enum AIProviderType {
  cloud,  // 云端 API
  local,  // 本地 LLM
}

/// AI 功能枚举
enum AIFeature {
  summary,    // 总结
  qa,         // 问答
  translate,  // 翻译
}

/// AI 配置
class AIConfig {
  final AIProviderType providerType;
  final String cloudEndpoint;   // OpenAI 兼容 API 地址
  final String cloudApiKey;     // API Key
  final String cloudModel;      // 模型名 (gpt-4o-mini, deepseek-chat 等)
  final String? localModelPath; // 本地 GGUF 模型文件路径

  const AIConfig({
    this.providerType = AIProviderType.cloud,
    this.cloudEndpoint = 'https://api.openai.com/v1',
    this.cloudApiKey = '',
    this.cloudModel = 'gpt-4o-mini',
    this.localModelPath,
  });

  AIConfig copyWith({
    AIProviderType? providerType,
    String? cloudEndpoint,
    String? cloudApiKey,
    String? cloudModel,
    String? localModelPath,
  }) {
    return AIConfig(
      providerType: providerType ?? this.providerType,
      cloudEndpoint: cloudEndpoint ?? this.cloudEndpoint,
      cloudApiKey: cloudApiKey ?? this.cloudApiKey,
      cloudModel: cloudModel ?? this.cloudModel,
      localModelPath: localModelPath ?? this.localModelPath,
    );
  }

  Map<String, dynamic> toJson() => {
        'providerType': providerType.name,
        'cloudEndpoint': cloudEndpoint,
        'cloudApiKey': cloudApiKey,
        'cloudModel': cloudModel,
        'localModelPath': localModelPath,
      };

  factory AIConfig.fromJson(Map<String, dynamic> json) => AIConfig(
        providerType: AIProviderType.values.firstWhere(
          (e) => e.name == json['providerType'],
          orElse: () => AIProviderType.cloud,
        ),
        cloudEndpoint: json['cloudEndpoint'] as String? ?? 'https://api.openai.com/v1',
        cloudApiKey: json['cloudApiKey'] as String? ?? '',
        cloudModel: json['cloudModel'] as String? ?? 'gpt-4o-mini',
        localModelPath: json['localModelPath'] as String?,
      );
}

/// AI 响应
class AIResponse {
  final bool success;
  final String content;
  final String? error;

  const AIResponse({
    required this.success,
    this.content = '',
    this.error,
  });
}

/// PDF 文本片段（用于 AI 上下文）
class PDFTextChunk {
  final int pageNumber;
  final String text;

  const PDFTextChunk({required this.pageNumber, required this.text});
}
