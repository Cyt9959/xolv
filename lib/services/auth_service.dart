import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // 👈 新增：接通 Firestore 云端总账本的电线

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // 确保 Google SignIn 只被初始化一次 (V7 新规)
  bool _isGoogleSignInInitialized = false;

  // ==========================================
  //               1. 谷歌登录 (V7 最新架构) + 自动建档
  // ==========================================
  Future<User?> signInWithGoogle() async {
    try {
      // V7 规定：必须先调用 initialize()
      if (!_isGoogleSignInInitialized) {
        await GoogleSignIn.instance.initialize();
        _isGoogleSignInInitialized = true;
      }

      // V7 规定：使用 authenticate() 唤起弹窗
      final googleUser = await GoogleSignIn.instance.authenticate();
      // 👈 增加保护：防止用户中途取消登录导致报错

      // V7 规定：authentication 变成同步获取，不需要 await
      final GoogleSignInAuthentication googleAuth = googleUser.authentication;

      // V7 核心机制：独立请求授权，彻底解决 empty scopes 报错！
      final authClient = googleUser.authorizationClient;
      final authz = await authClient.authorizationForScopes(['email']);

      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: authz?.accessToken,
        idToken: googleAuth.idToken,
      );

      final UserCredential userCredential = await _auth.signInWithCredential(
        credential,
      );

      final User? user = userCredential.user;

      // ==========================================
      // 🚨 --- 建立/更新用户档案开始 --- 🚨
      // ==========================================
      if (user != null) {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'name': user.displayName ?? '未命名用户',
          'email': user.email ?? '',
          'avatarUrl': user.photoURL ?? '',
          'kyc_status': 'pending', // 👈 老板你的专属设定：默认状态为待审核
          'role': 'user', // 身份：普通用户
          'createdAt': FieldValue.serverTimestamp(), // 自动记录这通档案的创建时间
        }, SetOptions(merge: true));
        // 💡 SetOptions(merge: true)：保证老用户再次登录时，不会清空之前的 KYC 数据！
      }
      // ==========================================
      // 🚨 --- 建立/更新用户档案结束 --- 🚨
      // ==========================================

      return user;
    } catch (e) {
      debugPrint("谷歌登录发生致命错误: $e");
      return null;
    }
  }

  // ==========================================
  //               2. 邮箱登录 & 注册
  // ==========================================
  Future<User?> registerWithEmail(String email, String password) async {
    try {
      final UserCredential userCredential = await _auth
          .createUserWithEmailAndPassword(email: email, password: password);
      return userCredential.user;
    } catch (e) {
      debugPrint("邮箱注册失败: $e");
      return null;
    }
  }

  Future<User?> signInWithEmail(String email, String password) async {
    try {
      final UserCredential userCredential = await _auth
          .signInWithEmailAndPassword(email: email, password: password);
      return userCredential.user;
    } catch (e) {
      debugPrint("邮箱登录失败: $e");
      return null;
    }
  }

  // ==========================================
  //               3. 手机号登录模块
  // ==========================================
  Future<void> sendPhoneOtp({
    required String phoneNumber,
    required Function(String verificationId) onCodeSent,
    required Function(String error) onError,
  }) async {
    try {
      await _auth.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        verificationCompleted: (PhoneAuthCredential credential) async {
          await _auth.signInWithCredential(credential);
        },
        verificationFailed: (FirebaseAuthException e) {
          onError(e.message ?? '发送验证码失败');
        },
        codeSent: (String verificationId, int? resendToken) {
          onCodeSent(verificationId);
        },
        codeAutoRetrievalTimeout: (String verificationId) {},
      );
    } catch (e) {
      onError(e.toString());
    }
  }

  Future<User?> verifyPhoneOtp(String verificationId, String smsCode) async {
    try {
      final PhoneAuthCredential credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: smsCode,
      );
      final UserCredential userCredential = await _auth.signInWithCredential(
        credential,
      );
      return userCredential.user;
    } catch (e) {
      debugPrint("验证码核验失败: $e");
      return null;
    }
  }

  // ==========================================
  //               4. 退出登录
  // ==========================================
  Future<void> signOut() async {
    // V7 规定：退出也需要用 instance
    await GoogleSignIn.instance.signOut();
    await _auth.signOut();
  }
}
