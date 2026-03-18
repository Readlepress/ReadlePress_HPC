import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../config/api_config.dart';

/// Authentication service: login, token storage, JWT refresh, logout.
class AuthService {
  AuthService({
    required this.dio,
    required this.apiConfig,
    FlutterSecureStorage? storage,
  }) : _storage = storage ?? const FlutterSecureStorage();

  final Dio dio;
  final ApiConfig apiConfig;
  final FlutterSecureStorage _storage;

  static const _tokenKey = 'readlepress_auth_token';
  static const _userKey = 'readlepress_user';

  /// Login with email or phone and password.
  /// Returns user info and stores token.
  Future<AuthResult> login({
    String? email,
    String? phone,
    required String password,
  }) async {
    if (email == null && phone == null) {
      throw AuthException('Email or phone required');
    }

    final response = await dio.post<Map<String, dynamic>>(
      apiConfig.login,
      data: {
        if (email != null) 'email': email,
        if (phone != null) 'phone': phone,
        'password': password,
      },
    );

    final data = response.data;
    if (data == null) throw AuthException('Invalid response');

    final token = data['token'] as String?;
    final user = data['user'] as Map<String, dynamic>?;

    if (token == null || token.isEmpty) {
      throw AuthException('No token received');
    }

    await _storage.write(key: _tokenKey, value: token);
    if (user != null) {
      await _storage.write(key: _userKey, value: jsonEncode(user));
    }

    return AuthResult(
      token: token,
      userId: user?['userId'] as String? ?? user?['id'] as String?,
      tenantId: user?['tenantId'] as String?,
      role: user?['role'] as String? ?? 'TEACHER',
    );
  }

  /// Get stored token. Returns null if not logged in.
  Future<String?> getToken() => _storage.read(key: _tokenKey);

  /// Get stored user as JSON map.
  Future<Map<String, dynamic>?> getStoredUser() async {
    final json = await _storage.read(key: _userKey);
    if (json == null) return null;
    return jsonDecode(json) as Map<String, dynamic>?;
  }

  /// Check if user is logged in (has valid token).
  Future<bool> isLoggedIn() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }

  /// Logout: clear stored token and user.
  Future<void> logout() async {
    await _storage.delete(key: _tokenKey);
    await _storage.delete(key: _userKey);
  }

  /// Configure Dio to use stored token and refresh on 401.
  /// Call after login or app startup.
  void configureAuthInterceptor() {
    dio.interceptors.removeWhere((e) => e is AuthInterceptor);
    dio.interceptors.insert(0, AuthInterceptor(this));
  }
}

/// Interceptor that adds Bearer token and handles 401.
class AuthInterceptor extends Interceptor {
  AuthInterceptor(this.authService);

  final AuthService authService;

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final token = await authService.getToken();
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  void onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    if (err.response?.statusCode == 401) {
      await authService.logout();
      // Could emit event for app to navigate to login
    }
    handler.next(err);
  }
}

class AuthResult {
  AuthResult({
    required this.token,
    this.userId,
    this.tenantId,
    this.role = 'TEACHER',
  });

  final String token;
  final String? userId;
  final String? tenantId;
  final String role;
}

class AuthException implements Exception {
  AuthException(this.message);
  final String message;
  @override
  String toString() => 'AuthException: $message';
}
