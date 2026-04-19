import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Menggantikan SharedPreferences untuk data sensitif (token JWT)
class StorageService {
  static final StorageService _instance = StorageService._internal();
  factory StorageService() => _instance;
  StorageService._internal();

  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  // ── Token ─────────────────────────────────────────────────────
  Future<void> saveToken(String token) async {
    await _storage.write(key: 'auth_token', value: token);
  }

  Future<String?> getToken() async {
    return await _storage.read(key: 'auth_token');
  }

  Future<void> deleteToken() async {
    await _storage.delete(key: 'auth_token');
  }

  // ── User info ─────────────────────────────────────────────────
  Future<void> saveUser({
    required String id,
    required String name,
    required String email,
  }) async {
    await _storage.write(key: 'user_id',    value: id);
    await _storage.write(key: 'user_name',  value: name);
    await _storage.write(key: 'user_email', value: email);
  }

  Future<Map<String, String?>> getUser() async {
    return {
      'id':    await _storage.read(key: 'user_id'),
      'name':  await _storage.read(key: 'user_name'),
      'email': await _storage.read(key: 'user_email'),
    };
  }

  // ── Clear semua ───────────────────────────────────────────────
  Future<void> clearAll() async {
    await _storage.deleteAll();
  }
}