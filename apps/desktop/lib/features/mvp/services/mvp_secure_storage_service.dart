import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Secure storage service for MVP using platform-native secure storage
/// Uses macOS Keychain, Windows Credential Manager, Linux Secret Service
class MvpSecureStorageService {
  static const _openAiKeyKey = 'mvp_openai_api_key';
  static const _anthropicKeyKey = 'mvp_anthropic_api_key';
  static const _tavilyKeyKey = 'mvp_tavily_api_key';

  late final FlutterSecureStorage _secureStorage;
  bool _initialized = false;

  // Singleton pattern for consistent access
  static final MvpSecureStorageService _instance = MvpSecureStorageService._();
  static MvpSecureStorageService get instance => _instance;

  MvpSecureStorageService._() {
    _secureStorage = const FlutterSecureStorage(
      aOptions: AndroidOptions(
        encryptedSharedPreferences: true,
      ),
      iOptions: IOSOptions(
        groupId: 'group.com.asmbli.mvp',
        accountName: 'Asmbli MVP',
        accessibility: KeychainAccessibility.first_unlock_this_device,
      ),
      mOptions: MacOsOptions(
        groupId: 'group.com.asmbli.mvp',
        accountName: 'Asmbli MVP',
        accessibility: KeychainAccessibility.first_unlock_this_device,
      ),
      wOptions: WindowsOptions(),
      lOptions: LinuxOptions(),
    );
  }

  /// Factory constructor for dependency injection
  factory MvpSecureStorageService() => _instance;

  Future<void> initialize() async {
    if (_initialized) return;
    // flutter_secure_storage doesn't require explicit initialization
    // but we mark it initialized for consistency
    _initialized = true;
  }

  // --- OpenAI API Key ---

  Future<void> saveOpenAiApiKey(String key) async {
    if (key.isEmpty) {
      await _secureStorage.delete(key: _openAiKeyKey);
    } else {
      await _secureStorage.write(key: _openAiKeyKey, value: key);
    }
  }

  Future<String?> getOpenAiApiKey() async {
    return await _secureStorage.read(key: _openAiKeyKey);
  }

  Future<void> deleteOpenAiApiKey() async {
    await _secureStorage.delete(key: _openAiKeyKey);
  }

  // --- Anthropic API Key ---

  Future<void> saveAnthropicApiKey(String key) async {
    if (key.isEmpty) {
      await _secureStorage.delete(key: _anthropicKeyKey);
    } else {
      await _secureStorage.write(key: _anthropicKeyKey, value: key);
    }
  }

  Future<String?> getAnthropicApiKey() async {
    return await _secureStorage.read(key: _anthropicKeyKey);
  }

  Future<void> deleteAnthropicApiKey() async {
    await _secureStorage.delete(key: _anthropicKeyKey);
  }

  // --- Tavily API Key ---

  Future<void> saveTavilyApiKey(String key) async {
    if (key.isEmpty) {
      await _secureStorage.delete(key: _tavilyKeyKey);
    } else {
      await _secureStorage.write(key: _tavilyKeyKey, value: key);
    }
  }

  Future<String?> getTavilyApiKey() async {
    return await _secureStorage.read(key: _tavilyKeyKey);
  }

  Future<void> deleteTavilyApiKey() async {
    await _secureStorage.delete(key: _tavilyKeyKey);
  }

  // --- Utility Methods ---

  Future<bool> hasAnyLlmApiKey() async {
    final openAi = await getOpenAiApiKey();
    final anthropic = await getAnthropicApiKey();
    return (openAi?.isNotEmpty ?? false) || (anthropic?.isNotEmpty ?? false);
  }

  Future<void> clearAllApiKeys() async {
    await Future.wait([
      _secureStorage.delete(key: _openAiKeyKey),
      _secureStorage.delete(key: _anthropicKeyKey),
      _secureStorage.delete(key: _tavilyKeyKey),
    ]);
  }

  /// Validate API key format
  bool validateApiKeyFormat(String key, String provider) {
    if (key.isEmpty) return false;

    switch (provider.toLowerCase()) {
      case 'openai':
        return key.startsWith('sk-') && key.length > 20;
      case 'anthropic':
        return key.startsWith('sk-ant-') && key.length > 20;
      case 'tavily':
        return key.startsWith('tvly-') && key.length > 10;
      default:
        return key.length >= 10;
    }
  }
}
