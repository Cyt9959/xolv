// Material 组件：按钮、输入框、页面布局
import 'package:flutter/material.dart';
// Firebase 核心：读取当前连接的项目 ID
import 'package:firebase_core/firebase_core.dart';
// Firebase 登录：邮箱密码登录 / 注册
import 'package:firebase_auth/firebase_auth.dart';

/// 登录页（带完整终端日志，方便零基础在终端里看卡在哪一步）
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  bool _isSubmitting = false;
  bool _obscurePassword = true;
  String? _errorMessage;

  String get _connectedProjectId => Firebase.app().options.projectId;

  /// 统一日志前缀，终端里搜索「Xolv」即可过滤
  void _log(String message) {
    // ignore: avoid_print — 创始人需要在终端里直接看到 print 输出
    print('========== [Xolv 登录] $message ==========');
  }

  String _formatAuthError(FirebaseAuthException e) {
    final String detail = e.message?.trim().isNotEmpty == true
        ? e.message!.trim()
        : '无附加说明';
    final String head = '错误码: ${e.code}\n详情: $detail';

    if (e.code == 'operation-not-allowed') {
      return '$head\n\n'
          'App 当前连接的项目：$_connectedProjectId\n'
          '请在该项目启用：Authentication → 电子邮件地址/密码\n'
          'https://console.firebase.google.com/project/$_connectedProjectId/authentication/providers';
    }

    return '$head\n（项目 $_connectedProjectId）';
  }

  void _showError(String message) {
    _log('界面显示错误：$message');
    setState(() => _errorMessage = message);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 8),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _log('步骤 0：登录页已打开（initState）');
    _log('当前 Firebase 项目 ID：$_connectedProjectId');
    _log('当前是否已有登录用户：${FirebaseAuth.instance.currentUser?.email ?? "无"}');
  }

  @override
  void dispose() {
    _log('登录页关闭（dispose），释放输入框');
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  /// 点击「进入 Xolv」后的完整流程（每一步都有 print）
  Future<void> _enterXolv() async {
    _log('步骤 1：_enterXolv 函数已开始执行');

    _log('步骤 2：准备检查表单（邮箱、密码是否填写正确）');

    final FormState? formState = _formKey.currentState;
    if (formState == null) {
      _log('步骤 2 失败：formState 为 null，表单还没准备好，停止');
      _showError('表单未就绪，请稍后再点一次按钮。');
      return;
    }

    _log('步骤 2：开始调用 formState.validate()');
    final bool isValid = formState.validate();
    _log('步骤 2 结果：validate() = $isValid');

    if (!isValid) {
      _log('步骤 2 失败：校验未通过（常见原因：邮箱为空、密码少于 6 位）');
      _log('你输入的邮箱长度：${_emailController.text.trim().length}');
      _log('你输入的密码长度：${_passwordController.text.length}');
      _showError('请先填好邮箱和密码（密码至少 6 位）。');
      return;
    }

    final String email = _emailController.text.trim();
    final String password = _passwordController.text;

    _log('步骤 3：校验通过');
    _log('步骤 3：邮箱 = $email（密码长度 ${password.length}，不在终端打印密码）');

    _log('步骤 4：设置加载中 _isSubmitting = true（按钮会转圈）');
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      _log('步骤 5：获取 FirebaseAuth.instance');
      final FirebaseAuth auth = FirebaseAuth.instance;

      _log('步骤 6：开始调用 signInWithEmailAndPassword（老用户登录）');
      final UserCredential signInResult = await auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      _log('步骤 7：登录成功！');
      _log('步骤 7：用户 UID = ${signInResult.user?.uid}');
      _log('步骤 7：用户邮箱 = ${signInResult.user?.email}');
      _log('步骤 7：接下来 App 应自动跳到首页（authStateChanges 监听）');
    } on FirebaseAuthException catch (e) {
      _log('步骤 6 失败：Firebase 登录异常');
      _log('步骤 6 失败：code = ${e.code}');
      _log('步骤 6 失败：message = ${e.message}');

      final bool shouldTryRegister =
          e.code == 'user-not-found' || e.code == 'invalid-credential';

      _log('步骤 8：是否尝试自动注册？shouldTryRegister = $shouldTryRegister');

      if (shouldTryRegister) {
        try {
          _log('步骤 9：开始调用 createUserWithEmailAndPassword（新用户注册）');
          final UserCredential registerResult =
              await FirebaseAuth.instance.createUserWithEmailAndPassword(
            email: email,
            password: password,
          );

          _log('步骤 10：注册成功！');
          _log('步骤 10：用户 UID = ${registerResult.user?.uid}');
          _log('步骤 10：用户邮箱 = ${registerResult.user?.email}');
          _log('步骤 10：接下来 App 应自动跳到首页');
        } on FirebaseAuthException catch (createError) {
          _log('步骤 9 失败：注册异常');
          _log('步骤 9 失败：code = ${createError.code}');
          _log('步骤 9 失败：message = ${createError.message}');

          if (createError.code == 'email-already-in-use') {
            _log('步骤 9 结论：邮箱已存在，多半是密码错了');
            _showError('该邮箱已注册，密码不正确，请重试。');
          } else {
            _showError(_formatAuthError(createError));
          }
        }
      } else if (e.code == 'wrong-password') {
        _log('步骤 8 结论：密码错误，不尝试注册');
        _showError('密码不正确，请重试。');
      } else {
        _log('步骤 8 结论：其他错误，不尝试注册');
        _showError(_formatAuthError(e));
      }
    } catch (e, stackTrace) {
      _log('步骤 ?：发生未知错误（非 FirebaseAuthException）');
      _log('错误内容：$e');
      _log('堆栈：$stackTrace');
      _showError('发生错误：$e');
    } finally {
      _log('步骤 11：进入 finally，准备结束加载状态');
      if (mounted) {
        setState(() => _isSubmitting = false);
        _log('步骤 11：_isSubmitting = false，按钮恢复可点');
      } else {
        _log('步骤 11：页面已销毁（mounted=false），不再 setState');
      }
      _log('步骤 12：_enterXolv 函数执行完毕');
    }
  }

  /// 按钮点击入口（最先执行，确认「点按钮」这件事本身有没有触发）
  void _onEnterButtonPressed() {
    _log('★ 按钮被点击了（_onEnterButtonPressed）');

    if (_isSubmitting) {
      _log('★ 当前正在提交中，忽略本次点击');
      return;
    }

    _log('★ 即将调用 _enterXolv()');
    _enterXolv();
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Center(
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Text(
                    '进入 Xolv',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          color: scheme.primary,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '新邮箱将自动创建账号；老用户直接登录。',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                  ),
                  const SizedBox(height: 28),
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      labelText: '邮箱',
                      filled: true,
                      fillColor: scheme.surface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    validator: (String? value) {
                      if (value == null || value.trim().isEmpty) {
                        return '请输入邮箱';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    decoration: InputDecoration(
                      labelText: '密码',
                      filled: true,
                      fillColor: scheme.surface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      suffixIcon: IconButton(
                        onPressed: () {
                          setState(() => _obscurePassword = !_obscurePassword);
                        },
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                      ),
                    ),
                    validator: (String? value) {
                      if (value == null || value.isEmpty) {
                        return '请输入密码';
                      }
                      if (value.length < 6) {
                        return '密码至少 6 位';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 28),
                  if (_errorMessage != null) ...<Widget>[
                    Text(
                      _errorMessage!,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: scheme.error,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  SizedBox(
                    height: 52,
                    child: FilledButton(
                      onPressed: _onEnterButtonPressed,
                      style: FilledButton.styleFrom(
                        backgroundColor: scheme.primary,
                        foregroundColor: scheme.onPrimary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        textStyle: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      child: _isSubmitting
                          ? SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: scheme.onPrimary,
                              ),
                            )
                          : const Text('进入 Xolv'),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    '当前 App 连接 Firebase 项目：\n$_connectedProjectId',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                          height: 1.3,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '调试提示：点按钮后请在运行 flutter run 的终端里搜索「Xolv」',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                          fontSize: 11,
                        ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
