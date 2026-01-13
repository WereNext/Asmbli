import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/mvp_message.dart';
import '../models/mvp_settings.dart';

/// Simple storage service for MVP using SharedPreferences
/// Stores: API keys, settings, conversation history
class MvpStorageService {
  static const _openAiKeyKey = 'mvp_openai_api_key';
  static const _anthropicKeyKey = 'mvp_anthropic_api_key';
  static const _tavilyKeyKey = 'mvp_tavily_api_key';
  static const _settingsKey = 'mvp_settings';
  static const _messagesKey = 'mvp_messages';
  static const _setupCompleteKey = 'mvp_setup_complete';

  SharedPreferences? _prefs;

  Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
  }

  SharedPreferences get _preferences {
    if (_prefs == null) {
      throw StateError('MvpStorageService not initialized. Call initialize() first.');
    }
    return _prefs!;
  }

  // --- API Keys ---

  Future<void> saveOpenAiApiKey(String key) async {
    await _preferences.setString(_openAiKeyKey, key);
  }

  String? getOpenAiApiKey() {
    return _preferences.getString(_openAiKeyKey);
  }

  Future<void> saveAnthropicApiKey(String key) async {
    await _preferences.setString(_anthropicKeyKey, key);
  }

  String? getAnthropicApiKey() {
    return _preferences.getString(_anthropicKeyKey);
  }

  Future<void> saveTavilyApiKey(String key) async {
    await _preferences.setString(_tavilyKeyKey, key);
  }

  String? getTavilyApiKey() {
    return _preferences.getString(_tavilyKeyKey);
  }

  bool hasAnyApiKey() {
    final openAi = getOpenAiApiKey();
    final anthropic = getAnthropicApiKey();
    return (openAi?.isNotEmpty ?? false) || (anthropic?.isNotEmpty ?? false);
  }

  // --- Settings ---

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

  // --- Conversation History ---

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
    await _preferences.remove(_openAiKeyKey);
    await _preferences.remove(_anthropicKeyKey);
    await _preferences.remove(_tavilyKeyKey);
    await _preferences.remove(_settingsKey);
    await _preferences.remove(_messagesKey);
    await _preferences.remove(_setupCompleteKey);
  }
}
