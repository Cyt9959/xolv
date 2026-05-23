import 'package:flutter/material.dart';
import 'login_page.dart';

class IntroPage extends StatelessWidget {
  const IntroPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A), // 深邃的高级背景色
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          // 点击任意地方，丝滑跳转到登录页
          Navigator.pushReplacement(
            context,
            PageRouteBuilder(
              pageBuilder: (context, animation, secondaryAnimation) => const LoginPage(),
              transitionsBuilder: (context, animation, secondaryAnimation, child) {
                return FadeTransition(opacity: animation, child: child);
              },
              transitionDuration: const Duration(milliseconds: 600), // 高级的淡入淡出效果
            ),
          );
        },
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'XOLV',
                style: TextStyle(
                  fontSize: 72,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: 20.0, // 极致宽阔的字间距，彰显品牌力量
                ),
              ),
              SizedBox(height: 24),
              Text(
                '点击屏幕进入',
                style: TextStyle(
                  fontSize: 14,
                  color: Color(0xFFF97316), // 品牌橙色点缀
                  letterSpacing: 4.0,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
