import 'package:flutter/material.dart';
import 'services/auth_service.dart';
import 'main_square_page.dart'; // 👈 引入了万能广场的传送门坐标

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

// 定义页面的三种“变身”状态
enum LoginState { buttonsOnly, enterPhone, enterOtp }

class _LoginPageState extends State<LoginPage> {
  // 默认状态：只显示极简按钮
  LoginState _currentState = LoginState.buttonsOnly;

  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _otpController = TextEditingController();

  bool _isLoading = false;
  String _verificationId = '';

  @override
  void dispose() {
    _phoneController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  void _showMessage(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }

  // ==========================================
  //               1. Google 登录
  // ==========================================
  Future<void> _handleGoogle() async {
    setState(() => _isLoading = true);
    final user = await AuthService().signInWithGoogle();
    setState(() => _isLoading = false);

    // 登录成功，触发传送门
    if (user != null) {
      if (!mounted) return;
      _showMessage('Google 登录成功: ${user.displayName}');
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const MainSquarePage()),
      );
    }
  }

  // ==========================================
  //           2. 手机号：发送验证码
  // ==========================================
  Future<void> _handleSendOtp() async {
    final phone = _phoneController.text.trim();
    if (phone.isEmpty) return _showMessage('请输入手机号 (记得加+60)', isError: true);

    setState(() => _isLoading = true);
    await AuthService().sendPhoneOtp(
      phoneNumber: phone,
      onCodeSent: (verId) {
        setState(() {
          _verificationId = verId;
          _currentState = LoginState.enterOtp; // 变身：切换到验证码输入界面
          _isLoading = false;
        });
        _showMessage('验证码已发送！');
      },
      onError: (error) {
        setState(() => _isLoading = false);
        _showMessage(error, isError: true);
      },
    );
  }

  // ==========================================
  //           3. 手机号：核验登录
  // ==========================================
  Future<void> _handleVerifyOtp() async {
    final otp = _otpController.text.trim();
    if (otp.isEmpty) return _showMessage('请输入 6 位数验证码', isError: true);

    setState(() => _isLoading = true);
    final user = await AuthService().verifyPhoneOtp(_verificationId, otp);
    setState(() => _isLoading = false);

    // 验证成功，触发传送门
    if (user != null) {
      if (!mounted) return;
      _showMessage('手机号登录成功！');
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const MainSquarePage()),
      );
    } else {
      _showMessage('验证码错误，请重试', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ================= 顶部极简 Logo =================
              const Text(
                'XOLV',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 8,
                ),
              ),
              const SizedBox(height: 80),

              // 加载圈圈
              if (_isLoading)
                const Center(
                  child: CircularProgressIndicator(color: Colors.black),
                )
              // ================= 状态 A：极简双按钮 =================
              else if (_currentState == LoginState.buttonsOnly) ...[
                ElevatedButton.icon(
                  onPressed: () =>
                      setState(() => _currentState = LoginState.enterPhone),
                  icon: const Icon(Icons.phone_iphone),
                  label: const Text(
                    '手机号登录 / 注册',
                    style: TextStyle(fontSize: 16),
                  ),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: _handleGoogle,
                  icon: const Icon(Icons.g_mobiledata, size: 32),
                  label: const Text(
                    'Google 账号登录',
                    style: TextStyle(fontSize: 16, color: Colors.black87),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    side: const BorderSide(color: Colors.black26),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ]
              // ================= 状态 B：输入手机号 =================
              else if (_currentState == LoginState.enterPhone) ...[
                const Text(
                  '请输入您的手机号',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    labelText: '手机号 (例如: +60123456789)',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    prefixIcon: const Icon(Icons.phone),
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _handleSendOtp,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('获取验证码', style: TextStyle(fontSize: 16)),
                ),
                TextButton(
                  onPressed: () =>
                      setState(() => _currentState = LoginState.buttonsOnly),
                  child: const Text('返回', style: TextStyle(color: Colors.grey)),
                ),
              ]
              // ================= 状态 C：输入验证码 =================
              else if (_currentState == LoginState.enterOtp) ...[
                const Text(
                  '输入验证码',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  '已发送至 ${_phoneController.text}',
                  style: const TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: _otpController,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 24, letterSpacing: 8),
                  decoration: InputDecoration(
                    hintText: '000000',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _handleVerifyOtp,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('验证并登录', style: TextStyle(fontSize: 16)),
                ),
                TextButton(
                  onPressed: () =>
                      setState(() => _currentState = LoginState.enterPhone),
                  child: const Text(
                    '返回修改手机号',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
