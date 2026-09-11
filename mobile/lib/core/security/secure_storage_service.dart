import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

final secureStorageServiceProvider = Provider<SecureStorageService>((ref) {
  return SecureStorageService();
});

class SecureStorageService {
  final FlutterSecureStorage _storage;

  SecureStorageService()
      : _storage = const FlutterSecureStorage(
          aOptions: AndroidOptions(
            resetOnError: true,
          ),
          iOptions: IOSOptions(
            accessibility: KeychainAccessibility.first_unlock,
          ),
        );

  Future<void> write(String key, String value) async {
    await _storage.write(key: key, value: value);
  }

  Future<String?> read(String key) async {
    return await _storage.read(key: key);
  }

  Future<void> delete(String key) async {
    await _storage.delete(key: key);
  }

  Future<bool> containsKey(String key) async {
    return await _storage.containsKey(key: key);
  }

  // Security preferences
  static const String _keyBiometricEnabled = 'pref_biometric_enabled';

  Future<bool> isBiometricEnabled() async {
    final val = await read(_keyBiometricEnabled);
    return val == null ? true : val == 'true'; // Enabled by default
  }

  Future<void> setBiometricEnabled(bool enabled) async {
    await write(_keyBiometricEnabled, enabled.toString());
  }
}
