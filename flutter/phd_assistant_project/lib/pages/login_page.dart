import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../service/auth_service.dart';
import '../utils/theme_manager.dart';

class LoginPage extends StatefulWidget {
  final AuthService auth;
  final ThemeManager themeManager; // 添加 ThemeManager

  const LoginPage({
    super.key,
    required this.auth,
    required this.themeManager, // 添加参数
  });

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  bool _submittingLogin = false;
  String? _error;
  bool _obscure = true;

  // 获取主题色
  Color get _primaryColor => widget.themeManager.getPrimaryColor();

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _onSubmit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _submittingLogin = true;
      _error = null;
    });
    try {
      await widget.auth.login(_usernameCtrl.text.trim(), _passwordCtrl.text);
      if (mounted) {
        context.go('/dashboard');
      }
    } catch (e) {
      setState(() {
        _submittingLogin = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF0A0B0D)
          : const Color(0xFFF5F5F5),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Card(
              color: isDark ? const Color(0xFF1A1D23) : Colors.white,
              elevation: 8,
              shadowColor: Colors.black.withOpacity(isDark ? 0.5 : 0.08),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16.0),
              ),
              child: Padding(
                padding: const EdgeInsets.all(40.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 标题
                    Text(
                      '🔐 登录',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w600,
                        color: isDark
                            ? const Color(0xFFF9FAFB)
                            : const Color(0xFF2C2C2C),
                      ),
                    ),
                    const SizedBox(height: 30),

                    // 表单
                    Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          // 用户名
                          _buildFormGroup(
                            label: '用户名',
                            isDark: isDark,
                            child: TextFormField(
                              controller: _usernameCtrl,
                              style: TextStyle(
                                fontSize: 14,
                                color: isDark ? Colors.white : Colors.black,
                              ),
                              decoration: _inputDecoration(isDark: isDark),
                              validator: (value) =>
                                  value?.isEmpty ?? true ? '请输入用户名' : null,
                            ),
                          ),
                          const SizedBox(height: 20),

                          // 密码
                          _buildFormGroup(
                            label: '密码',
                            isDark: isDark,
                            child: TextFormField(
                              controller: _passwordCtrl,
                              obscureText: _obscure,
                              style: TextStyle(
                                fontSize: 14,
                                color: isDark ? Colors.white : Colors.black,
                              ),
                              decoration: _inputDecoration(
                                isDark: isDark,
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscure
                                        ? Icons.visibility_off_outlined
                                        : Icons.visibility_outlined,
                                    size: 20,
                                    color: isDark
                                        ? const Color(0xFF9CA3AF)
                                        : const Color(0xFF666666),
                                  ),
                                  onPressed: () =>
                                      setState(() => _obscure = !_obscure),
                                ),
                              ),
                              validator: (value) =>
                                  value?.isEmpty ?? true ? '请输入密码' : null,
                            ),
                          ),

                          const SizedBox(height: 30),

                          // 登录按钮
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: ElevatedButton(
                              onPressed: _submittingLogin ? null : _onSubmit,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: isDark
                                    ? const Color(0xFF343842)
                                    : _primaryColor,
                                disabledBackgroundColor: const Color(
                                  0xFFCCCCCC,
                                ),
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shadowColor: Colors.transparent,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              child: _submittingLogin
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Text(
                                      '登录',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // 注册链接
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '还没有账号？',
                          style: TextStyle(
                            fontSize: 14,
                            color: isDark
                                ? const Color(0xFF9CA3AF)
                                : const Color(0xFF666666),
                          ),
                        ),
                        TextButton(
                          onPressed: () => context.go('/register'),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 0,
                            ),
                            minimumSize: const Size(0, 0),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: Text(
                            '点击注册',
                            style: TextStyle(
                              fontSize: 14,
                              color: isDark
                                  ? const Color(0xFFF3F4F6)
                                  : _primaryColor,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),

                    // 错误消息
                    if (_error != null) ...[
                      const SizedBox(height: 20),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(15),
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF2A1616)
                              : const Color(0xFFFFEBEE),
                          border: Border.all(
                            color: isDark
                                ? const Color(0xFF5C2020)
                                : const Color(0xFFFFCDD2),
                            width: 1,
                          ),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          _error!,
                          style: TextStyle(
                            color: isDark
                                ? const Color(0xFFFFCDD2)
                                : const Color(0xFFC62828),
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFormGroup({
    required String label,
    required Widget child,
    required bool isDark,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: isDark ? const Color(0xFFE5E7EB) : const Color(0xFF333333),
          ),
        ),
        const SizedBox(height: 8),
        child,
      ],
    );
  }

  InputDecoration _inputDecoration({Widget? suffixIcon, required bool isDark}) {
    return InputDecoration(
      filled: true,
      fillColor: isDark ? const Color(0xFF0A0B0D) : Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(
          color: isDark ? const Color(0xFF374151) : const Color(0xFFE0E0E0),
          width: 2,
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(
          color: isDark ? const Color(0xFF374151) : const Color(0xFFE0E0E0),
          width: 2,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(
          color: isDark ? const Color(0xFFF3F4F6) : _primaryColor,
          width: 2,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFE57373), width: 2),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(
          color: isDark ? const Color(0xFFE57373) : _primaryColor,
          width: 2,
        ),
      ),
      suffixIcon: suffixIcon,
    );
  }
}
