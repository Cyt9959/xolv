import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:share_plus/share_plus.dart';
import 'kyc_page.dart';
import 'theme/app_theme.dart';
import 'widgets/app_tappable.dart';

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

  // ========================================
  // 📲 一键分享任务（原生分享菜单）
  // ========================================
  Future<void> _shareTask() async {
    final data = widget.taskData;
    final String taskId = widget.taskId;
    final String shareText =
        '''
📢 【XOLV 悬赏任务】

📝 ${data['description']}
📍 ${data['location']}
💰 悬赏金额：RM ${data['amount']}
⏰ 完成时限：${data['expectedTime']}

👇 点击直接查看任务：
https://cytxolv.com/task/$taskId

快来 XOLV 接单赚钱！💪
''';

    await Share.share(shareText, subject: 'XOLV 悬赏任务');
  }

  // ========================================
  // 🛡️ KYC 双轨容错验证（与其他页面保持一致）
  // ========================================
  Future<String> _getKycStatus() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return 'none';

    // 轨道 A：查 users 总表
    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();
    String kycStatus = (userDoc.data()?['kyc_status'] ?? 'none')
        .toString()
        .trim()
        .toLowerCase();

    // 轨道 B：总表未通过则深度扫描申请表
    if (kycStatus != 'approved') {
      final kycAppDoc = await FirebaseFirestore.instance
          .collection('kyc_applications')
          .doc(user.uid)
          .get();
      if (kycAppDoc.exists) {
        final appStatus = (kycAppDoc.data()?['status'] ?? 'none')
            .toString()
            .trim()
            .toLowerCase();
        if (appStatus == 'approved') {
          kycStatus = 'approved';
        } else if (appStatus == 'pending' && kycStatus == 'none')
          kycStatus = 'pending';
        else if (appStatus == 'rejected' && kycStatus == 'none')
          kycStatus = 'rejected';
      }
    }

    return kycStatus;
  }

  // ========================================
  // ⚡ 主入口：接单前安检 + 防刷单 + 弹出选项
  // ========================================
  Future<void> _handleApply() async {
    setState(() => _isApplying = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('未登录');

      // 🚨 第 0 步：防刷单——雇主不能接自己的单
      final String publisherId = widget.taskData['publisherId'] ?? '';
      if (publisherId == user.uid) {
        _showErrorDialog('老板，您不能接自己发布的悬赏哦！');
        return;
      }

      // 🚨 第 1 步：KYC 双轨验证
      final kycStatus = await _getKycStatus();

      if (kycStatus != 'approved') {
        if (kycStatus == 'pending') {
          _showKYCDialog('【审核中】\n您的实名资料正在人工审核中，通过后即可抢单！', false);
        } else if (kycStatus == 'rejected') {
          _showKYCDialog('【认证失败】\n您的实名资料不符合要求，请重新拍摄清晰的证件。', true);
        } else if (kycStatus == 'revoked') {
          _showKYCDialog('您的实名认证已被平台撤销，请联系客服了解详情。', false);
        } else {
          _showKYCDialog('【平台安全合规】\n为了保障雇主资金安全，接单前必须完成大马卡实名建档！', true);
        }
        return;
      }

      // 🚨 第 2 步：防重复投递
      // ✅ 修复：正确路径 tasks/{taskId}/applications，字段名 takerId
      final existingApp = await FirebaseFirestore.instance
          .collection('tasks')
          .doc(widget.taskId)
          .collection('applications')
          .where('takerId', isEqualTo: user.uid)
          .get();

      if (existingApp.docs.isNotEmpty) {
        // 检查是否所有历史申请都是被拒绝的，如果有 pending 或 approved 才真正拦截
        final hasActiveApplication = existingApp.docs.any((doc) {
          final status = (doc.data())['status'];
          return status == 'pending' || status == 'approved';
        });

        if (hasActiveApplication) {
          _showErrorDialog('您已经申请过这个任务啦，请耐心等待雇主审核录用！');
          return;
        }
        // 如果都是 rejected 状态，允许继续往下走，重新申请
      }

      // ✅ 第 3 步：通过所有安检，弹出接单方式选择器
      if (mounted) _showApplyOptionsSheet(user);
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

  // ========================================
  // 💬 接单选项底部弹窗（直接抢单 / 谈价接单）
  // ========================================
  void _showApplyOptionsSheet(User user) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    final originalAmount = widget.taskData['amount']?.toString() ?? '0';
    final negotiateAmountController = TextEditingController();
    final reasonController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            top: 24,
            left: 24,
            right: 24,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 32,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 顶部 Handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const Text(
                '选择接单方式',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Text(
                '原悬赏金额：RM $originalAmount',
                style: const TextStyle(color: Colors.grey, fontSize: 14),
              ),
              const SizedBox(height: 20),

              // ⚡ 直接抢单
              ElevatedButton.icon(
                icon: const Icon(Icons.flash_on, size: 18),
                label: const Text(
                  '⚡ 直接抢单（按原定金额）',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 52),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () async {
                  Navigator.pop(ctx);
                  await _submitApplication(
                    user: user,
                    type: 'direct',
                    proposedAmount: originalAmount,
                    reason: '直接接单，无额外留言。',
                  );
                },
              ),

              const SizedBox(height: 20),
              const Row(
                children: [
                  Expanded(child: Divider()),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: Text('或者谈价接单', style: TextStyle(color: Colors.grey)),
                  ),
                  Expanded(child: Divider()),
                ],
              ),
              const SizedBox(height: 16),

              // 💬 谈价接单区域
              TextField(
                controller: negotiateAmountController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: '我的出价（RM）',
                  prefixText: 'RM ',
                  filled: true,
                  fillColor: Colors.grey[50],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.black12),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.black12),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: reasonController,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: '留言给雇主（说明你的技能或理由）',
                  filled: true,
                  fillColor: Colors.grey[50],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.black12),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.black12),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              OutlinedButton.icon(
                icon: const Icon(Icons.send_outlined, size: 18),
                label: const Text(
                  '提交谈价申请',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: primaryColor,
                  side: BorderSide(color: primaryColor),
                  minimumSize: const Size(double.infinity, 52),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () async {
                  final amount = negotiateAmountController.text.trim();
                  if (amount.isEmpty) {
                    ScaffoldMessenger.of(
                      ctx,
                    ).showSnackBar(const SnackBar(content: Text('请填写您的出价！')));
                    return;
                  }
                  Navigator.pop(ctx);
                  await _submitApplication(
                    user: user,
                    type: 'negotiation',
                    proposedAmount: amount,
                    reason: reasonController.text.trim().isEmpty
                        ? '谈价接单，无额外留言。'
                        : reasonController.text.trim(),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  // ========================================
  // ✅ 核心写入（修复后的正确路径与字段名）
  // ========================================
  Future<void> _submitApplication({
    required User user,
    required String type, // 'direct' 或 'negotiation'
    required String proposedAmount, // 出价金额
    required String reason, // 留言
  }) async {
    try {
      // ✅ 修复 1：正确集合路径 —— tasks/{taskId}/applications（子集合）
      // ❌ 原来错误路径：task_applications（根集合）
      await FirebaseFirestore.instance
          .collection('tasks')
          .doc(widget.taskId)
          .collection('applications')
          .add({
            'takerId': user.uid, // ✅ 修复 2：字段名 takerId
            'takerName':
                user.displayName ?? 'XOLV 闪电小哥', // ✅ 修复 3：字段名 takerName
            'type': type, // ✅ 新增：接单类型
            'proposedAmount': proposedAmount, // ✅ 新增：出价金额
            'reason': reason, // ✅ 新增：留言
            'status': 'pending',
            'appliedAt': FieldValue.serverTimestamp(),
          });

      // 📛 新增一个待审核申请，未读 Badge 数 +1
      await FirebaseFirestore.instance
          .collection('tasks')
          .doc(widget.taskId)
          .update({'pendingApplicationsCount': FieldValue.increment(1)});

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              type == 'direct' ? '✅ 抢单成功！请等待雇主录用！' : '✅ 谈价申请已发送，请等待雇主回复！',
            ),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('提交失败: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // ========================================
  // 📢 弹窗辅助方法
  // ========================================
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
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const KYCPage()),
                );
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

  // ========================================
  // 🖼️ 全屏查看任务附图
  // ========================================
  void _showFullImage(BuildContext context, String imageUrl) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.zero,
        child: Stack(
          children: [
            GestureDetector(
              onTap: () => Navigator.pop(ctx),
              child: Container(
                color: Colors.black,
                width: double.infinity,
                height: double.infinity,
                child: InteractiveViewer(
                  child: Center(
                    child: Image.network(imageUrl, fit: BoxFit.contain),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 40,
              right: 16,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 28),
                onPressed: () => Navigator.pop(ctx),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ========================================
  // 🎨 UI 构建
  // ========================================
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
        actions: [
          IconButton(
            icon: const Icon(Icons.share, color: Colors.black),
            onPressed: _shareTask,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 悬赏金额卡片
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
            if (data['isUrgent'] == true)
              Container(
                margin: const EdgeInsets.only(top: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(
                  children: [
                    const Text('🔥', style: TextStyle(fontSize: 20)),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '急单任务',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.red,
                          ),
                        ),
                        const Text(
                          '接单额外获得 RM 2 急单奖励！',
                          style: TextStyle(fontSize: 12, color: Colors.red),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 24),
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
            if ((data['imageUrls'] as List?)?.isNotEmpty == true) ...[
              const SizedBox(height: 16),
              SizedBox(
                height: 200,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: (data['imageUrls'] as List).length,
                  itemBuilder: (ctx, i) => AppTappable(
                    borderRadius: AppRadius.md,
                    onTap: () => _showFullImage(context, data['imageUrls'][i]),
                    child: Container(
                      margin: const EdgeInsets.only(right: 8),
                      width: 200,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        image: DecorationImage(
                          image: NetworkImage(data['imageUrls'][i]),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 24),
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
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: ElevatedButton(
            onPressed: _isApplying ? null : _handleApply,
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
