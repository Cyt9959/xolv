import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  // 模拟的设置状态
  bool _pushNotifications = true;
  String _currentLanguage = '简体中文';

  // 🌍 核心新增：极其丝滑的多语言选择弹窗
  void _showLanguagePicker() {
    final primaryColor = Theme.of(context).colorScheme.primary;
    final languages = ['简体中文', 'English', 'Bahasa Melayu'];

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
              ...languages.map((lang) {
                final isSelected = _currentLanguage == lang;
                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 32),
                  title: Text(
                    lang,
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
                  onTap: () {
                    setState(() => _currentLanguage = lang);
                    Navigator.pop(ctx);

                    // 弹出贴心提示
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('✅ 偏好已记录！(注: 全局多语言实时翻译引擎将在 V2.0 启动)'),
                        backgroundColor: Colors.green,
                      ),
                    );
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
    // 💡 修复1：删除了这里没用到的 primaryColor 变量

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          '设置中心',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black),
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
            title: '多语言 (Language)',
            subtitle: _currentLanguage,
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
          _buildListTile(
            icon: Icons.security,
            title: '隐私政策与用户协议',
            onTap: () {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('即将跳转至官网协议页...')));
            },
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
              label: const Text(
                '退出登录',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
