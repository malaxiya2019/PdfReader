import 'package:flutter/material.dart';
import '../../services/ai/models.dart';
import '../../services/ai/ai_factory.dart';
import '../settings/ai_settings_page.dart';

class AIAssistantPage extends StatefulWidget {
  final String pdfText;
  final String pdfName;

  const AIAssistantPage({
    super.key,
    required this.pdfText,
    required this.pdfName,
  });

  @override
  State<AIAssistantPage> createState() => _AIAssistantPageState();
}

class _AIAssistantPageState extends State<AIAssistantPage> {
  final _questionController = TextEditingController();
  final _scrollController = ScrollController();
  final _messages = <_ChatMessage>[];
  bool _isLoading = false;
  String? _conversationHistory;

  // 翻译状态
  String? _translationResult;
  String _translationTarget = '中文';

  @override
  void dispose() {
    _questionController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _summarize() async {
    setState(() {
      _isLoading = true;
      _messages.add(_ChatMessage(
        content: '🤖 正在生成 PDF 总结...',
        isUser: false,
        isLoading: true,
      ));
    });

    final result = await AIFactory.service.summarize(
      pdfText: widget.pdfText,
      pdfName: widget.pdfName,
    );

    setState(() {
      _isLoading = false;
      _messages.removeLast();
      if (result.success) {
        _messages.add(_ChatMessage(content: result.content, isUser: false));
        _conversationHistory =
            'AI 提供了 PDF 总结。\n${result.content}\n';
      } else {
        _messages.add(_ChatMessage(
            content: '❌ ${result.error ?? "未知错误"}', isUser: false));
      }
    });
    _scrollToBottom();
  }

  Future<void> _askQuestion() async {
    final question = _questionController.text.trim();
    if (question.isEmpty) return;

    setState(() {
      _messages.add(_ChatMessage(content: question, isUser: true));
      _messages.add(_ChatMessage(
        content: '🤖 正在思考...',
        isUser: false,
        isLoading: true,
      ));
    });

    _questionController.clear();

    final result = await AIFactory.service.askQuestion(
      pdfText: widget.pdfText,
      pdfName: widget.pdfName,
      question: question,
      conversationHistory: _conversationHistory,
    );

    setState(() {
      _isLoading = false;
      _messages.removeLast();
      if (result.success) {
        _messages.add(_ChatMessage(content: result.content, isUser: false));
        _conversationHistory =
            '${_conversationHistory ?? ""}\n用户: $question\nAI: ${result.content}\n';
      } else {
        _messages.add(_ChatMessage(
            content: '❌ ${result.error ?? "未知错误"}', isUser: false));
      }
    });
    _scrollToBottom();
  }

  Future<void> _translate() async {
    final text = widget.pdfText.length > 3000
        ? widget.pdfText.substring(0, 3000)
        : widget.pdfText;

    setState(() {
      _messages.add(_ChatMessage(
        content: '🌐 正在翻译为 $_translationTarget...',
        isUser: false,
        isLoading: true,
      ));
    });

    final result = await AIFactory.service.translate(
      text: text,
      targetLanguage: _translationTarget,
    );

    setState(() {
      _messages.removeLast();
      if (result.success) {
        _messages.add(_ChatMessage(content: result.content, isUser: false));
      } else {
        _messages.add(_ChatMessage(
            content: '❌ ${result.error ?? "翻译失败"}', isUser: false));
      }
    });
    _scrollToBottom();
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isCloud = AIFactory.service.providerType == AIProviderType.cloud;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Text('🤖 AI 助手'),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: isCloud
                    ? theme.colorScheme.primary.withOpacity(0.15)
                    : theme.colorScheme.secondary.withOpacity(0.15),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                isCloud ? '云端' : '本地',
                style: TextStyle(
                  fontSize: 10,
                  color:
                      isCloud ? theme.colorScheme.primary : theme.colorScheme.secondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AISettingsPage()),
              );
              // 重新加载后刷新
              if (mounted) setState(() {});
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Message list
          Expanded(
            child: _messages.isEmpty
                ? _buildWelcome(theme, isCloud)
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final msg = _messages[index];
                      return _buildMessageBubble(msg, theme);
                    },
                  ),
          ),

          // Translation target selector (when not loading)
          if (_translationResult == null && !_isLoading && _messages.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  const Spacer(),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: '中文', label: Text('→ 中文', style: TextStyle(fontSize: 11))),
                      ButtonSegment(value: 'English', label: Text('→ English', style: TextStyle(fontSize: 11))),
                    ],
                    selected: {_translationTarget},
                    onSelectionChanged: (s) =>
                        setState(() => _translationTarget = s.first),
                    style: ButtonStyle(
                      visualDensity: VisualDensity.compact,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ],
              ),
            ),

          // Quick actions
          if (_messages.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: _actionButton(
                      icon: Icons.summarize,
                      label: '总结',
                      color: theme.colorScheme.primary,
                      onTap: _summarize,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _actionButton(
                      icon: Icons.translate,
                      label: '翻译',
                      color: theme.colorScheme.secondary,
                      onTap: _translate,
                    ),
                  ),
                ],
              ),
            ),

          // Input area
          if (_messages.isNotEmpty)
            Container(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                border: Border(
                  top: BorderSide(
                      color: theme.colorScheme.outline.withOpacity(0.1)),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _questionController,
                      style: TextStyle(
                          color: theme.colorScheme.onSurface, fontSize: 14),
                      decoration: InputDecoration(
                        hintText: '输入问题...',
                        filled: true,
                        fillColor: theme.cardColor,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                      ),
                      onSubmitted: (_) => _askQuestion(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _askQuestion,
                    icon: const Icon(Icons.send, size: 18),
                    style: IconButton.styleFrom(
                      backgroundColor: theme.colorScheme.primary,
                      foregroundColor: theme.colorScheme.onPrimary,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildWelcome(ThemeData theme, bool isCloud) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('🤖', style: TextStyle(fontSize: 64)),
            const SizedBox(height: 16),
            Text(
              'AI PDF 助手',
              style: TextStyle(
                  color: theme.colorScheme.onSurface,
                  fontSize: 22,
                  fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              '当前 PDF：${widget.pdfName}',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: theme.colorScheme.onSurface.withOpacity(0.5),
                  fontSize: 13),
            ),
            const SizedBox(height: 24),
            Text(
              isCloud ? '☁️ 云端模式' : '📱 本地模式',
              style: TextStyle(
                  color: isCloud
                      ? theme.colorScheme.primary
                      : theme.colorScheme.secondary,
                  fontSize: 14,
                  fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(
              isCloud ? '已连接 API，可生成式 AI 回答' : '提取式摘要（无需网络）',
              style: TextStyle(
                  color: theme.colorScheme.onSurface.withOpacity(0.4),
                  fontSize: 12),
            ),
            const SizedBox(height: 32),
            Text(
              '点击下方按钮开始使用',
              style: TextStyle(
                  color: theme.colorScheme.onSurface.withOpacity(0.4),
                  fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageBubble(_ChatMessage msg, ThemeData theme) {
    if (msg.isUser) {
      return Align(
        alignment: Alignment.centerRight,
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.75),
          decoration: BoxDecoration(
            color: theme.colorScheme.primary,
            borderRadius: BorderRadius.circular(16).copyWith(
              bottomRight: Radius.zero,
            ),
          ),
          child: Text(msg.content,
              style: TextStyle(color: theme.colorScheme.onPrimary)),
        ),
      );
    }

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        constraints:
            BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.85),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(16).copyWith(
            bottomLeft: Radius.zero,
          ),
        ),
        child: msg.isLoading
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: theme.colorScheme.primary),
                  ),
                  const SizedBox(width: 8),
                  Text('处理中...',
                      style: TextStyle(
                          color: theme.colorScheme.onSurface.withOpacity(0.5),
                          fontSize: 13)),
                ],
              )
            : SelectableText(msg.content,
                style: TextStyle(
                    color: theme.colorScheme.onSurface,
                    fontSize: 14,
                    height: 1.5)),
      ),
    );
  }

  Widget _actionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      color: color.withOpacity(0.1),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            children: [
              Icon(icon, color: color, size: 32),
              const SizedBox(height: 8),
              Text(label,
                  style: TextStyle(
                      color: color,
                      fontSize: 14,
                      fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChatMessage {
  final String content;
  final bool isUser;
  final bool isLoading;

  const _ChatMessage({
    required this.content,
    required this.isUser,
    this.isLoading = false,
  });
}
