import 'dart:io';
import 'models.dart';
import 'ai_service.dart';

/// 本地 AI Provider
///
/// 实现方式：
/// 1. 如果配置了本地 GGUF 模型路径 → 通过 MethodChannel 调用 llama.cpp
/// 2. 无模型时 → 使用提取式方法（词频评分 + 关键词匹配）
class LocalAIProvider implements AIService {
  final AIConfig config;

  LocalAIProvider({required this.config});

  @override
  AIProviderType get providerType => AIProviderType.local;

  @override
  bool get isAvailable => true; // 提取式摘要始终可用

  bool get _hasModelFile =>
      config.localModelPath != null &&
      File(config.localModelPath!).existsSync();

  // ============================================================
  // 提取式摘要：基于词频对句子评分，选出最高分句子
  // ============================================================

  @override
  Future<AIResponse> summarize({
    required String pdfText,
    required String pdfName,
  }) async {
    try {
      if (pdfText.trim().isEmpty) {
        return const AIResponse(
          success: true,
          content: '文档内容为空，无法生成摘要。',
        );
      }

      if (_hasModelFile) {
        // TODO: 通过 MethodChannel 调用 llama.cpp 生成摘要
        return const AIResponse(
          success: false,
          error: '本地 LLM 推理尚未集成（可通过云端 API 使用）',
        );
      }

      // 提取式摘要
      final summary = _extractiveSummary(pdfText, maxSentences: 5);
      final keywords = _extractKeywords(pdfText, maxWords: 8);

      return AIResponse(
        success: true,
        content: '📄 **文档**: $pdfName\n\n'
            '🔑 **关键词**: ${keywords.join(", ")}\n\n'
            '📝 **内容摘要**:\n$summary\n\n'
            '---\n'
            '_⚠️ 本地模式使用提取式摘要（基于词频统计）。'
            '配置本地 GGUF 模型或切换云端 API 可获得更智能的生成式摘要。_',
      );
    } catch (e) {
      return AIResponse(success: false, error: '摘要生成失败: $e');
    }
  }

  @override
  Future<AIResponse> askQuestion({
    required String pdfText,
    required String pdfName,
    required String question,
    String? conversationHistory,
  }) async {
    try {
      if (pdfText.trim().isEmpty) {
        return const AIResponse(
          success: true,
          content: '文档内容为空，无法回答问题。',
        );
      }

      if (_hasModelFile) {
        // TODO: 通过 MethodChannel 调用 llama.cpp 问答
        return const AIResponse(
          success: false,
          error: '本地 LLM 推理尚未集成（可通过云端 API 使用）',
        );
      }

      // 基于关键词匹配的简单问答
      final answer = _keywordQA(pdfText, question);
      return AIResponse(
        success: true,
        content: '$answer\n\n---\n'
            '_⚠️ 本地模式使用关键词匹配。'
            '配置本地 GGUF 模型或切换云端 API 可获得更准确的答案。_',
      );
    } catch (e) {
      return AIResponse(success: false, error: '问答失败: $e');
    }
  }

  @override
  Future<AIResponse> translate({
    required String text,
    required String targetLanguage,
  }) async {
    if (_hasModelFile) {
      // TODO: 通过 MethodChannel 调用 llama.cpp 翻译
      return const AIResponse(
        success: false,
        error: '本地 LLM 推理尚未集成（可通过云端 API 使用）',
      );
    }

    // 本地模式不支持翻译
    return AIResponse(
      success: true,
      content: '本地模式不支持翻译功能。\n\n'
          '请切换至 **云端 API** 模式（设置中配置 OpenAI/DeepSeek API Key）\n'
          '或下载 GGUF 模型后使用本地 LLM 推理。\n\n'
          '原始文本：\n$text',
    );
  }

  // ============================================================
  // 提取式摘要算法
  // ============================================================

  String _extractiveSummary(String text, {int maxSentences = 5}) {
    final sentences = _splitSentences(text);
    if (sentences.length <= maxSentences) {
      return sentences.map((s) => '• $s').join('\n');
    }

    // 1. 计算词频
    final wordFreq = <String, int>{};
    for (final sentence in sentences) {
      final words = _tokenize(sentence);
      for (final word in words) {
        wordFreq[word] = (wordFreq[word] ?? 0) + 1;
      }
    }

    // 2. 评分每个句子（基于词频）
    final scored = <_ScoredSentence>[];
    for (int i = 0; i < sentences.length; i++) {
      final words = _tokenize(sentences[i]);
      double score = 0;
      for (final word in words) {
        score += (wordFreq[word] ?? 0).toDouble();
      }
      score = words.isNotEmpty ? score / words.length : 0;

      // 加权：标题/开头句子权重更高
      if (i < 3) score *= 1.3;
      if (_isHeadingSentence(sentences[i])) score *= 1.2;

      scored.add(_ScoredSentence(score: score, text: sentences[i], index: i));
    }

    // 3. 按分数排序取前 N 个，再按原文顺序排列
    scored.sort((a, b) => b.score.compareTo(a.score));
    final topSentences = scored.take(maxSentences).toList();
    topSentences.sort((a, b) => a.index.compareTo(b.index));

    return topSentences.map((s) => '• ${s.text}').join('\n');
  }

  String _keywordQA(String text, String question) {
    final sentences = _splitSentences(text);
    final queryWords = _tokenize(question).map((w) => w.toLowerCase()).toSet();

    if (queryWords.isEmpty) {
      return '请提出更具体的问题。';
    }

    // 评分句子：包含查询词越多分数越高
    final scored = <_ScoredSentence>[];
    for (int i = 0; i < sentences.length; i++) {
      final lowerSentence = sentences[i].toLowerCase();
      int matchCount = 0;
      for (final word in queryWords) {
        if (lowerSentence.contains(word)) matchCount++;
      }
      if (matchCount > 0) {
        scored.add(_ScoredSentence(
          score: matchCount.toDouble() / queryWords.length,
          text: sentences[i],
          index: i,
        ));
      }
    }

    if (scored.isEmpty) {
      return '在文档中未找到与问题相关的内容。\n'
          '请尝试：\n'
          '1. 使用不同的关键词重新提问\n'
          '2. 切换到**云端 API**模式获取更准确的答案';
    }

    scored.sort((a, b) => b.score.compareTo(a.score));
    final topAnswers = scored.take(3).toList();
    topAnswers.sort((a, b) => a.index.compareTo(b.index));

    final buffer = StringBuffer('根据文档内容，找到以下相关信息：\n\n');
    for (final ans in topAnswers) {
      buffer.writeln('📄 ${ans.text}');
      buffer.writeln();
    }
    return buffer.toString().trim();
  }

  // ============================================================
  // 文本处理工具
  // ============================================================

  List<String> _splitSentences(String text) {
    // Remove extra whitespace
    text = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (text.isEmpty) return [];

    // Split by Chinese/English sentence endings
    final parts = text.split(RegExp(r'(?<=[。！？.!?\n])\s*'));
    return parts
        .map((s) => s.trim())
        .where((s) => s.length > 5)
        .toList();
  }

  List<String> _tokenize(String text) {
    // Simple tokenization: split by non-word characters
    // For Chinese: extract 2+ character segments
    final tokens = <String>[];
    final chineseSegments =
        RegExp(r'[\u4e00-\u9fff]{2,}').allMatches(text);

    for (final match in chineseSegments) {
      tokens.add(match.group(0)!);
    }

    // English words (3+ chars, not stop words)
    final stopWords = {
      'the', 'this', 'that', 'and', 'for', 'with', 'from',
      'are', 'was', 'were', 'has', 'have', 'been', 'being',
      'will', 'would', 'could', 'should', 'their', 'there',
      'which', 'what', 'about', 'into', 'than', 'then',
    };
    final englishWords =
        RegExp(r'[a-zA-Z]{3,}').allMatches(text);
    for (final match in englishWords) {
      final word = match.group(0)!.toLowerCase();
      if (!stopWords.contains(word)) tokens.add(word);
    }

    return tokens;
  }

  bool _isHeadingSentence(String s) {
    return s.length < 50 &&
        (s.endsWith('：') ||
            s.endsWith(':') ||
            s.endsWith('') ||
            RegExp(r'^[第章节部篇]').hasMatch(s) ||
            RegExp(r'^\d+[\.、\)）]').hasMatch(s));
  }

  Set<String> _extractKeywords(String text, {int maxWords = 8}) {
    final words = _tokenize(text);
    final freq = <String, int>{};
    for (final w in words) {
      freq[w] = (freq[w] ?? 0) + 1;
    }
    final sorted = freq.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted.take(maxWords).map((e) => e.key).toSet();
  }

  @override
  void dispose() {}
}

class _ScoredSentence {
  final double score;
  final String text;
  final int index;

  const _ScoredSentence({
    required this.score,
    required this.text,
    required this.index,
  });
}
