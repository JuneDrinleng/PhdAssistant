import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthService extends ChangeNotifier {
  static const String _kUserKey = 'currentUser';
  static const String _kTokenKey = 'authToken';

  final Dio _dio;
  Map<String, dynamic>? _user;
  String? _token;
  bool _initialized = false;

  AuthService({Dio? dio}) : _dio = dio ?? Dio();

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
    final res = await _dio.post(
      'https://phdapi.junedrinleng.com/auth/login',
      data: {'username': username, 'password': password},
    );

    // 假设服务端返回：{"token": "xxx", "user": {"id": 1, "username": "张三"}}
    final data = res.data as Map<String, dynamic>;
    _token = data['token'] as String?;
    _user = (data['user'] as Map).cast<String, dynamic>();

    if (_token == null || _user == null) {
      throw StateError('登录返回数据不完整');
    }

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
