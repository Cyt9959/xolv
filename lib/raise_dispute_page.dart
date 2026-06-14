import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class RaiseDisputePage extends StatefulWidget {
  final String taskId;
  final String taskDescription;
  final double amount;
  final String currentUserRole; // 'employer' 或 'taker'
  final String againstUid;

  const RaiseDisputePage({
    super.key,
    required this.taskId,
    required this.taskDescription,
    required this.amount,
    required this.currentUserRole,
    required this.againstUid,
  });

  @override
  State<RaiseDisputePage> createState() => _RaiseDisputePageState();
}

class _RaiseDisputePageState extends State<RaiseDisputePage> {
  final _formKey = GlobalKey<FormState>();
  final _descController = TextEditingController();

  final List<String> _reasons = const [
    '对方失联/不回应',
    '任务未完成',
    '质量不达标',
    '欺诈/虚假信息',
    '其他',
  ];

  String? _selectedReason;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _descController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedReason == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请选择争议原因')),
      );
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _isSubmitting = true);

    try {
      await FirebaseFirestore.instance.collection('disputes').add({
        'taskId': widget.taskId,
        'taskDescription': widget.taskDescription,
        'amount': widget.amount,
        'raisedBy': user.uid,
        'raisedByName': user.displayName ?? 'XOLV 用户',
        'raisedByRole': widget.currentUserRole,
        'againstUid': widget.againstUid,
        'reason': _selectedReason,
        'description': _descController.text.trim(),
        'status': 'open',
        'adminNote': '',
        'createdAt': FieldValue.serverTimestamp(),
        'resolvedAt': null,
      });

      if (!mounted) return;

      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text('提交成功'),
          content: const Text('纠纷已提交，平台将在 24 小时内介入处理'),
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
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('提交失败：$e')),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          '提交纠纷申请',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        backgroundColor: Colors.white,
        elevation: 0.5,
        foregroundColor: Colors.black,
        centerTitle: true,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.black12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '任务信息',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.taskDescription,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '争议金额：RM ${widget.amount.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: primaryColor,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              '争议原因',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _selectedReason,
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.black12),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
              hint: const Text('请选择原因'),
              items: _reasons
                  .map(
                    (r) => DropdownMenuItem<String>(value: r, child: Text(r)),
                  )
                  .toList(),
              onChanged: (value) => setState(() => _selectedReason = value),
              validator: (value) => value == null ? '请选择争议原因' : null,
            ),
            const SizedBox(height: 20),
            const Text(
              '详细描述',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _descController,
              maxLines: 6,
              decoration: InputDecoration(
                hintText: '请详细描述事情经过，至少 20 字...',
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.black12),
                ),
                contentPadding: const EdgeInsets.all(16),
              ),
              validator: (value) {
                final text = value?.trim() ?? '';
                if (text.length < 20) {
                  return '详细描述至少需要 20 字（当前 ${text.length} 字）';
                }
                return null;
              },
            ),
            const SizedBox(height: 28),
            ElevatedButton(
              onPressed: _isSubmitting ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isSubmitting
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2.5,
                      ),
                    )
                  : const Text(
                      '提交纠纷',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
