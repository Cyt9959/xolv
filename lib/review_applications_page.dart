import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'taker_profile_page.dart';

class ReviewApplicationsPage extends StatelessWidget {
  final String taskId;
  const ReviewApplicationsPage({super.key, required this.taskId});

  // ⚡ 终极确认录用逻辑（事务锁）
  Future<void> _approveTaker(
    BuildContext context,
    String appId,
    Map<String, dynamic> appData,
  ) async {
    final taskRef = FirebaseFirestore.instance.collection('tasks').doc(taskId);
    final appRef = taskRef.collection('applications').doc(appId);

    final String takerId = appData['takerId'] ?? '';
    final String proposedAmount = appData['proposedAmount'] ?? '0.00';

    try {
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final taskSnapshot = await transaction.get(taskRef);
        if (!taskSnapshot.exists) return;

        final taskData = taskSnapshot.data() as Map<String, dynamic>;
        final List<dynamic> acceptedUsers = taskData['acceptedUsers'] ?? [];
        final int peopleCount = taskData['peopleCount'] ?? 1;

        if (!acceptedUsers.contains(takerId)) {
          acceptedUsers.add(takerId);
        }
        final int newAcceptedCount = acceptedUsers.length;
        final String newStatus = newAcceptedCount >= peopleCount
            ? 'in_progress'
            : 'pending';

        // 更新主任务档案
        transaction.update(taskRef, {
          'amount': proposedAmount, // 如果是谈判成功，自动修改为主价格；如果是普通抢单，保持原价不变
          'acceptedUsers': acceptedUsers,
          'acceptedCount': newAcceptedCount,
          'status': newStatus,
        });

        // 将当前申请标记为已录用成功
        transaction.update(appRef, {'status': 'accepted'});
      });

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🎉 录用成功！接单伙伴已加入队伍并收到通知！'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('处理失败: $e')));
      }
    }
  }

  // 拒绝申请
  Future<void> _rejectTaker(BuildContext context, String appId) async {
    try {
      await FirebaseFirestore.instance
          .collection('tasks')
          .doc(taskId)
          .collection('applications')
          .doc(appId)
          .update({'status': 'rejected'});
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已婉拒该申请'), backgroundColor: Colors.grey),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('失败: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('审批接单与谈判申请'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0.5,
      ),
      body: StreamBuilder<QuerySnapshot>(
        // 实时追踪这单底下所有的 pending 申请
        stream: FirebaseFirestore.instance
            .collection('tasks')
            .doc(taskId)
            .collection('applications')
            .where('status', isEqualTo: 'pending')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.black),
            );
          }
          final apps = snapshot.data?.docs ?? [];
          if (apps.isEmpty) {
            return const Center(
              child: Text('暂无需要审批的接单申请', style: TextStyle(color: Colors.grey)),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: apps.length,
            itemBuilder: (context, index) {
              final doc = apps[index];
              final data = doc.data() as Map<String, dynamic>;
              final bool isNegotiation = data['type'] == 'negotiation';

              return Card(
                margin: const EdgeInsets.only(bottom: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: const BorderSide(color: Colors.black12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          InkWell(
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => TakerProfilePage(
                                  takerId: data['takerId'],
                                ),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  data['takerName'] ?? '申请人',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    decoration: TextDecoration.underline,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                TakerLevelBadge(takerId: data['takerId'] ?? ''),
                              ],
                            ),
                          ),

                          // 📺 标志性高亮徽章：一眼看穿他是直接来抢单，还是来谈判的！
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: isNegotiation
                                  ? Colors.blue[50]
                                  : Colors.green[50],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              isNegotiation ? '谈价谈判' : '直接抢单',
                              style: TextStyle(
                                color: isNegotiation
                                    ? Colors.blue
                                    : Colors.green,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          const Text(
                            '出价赏金：',
                            style: TextStyle(color: Colors.grey, fontSize: 14),
                          ),
                          Text(
                            'RM ${data['proposedAmount']}',
                            style: const TextStyle(
                              color: Colors.blue,
                              fontWeight: FontWeight.w900,
                              fontSize: 18,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        '说明/留言：',
                        style: TextStyle(
                          color: Colors.grey,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        data['reason'] ?? '',
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.black87,
                          height: 1.4,
                        ),
                      ),
                      const Divider(height: 28),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => _rejectTaker(context, doc.id),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.redAccent,
                                side: const BorderSide(color: Colors.redAccent),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text(
                                '婉拒申请',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () =>
                                  _approveTaker(context, doc.id, data),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.black,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text(
                                '录用并让其加入',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
