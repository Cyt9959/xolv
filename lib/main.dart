import 'dart:async';

import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:app_links/app_links.dart';
import 'firebase_options.dart';
import 'intro_page.dart';
import 'main_square_page.dart';
import 'global_notification_radar.dart'; // 👈 完美引入我们刚造好的全局雷达
import 'services/fcm_service.dart';
import 'task_detail_page.dart';

// 🔗 全局导航键：让 Deep Link 等非 Widget 逻辑也能跳转页面
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

// ==========================================
// 📨 FCM 后台消息处理器（必须是顶层函数）
// ==========================================
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
}

void main() async {
  // 确保 Flutter 底层组件加载完毕
  WidgetsFlutterBinding.ensureInitialized();

  // 🌍 确保多语言翻译资源加载完毕
  await EasyLocalization.ensureInitialized();

  // 启动 Firebase 云端引擎
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // 📨 1. 申请通知权限
  await FirebaseMessaging.instance.requestPermission(
    alert: true,
    badge: true,
    sound: true,
  );

  // 📨 2. 设置前台通知显示（iOS 默认前台不弹窗，需要手动开启）
  await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
    alert: true,
    badge: true,
    sound: true,
  );

  // 📨 3. 注册后台消息处理器
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  runApp(
    EasyLocalization(
      supportedLocales: const [Locale('zh'), Locale('en'), Locale('ms')],
      path: 'assets/translations',
      fallbackLocale: const Locale('zh'),
      child: const XolvApp(),
    ),
  );
}

class XolvApp extends StatelessWidget {
  const XolvApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'XOLV',
      debugShowCheckedModeBanner: false, // 隐藏右上角的 Debug 标签
      localizationsDelegates: context.localizationDelegates,
      supportedLocales: context.supportedLocales,
      locale: context.locale,
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
        // ✨ 全局页面切换动画：淡入 + 轻微上升
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: {
            TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
            TargetPlatform.iOS: FadeUpwardsPageTransitionsBuilder(),
            TargetPlatform.macOS: FadeUpwardsPageTransitionsBuilder(),
            TargetPlatform.windows: FadeUpwardsPageTransitionsBuilder(),
            TargetPlatform.linux: FadeUpwardsPageTransitionsBuilder(),
            TargetPlatform.fuchsia: FadeUpwardsPageTransitionsBuilder(),
          },
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
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  // 📨 防止 StreamBuilder 重建时重复注册推送监听
  static bool _fcmInitialized = false;

  final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri>? _linkSubscription;

  @override
  void initState() {
    super.initState();
    _initDeepLinks();
  }

  @override
  void dispose() {
    _linkSubscription?.cancel();
    super.dispose();
  }

  // ==========================================
  // 🔗 Deep Link 监听：处理 https://cytxolv.com/task/{taskId}
  // ==========================================
  void _initDeepLinks() {
    _linkSubscription = _appLinks.uriLinkStream.listen((uri) {
      _handleDeepLink(uri);
    });
  }

  Future<void> _handleDeepLink(Uri uri) async {
    if (uri.host != 'cytxolv.com') return;

    final segments = uri.pathSegments;
    if (segments.length < 2 || segments[0] != 'task') return;

    final String taskId = segments[1];

    try {
      final doc = await FirebaseFirestore.instance
          .collection('tasks')
          .doc(taskId)
          .get();
      if (!doc.exists) return;

      final data = doc.data() as Map<String, dynamic>;
      data['id'] = doc.id;

      navigatorKey.currentState?.push(
        MaterialPageRoute(
          builder: (_) => TaskDetailPage(taskId: taskId, taskData: data),
        ),
      );
    } catch (e) {
      debugPrint('Deep Link 跳转失败: $e');
    }
  }

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
          // 📨 登录成功后立即注册推送通知系统（只注册一次）
          if (!_fcmInitialized) {
            _fcmInitialized = true;
            FcmService().saveTokenToFirestore();
            FcmService().initLocalNotifications();
            FcmService().listenForegroundMessages();
          }

          // 🚀 核心通电：在放行进入广场的一瞬间，在最外层套上我们的【全自动智能雷达】！
          // 这样不管用户后续是在逛广场、看个人中心还是在聊天，通知全天候畅通无阻！
          return const GlobalNotificationRadar(child: MainSquarePage());
        }

        // 状态 3：什么都没扫到（新用户，或者点击了“退出登录”）
        _fcmInitialized = false;
        return const IntroPage(); // 🛑 乖乖去引导页/登录页
      },
    );
  }
}
