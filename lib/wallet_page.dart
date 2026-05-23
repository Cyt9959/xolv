import 'package:flutter/material.dart';

class WalletPage extends StatefulWidget {
  const WalletPage({super.key});

  @override
  State<WalletPage> createState() => _WalletPageState();
}

class _WalletPageState extends State<WalletPage> {
  // 模拟钱包数据
  final double _availableBalance = 45.00; // 假设已经赚了RM50，扣了RM5认证费
  final double _escrowBalance = 50.00; // 假设还有一个进行中的任务钱被平台锁着

  // 模拟交易记录
  final List<Map<String, dynamic>> _transactions = [
    {
      'title': '任务酬金 - 代买粿条',
      'date': '2023-10-24 14:20',
      'amount': 15.00,
      'type': 'income',
      'status': '已入账',
    },
    {
      'title': '终身实名认证建档费',
      'date': '2023-10-24 14:21',
      'amount': -5.00,
      'type': 'fee',
      'status': '系统扣除',
    },
    {
      'title': '任务酬金 - 帮看父母',
      'date': '2023-10-23 10:00',
      'amount': 35.00,
      'type': 'income',
      'status': '已入账',
    },
  ];

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          '我的钱包',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0.5,
        foregroundColor: Colors.black,
      ),
      body: Column(
        children: [
          // 💳 顶部大金额卡片
          Container(
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
                const Text(
                  '可用余额 (RM)',
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
                const SizedBox(height: 8),
                Text(
                  _availableBalance.toStringAsFixed(2),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 40,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    _buildBalanceInfo(
                      '托管中',
                      'RM ${_escrowBalance.toStringAsFixed(2)}',
                    ),
                    const SizedBox(width: 40),
                    _buildBalanceInfo('本月收入', 'RM 245.00'),
                  ],
                ),
              ],
            ),
          ),

          // ⚡ 快捷操作区
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Expanded(
                  child: _buildActionBtn(
                    Icons.account_balance_wallet,
                    '充值',
                    Colors.blue,
                    () {},
                  ),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: _buildActionBtn(
                    Icons.payments,
                    '提现',
                    Colors.green,
                    () {},
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 30),

          // 📜 交易明细列表
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
                  const Padding(
                    padding: EdgeInsets.only(left: 24, top: 24, bottom: 16),
                    child: Text(
                      '交易明细',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      itemCount: _transactions.length,
                      itemBuilder: (context, index) {
                        final tx = _transactions[index];
                        final isIncome = tx['amount'] > 0;
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
                            tx['title'],
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                          subtitle: Text(
                            tx['date'],
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
                                '${isIncome ? "+" : ""}${tx['amount'].toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: isIncome ? Colors.black : Colors.red,
                                ),
                              ),
                              Text(
                                tx['status'],
                                style: const TextStyle(
                                  color: Colors.grey,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
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
