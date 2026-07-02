import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'theme/app_theme.dart';
import 'widgets/app_skeleton.dart';

class WalletPage extends StatefulWidget {
  const WalletPage({super.key});

  @override
  State<WalletPage> createState() => _WalletPageState();
}

class _WalletPageState extends State<WalletPage> {
  final user = FirebaseAuth.instance.currentUser;

  // 💡 这是一个模拟充值的方法，用来给你测试扣钱
  Future<void> _simulateTopUp() async {
    if (user == null) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final double topUpAmount = 50.00; // 每次充值 50 块

      final batch = FirebaseFirestore.instance.batch();
      final userRef = FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid);
      final txRef = FirebaseFirestore.instance.collection('transactions').doc();

      // 1. 给钱包加钱 (使用 FieldValue.increment)
      batch.update(userRef, {
        'wallet_balance': FieldValue.increment(topUpAmount),
      });

      // 2. 写入一条流水
      batch.set(txRef, {
        'userId': user!.uid,
        'title': '微信/银行卡充值',
        'amount': topUpAmount,
        'type': 'income',
        'createdAt': FieldValue.serverTimestamp(),
        'status': '已入账',
      });

      await batch.commit();

      if (mounted) {
        Navigator.pop(context); // 关掉圈圈
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ 成功充值 RM 50.00！'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
    }
  }

  // 辅助方法：格式化云端时间戳
  String _formatDate(Timestamp? timestamp) {
    if (timestamp == null) return '时间获取中...';
    final DateTime date = timestamp.toDate();
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;

    if (user == null) {
      return const Scaffold(body: Center(child: Text("请先登录！")));
    }

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          'wallet'.tr(),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0.5,
        foregroundColor: Colors.black,
      ),
      body: Column(
        children: [
          // ==========================================
          // 💳 第一只云端眼睛：监听用户余额
          // ==========================================
          StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .doc(user!.uid)
                .snapshots(),
            builder: (context, snapshot) {
              double availableBalance = 0.00;

              if (snapshot.hasData && snapshot.data!.exists) {
                final data = snapshot.data!.data() as Map<String, dynamic>?;
                // 如果数据库里还没有 wallet_balance 字段，当做 0 处理
                availableBalance = (data?['wallet_balance'] ?? 0.0).toDouble();
              }

              return Container(
                width: double.infinity,
                margin: const EdgeInsets.all(20),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [primaryColor, const Color(0xFFFF8E4D)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: primaryColor.withValues(alpha: 0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${'balance'.tr()} (RM)',
                      style: const TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      availableBalance.toStringAsFixed(2),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 40,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        _buildBalanceInfo('托管中 (即将上线)', 'RM 0.00'),
                        const SizedBox(width: 40),
                        _buildBalanceInfo('本月收入', 'RM 0.00'),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),

          // ⚡ 快捷操作区
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Expanded(
                  child: _buildActionBtn(
                    Icons.account_balance_wallet,
                    'top_up'.tr(),
                    Colors.blue,
                    _simulateTopUp, // 👈 接入充值测试电线
                  ),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: _buildActionBtn(Icons.payments, 'withdraw'.tr(), Colors.grey, () {
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(const SnackBar(content: Text('提现功能开发中...')));
                  }),
                ),
              ],
            ),
          ),

          const SizedBox(height: 30),

          // ==========================================
          // 📜 第二只云端眼睛：监听流水明细
          // ==========================================
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(left: 24, top: 24, bottom: 16),
                    child: Text(
                      'transactions'.tr(),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Expanded(
                    child: StreamBuilder<QuerySnapshot>(
                      // 实时拉取属于我的交易记录，并按时间倒序排列
                      stream: FirebaseFirestore.instance
                          .collection('transactions')
                          .where('userId', isEqualTo: user!.uid)
                          .orderBy('createdAt', descending: true)
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const _WalletSkeletonList();
                        }

                        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                          return const Center(
                            child: Text(
                              '暂无交易记录\n点击上方测试充值试一试！',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.grey),
                            ),
                          );
                        }

                        final docs = snapshot.data!.docs;

                        return ListView.builder(
                          itemCount: docs.length,
                          itemBuilder: (context, index) {
                            final tx =
                                docs[index].data() as Map<String, dynamic>;
                            final double amount = (tx['amount'] ?? 0)
                                .toDouble();
                            final bool isIncome = amount > 0;

                            return ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 8,
                              ),
                              leading: CircleAvatar(
                                backgroundColor: isIncome
                                    ? Colors.orange[50]
                                    : Colors.red[50],
                                child: Icon(
                                  isIncome
                                      ? Icons.add_rounded
                                      : Icons.remove_rounded,
                                  color: isIncome ? Colors.orange : Colors.red,
                                ),
                              ),
                              title: Text(
                                tx['title'] ?? '未知交易',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                              subtitle: Text(
                                _formatDate(tx['createdAt'] as Timestamp?),
                                style: const TextStyle(
                                  color: Colors.grey,
                                  fontSize: 12,
                                ),
                              ),
                              trailing: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    '${isIncome ? "+" : ""}${amount.toStringAsFixed(2)}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      color: isIncome
                                          ? Colors.black
                                          : Colors.red,
                                    ),
                                  ),
                                  Text(
                                    tx['status'] ?? '已处理',
                                    style: const TextStyle(
                                      color: Colors.grey,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBalanceInfo(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.white60, fontSize: 12),
        ),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildActionBtn(
    IconData icon,
    String label,
    Color color,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.black12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// 💀 交易流水加载骨架屏
// ==========================================
class _WalletSkeletonRow extends StatelessWidget {
  const _WalletSkeletonRow();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Row(
        children: [
          const AppSkeleton(
            width: 40,
            height: 40,
            borderRadius: AppRadius.sm,
          ),
          const SizedBox(width: AppSpacing.md),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppSkeleton(width: 120, height: 14),
                SizedBox(height: AppSpacing.xs),
                AppSkeleton(width: 80, height: 12),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          const AppSkeleton(width: 60, height: 16),
        ],
      ),
    );
  }
}

class _WalletSkeletonList extends StatelessWidget {
  const _WalletSkeletonList();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      itemCount: 6,
      separatorBuilder: (context, index) =>
          const SizedBox(height: AppSpacing.md),
      itemBuilder: (context, index) => const _WalletSkeletonRow(),
    );
  }
}
