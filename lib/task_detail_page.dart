import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'kyc_page.dart'; // 引入信任中心

class TaskDetailPage extends StatefulWidget {
  final String taskId;
  final Map<String, dynamic> taskData;

  const TaskDetailPage({
    super.key,
    required this.taskId,
    required this.taskData,
  });

  @override
  State<TaskDetailPage> createState() => _TaskDetailPageState();
}

class _TaskDetailPageState extends State<TaskDetailPage> {
  bool _isApplying = false;

  // ⚡ 核心功能：带 KYC 拦截器与防刷单的接单逻辑
  Future<void> _applyForTask() async {
    setState(() => _isApplying = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('未登录');

      // 🚨 第 0 步：防刷单机制！雇主绝对不能接自己的单！
      final String publisherId = widget.taskData['publisherId'] ?? '';
      if (publisherId == user.uid) {
        _showErrorDialog('老板，您不能接自己发布的悬赏哦！');
        setState(() => _isApplying = false);
        return;
      }

      // 🚨 第 1 步：查档！(修复了极其致命的下划线 Bug)
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      // ⚠️ 重点：数据库里存的是 kyc_status！
      final kycStatus = userDoc.data()?['kyc_status'] ?? 'none';

      // 🛡️ 第 2 步：智能拦截！
      if (kycStatus == 'none' || kycStatus == 'unverified') {
        _showKYCDialog('【平台安全合规】\n为了保障雇主资金安全，接单前必须完成大马卡实名建档！', true);
        setState(() => _isApplying = false);
        return; // 🛑 拦截
      } else if (kycStatus == 'pending') {
        _showKYCDialog('【审核中】\n您的实名资料正在人工审核中，通过后即可抢单！', false);
        setState(() => _isApplying = false);
        return; // 🛑 拦截
      } else if (kycStatus == 'rejected') {
        _showKYCDialog('【认证失败】\n您的实名资料不符合要求，请重新拍摄清晰的证件。', true);
        setState(() => _isApplying = false);
        return; // 🛑 拦截
      }

      // 🚨 第 2.5 步：防重复投递机制 (查云端是否已经投过简历了)
      final existingApp = await FirebaseFirestore.instance
          .collection('task_applications')
          .where('taskId', isEqualTo: widget.taskId)
          .where('applicantId', isEqualTo: user.uid)
          .get();

      if (existingApp.docs.isNotEmpty) {
        _showErrorDialog('您已经申请过这个任务啦，请耐心等待雇主审核录用！');
        setState(() => _isApplying = false);
        return; // 🛑 拦截
      }

      // ✅ 第 3 步：身份核验全绿灯，正式提交接单申请！
      await FirebaseFirestore.instance.collection('task_applications').add({
        'taskId': widget.taskId,
        'applicantId': user.uid,
        'applicantName': user.displayName ?? 'XOLV 闪电小哥',
        'status': 'pending',
        'appliedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ 接单申请已发送，请等待雇主录用！'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context); // 退回广场
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('错误: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isApplying = false);
    }
  }

  // 🛑 通用错误提示弹窗
  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange),
            SizedBox(width: 8),
            Text('拦截提示', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          message,
          style: const TextStyle(height: 1.5, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('我知道了', style: TextStyle(color: Colors.grey)),
          ),
        ],
      ),
    );
  }

  // 🛑 KYC 专属拦截弹窗 UI
  void _showKYCDialog(String message, bool showGoToKYC) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.gpp_bad, color: primaryColor, size: 28),
            const SizedBox(width: 8),
            const Text(
              '安全拦截',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ],
        ),
        content: Text(
          message,
          style: const TextStyle(height: 1.5, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('稍后再说', style: TextStyle(color: Colors.grey)),
          ),
          if (showGoToKYC)
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context); // 关掉弹窗
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const KYCPage()),
                ); // 强制押送去认证中心！
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
              child: const Text(
                '立即前往认证',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.taskData;
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          '任务详情',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0.5,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 💰 赏金卡片
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [primaryColor, primaryColor.withValues(alpha: 0.8)],
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: primaryColor.withValues(alpha: 0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Column(
                children: [
                  const Text(
                    '悬赏金额',
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'RM ${data['amount']}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 36,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            // 📝 任务描述
            const Text(
              '任务内容',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(
              data['description'] ?? '无描述',
              style: const TextStyle(
                fontSize: 16,
                height: 1.5,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 24),
            // 📍 任务信息
            const Divider(),
            const SizedBox(height: 16),
            _buildInfoRow(Icons.timer, '期望完成时间', data['expectedTime'] ?? '尽快'),
            const SizedBox(height: 12),
            _buildInfoRow(
              Icons.group,
              '招募人数',
              '${data['acceptedCount'] ?? 0} / ${data['peopleCount'] ?? 1} 人',
            ),
          ],
        ),
      ),
      // 🚀 底部接单按钮
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: ElevatedButton(
            onPressed: _isApplying ? null : _applyForTask,
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 54),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: _isApplying
                ? const CircularProgressIndicator(color: Colors.white)
                : const Text(
                    '⚡ 我要接单',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, color: Colors.grey, size: 20),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 14)),
        const Spacer(),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
      ],
    );
  }
}
