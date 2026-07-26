import 'package:flutter/material.dart';
import '../../services/ai/models.dart';
import '../../services/ai/ai_factory.dart';

class AISettingsPage extends StatefulWidget {
  const AISettingsPage({super.key});

  @override
  State<AISettingsPage> createState() => _AISettingsPageState();
}

class _AISettingsPageState extends State<AISettingsPage> {
  AIConfig _config = const AIConfig();
  bool _loading = true;
  bool _saving = false;
  bool _showApiKey = false;

  final _endpointController = TextEditingController();
  final _apiKeyController = TextEditingController();
  final _modelController = TextEditingController();
  final _modelPathController = TextEditingController();

  static const _presetEndpoints = [
    ('OpenAI', 'https://api.openai.com/v1', 'gpt-4o-mini'),
    ('DeepSeek', 'https://api.deepseek.com', 'deepseek-chat'),
    ('自定义', '', ''),
  ];

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  @override
  void dispose() {
    _endpointController.dispose();
    _apiKeyController.dispose();
    _modelController.dispose();
    _modelPathController.dispose();
    super.dispose();
  }

  Future<void> _loadConfig() async {
    _config = await AIFactory.loadConfig();
    _endpointController.text = _config.cloudEndpoint;
    _apiKeyController.text = _config.cloudApiKey;
    _modelController.text = _config.cloudModel;
    _modelPathController.text = _config.localModelPath ?? '';
    setState(() => _loading = false);
  }

  Future<void> _save() async {
    setState(() => _saving = true);

    final newConfig = _config.copyWith(
      cloudEndpoint: _endpointController.text.trim(),
      cloudApiKey: _apiKeyController.text.trim(),
      cloudModel: _modelController.text.trim(),
      localModelPath: _modelPathController.text.trim().isEmpty
          ? null
          : _modelPathController.text.trim(),
    );

    await AIFactory.switchProvider(newConfig);
    setState(() {
      _config = newConfig;
      _saving = false;
    });

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('AI 配置已保存'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('AI 设置'), centerTitle: true),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('AI 设置'),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ---- 供应商选择 ----
          Text('供应商',
              style: TextStyle(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                  fontSize: 14,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          SegmentedButton<AIProviderType>(
            segments: const [
              ButtonSegment(
                value: AIProviderType.cloud,
                label: Text('云端 API'),
                icon: Icon(Icons.cloud, size: 18),
              ),
              ButtonSegment(
                value: AIProviderType.local,
                label: Text('本地 LLM'),
                icon: Icon(Icons.phone_android, size: 18),
              ),
            ],
            selected: {_config.providerType},
            onSelectionChanged: (s) =>
                setState(() => _config = _config.copyWith(providerType: s.first)),
          ),
          const SizedBox(height: 24),

          if (_config.providerType == AIProviderType.cloud) ...[
            // ---- 云端 API 配置 ----
            Text('API 端点',
                style: TextStyle(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                    fontSize: 14,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _presetEndpoints.map((ep) {
                final selected = _endpointController.text == ep.$1 ||
                    _endpointController.text == ep.$2;
                return ActionChip(
                  avatar: Icon(
                    ep.$1 == 'OpenAI'
                        ? Icons.auto_awesome
                        : ep.$1 == 'DeepSeek'
                            ? Icons.explore
                            : Icons.settings,
                    size: 16,
                    color: selected ? theme.colorScheme.primary : null,
                  ),
                  label: Text(ep.$1, style: const TextStyle(fontSize: 12)),
                  onPressed: () {
                    setState(() {
                      _endpointController.text = ep.$2;
                      if (ep.$3.isNotEmpty) _modelController.text = ep.$3;
                    });
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _endpointController,
              style: TextStyle(color: theme.colorScheme.onSurface, fontSize: 14),
              decoration: _inputDec('API 地址', 'https://api.openai.com/v1'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _apiKeyController,
              obscureText: !_showApiKey,
              style: TextStyle(color: theme.colorScheme.onSurface, fontSize: 14),
              decoration: _inputDec('API Key', 'sk-...').copyWith(
                suffixIcon: IconButton(
                  icon: Icon(
                      _showApiKey ? Icons.visibility_off : Icons.visibility),
                  onPressed: () => setState(() => _showApiKey = !_showApiKey),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _modelController,
              style: TextStyle(color: theme.colorScheme.onSurface, fontSize: 14),
              decoration: _inputDec('模型名称', 'gpt-4o-mini / deepseek-chat'),
            ),

            // Provider info
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline,
                      color: theme.colorScheme.primary, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '云端模式需要 API Key。支持所有兼容 OpenAI 格式的 API。'
                      '推荐：DeepSeek（便宜）、OpenAI（高质量）',
                      style: TextStyle(
                          color: theme.colorScheme.primary, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            // ---- 本地 LLM 配置 ----
            Text('模型文件路径',
                style: TextStyle(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                    fontSize: 14,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            TextField(
              controller: _modelPathController,
              style: TextStyle(color: theme.colorScheme.onSurface, fontSize: 14),
              decoration: _inputDec(
                  'GGUF 模型路径', '/storage/emulated/0/Models/model.gguf'),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.secondary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline,
                      color: theme.colorScheme.secondary, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '本地模式使用提取式摘要（词频分析），无需下载模型。',
                          style: TextStyle(
                              color: theme.colorScheme.secondary, fontSize: 12),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '如需完整 LLM 推理，需下载 GGUF 格式模型文件并填写路径。',
                          style: TextStyle(
                              color:
                                  theme.colorScheme.secondary.withValues(alpha: 0.7),
                              fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 32),

          // ---- 保存 ----
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.save, size: 18),
              label: Text(_saving ? '保存中...' : '保存配置'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDec(String label, String hint) {
    final theme = Theme.of(context);
    return InputDecoration(
      labelText: label,
      hintText: hint,
      filled: true,
      fillColor: theme.cardColor,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      labelStyle: TextStyle(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.5), fontSize: 13),
    );
  }
}
