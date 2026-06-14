import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// ==========================================
// 👤 接单人个人主页（数据化版本）
// ==========================================
class TakerProfilePage extends StatelessWidget {
  final String takerId;
  const TakerProfilePage({super.key, required this.takerId});

  String _formatJoinedDays(Timestamp? createdAt) {
    if (createdAt == null) return '加入时间未知';
    final int days = DateTime.now().difference(createdAt.toDate()).inDays;
    if (days <= 0) return '今天加入';
    return '$days 天前加入';
  }

  String _formatDate(Timestamp? timestamp) {
    if (timestamp == null) return '';
    final DateTime date = timestamp.toDate();
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;

    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('users').doc(takerId).get(),
      builder: (context, userSnapshot) {
        if (userSnapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            appBar: AppBar(
              backgroundColor: Colors.white,
              foregroundColor: Colors.black,
              elevation: 0.5,
            ),
            body: const Center(
              child: CircularProgressIndicator(color: Colors.black),
            ),
          );
        }

        final userData =
            userSnapshot.data?.data() as Map<String, dynamic>? ?? {};
        final String name = userData['name'] ?? 'XOLV 用户';
        final String avatarUrl = userData['avatarUrl'] ?? '';
        final bool isVerified = (userData['kyc_status'] ?? '') == 'approved';
        final Timestamp? createdAt = userData['createdAt'] as Timestamp?;

        return Scaffold(
          backgroundColor: Colors.grey[50],
          appBar: AppBar(
            title: Text(
              name,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            backgroundColor: Colors.white,
            foregroundColor: Colors.black,
            elevation: 0.5,
          ),
          body: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              // ========================================
              // 🧑 头像 + 名字 + 蓝V认证
              // ========================================
              Center(
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 44,
                      backgroundColor: primaryColor.withValues(alpha: 0.1),
                      backgroundImage: avatarUrl.isNotEmpty
                          ? NetworkImage(avatarUrl)
                          : null,
                      child: avatarUrl.isEmpty
                          ? Icon(
                              Icons.person,
                              size: 44,
                              color: primaryColor,
                            )
                          : null,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          name,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (isVerified) ...[
                          const SizedBox(width: 6),
                          const Icon(
                            Icons.verified,
                            color: Colors.blue,
                            size: 20,
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // ========================================
              // 📊 数据统计卡片（横排三格）
              // ========================================
              Row(
                children: [
                  Expanded(
                    child: _StatCard(
                      label: '完成任务数',
                      primaryColor: primaryColor,
                      child: FutureBuilder<QuerySnapshot>(
                        future: FirebaseFirestore.instance
                            .collection('tasks')
                            .where('status', isEqualTo: 'completed')
                            .where('acceptedUsers', arrayContains: takerId)
                            .get(),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData) {
                            return const _StatLoading();
                          }
                          return _StatValue(
                            text: '${snapshot.data!.docs.length}',
                            color: primaryColor,
                          );
                        },
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _StatCard(
                      label: '平均评分',
                      primaryColor: primaryColor,
                      child: FutureBuilder<QuerySnapshot>(
                        future: FirebaseFirestore.instance
                            .collection('reviews')
                            .where('rateeId', isEqualTo: takerId)
                            .get(),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData) {
                            return const _StatLoading();
                          }
                          final docs = snapshot.data!.docs;
                          if (docs.isEmpty) {
                            return _StatValue(
                              text: '⭐ -',
                              color: primaryColor,
                            );
                          }
                          double total = 0;
                          for (var doc in docs) {
                            final data = doc.data() as Map<String, dynamic>;
                            total += (data['rating'] as num?)?.toDouble() ?? 0;
                          }
                          final double avg = total / docs.length;
                          return _StatValue(
                            text: '⭐ ${avg.toStringAsFixed(1)}',
                            color: primaryColor,
                          );
                        },
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _StatCard(
                      label: '加入时间',
                      primaryColor: primaryColor,
                      child: _StatValue(
                        text: _formatJoinedDays(createdAt),
                        color: primaryColor,
                        small: true,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),

              // ========================================
              // 💬 最近评价列表
              // ========================================
              const Text(
                '最近评价',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('reviews')
                    .where('rateeId', isEqualTo: takerId)
                    .orderBy('createdAt', descending: true)
                    .limit(5)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Center(
                        child: CircularProgressIndicator(color: Colors.black),
                      ),
                    );
                  }

                  final docs = snapshot.data?.docs ?? [];
                  if (docs.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Center(
                        child: Text(
                          '暂无评价记录',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
                    );
                  }

                  return Column(
                    children: docs.map((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      final double rating =
                          (data['rating'] as num?)?.toDouble() ?? 0;
                      final String comment = data['comment'] ?? '';
                      final String raterName = data['raterName'] ?? 'XOLV 用户';
                      final Timestamp? createdAt =
                          data['createdAt'] as Timestamp?;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
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
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: List.generate(5, (i) {
                                    return Icon(
                                      i < rating.round()
                                          ? Icons.star
                                          : Icons.star_border,
                                      color: Colors.amber,
                                      size: 16,
                                    );
                                  }),
                                ),
                                Text(
                                  _formatDate(createdAt),
                                  style: const TextStyle(
                                    color: Colors.grey,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              comment,
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.black87,
                                height: 1.4,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '- $raterName',
                              style: const TextStyle(
                                color: Colors.grey,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

// ------------------------------------------------------------
// 📦 统计卡片容器
// ------------------------------------------------------------
class _StatCard extends StatelessWidget {
  final String label;
  final Widget child;
  final Color primaryColor;

  const _StatCard({
    required this.label,
    required this.child,
    required this.primaryColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 8),
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
        children: [
          child,
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(color: Colors.grey, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------
// 🔢 统计数值（加粗放大）
// ------------------------------------------------------------
class _StatValue extends StatelessWidget {
  final String text;
  final Color color;
  final bool small;

  const _StatValue({
    required this.text,
    required this.color,
    this.small = false,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: small ? 14 : 22,
        fontWeight: FontWeight.w900,
        color: color,
      ),
    );
  }
}

class _StatLoading extends StatelessWidget {
  const _StatLoading();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 22,
      width: 22,
      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.grey),
    );
  }
}
