import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Secure storage service for MVP using platform-native secure storage
/// Uses macOS Keychain, Windows Credential Manager, Linux Secret Service
/// Falls back to SharedPreferences if secure storage fails (dev mode)
class MvpSecureStorageService {
  static const _openAiKeyKey = 'mvp_openai_api_key';
  static const _anthropicKeyKey = 'mvp_anthropic_api_key';
  static const _tavilyKeyKey = 'mvp_tavily_api_key';

  late final FlutterSecureStorage _secureStorage;
  SharedPreferences? _prefs;
  bool _initialized = false;
  bool _useSecureStorage = true; // Falls back to false if keychain fails

  // Singleton pattern for consistent access
  static final MvpSecureStorageService _instance = MvpSecureStorageService._();
  static MvpSecureStorageService get instance => _instance;

  MvpSecureStorageService._() {
    // Use simpler options that work without keychain-access-groups entitlement
    _secureStorage = const FlutterSecureStorage(
      aOptions: AndroidOptions(
        encryptedSharedPreferences: true,
      ),
      iOptions: IOSOptions(
        accessibility: KeychainAccessibility.first_unlock_this_device,
      ),
      mOptions: MacOsOptions(
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

    // Test if secure storage works
    try {
      await _secureStorage.read(key: '__test__');
      _useSecureStorage = true;
    } catch (e) {
      // Secure storage failed (likely missing entitlements in dev mode)
      // Fall back to SharedPreferences
      print('⚠️ Secure storage unavailable, using SharedPreferences fallback: $e');
      _useSecureStorage = false;
      _prefs = await SharedPreferences.getInstance();
    }

    _initialized = true;
  }

  Future<void> _ensureInitialized() async {
    if (!_initialized) {
      await initialize();
    }
  }

  // --- Storage abstraction ---

  Future<void> _write(String key, String value) async {
    await _ensureInitialized();
    if (_useSecureStorage) {
      await _secureStorage.write(key: key, value: value);
    } else {
      await _prefs?.setString(key, value);
    }
  }

  Future<String?> _read(String key) async {
    await _ensureInitialized();
    if (_useSecureStorage) {
      return await _secureStorage.read(key: key);
    } else {
      return _prefs?.getString(key);
    }
  }

  Future<void> _delete(String key) async {
    await _ensureInitialized();
    if (_useSecureStorage) {
      await _secureStorage.delete(key: key);
    } else {
      await _prefs?.remove(key);
    }
  }

  // --- OpenAI API Key ---

  Future<void> saveOpenAiApiKey(String key) async {
    if (key.isEmpty) {
      await _delete(_openAiKeyKey);
    } else {
      await _write(_openAiKeyKey, key);
    }
  }

  Future<String?> getOpenAiApiKey() async {
    return await _read(_openAiKeyKey);
  }

  Future<void> deleteOpenAiApiKey() async {
    await _delete(_openAiKeyKey);
  }

  // --- Anthropic API Key ---

  Future<void> saveAnthropicApiKey(String key) async {
    if (key.isEmpty) {
      await _delete(_anthropicKeyKey);
    } else {
      await _write(_anthropicKeyKey, key);
    }
  }

  Future<String?> getAnthropicApiKey() async {
    return await _read(_anthropicKeyKey);
  }

  Future<void> deleteAnthropicApiKey() async {
    await _delete(_anthropicKeyKey);
  }

  // --- Tavily API Key ---

  Future<void> saveTavilyApiKey(String key) async {
    if (key.isEmpty) {
      await _delete(_tavilyKeyKey);
    } else {
      await _write(_tavilyKeyKey, key);
    }
  }

  Future<String?> getTavilyApiKey() async {
    return await _read(_tavilyKeyKey);
  }

  Future<void> deleteTavilyApiKey() async {
    await _delete(_tavilyKeyKey);
  }

  // --- Utility Methods ---

  Future<bool> hasAnyLlmApiKey() async {
    final openAi = await getOpenAiApiKey();
    final anthropic = await getAnthropicApiKey();
    return (openAi?.isNotEmpty ?? false) || (anthropic?.isNotEmpty ?? false);
  }

  Future<void> clearAllApiKeys() async {
    await Future.wait([
      _delete(_openAiKeyKey),
      _delete(_anthropicKeyKey),
      _delete(_tavilyKeyKey),
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
