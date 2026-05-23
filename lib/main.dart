import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';
import 'intro_page.dart';
import 'main_square_page.dart';
import 'global_notification_radar.dart'; // 👈 完美引入我们刚造好的全局雷达

void main() async {
  // 确保 Flutter 底层组件加载完毕
  WidgetsFlutterBinding.ensureInitialized();

  // 启动 Firebase 云端引擎
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  runApp(const XolvApp());
}

class XolvApp extends StatelessWidget {
  const XolvApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'XOLV',
      debugShowCheckedModeBanner: false, // 隐藏右上角的 Debug 标签
      theme: ThemeData(
        // ⚡️ 核心灵魂色：闪电橙
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFFF5E00), // 专属定制橙色
          primary: const Color(0xFFFF5E00), // 主按钮颜色
        ),
        scaffoldBackgroundColor: Colors.white, // 保持高级的纯白背景
        useMaterial3: true,
        // 让所有的顶部导航栏也融入这种年轻活力的氛围
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Color.fromARGB(221, 0, 0, 0),
          elevation: 0,
        ),
      ),
      // 🚀 核心重构：把入口控制权交给“智能保安” AuthGate
      home: const AuthGate(),
    );
  }
}

// ==========================================
// 🛡️ 智能保安哨所：光速判断用户是否已经登录
// ==========================================
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      // ⚡ 监听 Firebase 认证管道里的最新状态
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // 状态 1：系统正在扫描本地芯片中的 Token（转圈圈）
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator(color: Colors.black)),
          );
        }

        // 状态 2：扫描到了用户数据！说明之前登录过且没点退出！
        if (snapshot.hasData) {
          // 🚀 核心通电：在放行进入广场的一瞬间，在最外层套上我们的【全自动智能雷达】！
          // 这样不管用户后续是在逛广场、看个人中心还是在聊天，通知全天候畅通无阻！
          return const GlobalNotificationRadar(child: MainSquarePage());
        }

        // 状态 3：什么都没扫到（新用户，或者点击了“退出登录”）
        return const IntroPage(); // 🛑 乖乖去引导页/登录页
      },
    );
  }
}
