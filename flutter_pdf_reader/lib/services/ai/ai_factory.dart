import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'models.dart';
import 'ai_service.dart';
import 'cloud_ai_provider.dart';
import 'local_ai_provider.dart';

/// AI 服务工厂 - 管理配置和创建 Provider
class AIFactory {
  static const _prefsKey = 'ai_config';

  static AIService? _instance;

  /// 获取当前 AI 服务实例
  static AIService get service {
    if (_instance == null) {
      throw StateError('AI 服务未初始化，请先调用 AIFactory.init()');
    }
    return _instance!;
  }

  /// 初始化 AI 服务
  static Future<void> init() async {
    final config = await loadConfig();
    _instance = _createService(config);
  }

  /// 根据配置创建服务
  static AIService _createService(AIConfig config) {
    switch (config.providerType) {
      case AIProviderType.cloud:
        return CloudAIProvider(config: config);
      case AIProviderType.local:
        return LocalAIProvider(config: config);
    }
  }

  /// 切换供应商
  static Future<void> switchProvider(AIConfig newConfig) async {
    await saveConfig(newConfig);
    _instance?.dispose();
    _instance = _createService(newConfig);
  }

  /// 重新加载配置
  static Future<void> reload() async {
    final config = await loadConfig();
    _instance?.dispose();
    _instance = _createService(config);
  }

  /// 从 SharedPreferences 加载配置
  static Future<AIConfig> loadConfig() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_prefsKey);
    if (jsonStr == null) return const AIConfig();
    try {
      return AIConfig.fromJson(jsonDecode(jsonStr) as Map<String, dynamic>);
    } catch (_) {
      return const AIConfig();
    }
  }

  /// 保存配置到 SharedPreferences
  static Future<void> saveConfig(AIConfig config) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, jsonEncode(config.toJson()));
  }

  /// 获取当前配置
  static Future<AIConfig> getConfig() => loadConfig();
}
