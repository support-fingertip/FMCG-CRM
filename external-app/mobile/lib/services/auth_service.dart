// Reference implementation of the auth service for the Flutter mobile app.
//
// Required pubspec.yaml dependencies:
//   dio: ^5.4.0
//   flutter_secure_storage: ^9.0.0
//
// The JWT issued by the backend is stored in flutter_secure_storage so it
// lives in iOS Keychain / Android Keystore, not SharedPreferences. This
// matches the security stance described in external-app/README.md.

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AuthService {
  AuthService({required String backendBaseUrl, FlutterSecureStorage? storage})
      : _dio = Dio(BaseOptions(
          baseUrl: backendBaseUrl,
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
        )),
        _storage = storage ?? const FlutterSecureStorage();

  static const _tokenKey = 'app_jwt';

  final Dio _dio;
  final FlutterSecureStorage _storage;

  /// Validates [username]/[password] against the backend (which calls
  /// Salesforce). Returns true on success. If the user's org is
  /// IP-restricted, the caller must concatenate their Salesforce security
  /// token onto [password].
  Future<bool> login(String username, String password) async {
    try {
      final res = await _dio.post(
        '/auth/login',
        data: {'username': username, 'password': password},
      );
      final token = res.data['token'] as String?;
      if (token == null || token.isEmpty) return false;
      await _storage.write(key: _tokenKey, value: token);
      return true;
    } on DioException {
      // 401 / network / timeout → login fails. Keep callers simple.
      return false;
    }
  }

  Future<void> logout() => _storage.delete(key: _tokenKey);

  Future<String?> getToken() => _storage.read(key: _tokenKey);

  Future<bool> isLoggedIn() async {
    final t = await getToken();
    return t != null && t.isNotEmpty;
  }
}
