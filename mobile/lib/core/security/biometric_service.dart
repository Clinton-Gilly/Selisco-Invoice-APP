import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';

final biometricServiceProvider = Provider<BiometricService>((ref) {
  return BiometricService();
});

class BiometricService {
  final LocalAuthentication _auth;

  BiometricService({LocalAuthentication? auth}) : _auth = auth ?? LocalAuthentication();

  Future<bool> isDeviceSupported() async {
    try {
      return await _auth.isDeviceSupported();
    } catch (_) {
      return false;
    }
  }

  Future<bool> canCheckBiometrics() async {
    try {
      return await _auth.canCheckBiometrics;
    } catch (_) {
      return false;
    }
  }

  Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      return await _auth.getAvailableBiometrics();
    } catch (_) {
      return [];
    }
  }

  /// Authenticates using Fingerprint, Face ID, or falls back to device PIN/Pattern/Passcode.
  Future<bool> authenticate({
    String localizedReason = 'Please authenticate to access Selisco Invoice System',
  }) async {
    try {
      final isSupported = await _auth.isDeviceSupported();
      if (!isSupported) {
        // If device has no security hardware, allow access
        return true;
      }

      return await _auth.authenticate(
        localizedReason: localizedReason,
        biometricOnly: false, // Allows Device PIN / Pattern / Passcode fallback!
        persistAcrossBackgrounding: true,
        sensitiveTransaction: true,
      );
    } on PlatformException catch (e) {
      debugPrint('Biometric authentication error: ${e.code} - ${e.message}');
      return false;
    } catch (e) {
      debugPrint('Unexpected error during authentication: $e');
      return false;
    }
  }

  Future<void> cancelAuthentication() async {
    try {
      await _auth.stopAuthentication();
    } catch (_) {}
  }
}
