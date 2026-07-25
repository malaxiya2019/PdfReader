import 'dart:convert';
import 'package:http/http.dart' as http;
import 'models.dart';
import 'ai_service.dart';

/// 云端 AI Provider - 兼容 OpenAI / DeepSeek / 任意兼容 API
class CloudAIProvider implements AIService {
  final AIConfig config;

  CloudAIProvider({required this.config});

  @override
  AIProviderType get providerType => AIProviderType.cloud;

  @override
  bool get isAvailable =>
      config.cloudApiKey.isNotEmpty && config.cloudEndpoint.isNotEmpty;

  String get _apiUrl => '${config.cloudEndpoint.replaceAll(RegExp(r'/+$'), '')}/chat/completions';

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${config.cloudApiKey}',
      };

  Future<AIResponse> _chat(String systemPrompt, String userMessage) async {
    try {
      final body = jsonEncode({
        'model': config.cloudModel,
        'messages': [
          {'role': 'system', 'content': systemPrompt},
          {'role': 'user', 'content': userMessage},
        ],
        'temperature': 0.3,
        'max_tokens': 2048,
      });

      final response = await http
          .post(Uri.parse(_apiUrl), headers: _headers, body: body)
          .timeout(const Duration(seconds: 60));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final content =
            data['choices']?[0]?['message']?['content'] as String? ?? '';
        return AIResponse(success: true, content: content.trim());
      } else {
        return AIResponse(
          success: false,
          error: 'API 错误 (${response.statusCode}): ${response.body}',
        );
      }
    } catch (e) {
      return AIResponse(success: false, error: '请求失败: $e');
    }
  }

  @override
  Future<AIResponse> summarize({
    required String pdfText,
    required String pdfName,
  }) async {
    final truncated = _truncate(pdfText, 8000);
    return _chat(
      '你是一个专业的 PDF 文档分析助手。请对用户提供的 PDF 内容进行分析。',
      '请为以下 PDF 文件"$pdfName"生成：\n'
      '1️⃣ **内容摘要**：用 3-5 句话概括文档核心内容\n'
      '2️⃣ **关键要点**：列出 3-6 个最重要的关键点\n'
      '3️⃣ **文档结构**：简要说明文档的组织结构\n\n'
      'PDF 内容：\n$truncated',
    );
  }

  @override
  Future<AIResponse> askQuestion({
    required String pdfText,
    required String pdfName,
    required String question,
    String? conversationHistory,
  }) async {
    final truncated = _truncate(pdfText, 6000);
    final history = conversationHistory ?? '';
    return _chat(
      '你是一个 PDF 文档问答助手。基于提供的 PDF 内容回答用户的问题。'
      '如果问题在文档中找不到答案，请如实说明，不要编造。',
      '文档"$pdfName"的内容：\n$truncated\n\n'
      '${history.isNotEmpty ? "对话历史：\n$history\n\n" : ""}'
      '用户问题：$question',
    );
  }

  @override
  Future<AIResponse> translate({
    required String text,
    required String targetLanguage,
  }) async {
    if (text.length > 4000) text = text.substring(0, 4000);
    return _chat(
      '你是一个专业翻译助手。请将用户提供的文本翻译成$targetLanguage。'
      '只返回翻译结果，不要添加解释。保持原文格式。',
      '请翻译以下内容为$targetLanguage：\n\n$text',
    );
  }

  String _truncate(String text, int maxChars) {
    if (text.length <= maxChars) return text;
    return '${text.substring(0, maxChars)}\n\n...[内容过长，已截断]...';
  }

  @override
  void dispose() {}
}
