// Dio-based HTTP client that auto-attaches the app's JWT to every request
// and clears it on 401 so the app can navigate back to the login screen.

import 'package:dio/dio.dart';

import 'auth_service.dart';

class ApiClient {
  ApiClient({required String baseUrl, required this.authService})
      : _dio = Dio(BaseOptions(
          baseUrl: baseUrl,
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
        )) {
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await authService.getToken();
        if (token != null && token.isNotEmpty) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },
      onError: (err, handler) async {
        if (err.response?.statusCode == 401) {
          // Token expired or invalid; clear it so the UI can react.
          await authService.logout();
        }
        handler.next(err);
      },
    ));
  }

  final Dio _dio;
  final AuthService authService;

  Dio get dio => _dio;

  /// Example: fetch the current user's JWT claims from the backend.
  Future<Map<String, dynamic>?> me() async {
    try {
      final res = await _dio.get('/auth/me');
      return (res.data as Map).cast<String, dynamic>();
    } on DioException {
      return null;
    }
  }
}
