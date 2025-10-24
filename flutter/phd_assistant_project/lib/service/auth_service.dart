import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// === 配置你的后端地址 ===
class AppApi {
  /// TODO: 改成你的后端基地址（不要以 `/` 结尾）
  /// 例如 'http://localhost:8080/api' 或 'https://api.example.com'
  static const String baseUrl = 'https://phdapi.junedrinleng.com';

  /// 登录接口相对路径（不要以 `/` 开头）
  /// 例如后端是 /api/auth/login，这里就写 'auth/login'
  static const String loginPath = '/auth/login';

  /// 注册接口相对路径
  static const String registerPath = '/auth/register';
}

/// 自定义异常，登录失败时抛出更友好的信息
class AuthException implements Exception {
  final String message;
  AuthException(this.message);
  @override
  String toString() => message;
}

class AuthService extends ChangeNotifier {
  static const String _kUserKey = 'currentUser';
  static const String _kTokenKey = 'authToken';

  final Dio _dio;
  Map<String, dynamic>? _user;
  String? _token;
  bool _initialized = false;

  AuthService({Dio? dio})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              baseUrl: AppApi.baseUrl,
              connectTimeout: const Duration(seconds: 10),
              receiveTimeout: const Duration(seconds: 10),
              // 让 4xx 不抛异常，我们自己处理；5xx 仍抛异常
              validateStatus: (code) => code != null && code < 500,
            ),
          );

  bool get isInitialized => _initialized;
  Map<String, dynamic>? get user => _user;
  String? get token => _token;
  Dio get dio => _dio;

  bool get isLoggedIn =>
      _user != null && _token != null && !_isTokenExpired(_token!);

  /// 启动时调用：从本地恢复会话并校验 Token
  Future<void> restoreAndValidateSession() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString(_kTokenKey);
    final userJson = prefs.getString(_kUserKey);
    _user = (userJson != null && userJson.isNotEmpty)
        ? (jsonDecode(userJson) as Map<String, dynamic>)
        : null;

    if (_token != null) {
      _dio.options.headers['Authorization'] = 'Bearer $_token';
      if (_isTokenExpired(_token!)) {
        await logout(save: true, silent: true);
      }
    }

    _initialized = true;
    notifyListeners();
  }

  /// 登录：按你的接口字段名对齐
  Future<void> login(String username, String password) async {
    Response res;
    try {
      // 使用相对路径，避免覆盖 baseUrl 的 /api
      res = await _dio.post(
        AppApi.loginPath,
        data: {'username': username, 'password': password},
      );
    } on DioException catch (e) {
      throw AuthException('网络错误：${e.message}');
    }

    if (kDebugMode) {
      // ignore: avoid_print
      print('Login URL => ${res.requestOptions.uri}');
    }

    final code = res.statusCode ?? 0;
    if (code == 404) {
      throw AuthException(
        '登录接口不存在(404)：${res.requestOptions.uri}，请检查 baseUrl 与 loginPath。',
      );
    }
    if (code == 401 || code == 403) {
      throw AuthException('用户名或密码错误');
    }
    if (code < 200 || code >= 300) {
      final msg = _extractMessage(res.data) ?? '登录失败（HTTP $code）';
      throw AuthException(msg);
    }

    // 解析返回
    final Map<String, dynamic> data = res.data is Map<String, dynamic>
        ? (res.data as Map<String, dynamic>)
        : (res.data is String
              ? jsonDecode(res.data as String) as Map<String, dynamic>
              : <String, dynamic>{});

    // 兼容常见字段名
    String? tok =
        (data['token'] ?? data['access_token'] ?? data['jwt']) as String?;
    Map<String, dynamic>? usr;
    if (data['user'] is Map) {
      usr = (data['user'] as Map).cast<String, dynamic>();
    } else if (data['data'] is Map) {
      final d = (data['data'] as Map).cast<String, dynamic>();
      tok = (tok ?? d['token'] ?? d['access_token'] ?? d['jwt']) as String?;
      if (d['user'] is Map) usr = (d['user'] as Map).cast<String, dynamic>();
    }

    if (tok == null) {
      throw AuthException(
        '登录成功但未返回 token，请检查接口字段（token / access_token / jwt）。',
      );
    }

    _token = tok;
    _user = usr ?? {'username': username};

    _dio.options.headers['Authorization'] = 'Bearer $_token';

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kTokenKey, _token!);
    await prefs.setString(_kUserKey, jsonEncode(_user));

    notifyListeners();
  }

  String? _extractMessage(dynamic data) {
    try {
      if (data is Map<String, dynamic>) {
        return (data['message'] ?? data['error'] ?? data['msg'])?.toString();
      }
      if (data is String) return data;
    } catch (_) {}
    return null;
  }

  /// 注册：按你的接口字段名对齐
  Future<void> register(String username, String password) async {
    Response res;
    try {
      // 使用相对路径，避免覆盖 baseUrl 的 /api
      res = await _dio.post(
        AppApi.registerPath,
        data: {'username': username, 'password': password},
      );
    } on DioException catch (e) {
      throw AuthException('网络错误：${e.message}');
    }

    if (kDebugMode) {
      // ignore: avoid_print
      print('Login URL => ${res.requestOptions.uri}');
    }

    final code = res.statusCode ?? 0;
    if (code == 404) {
      throw AuthException(
        '登录接口不存在(404)：${res.requestOptions.uri}，请检查 baseUrl 与 loginPath。',
      );
    }
    if (code == 401 || code == 403) {
      throw AuthException('用户名或密码错误');
    }
    if (code < 200 || code >= 300) {
      final msg = _extractMessage(res.data) ?? '登录失败（HTTP $code）';
      throw AuthException(msg);
    }

    // 解析返回
    final Map<String, dynamic> data = res.data is Map<String, dynamic>
        ? (res.data as Map<String, dynamic>)
        : (res.data is String
              ? jsonDecode(res.data as String) as Map<String, dynamic>
              : <String, dynamic>{});

    // 兼容常见字段名
    String? tok =
        (data['token'] ?? data['access_token'] ?? data['jwt']) as String?;
    Map<String, dynamic>? usr;
    if (data['user'] is Map) {
      usr = (data['user'] as Map).cast<String, dynamic>();
    } else if (data['data'] is Map) {
      final d = (data['data'] as Map).cast<String, dynamic>();
      tok = (tok ?? d['token'] ?? d['access_token'] ?? d['jwt']) as String?;
      if (d['user'] is Map) usr = (d['user'] as Map).cast<String, dynamic>();
    }

    if (tok == null) {
      throw AuthException(
        '登录成功但未返回 token，请检查接口字段（token / access_token / jwt）。',
      );
    }

    _token = tok;
    _user = usr ?? {'username': username};

    _dio.options.headers['Authorization'] = 'Bearer $_token';

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kTokenKey, _token!);
    await prefs.setString(_kUserKey, jsonEncode(_user));

    notifyListeners();
  }

  /// 登出：清空缓存和头部
  Future<void> logout({bool save = true, bool silent = false}) async {
    _token = null;
    _user = null;
    _dio.options.headers.remove('Authorization');

    if (save) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_kTokenKey);
      await prefs.remove(_kUserKey);
    }

    if (!silent) notifyListeners();
  }

  /// 判断 JWT 是否过期（容错 base64Url，无 padding 时 normalize）
  bool _isTokenExpired(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return true; // 非标准 JWT，当作过期处理
      final normalized = base64Url.normalize(parts[1]);
      final payload =
          jsonDecode(utf8.decode(base64Url.decode(normalized)))
              as Map<String, dynamic>;
      final exp = payload['exp'];
      if (exp is num) {
        final nowSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;
        return nowSec >= exp.toInt();
      }
      return true; // 没有 exp 字段，保守处理为过期
    } catch (_) {
      return true; // 解码失败，一律按过期处理
    }
  }
}
