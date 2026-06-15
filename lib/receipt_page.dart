import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

// ==========================================
// 🧾 电子收据页面
// ==========================================
class ReceiptPage extends StatelessWidget {
  final String taskId;
  final Map<String, dynamic> taskData;
  final String takerName;
  final String employerName;
  final String completedAt;

  const ReceiptPage({
    super.key,
    required this.taskId,
    required this.taskData,
    required this.takerName,
    required this.employerName,
    required this.completedAt,
  });

  static const Color _themeColor = Color(0xFFFF5E00);

  String get _receiptNumber {
    final String id = taskId.length >= 8 ? taskId.substring(0, 8) : taskId;
    return 'XOLV-$id';
  }

  void _shareReceipt() {
    final text =
        '''
⚡ XOLV 任务收据
━━━━━━━━━━━━━━
收据编号：$_receiptNumber
任务：${taskData['description']}
雇主：$employerName
接单人：$takerName
金额：RM ${taskData['amount']}
完成时间：$completedAt
━━━━━━━━━━━━━━
由 XOLV 平台资金担保
cytxolv.com
''';
    Share.share(text);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text(
          '电子收据',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0.5,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                offset: const Offset(0, 4),
                blurRadius: 16,
                color: Colors.black.withValues(alpha: 0.06),
              ),
            ],
          ),
          child: Column(
            children: [
              const Icon(Icons.bolt, color: _themeColor, size: 48),
              const SizedBox(height: 8),
              const Text(
                '⚡ XOLV 官方收据',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: _themeColor,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _receiptNumber,
                style: const TextStyle(color: Colors.grey, fontSize: 13),
              ),
              const Divider(height: 32),
              _ReceiptRow(
                label: '任务描述',
                value: taskData['description']?.toString() ?? '',
              ),
              _ReceiptRow(label: '雇主', value: employerName),
              _ReceiptRow(label: '接单人', value: takerName),
              _ReceiptRow(label: '完成时间', value: completedAt),
              const SizedBox(height: 20),
              const Text(
                '悬赏金额',
                style: TextStyle(color: Colors.grey, fontSize: 13),
              ),
              const SizedBox(height: 4),
              Text(
                'RM ${taskData['amount']}',
                style: const TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.w900,
                  color: _themeColor,
                ),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.verified, color: Colors.green[700], size: 18),
                    const SizedBox(width: 8),
                    Text(
                      '✅ 由 XOLV 平台资金担保',
                      style: TextStyle(
                        color: Colors.green[700],
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'cytxolv.com',
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 12,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _shareReceipt,
        backgroundColor: _themeColor,
        icon: const Icon(Icons.share, color: Colors.white),
        label: const Text(
          '分享收据',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}

// ------------------------------------------------------------
// 📦 收据信息行
// ------------------------------------------------------------
class _ReceiptRow extends StatelessWidget {
  final String label;
  final String value;

  const _ReceiptRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: const TextStyle(color: Colors.grey, fontSize: 13),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}
