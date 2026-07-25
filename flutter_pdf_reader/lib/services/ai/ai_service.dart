import 'models.dart';

/// AI 服务抽象接口
abstract class AIService {
  /// 获取供应商类型
  AIProviderType get providerType;

  /// 是否可用（已配置）
  bool get isAvailable;

  /// PDF 总结
  Future<AIResponse> summarize({
    required String pdfText,
    required String pdfName,
  });

  /// PDF 问答
  Future<AIResponse> askQuestion({
    required String pdfText,
    required String pdfName,
    required String question,
    String? conversationHistory,
  });

  /// 翻译
  Future<AIResponse> translate({
    required String text,
    required String targetLanguage, // '中文' or 'English'
  });

  /// 释放资源
  void dispose();
}
