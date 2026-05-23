import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

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
  bool _isSubmitting = false;

  // 🚀 核心重构：不管是“直接接单”还是“谈价谈判”，统一走申请管道写入云端！
  Future<void> _submitApplication({
    required String type,
    required String amount,
    required String reason,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    if (user.uid == widget.taskData['publisherId']) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('老板，不能接自己发布的单哦'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      // 写入统一的 applications 子集合
      await FirebaseFirestore.instance
          .collection('tasks')
          .doc(widget.taskId)
          .collection('applications')
          .add({
            'takerId': user.uid,
            'takerName': user.displayName ?? 'XOLV 伙伴',
            'proposedAmount': amount,
            'reason': reason,
            'type': type, // 'direct_claim' (直接接单) 或 'negotiation' (出价谈判)
            'status': 'pending',
            'createdAt': FieldValue.serverTimestamp(),
          });

      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('🎉 申请已提交'),
            content: Text(
              type == 'direct_claim'
                  ? '接单意向已送达老板后台！请耐心等待老板审核录用。'
                  : '谈判出价已送达！老板同意后将自动加入项目。',
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.pop(context);
                },
                child: const Text('好的'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('提交失败: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showNegotiationBottomSheet() {
    final priceController = TextEditingController();
    final reasonController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          top: 24,
          left: 24,
          right: 24,
          bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              '发起赏金谈判',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: priceController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: '您期望的每人可得金额 (RM)',
                prefixIcon: const Icon(Icons.attach_money),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: '写下您的谈价理由...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                final p = priceController.text.trim();
                final r = reasonController.text.trim();
                if (p.isEmpty || r.isEmpty) return;
                _submitApplication(type: 'negotiation', amount: p, reason: r);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                '提交谈判申请',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('tasks')
          .doc(widget.taskId)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final data = snapshot.data!.data() as Map<String, dynamic>;

        final int peopleCount = data['peopleCount'] ?? 1;
        final int acceptedCount = data['acceptedCount'] ?? 0;
        final List<dynamic> acceptedUsers = data['acceptedUsers'] ?? [];
        final currentUid = FirebaseAuth.instance.currentUser?.uid;
        final bool alreadyJoined = acceptedUsers.contains(currentUid);

        return Scaffold(
          appBar: AppBar(
            title: const Text('委托详情'),
            backgroundColor: Colors.white,
            foregroundColor: Colors.black,
            elevation: 0.5,
          ),
          body: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Column(
                    children: [
                      const Text('每人赏金', style: TextStyle(color: Colors.grey)),
                      Text(
                        'RM ${data['amount']}',
                        style: const TextStyle(
                          fontSize: 40,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 48),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildDetailItem(
                      Icons.people,
                      "招募进度",
                      "$acceptedCount / $peopleCount 人",
                      valueColor: Colors.orange,
                    ),
                    _buildDetailItem(
                      Icons.timer,
                      "时间期限",
                      "${data['expectedTime']}",
                    ),
                  ],
                ),
                const SizedBox(height: 30),
                const Text(
                  '任务描述',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
                ),
                const SizedBox(height: 10),
                Text(
                  data['description'] ?? '',
                  style: const TextStyle(
                    fontSize: 16,
                    height: 1.5,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 30),
                const Text(
                  '送达地点',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Icon(Icons.location_on, color: Colors.redAccent),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        data['location'] ?? '',
                        style: const TextStyle(fontSize: 15),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.info_outline, size: 20, color: Colors.blue),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          '温馨提示：时间期限仅为委托人期望的完成时间。超时系统不会进行自动惩罚，接单后您可以与委托人自由沟通并调整细节。',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.blueGrey,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),

                _buildBottomActionButtons(
                  alreadyJoined,
                  acceptedCount,
                  peopleCount,
                  currentUid == data['publisherId'],
                  data['amount'] ?? '0.00',
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildBottomActionButtons(
    bool alreadyJoined,
    int acceptedCount,
    int peopleCount,
    bool isPublisher,
    String originalAmount,
  ) {
    if (_isSubmitting) return const Center(child: CircularProgressIndicator());
    if (alreadyJoined) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          color: Colors.green[50],
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.center,
        child: const Text(
          '您已在队伍中 🏃',
          style: TextStyle(
            color: Colors.green,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }
    if (acceptedCount >= peopleCount) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          color: Colors.grey[300],
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.center,
        child: const Text(
          '名额已满啦',
          style: TextStyle(
            color: Colors.grey,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }
    if (isPublisher) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          color: Colors.orange[50],
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.center,
        child: const Text(
          '这是您的委托，请到个人中心审批接单申请',
          style: TextStyle(
            color: Colors.orange,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }

    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: _showNegotiationBottomSheet,
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.blue,
              side: const BorderSide(color: Colors.blue, width: 1.5),
              padding: const EdgeInsets.symmetric(vertical: 18),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              '我有异议/谈价',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton(
            // 💡 核心修改：点击抢单，直接提交 type: 'direct_claim' 类型的申请！
            onPressed: () => _submitApplication(
              type: 'direct_claim',
              amount: originalAmount,
              reason: '申请直接抢单接单',
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 18),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              '立即申请抢单',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDetailItem(
    IconData icon,
    String label,
    String value, {
    Color valueColor = Colors.black,
  }) {
    return Column(
      children: [
        Icon(icon, color: Colors.grey),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 17,
            color: valueColor,
          ),
        ),
      ],
    );
  }
}
