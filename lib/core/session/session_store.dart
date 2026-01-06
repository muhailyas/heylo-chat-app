import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';

class SessionStore {
  SessionStore._();

  static const _storage = FlutterSecureStorage();
  static const _keyUid = 'current_uid';
  static const _keyDeviceId = 'stable_device_id';
  static const _keySessionId = 'session_row_id';

  static Future<void> saveUid(String uid) =>
      _storage.write(key: _keyUid, value: uid);

  static Future<String?> readUid() => _storage.read(key: _keyUid);

  static Future<void> saveSessionId(String id) =>
      _storage.write(key: _keySessionId, value: id);

  static Future<String?> readSessionId() => _storage.read(key: _keySessionId);

  static Future<String> getDeviceId() async {
    String? id = await _storage.read(key: _keyDeviceId);
    if (id == null) {
      id = const Uuid().v4();
      await _storage.write(key: _keyDeviceId, value: id);
    }
    return id;
  }

  static Future<void> clear() async {
    await _storage.delete(key: _keyUid);
    // Note: We DO NOT clear the device ID, as it should stay stable for this hardware.
  }
}
