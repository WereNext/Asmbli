import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/mvp_message.dart';
import '../models/mvp_settings.dart';
import 'mvp_secure_storage_service.dart';

/// Storage service for MVP - combines SharedPreferences and Secure Storage
///
/// - API keys: Stored in platform-native secure storage (Keychain/Credential Manager)
/// - Settings: Stored in SharedPreferences (not sensitive)
/// - Messages: Stored in SharedPreferences (local only)
class MvpStorageService {
  static const _settingsKey = 'mvp_settings';
  static const _messagesKey = 'mvp_messages';
  static const _setupCompleteKey = 'mvp_setup_complete';
  static const _proxyEnabledKey = 'mvp_proxy_enabled';
  static const _ollamaEnabledKey = 'mvp_ollama_enabled';
  static const _ollamaBaseUrlKey = 'mvp_ollama_base_url';

  SharedPreferences? _prefs;
  final MvpSecureStorageService _secureStorage = MvpSecureStorageService.instance;

  Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
    await _secureStorage.initialize();
  }

  SharedPreferences get _preferences {
    if (_prefs == null) {
      throw StateError('MvpStorageService not initialized. Call initialize() first.');
    }
    return _prefs!;
  }

  // --- API Keys (Secure Storage) ---

  Future<void> saveOpenAiApiKey(String key) async {
    await _secureStorage.saveOpenAiApiKey(key);
  }

  Future<String?> getOpenAiApiKey() async {
    return await _secureStorage.getOpenAiApiKey();
  }

  Future<void> saveAnthropicApiKey(String key) async {
    await _secureStorage.saveAnthropicApiKey(key);
  }

  Future<String?> getAnthropicApiKey() async {
    return await _secureStorage.getAnthropicApiKey();
  }

  Future<void> saveTavilyApiKey(String key) async {
    await _secureStorage.saveTavilyApiKey(key);
  }

  Future<String?> getTavilyApiKey() async {
    return await _secureStorage.getTavilyApiKey();
  }

  Future<bool> hasAnyApiKey() async {
    return await _secureStorage.hasAnyLlmApiKey();
  }

  // --- Settings (SharedPreferences) ---

  Future<void> saveSettings(MvpSettings settings) async {
    await _preferences.setString(_settingsKey, jsonEncode(settings.toJson()));
  }

  MvpSettings getSettings() {
    final json = _preferences.getString(_settingsKey);
    if (json == null) return MvpSettings.defaults();
    try {
      return MvpSettings.fromJson(jsonDecode(json));
    } catch (_) {
      return MvpSettings.defaults();
    }
  }

  // --- Proxy Settings ---

  Future<void> setProxyEnabled(bool enabled) async {
    await _preferences.setBool(_proxyEnabledKey, enabled);
  }

  bool isProxyEnabled() {
    return _preferences.getBool(_proxyEnabledKey) ?? false;
  }

  // --- Ollama Settings ---

  Future<void> setOllamaEnabled(bool enabled) async {
    await _preferences.setBool(_ollamaEnabledKey, enabled);
  }

  bool isOllamaEnabled() {
    return _preferences.getBool(_ollamaEnabledKey) ?? false;
  }

  Future<void> setOllamaBaseUrl(String url) async {
    await _preferences.setString(_ollamaBaseUrlKey, url);
  }

  String getOllamaBaseUrl() {
    return _preferences.getString(_ollamaBaseUrlKey) ?? 'http://localhost:11434';
  }

  // --- Conversation History (SharedPreferences) ---

  Future<void> saveMessages(List<MvpMessage> messages) async {
    final json = messages.map((m) => m.toJson()).toList();
    await _preferences.setString(_messagesKey, jsonEncode(json));
  }

  List<MvpMessage> getMessages() {
    final json = _preferences.getString(_messagesKey);
    if (json == null) return [];
    try {
      final list = jsonDecode(json) as List;
      return list
          .map((m) => MvpMessage.fromJson(m as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> clearMessages() async {
    await _preferences.remove(_messagesKey);
  }

  // --- Setup State ---

  Future<void> setSetupComplete(bool complete) async {
    await _preferences.setBool(_setupCompleteKey, complete);
  }

  bool isSetupComplete() {
    return _preferences.getBool(_setupCompleteKey) ?? false;
  }

  // --- Clear All ---

  Future<void> clearAll() async {
    await _secureStorage.clearAllApiKeys();
    await _preferences.remove(_settingsKey);
    await _preferences.remove(_messagesKey);
    await _preferences.remove(_setupCompleteKey);
    await _preferences.remove(_proxyEnabledKey);
  }
}
