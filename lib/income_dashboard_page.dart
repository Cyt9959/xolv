import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'theme/app_theme.dart';
import 'widgets/app_skeleton.dart';

// ==========================================
// 📊 接单人收入仪表板
// ==========================================
class IncomeDashboardPage extends StatelessWidget {
  const IncomeDashboardPage({super.key});

  String _formatDate(Timestamp? timestamp) {
    if (timestamp == null) return '';
    final DateTime date = timestamp.toDate();
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final primaryColor = Theme.of(context).colorScheme.primary;

    if (user == null) {
      return const Scaffold(body: Center(child: Text('请先登录！')));
    }

    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final weekStart = todayStart.subtract(Duration(days: now.weekday - 1));
    final monthStart = DateTime(now.year, now.month, 1);

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          '收入报告',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0.5,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('transactions')
            .where('userId', isEqualTo: user.uid)
            .where('type', whereIn: ['income', 'refund'])
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const _IncomeSkeleton();
          }

          final docs = snapshot.data?.docs ?? [];

          double todayTotal = 0;
          double weekTotal = 0;
          double monthTotal = 0;

          for (final doc in docs) {
            final data = doc.data() as Map<String, dynamic>;
            final Timestamp? ts = data['createdAt'] as Timestamp?;
            if (ts == null) continue;
            final date = ts.toDate();
            final double amount = (data['amount'] as num?)?.toDouble() ?? 0;

            if (!date.isBefore(todayStart)) todayTotal += amount;
            if (!date.isBefore(weekStart)) weekTotal += amount;
            if (!date.isBefore(monthStart)) monthTotal += amount;
          }

          final recent = docs.take(10).toList();

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.7,
                children: [
                  _StatCard(label: '今日收入', value: todayTotal, color: primaryColor),
                  _StatCard(label: '本周收入', value: weekTotal, color: primaryColor),
                  _StatCard(label: '本月收入', value: monthTotal, color: primaryColor),
                  _CompletedTasksCard(uid: user.uid, primaryColor: primaryColor),
                ],
              ),
              const SizedBox(height: 24),
              const Text(
                '最近收入流水',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              if (recent.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Text('暂无收入记录', style: TextStyle(color: Colors.grey)),
                  ),
                )
              else
                ...recent.map((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final double amount =
                      (data['amount'] as num?)?.toDouble() ?? 0;
                  final Timestamp? ts = data['createdAt'] as Timestamp?;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          offset: const Offset(0, 2),
                          blurRadius: 8,
                          color: Colors.black.withValues(alpha: 0.05),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                data['title'] ?? '收入',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _formatDate(ts),
                                style: const TextStyle(
                                  color: Colors.grey,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          '+RM ${amount.toStringAsFixed(2)}',
                          style: const TextStyle(
                            color: Colors.green,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
            ],
          );
        },
      ),
    );
  }
}

// ------------------------------------------------------------
// 📦 统计卡片
// ------------------------------------------------------------
class _StatCard extends StatelessWidget {
  final String label;
  final double value;
  final Color color;

  const _StatCard({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            offset: const Offset(0, 4),
            blurRadius: 12,
            color: Colors.black.withValues(alpha: 0.05),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13)),
          const SizedBox(height: 8),
          Text(
            'RM ${value.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------
// 📦 累计完成任务数卡片
// ------------------------------------------------------------
class _CompletedTasksCard extends StatelessWidget {
  final String uid;
  final Color primaryColor;

  const _CompletedTasksCard({required this.uid, required this.primaryColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            offset: const Offset(0, 4),
            blurRadius: 12,
            color: Colors.black.withValues(alpha: 0.05),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            '累计完成任务数',
            style: TextStyle(color: Colors.grey, fontSize: 13),
          ),
          const SizedBox(height: 8),
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('tasks')
                .where('acceptedUsers', arrayContains: uid)
                .where('status', isEqualTo: 'completed')
                .snapshots(),
            builder: (context, snapshot) {
              final int count = snapshot.data?.docs.length ?? 0;
              return Text(
                '$count',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: primaryColor,
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

// ==========================================
// 💀 收入仪表板加载骨架屏
// ==========================================
class _IncomeSkeleton extends StatelessWidget {
  const _IncomeSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: const [
        Row(
          children: [
            Expanded(
              child: AppSkeleton(height: 80, borderRadius: AppRadius.md),
            ),
            SizedBox(width: AppSpacing.sm),
            Expanded(
              child: AppSkeleton(height: 80, borderRadius: AppRadius.md),
            ),
            SizedBox(width: AppSpacing.sm),
            Expanded(
              child: AppSkeleton(height: 80, borderRadius: AppRadius.md),
            ),
          ],
        ),
        SizedBox(height: AppSpacing.lg),
        AppSkeleton(height: 160, borderRadius: AppRadius.lg),
      ],
    );
  }
}
