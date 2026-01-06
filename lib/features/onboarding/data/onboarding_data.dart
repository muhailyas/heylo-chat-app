import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class OnboardingStore {
  OnboardingStore._();

  static const _storage = FlutterSecureStorage();
  static const _keySeen = 'onboarding_seen';

  static Future<bool> hasSeen() async {
    final v = await _storage.read(key: _keySeen);
    return v == '1';
  }

  static Future<void> markSeen() async {
    await _storage.write(key: _keySeen, value: '1');
  }
}
