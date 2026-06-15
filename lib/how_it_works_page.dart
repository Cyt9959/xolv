import 'package:flutter/material.dart';

// 📖 平台使用指南：分别介绍雇主与接单人的完整流程
class HowItWorksPage extends StatelessWidget {
  const HowItWorksPage({super.key});

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Colors.grey[50],
        appBar: AppBar(
          title: const Text(
            'XOLV 平台指南',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0.5,
          bottom: TabBar(
            labelColor: primaryColor,
            indicatorColor: primaryColor,
            unselectedLabelColor: Colors.grey,
            tabs: const [
              Tab(text: '我是雇主 👔'),
              Tab(text: '我要接单 ⚡'),
            ],
          ),
        ),
        body: Column(
          children: [
            Expanded(
              child: TabBarView(
                children: [_buildEmployerTab(), _buildTakerTab()],
              ),
            ),
            _buildPromiseBar(),
          ],
        ),
      ),
    );
  }

  // 👔 Tab 1：我是雇主
  Widget _buildEmployerTab() {
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 0),
      children: [
        const _StepCard(
          step: 1,
          icon: Icons.verified_user,
          title: '完成实名认证',
          description:
              '上传大马卡正反面 + 自拍照，等待平台审核通过（通常 24 小时内）。认证后才能发布任务。',
        ),
        const _StepCard(
          step: 2,
          icon: Icons.account_balance_wallet,
          title: '充值钱包',
          description:
              '发布任务前需要确保钱包余额充足。发布时系统会自动锁定悬赏金额，资金由平台安全托管。',
        ),
        const _StepCard(
          step: 3,
          icon: Icons.add_circle,
          title: '发布任务',
          description:
              '描述你需要的帮助、设定地点、人数和悬赏金额。可使用 AI 助手优化描述，或开启🔥急单模式让接单人优先看到。',
        ),
        const _StepCard(
          step: 4,
          icon: Icons.people,
          title: '审核申请人',
          description:
              '接单人投递申请后，你可以查看他们的等级、评分和完成记录，选择最合适的人选点击【录用】。',
        ),
        const _StepCard(
          step: 5,
          icon: Icons.chat,
          title: '任务进行中',
          description:
              '录用后进入任务群聊，与接单人保持沟通。接单人完成后会上传完工照片作为证明。',
        ),
        const _StepCard(
          step: 6,
          icon: Icons.check_circle,
          title: '确认完工并付款',
          description:
              '确认任务完成后，平台自动将托管金额释放给接单人，并生成电子收据。双方互相评分。',
        ),
        _buildInfoCard(
          title: '⚠️ 雇主须知',
          backgroundColor: Colors.orange[50],
          borderColor: Colors.orange[200],
          items: const [
            '发布任务后如取消，押金全额退回',
            '确认完工后资金不可撤回，请仔细核实',
            '若有纠纷请通过平台 SOS 按钮申请仲裁',
            '严禁发布违法任务，违者封号处理',
          ],
        ),
      ],
    );
  }

  // ⚡ Tab 2：我要接单
  Widget _buildTakerTab() {
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 0),
      children: [
        const _StepCard(
          step: 1,
          icon: Icons.verified_user,
          title: '完成实名认证',
          description:
              '上传大马卡正反面 + 自拍照完成 KYC 认证。这是平台信任体系的基础，保障你和雇主的安全。',
        ),
        const _StepCard(
          step: 2,
          icon: Icons.radar,
          title: '浏览附近任务',
          description:
              '广场会显示你附近的任务，距离越近排越前。🔥 火焰背景的是急单，接到后额外获得 RM 2 奖励。',
        ),
        const _StepCard(
          step: 3,
          icon: Icons.send,
          title: '投递申请',
          description:
              '可以选择【直接抢单】按原定金额接单，或选择【谈价接单】填写你的出价和留言，雇主会看到你的等级和评分。',
        ),
        const _StepCard(
          step: 4,
          icon: Icons.hourglass_top,
          title: '等待录用',
          description:
              '雇主审核申请后会选择录用你。录用后收到通知，进入任务群聊与雇主沟通任务细节。',
        ),
        const _StepCard(
          step: 5,
          icon: Icons.task_alt,
          title: '完成任务',
          description:
              '按约定时间完成任务，在群聊里上传完工照片作为证明，让雇主确认验收。',
        ),
        const _StepCard(
          step: 6,
          icon: Icons.payments,
          title: '收款 & 建立口碑',
          description:
              '雇主确认完工后，悬赏金额自动打入你的钱包。完成任务越多，等级越高（🌱新手→⚡老手→🏆认证达人），吸引更多雇主选择你！',
        ),
        _buildInfoCard(
          title: '💡 接单技巧',
          backgroundColor: Colors.green[50],
          borderColor: Colors.green[200],
          items: const [
            '保持个人资料完整，头像清晰更容易获得信任',
            '回复雇主消息要及时，提高录用率',
            '完工前拍清晰的完工照片，避免纠纷',
            '诚实评价雇主，共同维护平台生态',
          ],
        ),
      ],
    );
  }

  // 💡⚠️ 提示卡片（雇主须知 / 接单技巧）
  Widget _buildInfoCard({
    required String title,
    required Color? backgroundColor,
    required Color? borderColor,
    required List<String> items,
  }) {
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      elevation: 0,
      color: backgroundColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: borderColor ?? Colors.transparent),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            const SizedBox(height: 10),
            ...items.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('•  '),
                    Expanded(
                      child: Text(
                        item,
                        style: const TextStyle(fontSize: 13, height: 1.5),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 🔒✅⚖️ 底部固定区域：平台核心承诺（两个 Tab 共用）
  Widget _buildPromiseBar() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey[200] ?? Colors.grey)),
      ),
      child: Row(
        children: [
          Expanded(child: _buildPromiseItem('🔒', '资金托管')),
          Expanded(child: _buildPromiseItem('✅', '实名认证')),
          Expanded(child: _buildPromiseItem('⚖️', '公正仲裁')),
        ],
      ),
    );
  }

  Widget _buildPromiseItem(String emoji, String label) {
    return Column(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 22)),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[700],
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

// 🔢 单个步骤卡片：圆形序号 + 图标标题 + 说明文字
class _StepCard extends StatelessWidget {
  const _StepCard({
    required this.step,
    required this.icon,
    required this.title,
    required this.description,
  });

  final int step;
  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: Colors.grey[50],
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 圆形序号
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: primaryColor,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  '$step',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(icon, size: 18, color: primaryColor),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          title,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    description,
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 13,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
