// lib/services/auth_service.dart
import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthService extends ChangeNotifier {
  // 默认使用你提供的 API；也支持 --dart-define=BASE_URL 覆盖
  static const _defaultBase = String.fromEnvironment(
    'BASE_URL',
    defaultValue: 'https://phdapi.junedrinleng.com',
  ); // :contentReference[oaicite:8]{index=8}

  static const _kUserKey =
      'currentUser'; // 和前端 localStorage 对齐 :contentReference[oaicite:9]{index=9}
  static const _kTokenKey =
      'authToken'; // :contentReference[oaicite:10]{index=10}
  static const _kApiKey = 'apiUrl';

  final Dio _dio;
  bool _initialized = false;
  bool _loggedIn = false;
  Map<String, dynamic>? _user;
  String? _token;

  bool get isInitialized => _initialized;
  bool get isLoggedIn => _loggedIn;
  Map<String, dynamic>? get user => _user;
  String get baseUrl => _dio.options.baseUrl;

  AuthService._(this._dio);

  factory AuthService({String? baseUrl}) {
    final dio = Dio(
      BaseOptions(
        baseUrl: baseUrl ?? _defaultBase,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 20),
        headers: {'Content-Type': 'application/json'},
      ),
    );
    return AuthService._(dio);
  }

  // === 工具：JWT 判定与过期检查（等价于前端 looksLikeJWT / isExpiredJWT） ===
  bool _looksLikeJWT(String? t) =>
      t != null &&
      t.split('.').length == 3; // :contentReference[oaicite:11]{index=11}
  bool _isExpiredJWT(String t) {
    try {
      final payloadB64 = t.split('.')[1];
      String normalize(String s) {
        final pad = s.length % 4;
        return pad == 0 ? s : (s + '=' * (4 - pad));
      }

      final bytes = base64Url.decode(normalize(payloadB64));
      final map = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
      final exp = map['exp'];
      return exp is num
          ? (DateTime.now().millisecondsSinceEpoch / 1000) > exp
          : false;
    } catch (_) {
      return true;
    }
  } // :contentReference[oaicite:12]{index=12}

  Future<void> restoreAndValidateSession() async {
    final sp = await SharedPreferences.getInstance();
    // 基址优先读本地保存，其次用默认值（对齐前端 setSession 会保存 apiUrl） :contentReference[oaicite:13]{index=13}
    final savedBase = sp.getString(_kApiKey);
    if (savedBase != null && savedBase.isNotEmpty) {
      _dio.options.baseUrl = savedBase;
    }
    final token = sp.getString(_kTokenKey);
    final userStr = sp.getString(_kUserKey);
    Map<String, dynamic>? user;
    if (userStr != null) {
      try {
        user = jsonDecode(userStr) as Map<String, dynamic>;
      } catch (_) {}
    }

    if (user?['username'] == null ||
        !_looksLikeJWT(token) ||
        _isExpiredJWT(token!)) {
      await clearSession();
      _initialized = true;
      notifyListeners();
      return; // 与前端 guard 一致：不满足就停留在登录页 :contentReference[oaicite:14]{index=14}
    }

    // 后端校验 /auth/me 成功才算登录有效（与前端一致） :contentReference[oaicite:15]{index=15}
    try {
      _dio.options.headers['Authorization'] = 'Bearer $token';
      final r = await _dio.get('/auth/me');
      if (r.statusCode == 200) {
        _token = token;
        _user = r.data is Map ? (r.data as Map<String, dynamic>) : user;
        _loggedIn = true;
      } else {
        await clearSession();
      }
    } catch (_) {
      await clearSession();
    } finally {
      _initialized = true;
      notifyListeners();
    }
  }

  Future<void> login({
    required String username,
    required String password,
  }) async {
    // 调用与前端一致的 /auth/login，期望返回 {token, user} :contentReference[oaicite:16]{index=16}
    final r = await _dio.post(
      '/auth/login',
      data: {'username': username, 'password': password},
    );
    final data = r.data is Map
        ? r.data as Map<String, dynamic>
        : <String, dynamic>{};
    final token = data['token'] as String?;
    final user = data['user'] as Map<String, dynamic>?;
    if (token == null || token.isEmpty) {
      throw Exception('登录失败：未返回 token');
    }
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_kTokenKey, token);
    await sp.setString(_kUserKey, jsonEncode(user ?? {'username': username}));
    await sp.setString(
      _kApiKey,
      _dio.options.baseUrl,
    ); // 对齐前端 setSession 保存 apiUrl :contentReference[oaicite:17]{index=17}

    _token = token;
    _user = user;
    _loggedIn = true;
    _dio.options.headers['Authorization'] = 'Bearer $token';
    notifyListeners();
  }

  Future<void> logout() => clearSession();

  Future<void> clearSession() async {
    final sp = await SharedPreferences.getInstance();
    await sp.remove(_kUserKey);
    await sp.remove(_kTokenKey);
    _token = null;
    _user = null;
    _loggedIn = false;
    _dio.options.headers.remove('Authorization');
  }
}
