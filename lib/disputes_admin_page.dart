import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class DisputesAdminPage extends StatelessWidget {
  const DisputesAdminPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          '⚖️ 纠纷仲裁台',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        backgroundColor: Colors.white,
        elevation: 0.5,
        foregroundColor: Colors.black,
        centerTitle: true,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('disputes')
            .where('status', whereIn: ['open', 'under_review'])
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = snapshot.data?.docs ?? [];
          if (docs.isEmpty) {
            return const Center(child: Text('暂无待处理纠纷 🎉'));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, index) => _DisputeCard(doc: docs[index]),
          );
        },
      ),
    );
  }
}

class _DisputeCard extends StatefulWidget {
  final QueryDocumentSnapshot doc;
  const _DisputeCard({required this.doc});

  @override
  State<_DisputeCard> createState() => _DisputeCardState();
}

class _DisputeCardState extends State<_DisputeCard> {
  late TextEditingController _noteController;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    final data = widget.doc.data() as Map<String, dynamic>;
    _noteController = TextEditingController(text: data['adminNote'] ?? '');
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  String _roleLabel(String role) {
    switch (role) {
      case 'employer':
        return '雇主';
      case 'taker':
        return '接单人';
      default:
        return role;
    }
  }

  Future<bool> _confirm(String title, String content) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('确认'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<void> _resolve({required bool refundToEmployer}) async {
    final data = widget.doc.data() as Map<String, dynamic>;
    final String raisedByRole = data['raisedByRole'] ?? '';
    final String raisedBy = data['raisedBy'] ?? '';
    final String againstUid = data['againstUid'] ?? '';
    final String taskId = data['taskId'] ?? '';
    final double amount = (data['amount'] is num)
        ? (data['amount'] as num).toDouble()
        : double.tryParse(data['amount']?.toString() ?? '0') ?? 0;

    final String employerUid = raisedByRole == 'employer'
        ? raisedBy
        : againstUid;
    final String takerUid = raisedByRole == 'taker' ? raisedBy : againstUid;
    final String targetUid = refundToEmployer ? employerUid : takerUid;

    final confirmed = await _confirm(
      refundToEmployer ? '确认退款给雇主？' : '确认放款给接单人？',
      refundToEmployer
          ? '将把 RM ${amount.toStringAsFixed(2)} 退回雇主钱包，任务将标记为纠纷关闭。'
          : '将把 RM ${amount.toStringAsFixed(2)} 放款给接单人，任务将标记为纠纷关闭。',
    );
    if (!confirmed) return;

    setState(() => _isProcessing = true);

    final firestore = FirebaseFirestore.instance;
    final disputeRef = firestore.collection('disputes').doc(widget.doc.id);
    final taskRef = firestore.collection('tasks').doc(taskId);
    final txRef = firestore.collection('transactions').doc();
    final userRef = firestore.collection('users').doc(targetUid);
    final adminNote = _noteController.text.trim();

    try {
      await firestore.runTransaction((transaction) async {
        transaction.update(userRef, {
          'wallet_balance': FieldValue.increment(amount),
        });
        transaction.set(txRef, {
          'userId': targetUid,
          'title': refundToEmployer ? '纠纷退款' : '纠纷裁定收款',
          'amount': amount,
          'type': refundToEmployer ? 'refund' : 'income',
          'status': refundToEmployer ? '已退回' : '已入账',
          'createdAt': FieldValue.serverTimestamp(),
        });
        transaction.update(disputeRef, {
          'status': refundToEmployer ? 'resolved_refund' : 'resolved_release',
          'adminNote': adminNote,
          'resolvedAt': FieldValue.serverTimestamp(),
        });
        transaction.update(taskRef, {'status': 'disputed_closed'});
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(refundToEmployer ? '已退款给雇主' : '已放款给接单人'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('操作失败：$e')));
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.doc.data() as Map<String, dynamic>;
    final double amount = (data['amount'] is num)
        ? (data['amount'] as num).toDouble()
        : double.tryParse(data['amount']?.toString() ?? '0') ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  data['taskDescription'] ?? '无描述',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'RM ${amount.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Colors.redAccent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '提交人：${data['raisedByName'] ?? '未知'}（${_roleLabel(data['raisedByRole'] ?? '')}）',
            style: const TextStyle(fontSize: 13, color: Colors.grey),
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '原因：${data['reason'] ?? '未填写'}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  data['description'] ?? '',
                  style: const TextStyle(fontSize: 13, height: 1.4),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _noteController,
            maxLines: 2,
            decoration: InputDecoration(
              hintText: '管理员备注...',
              filled: true,
              fillColor: Colors.grey[50],
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Colors.black12),
              ),
              contentPadding: const EdgeInsets.all(12),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _isProcessing
                      ? null
                      : () => _resolve(refundToEmployer: true),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.redAccent,
                    side: const BorderSide(color: Colors.redAccent),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('退款给雇主'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                  onPressed: _isProcessing
                      ? null
                      : () => _resolve(refundToEmployer: false),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('放款给接单人'),
                ),
              ),
            ],
          ),
          if (_isProcessing)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: LinearProgressIndicator(),
            ),
        ],
      ),
    );
  }
}
