import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // 👈 CTO 新增：引入云端总账本

// 如果你的 kyc_page 已经准备好，可以取消下面这行的注释并导入正确的路径
// import 'kyc_page.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    const primaryTextColor = Color(0xFF1D2939);
    const accentColor = Color(0xFF0D9488);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: primaryTextColor),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined, color: primaryTextColor),
            onPressed: () {
              debugPrint("[Xolv 中心] 用户点击了设置按钮");
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 10),
            // ================= 1. 头像区域 =================
            Center(
              child: Stack(
                alignment: Alignment.bottomRight,
                children: [
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 4),
                      boxShadow: [
                        BoxShadow(
                          color: accentColor.withValues(alpha: 0.15),
                          spreadRadius: 8,
                          blurRadius: 24,
                        ),
                      ],
                    ),
                    child: CircleAvatar(
                      backgroundColor: accentColor.withValues(alpha: 0.1),
                      backgroundImage: user?.photoURL != null
                          ? NetworkImage(user!.photoURL!)
                          : null,
                      child: user?.photoURL == null
                          ? Text(
                              (user?.displayName ?? "X")
                                  .substring(0, 1)
                                  .toUpperCase(),
                              style: const TextStyle(
                                fontSize: 48,
                                fontWeight: FontWeight.w600,
                                color: accentColor,
                              ),
                            )
                          : null,
                    ),
                  ),
                  Container(
                    width: 36,
                    height: 36,
                    decoration: const BoxDecoration(
                      color: accentColor,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.edit,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            // ================= 2. 名字区域 =================
            Text(
              user?.displayName ?? "创始人 Chui Yee",
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w700,
                color: primaryTextColor,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildInfoBadge(Icons.cake_outlined, "28岁"),
                const SizedBox(width: 12),
                _buildInfoBadge(Icons.male, "男"),
              ],
            ),
            const SizedBox(height: 20),

            // ==============================================================
            // 🚨 3. CTO 专属打造：云端动态 KYC 状态按钮 (StreamBuilder) 🚨
            // ==============================================================
            if (user != null)
              StreamBuilder<DocumentSnapshot>(
                // 实时监听 kyc_applications 集合里，属于这个 user.uid 的档案
                stream: FirebaseFirestore.instance
                    .collection('kyc_applications')
                    .doc(user.uid)
                    .snapshots(),
                builder: (context, snapshot) {
                  // 1. 如果还在向云端查询，显示小菊花
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const SizedBox(
                      height: 40,
                      child: Center(
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    );
                  }

                  // 2. 解析云端传回来的状态
                  String status = 'none'; // 默认当做没提交过
                  if (snapshot.hasData && snapshot.data!.exists) {
                    final data = snapshot.data!.data() as Map<String, dynamic>?;
                    status = data?['status'] ?? 'none';
                  }

                  // 3. 根据状态，决定按钮长什么样
                  Color bgColor;
                  Color textColor;
                  String text;
                  IconData icon;
                  VoidCallback? onTap;

                  if (status == 'pending') {
                    // 🟠 状态 A：审核中
                    bgColor = Colors.orange.shade50;
                    textColor = Colors.orange.shade800;
                    text = "审核中，请耐心等待";
                    icon = Icons.hourglass_top_rounded;
                  } else if (status == 'approved') {
                    // 🟢 状态 B：已通过
                    bgColor = Colors.green.shade50;
                    textColor = Colors.green.shade800;
                    text = "✅ 实名认证已通过";
                    icon = Icons.verified_rounded;
                  } else if (status == 'rejected') {
                    // 🔴 状态 C：被驳回
                    bgColor = Colors.red.shade50;
                    textColor = Colors.red.shade800;
                    text = "认证被驳回，请点击重试";
                    icon = Icons.error_outline_rounded;
                    onTap = () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('准备跳转到重填页面')),
                      );
                    };
                  } else {
                    // ⚪ 状态 D：还没提交 (None)
                    bgColor = const Color(0xFFF0FDFA);
                    textColor = accentColor;
                    text = "去完成实名认证";
                    icon = Icons.shield_outlined;
                    onTap = () {
                      // 💡 传送门：取消下方代码注释，并确保上方 import 了 kyc_page.dart
                      // Navigator.push(context, MaterialPageRoute(builder: (_) => const KycPage()));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('假装跳转到了 KYC 上传页')),
                      );
                    };
                  }

                  // 4. 渲染按钮
                  return GestureDetector(
                    onTap: onTap,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: bgColor,
                        borderRadius: BorderRadius.circular(100),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(icon, size: 18, color: textColor),
                          const SizedBox(width: 8),
                          Text(
                            text,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: textColor,
                            ),
                          ),
                          if (onTap != null) ...[
                            const SizedBox(width: 4),
                            Icon(
                              Icons.chevron_right_rounded,
                              size: 18,
                              color: textColor,
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              ),

            // ==============================================================
            const SizedBox(height: 30),
            // ================= 4. 菜单列表 =================
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  _buildMenuTile(
                    context,
                    Icons.person_outline,
                    "编辑资料",
                    primaryTextColor,
                  ),
                  _buildMenuTile(
                    context,
                    Icons.shield_outlined,
                    "账号与安全",
                    primaryTextColor,
                  ),
                  _buildMenuTile(
                    context,
                    Icons.assignment_turned_in_outlined,
                    "我的互助委托",
                    primaryTextColor,
                  ),
                  _buildMenuTile(
                    context,
                    Icons.help_outline_rounded,
                    "帮助中心",
                    primaryTextColor,
                  ),
                  const Divider(height: 30, color: Color(0xFFEAECF0)),
                  _buildMenuTile(
                    context,
                    Icons.logout_rounded,
                    "退出登录",
                    const Color(0xFFE11D48),
                    onTap: () async {
                      await FirebaseAuth.instance.signOut();
                      if (!context.mounted) return;
                      Navigator.of(context).pop();
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoBadge(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDFA),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: const Color(0xFFCCFBF1)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: const Color(0xFF0D9488)),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Color(0xFF0D9488),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuTile(
    BuildContext context,
    IconData icon,
    String title,
    Color color, {
    VoidCallback? onTap,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: color, size: 22),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: color,
        ),
      ),
      trailing: const Icon(
        Icons.arrow_forward_ios,
        color: Color(0xFFD0D5DD),
        size: 16,
      ),
      onTap: onTap ?? () {},
    );
  }
}
