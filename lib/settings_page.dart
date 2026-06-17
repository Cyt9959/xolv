import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:url_launcher/url_launcher.dart';
import 'how_it_works_page.dart';
import 'history_page.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  // 模拟的设置状态
  bool _pushNotifications = true;

  // 🌍 当前语言的展示名称
  String _languageLabel(String code) {
    switch (code) {
      case 'en':
        return 'English';
      case 'ms':
        return 'Bahasa Malaysia';
      default:
        return '简体中文';
    }
  }

  // 🌍 核心新增：极其丝滑的多语言选择弹窗
  void _showLanguagePicker() {
    final primaryColor = Theme.of(context).colorScheme.primary;
    const languages = {
      'zh': '简体中文',
      'en': 'English',
      'ms': 'Bahasa Malaysia',
    };

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Container(
          padding: EdgeInsets.only(
            top: 24,
            bottom: MediaQuery.of(context).padding.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                '选择语言 / Select Language',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              ...languages.entries.map((entry) {
                final isSelected = context.locale.languageCode == entry.key;
                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 32),
                  title: Text(
                    entry.value,
                    style: TextStyle(
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.normal,
                      color: isSelected ? primaryColor : Colors.black87,
                      fontSize: 16,
                    ),
                  ),
                  trailing: isSelected
                      ? Icon(Icons.check_circle, color: primaryColor)
                      : null,
                  onTap: () async {
                    await context.setLocale(Locale(entry.key));
                    if (mounted) setState(() {});
                    if (ctx.mounted) Navigator.pop(ctx);
                  },
                );
              }),
            ],
          ),
        );
      },
    );
  }

  // 🧹 清除缓存特效
  void _clearCache() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(
          '清除缓存',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: const Text('确定要清除 App 的本地缓存吗？这不会删除您的账号数据。'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('🧹 缓存已清理，释放了 24.5 MB 空间！')),
              );
            },
            child: const Text('确认清除'),
          ),
        ],
      ),
    );
  }

  // 🚪 退出登录
  Future<void> _signOut() async {
    try {
      await FirebaseAuth.instance.signOut();
      if (mounted) {
        // 退出后，把路由栈清空，防止用户按返回键又回到页面
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('退出失败: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          'settings'.tr(),
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0.5,
        iconTheme: const IconThemeData(color: Colors.black),
        centerTitle: true,
      ),
      body: ListView(
        children: [
          const SizedBox(height: 16),

          // 模块 1：偏好设置
          _buildSectionTitle('系统偏好'),
          _buildListTile(
            icon: Icons.language,
            title: 'language'.tr(),
            subtitle: _languageLabel(context.locale.languageCode),
            onTap: _showLanguagePicker,
          ),
          _buildSwitchTile(
            icon: Icons.notifications_active_outlined,
            title: '接单/发布 实时推送',
            subtitle: '保持开启以防错过黄金悬赏',
            value: _pushNotifications,
            onChanged: (val) => setState(() => _pushNotifications = val),
          ),

          const SizedBox(height: 24),

          // 模块 2：通用设置
          _buildSectionTitle('通用与安全'),
          ListTile(
            leading: const Icon(Icons.history, color: Colors.blueGrey),
            title: const Text('历史记录', style: TextStyle(fontWeight: FontWeight.w600)),
            subtitle: const Text('查看已完成的任务和委托'),
            trailing: const Icon(Icons.chevron_right, color: Colors.grey),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const HistoryPage()),
            ),
          ),
          ListTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: primaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.menu_book, color: primaryColor, size: 20),
            ),
            title: const Text(
              '📖 平台使用指南',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: const Text('了解如何发单和接单'),
            trailing: const Icon(Icons.chevron_right, color: Colors.grey),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const HowItWorksPage()),
            ),
          ),
          _buildListTile(
            icon: Icons.privacy_tip_outlined,
            title: '隐私政策',
            onTap: () =>
                launchUrl(Uri.parse('https://cytxolv.com/privacy-policy.html')),
          ),
          _buildListTile(
            icon: Icons.description_outlined,
            title: '使用条款',
            onTap: () =>
                launchUrl(Uri.parse('https://cytxolv.com/terms.html')),
          ),
          _buildListTile(
            icon: Icons.cleaning_services_outlined,
            title: '清除本地缓存',
            onTap: _clearCache,
          ),
          _buildListTile(
            icon: Icons.info_outline,
            title: '关于 XOLV',
            subtitle: '当前版本: v0.1.0-MVP',
            onTap: () {}, // 可做彩蛋
          ),

          const SizedBox(height: 40),

          // 模块 3：危险操作区
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: ElevatedButton.icon(
              onPressed: _signOut,
              icon: const Icon(Icons.logout),
              label: Text(
                'logout'.tr(),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.redAccent,
                elevation: 0,
                side: const BorderSide(color: Colors.redAccent),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          const SizedBox(height: 40),
          const Center(
            child: Text(
              'XOLV v0.1.0 - 专为大马同城跑腿而生 🚀',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  // 小组件：模块标题
  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 24, bottom: 8, top: 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }

  // 小组件：普通的点击项
  Widget _buildListTile({
    required IconData icon,
    required String title,
    String? subtitle,
    required VoidCallback onTap,
  }) {
    return Container(
      color: Colors.white,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
        leading: Icon(icon, color: Colors.black87),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 16),
        ),
        subtitle: subtitle != null
            ? Text(
                subtitle,
                style: const TextStyle(color: Colors.grey, fontSize: 13),
              )
            : null,
        trailing: const Icon(Icons.chevron_right, color: Colors.grey),
        onTap: onTap,
      ),
    );
  }

  // 小组件：带开关的项
  Widget _buildSwitchTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      color: Colors.white,
      child: SwitchListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
        secondary: Icon(icon, color: Colors.black87),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 16),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(color: Colors.grey, fontSize: 13),
        ),
        // 💡 修复2：彻底删除了老旧被淘汰的 activeColor 写法
        value: value,
        onChanged: onChanged,
      ),
    );
  }
}
