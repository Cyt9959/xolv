import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';
import 'publish_task_page.dart';
import 'settings_page.dart';
import 'task_detail_page.dart';
import 'review_applications_page.dart';
import 'task_chat_page.dart';
import 'wallet_page.dart';
import 'kyc_page.dart';
import 'screens/kyc_review_page.dart';
import 'taker_profile_page.dart';
import 'income_dashboard_page.dart';
import 'receipt_page.dart';

class MainSquarePage extends StatefulWidget {
  const MainSquarePage({super.key});

  @override
  State<MainSquarePage> createState() => _MainSquarePageState();
}

class _MainSquarePageState extends State<MainSquarePage> {
  int _currentIndex = 0;
  final List<Widget> _pages = [const _HomeView(), const _ProfileView()];

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      body: IndexedStack(index: _currentIndex == 2 ? 1 : 0, children: _pages),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) async {
          if (index == 1) {
            final user = FirebaseAuth.instance.currentUser;
            if (user == null) {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('请先登录！')));
              return;
            }

            // ⚡ 1. 弹出安检扫描圈
            showDialog(
              context: context,
              barrierDismissible: false,
              builder: (_) => const Center(child: CircularProgressIndicator()),
            );

            try {
              // ⚡ 2. 轨道 A：查 users 总表
              final userDoc = await FirebaseFirestore.instance
                  .collection('users')
                  .doc(user.uid)
                  .get();
              String kycStatus = (userDoc.data()?['kyc_status'] ?? 'none')
                  .toString()
                  .trim()
                  .toLowerCase();

              // 🚀 轨道 B：深度扫描申请表做二次核验
              if (kycStatus != 'approved') {
                final kycAppDoc = await FirebaseFirestore.instance
                    .collection('kyc_applications')
                    .doc(user.uid)
                    .get();
                if (kycAppDoc.exists) {
                  final appStatus = (kycAppDoc.data()?['status'] ?? 'none')
                      .toString()
                      .trim()
                      .toLowerCase();
                  if (appStatus == 'approved') {
                    kycStatus = 'approved';
                  } else if (appStatus == 'pending' && kycStatus == 'none') {
                    kycStatus = 'pending';
                  } else if (appStatus == 'rejected' && kycStatus == 'none') {
                    kycStatus = 'rejected';
                  }
                }
              }

              if (context.mounted) Navigator.pop(context); // 关掉扫描圈

              // ⚡ 3. 终极审判
              if (kycStatus == 'approved') {
                if (context.mounted) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const PublishTaskPage()),
                  );
                }
              } else {
                if (context.mounted) {
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      title: const Row(
                        children: [
                          Icon(Icons.security, color: Colors.orange),
                          SizedBox(width: 8),
                          Text(
                            '安全拦截',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      content: Text(
                        kycStatus == 'pending'
                            ? '老板，您的实名资料正在人工审核中。\n\n请耐心等待通过后即可发布任务！'
                            : '老板，为了保障全网用户的交易安全，您必须通过实名认证才能发布任务哦！',
                        style: const TextStyle(height: 1.5),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text(
                            '稍后再说',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryColor,
                            foregroundColor: Colors.white,
                          ),
                          onPressed: () {
                            Navigator.pop(ctx);
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const KYCPage(),
                              ),
                            );
                          },
                          child: const Text(
                            '立即去认证',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  );
                }
              }
            } catch (e) {
              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text('网络验证失败: $e')));
              }
            }
          } else {
            setState(() => _currentIndex = index);
          }
        },
        selectedItemColor: primaryColor,
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        items: [
          const BottomNavigationBarItem(icon: Icon(Icons.explore), label: '广场'),
          BottomNavigationBarItem(
            icon: CircleAvatar(
              backgroundColor: primaryColor,
              child: const Icon(Icons.add, color: Colors.white),
            ),
            label: '发布',
          ),
          const BottomNavigationBarItem(icon: Icon(Icons.person), label: '我的'),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------
// 📺 广场视图
// ------------------------------------------------------------
class _HomeView extends StatefulWidget {
  const _HomeView();
  @override
  State<_HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<_HomeView> {
  Position? _currentTakerPosition;
  double _maxDistanceFilter = 11.0;

  @override
  void initState() {
    super.initState();
    _fetchTakerLocation();
  }

  // ========================================
  // 📲 一键分享任务（原生分享菜单）
  // ========================================
  Future<void> _shareTask(Map<String, dynamic> data) async {
    final String taskId = data['id'];
    final String shareText =
        '''
📢 【XOLV 悬赏任务】

📝 ${data['description']}
📍 ${data['location']}
💰 悬赏金额：RM ${data['amount']}
⏰ 完成时限：${data['expectedTime']}

👇 点击直接查看任务：
https://cytxolv.com/task/$taskId

快来 XOLV 接单赚钱！💪
''';

    await Share.share(shareText, subject: 'XOLV 悬赏任务');
  }

  Future<void> _fetchTakerLocation() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.always ||
          permission == LocationPermission.whileInUse) {
        Position pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
          ),
        );
        if (mounted) setState(() => _currentTakerPosition = pos);
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Text(
          '⚡ XOLV',
          style: GoogleFonts.montserrat(
            fontSize: 24,
            fontWeight: FontWeight.w900,
            color: const Color(0xFFFF5E00),
            letterSpacing: -0.5,
          ),
        ),
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  offset: const Offset(0, 3),
                  blurRadius: 8,
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
                      children: [
                        const Icon(
                          Icons.radar,
                          size: 18,
                          color: Colors.black87,
                        ),
                        Text(
                          '  探测接单范围',
                          style: GoogleFonts.montserrat(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      _maxDistanceFilter == 11.0
                          ? '全城悬赏 (无限制)'
                          : '${_maxDistanceFilter.toInt()} km 内',
                      style: TextStyle(
                        color: primaryColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                Slider(
                  value: _maxDistanceFilter,
                  min: 1.0,
                  max: 11.0,
                  divisions: 10,
                  activeColor: primaryColor,
                  inactiveColor: Colors.grey[200],
                  onChanged: (val) => setState(() => _maxDistanceFilter = val),
                ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('tasks')
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(
                    child: CircularProgressIndicator(color: primaryColor),
                  );
                }
                final rawDocs = snapshot.data?.docs ?? [];
                final List<Map<String, dynamic>> sortedFilteredTasks = [];

                for (var doc in rawDocs) {
                  final data = doc.data() as Map<String, dynamic>;
                  if (data['status'] != 'pending') continue;
                  double distanceInKm = -1.0;
                  if (_currentTakerPosition != null &&
                      data['latitude'] != null &&
                      data['longitude'] != null) {
                    distanceInKm =
                        Geolocator.distanceBetween(
                          _currentTakerPosition!.latitude,
                          _currentTakerPosition!.longitude,
                          data['latitude'],
                          data['longitude'],
                        ) /
                        1000;
                  }
                  if (_maxDistanceFilter < 11.0 &&
                      (distanceInKm == -1.0 ||
                          distanceInKm > _maxDistanceFilter)) {
                    continue;
                  }

                  data['id'] = doc.id;
                  data['computedDistance'] = distanceInKm;
                  sortedFilteredTasks.add(data);
                }

                sortedFilteredTasks.sort(
                  (a, b) => (a['computedDistance'] ?? double.infinity)
                      .compareTo(b['computedDistance'] ?? double.infinity),
                );

                if (sortedFilteredTasks.isEmpty) {
                  return const Center(
                    child: Text(
                      '在此范围内暂无新委托\n试着拉大雷达距离吧！',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: sortedFilteredTasks.length,
                  itemBuilder: (context, index) {
                    final data = sortedFilteredTasks[index];
                    final double distance = data['computedDistance'] ?? -1.0;
                    String distanceText = distance >= 0
                        ? (distance < 1.0
                              ? '${(distance * 1000).toInt()} 米'
                              : '${distance.toStringAsFixed(1)} km')
                        : '未知距离';

                    return _StaggeredListItem(
                      index: index,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => TaskDetailPage(
                              taskId: data['id'],
                              taskData: data,
                            ),
                          ),
                        ),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                offset: const Offset(0, 4),
                                blurRadius: 12,
                                color: Colors.black.withValues(alpha: 0.06),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: Container(
                              decoration: data['isUrgent'] == true
                                  ? BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          const Color(
                                            0xFFFF5E00,
                                          ).withValues(alpha: 0.12),
                                          const Color(
                                            0xFFFF0000,
                                          ).withValues(alpha: 0.06),
                                        ],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: Colors.red.withValues(
                                          alpha: 0.3,
                                        ),
                                        width: 1.5,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.red.withValues(
                                            alpha: 0.15,
                                          ),
                                          blurRadius: 8,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                    )
                                  : BoxDecoration(
                                      color: Colors.grey[50],
                                      border: Border.all(
                                        color: Colors.black12,
                                      ),
                                    ),
                              child: Stack(
                                children: [
                                  IntrinsicHeight(
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        // 🟧 左侧橙色装饰竖线
                                        Container(
                                          width: 4,
                                          color: primaryColor,
                                        ),
                                        Expanded(
                                          child: Padding(
                                            padding: const EdgeInsets.all(20),
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment
                                                          .spaceBetween,
                                                  children: [
                                                    Text(
                                                      'RM ${data['amount']}',
                                                      style: TextStyle(
                                                        color: const Color(
                                                          0xFF118C4F,
                                                        ),
                                                        fontWeight:
                                                            FontWeight.w900,
                                                        fontSize: 18,
                                                      ),
                                                    ),
                                                    Container(
                                                      padding:
                                                          const EdgeInsets.symmetric(
                                                            horizontal: 10,
                                                            vertical: 4,
                                                          ),
                                                      decoration: BoxDecoration(
                                                        color: primaryColor
                                                            .withValues(
                                                              alpha: 0.1,
                                                            ),
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              12,
                                                            ),
                                                      ),
                                                      child: Row(
                                                        children: [
                                                          Icon(
                                                            Icons.group,
                                                            size: 14,
                                                            color: primaryColor,
                                                          ),
                                                          Text(
                                                            '  ${data['acceptedCount'] ?? 0} / ${data['peopleCount'] ?? 1} 人',
                                                            style: TextStyle(
                                                              color:
                                                                  primaryColor,
                                                              fontSize: 13,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 12),
                                                Text(
                                                  data['description'] ?? '',
                                                  style: const TextStyle(
                                                    fontSize: 16,
                                                    height: 1.4,
                                                    color: Colors.black87,
                                                  ),
                                                  maxLines: 2,
                                                ),
                                                const SizedBox(height: 16),
                                                Row(
                                                  children: [
                                                    Icon(
                                                      Icons.near_me,
                                                      size: 14,
                                                      color: distance >= 0
                                                          ? primaryColor
                                                          : Colors.grey,
                                                    ),
                                                    Text(
                                                      ' $distanceText',
                                                      style: TextStyle(
                                                        color: distance >= 0
                                                            ? primaryColor
                                                            : Colors.grey,
                                                        fontSize: 13,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                                    ),
                                                    const SizedBox(width: 14),
                                                    const Icon(
                                                      Icons.timer_outlined,
                                                      size: 14,
                                                      color: Colors.grey,
                                                    ),
                                                    Text(
                                                      ' ${data['expectedTime']}',
                                                      style: const TextStyle(
                                                        color: Colors.grey,
                                                        fontSize: 13,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Positioned(
                                    bottom: 8,
                                    right: 8,
                                    child: Material(
                                      color: Colors.white,
                                      shape: const CircleBorder(),
                                      elevation: 2,
                                      child: InkWell(
                                        customBorder: const CircleBorder(),
                                        onTap: () => _shareTask(data),
                                        child: const Padding(
                                          padding: EdgeInsets.all(6),
                                          child: Icon(
                                            Icons.share,
                                            size: 16,
                                            color: Colors.black54,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  if (data['isUrgent'] == true)
                                    Positioned(
                                      top: 8,
                                      right: 8,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.red,
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        child: const Text(
                                          '🔥 急单',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------
// ✨ 任务卡片错落入场动画：淡入 + 轻微上滑，按 index 错开延迟
// ------------------------------------------------------------
class _StaggeredListItem extends StatefulWidget {
  final int index;
  final Widget child;
  const _StaggeredListItem({required this.index, required this.child});

  @override
  State<_StaggeredListItem> createState() => _StaggeredListItemState();
}

class _StaggeredListItemState extends State<_StaggeredListItem> {
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(Duration(milliseconds: widget.index * 60), () {
      if (mounted) setState(() => _visible = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: _visible ? 1.0 : 0.0),
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOut,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: FractionalTranslation(
            translation: Offset(0, (1 - value) * 0.08),
            child: child,
          ),
        );
      },
      child: widget.child,
    );
  }
}

// ------------------------------------------------------------
// 👆 按钮点击缩放反馈：按下轻微缩小 + 震动反馈
// ------------------------------------------------------------
class _TapScaleButton extends StatefulWidget {
  final Widget child;
  const _TapScaleButton({required this.child});

  @override
  State<_TapScaleButton> createState() => _TapScaleButtonState();
}

class _TapScaleButtonState extends State<_TapScaleButton> {
  double _scale = 1.0;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) {
        HapticFeedback.lightImpact();
        setState(() => _scale = 0.96);
      },
      onTapUp: (_) => setState(() => _scale = 1.0),
      onTapCancel: () => setState(() => _scale = 1.0),
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 100),
        child: widget.child,
      ),
    );
  }
}

// ------------------------------------------------------------
// 👤 个人大厅 (全自动档案显示版)
// ------------------------------------------------------------
class _ProfileView extends StatelessWidget {
  const _ProfileView();
  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final primaryColor = Theme.of(context).colorScheme.primary;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            '个人中心',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0,
          actions: [
            IconButton(
              icon: const Icon(Icons.settings_outlined),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsPage()),
              ),
            ),
          ],
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: StreamBuilder<DocumentSnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('kyc_applications')
                    .doc(user?.uid)
                    .snapshots(),
                builder: (context, kycSnapshot) {
                  String kycStatus = 'none';
                  if (kycSnapshot.hasData && kycSnapshot.data!.exists) {
                    kycStatus =
                        (kycSnapshot.data!.data()
                                as Map<String, dynamic>?)?['status']
                            ?.toString()
                            .trim()
                            .toLowerCase() ??
                        'none';
                  }
                  bool isVerified = kycStatus == 'approved';

                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 📸 头像区 (如果通过认证，边框会发绿光)
                      Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isVerified
                                ? Colors.green
                                : Colors.transparent,
                            width: 2,
                          ),
                        ),
                        child: CircleAvatar(
                          radius: 40,
                          backgroundColor: isVerified
                              ? Colors.green.withValues(alpha: 0.1)
                              : primaryColor.withValues(alpha: 0.1),
                          backgroundImage: user?.photoURL != null
                              ? NetworkImage(user!.photoURL!)
                              : null,
                          child: user?.photoURL == null
                              ? Icon(
                                  isVerified
                                      ? Icons.verified_user
                                      : Icons.person,
                                  size: 40,
                                  color: isVerified
                                      ? Colors.green
                                      : primaryColor,
                                )
                              : null,
                        ),
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // 🌟 名字与蓝 V 认证区
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    isVerified
                                        ? (user?.displayName ?? 'XOLV 实名认证会员')
                                        : (user?.displayName ?? 'XOLV 访客'),
                                    style: const TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    overflow: TextOverflow.ellipsis,
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
                                if (user != null) ...[
                                  const SizedBox(width: 6),
                                  TakerLevelBadge(takerId: user.uid),
                                ],
                              ],
                            ),
                            const SizedBox(height: 4),

                            // 📜 动态档案状态
                            if (isVerified)
                              const Text(
                                '✅ 已绑定大马卡实名资料',
                                style: TextStyle(
                                  color: Colors.green,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              )
                            else if (kycStatus == 'pending')
                              const Text(
                                '⏳ 实名资料审核中，请稍候',
                                style: TextStyle(
                                  color: Colors.orange,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              )
                            else
                              const Text(
                                '⚠️ 尚未绑定实名认证',
                                style: TextStyle(
                                  color: Colors.redAccent,
                                  fontSize: 12,
                                ),
                              ),

                            const SizedBox(height: 8),

                            // ⭐ 星级评价系统
                            StreamBuilder<QuerySnapshot>(
                              stream: FirebaseFirestore.instance
                                  .collection('reviews')
                                  .where('targetUserId', isEqualTo: user?.uid)
                                  .snapshots(),
                              builder: (context, snapshot) {
                                if (!snapshot.hasData ||
                                    snapshot.data!.docs.isEmpty) {
                                  return const Text(
                                    '⭐ 暂无评价',
                                    style: TextStyle(
                                      color: Colors.grey,
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  );
                                }
                                final docs = snapshot.data!.docs;
                                double totalStars = 0;
                                for (var doc in docs) {
                                  totalStars +=
                                      (doc.data()
                                          as Map<String, dynamic>)['rating'] ??
                                      5.0;
                                }
                                double avgRating = totalStars / docs.length;
                                return Row(
                                  children: [
                                    const Icon(
                                      Icons.star,
                                      color: Colors.amber,
                                      size: 16,
                                    ),
                                    Text(
                                      ' ${avgRating.toStringAsFixed(1)} ',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                        color: Colors.amber,
                                      ),
                                    ),
                                    Text(
                                      '(${docs.length}评价)',
                                      style: const TextStyle(
                                        color: Colors.grey,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),

                            const SizedBox(height: 16),

                            // 💰 云端钱包按钮
                            if (user != null)
                              StreamBuilder<DocumentSnapshot>(
                                stream: FirebaseFirestore.instance
                                    .collection('users')
                                    .doc(user.uid)
                                    .snapshots(),
                                builder: (context, snapshot) {
                                  double balance = 0.00;
                                  if (snapshot.hasData &&
                                      snapshot.data!.exists) {
                                    final data =
                                        snapshot.data!.data()
                                            as Map<String, dynamic>?;
                                    balance = (data?['wallet_balance'] ?? 0.0)
                                        .toDouble();
                                  }
                                  return Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: [
                                      InkWell(
                                        onTap: () => Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => const WalletPage(),
                                          ),
                                        ),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 14,
                                            vertical: 10,
                                          ),
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              colors: [
                                                primaryColor,
                                                primaryColor.withValues(
                                                  alpha: 0.8,
                                                ),
                                              ],
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: primaryColor.withValues(
                                                  alpha: 0.2,
                                                ),
                                                blurRadius: 8,
                                                offset: const Offset(0, 4),
                                              ),
                                            ],
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Icon(
                                                Icons.account_balance_wallet,
                                                color: Colors.white,
                                                size: 16,
                                              ),
                                              const SizedBox(width: 8),
                                              Text(
                                                '我的钱包: RM ${balance.toStringAsFixed(2)}',
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 12,
                                                ),
                                              ),
                                              const SizedBox(width: 4),
                                              const Icon(
                                                Icons.chevron_right,
                                                color: Colors.white,
                                                size: 14,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      _IncomeReportButton(uid: user.uid),
                                    ],
                                  );
                                },
                              ),

                            const SizedBox(height: 12),

                            // 🛡️ KYC 按钮
                            if (user != null)
                              Builder(
                                builder: (context) {
                                  Color bgColor = Colors.green[50]!;
                                  Color borderColor = Colors.green[200]!;
                                  Color textColor = Colors.green;
                                  String text = '去完成实名认证';
                                  IconData icon = Icons.verified_user;
                                  VoidCallback? onTap = () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => const KYCPage(),
                                    ),
                                  );

                                  if (kycStatus == 'pending') {
                                    bgColor = Colors.orange[50]!;
                                    borderColor = Colors.orange[200]!;
                                    textColor = Colors.orange[800]!;
                                    text = '审核中，请耐心等待';
                                    icon = Icons.hourglass_top_rounded;
                                    onTap = null;
                                  } else if (kycStatus == 'approved') {
                                    bgColor = Colors.green[50]!;
                                    borderColor = Colors.green[200]!;
                                    textColor = Colors.green[800]!;
                                    text = '实名档案已生效';
                                    icon = Icons.verified;
                                    onTap = null;
                                  } else if (kycStatus == 'rejected') {
                                    bgColor = Colors.red[50]!;
                                    borderColor = Colors.red[200]!;
                                    textColor = Colors.red[800]!;
                                    text = '认证被驳回，请重试';
                                    icon = Icons.error_outline;
                                  }

                                  return InkWell(
                                    onTap: onTap,
                                    borderRadius: BorderRadius.circular(12),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 14,
                                        vertical: 10,
                                      ),
                                      decoration: BoxDecoration(
                                        color: bgColor,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: borderColor),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            icon,
                                            color: textColor,
                                            size: 16,
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            text,
                                            style: TextStyle(
                                              color: textColor,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12,
                                            ),
                                          ),
                                          if (onTap != null)
                                            const Icon(
                                              Icons.chevron_right,
                                              size: 14,
                                            ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),

                            const SizedBox(height: 12),

                            // 👑 老板审核大厅入口
                            if (user != null &&
                                user.email == 'chuitheen@gmail.com')
                              InkWell(
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const KycReviewPage(),
                                  ),
                                ),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 10,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.purple[50],
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: Colors.purple[200]!,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.admin_panel_settings,
                                        color: Colors.purple[700],
                                        size: 16,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        '进入老板审核台',
                                        style: TextStyle(
                                          color: Colors.purple[700],
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      Icon(
                                        Icons.chevron_right,
                                        color: Colors.purple[700],
                                        size: 14,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            TabBar(
              labelColor: primaryColor,
              indicatorColor: primaryColor,
              unselectedLabelColor: Colors.grey,
              tabs: const [
                Tab(text: '我的委托'),
                Tab(text: '我的任务'),
              ],
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _MyPostedTasksView(currentUid: user?.uid ?? ''),
                  _MyAcceptedTasksView(currentUid: user?.uid ?? ''),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ------------------------------------------------------------
// 📊 收入报告按钮（仅对接过单的非雇主用户显示）
// ------------------------------------------------------------
class _IncomeReportButton extends StatelessWidget {
  final String uid;
  const _IncomeReportButton({required this.uid});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<QuerySnapshot>(
      future: FirebaseFirestore.instance
          .collection('tasks')
          .where('acceptedUsers', arrayContains: uid)
          .limit(1)
          .get(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const SizedBox.shrink();
        }
        return InkWell(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const IncomeDashboardPage()),
          ),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.black12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Text('📊', style: TextStyle(fontSize: 14)),
                SizedBox(width: 8),
                Text(
                  '收入报告',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                ),
                SizedBox(width: 4),
                Icon(Icons.chevron_right, size: 14),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ------------------------------------------------------------
// 💼 我的委托 (雇主视角)
// ------------------------------------------------------------
class _MyPostedTasksView extends StatelessWidget {
  final String currentUid;
  const _MyPostedTasksView({required this.currentUid});

  Future<void> _deleteTask(BuildContext context, String docId) async {
    final taskRef = FirebaseFirestore.instance.collection('tasks').doc(docId);
    final taskSnap = await taskRef.get();
    final data = taskSnap.data() ?? {};

    final double amount =
        double.tryParse(data['amount']?.toString() ?? '0') ?? 0;
    final int peopleCount = (data['peopleCount'] ?? 1) as int;
    final String publisherId = data['publisherId'] ?? '';
    final double totalRefund = amount * peopleCount;

    final batch = FirebaseFirestore.instance.batch();
    batch.delete(taskRef);
    batch.update(
      FirebaseFirestore.instance.collection('users').doc(publisherId),
      {'wallet_balance': FieldValue.increment(totalRefund)},
    );
    batch.set(FirebaseFirestore.instance.collection('transactions').doc(), {
      'userId': publisherId,
      'title': '任务取消退款',
      'amount': totalRefund,
      'type': 'refund',
      'status': '已退回',
      'createdAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();
  }

  void _showRatingAndCompleteDialog(
    BuildContext context,
    String taskId,
    List<dynamic> acceptedUsers,
    double amount,
    String description,
    double urgentBonus,
  ) {
    int currentRating = 5;
    final commentController = TextEditingController();
    final primaryColor = Theme.of(context).colorScheme.primary;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (bottomSheetContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Padding(
              padding: EdgeInsets.only(
                top: 24,
                left: 24,
                right: 24,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.check_circle, color: Colors.green, size: 60),
                  const SizedBox(height: 16),
                  const Text(
                    '确认完工并评价',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      5,
                      (index) => IconButton(
                        icon: Icon(
                          index < currentRating
                              ? Icons.star
                              : Icons.star_border,
                          color: Colors.amber,
                          size: 40,
                        ),
                        onPressed: () =>
                            setState(() => currentRating = index + 1),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () async {
                      Navigator.pop(bottomSheetContext);
                      final batch = FirebaseFirestore.instance.batch();
                      batch.update(
                        FirebaseFirestore.instance
                            .collection('tasks')
                            .doc(taskId),
                        {'status': 'completed'},
                      );
                      final String titleDesc = description.length > 5
                          ? description.substring(0, 5)
                          : description;
                      for (String targetUid in acceptedUsers) {
                        batch.set(
                          FirebaseFirestore.instance
                              .collection('reviews')
                              .doc(),
                          {
                            'taskId': taskId,
                            'reviewerId': currentUid,
                            'targetUserId': targetUid,
                            'rating': currentRating,
                            'comment': commentController.text.trim().isEmpty
                                ? '默认好评！'
                                : commentController.text.trim(),
                            'createdAt': FieldValue.serverTimestamp(),
                          },
                        );
                        // 💰 给接单人打钱（含急单奖励）
                        final double totalPayout = amount + urgentBonus;
                        batch.update(
                          FirebaseFirestore.instance
                              .collection('users')
                              .doc(targetUid),
                          {
                            'wallet_balance': FieldValue.increment(
                              totalPayout,
                            ),
                          },
                        );
                        batch.set(
                          FirebaseFirestore.instance
                              .collection('transactions')
                              .doc(),
                          {
                            'userId': targetUid,
                            'title': '任务完成收款 - $titleDesc',
                            'amount': amount,
                            'type': 'income',
                            'status': '已入账',
                            'createdAt': FieldValue.serverTimestamp(),
                          },
                        );
                        // 🔥 急单奖励流水（单独一条）
                        if (urgentBonus > 0) {
                          batch.set(
                            FirebaseFirestore.instance
                                .collection('transactions')
                                .doc(),
                            {
                              'userId': targetUid,
                              'title': '🔥 急单奖励',
                              'amount': urgentBonus,
                              'type': 'urgent_bonus',
                              'status': '已入账',
                              'taskId': taskId,
                              'createdAt': FieldValue.serverTimestamp(),
                            },
                          );
                        }
                      }
                      await batch.commit();

                      // 🧾 生成电子收据
                      final employerDoc = await FirebaseFirestore.instance
                          .collection('users')
                          .doc(currentUid)
                          .get();
                      final String employerName =
                          (employerDoc.data()?['name'] ?? 'XOLV 雇主')
                              .toString();

                      String takerName = 'XOLV 接单人';
                      if (acceptedUsers.isNotEmpty) {
                        final takerDoc = await FirebaseFirestore.instance
                            .collection('users')
                            .doc(acceptedUsers.first.toString())
                            .get();
                        takerName =
                            (takerDoc.data()?['name'] ?? 'XOLV 接单人')
                                .toString();
                      }

                      final now = DateTime.now();
                      final completedAt =
                          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} '
                          '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

                      if (context.mounted) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ReceiptPage(
                              taskId: taskId,
                              taskData: {
                                'description': description,
                                'amount': amount.toStringAsFixed(2),
                              },
                              takerName: takerName,
                              employerName: employerName,
                              completedAt: completedAt,
                            ),
                          ),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 50),
                    ),
                    child: const Text(
                      '提交评价并结案',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('tasks')
          .where('publisherId', isEqualTo: currentUid)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text('暂无发布'));
        }
        return ListView(
          padding: const EdgeInsets.all(16),
          children: snapshot.data!.docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final rawStatus = data['status'] ?? 'pending';
            final desc = data['description'] ?? '无描述';
            final int acceptedCount = data['acceptedCount'] ?? 0;
            final List<dynamic> acceptedUsers = data['acceptedUsers'] ?? [];

            String statusText = '等待接单';
            Color statusColor = Colors.orange;
            if (rawStatus == 'in_progress') {
              statusText = '进行中';
              statusColor = primaryColor;
            } else if (rawStatus == 'completed') {
              statusText = '已完成';
              statusColor = Colors.grey;
            } else if (rawStatus == 'pending' && acceptedCount > 0) {
              statusText = '招募中 (已进组 $acceptedCount 人)';
              statusColor = primaryColor;
            }

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: Colors.black12),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Column(
                  children: [
                    ListTile(
                      title: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'RM ${data['amount']}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF118C4F),
                              fontSize: 18,
                            ),
                          ),
                          Text(
                            statusText,
                            style: TextStyle(
                              color: statusColor,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 6.0),
                        child: Text(
                          desc,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      trailing: rawStatus == 'pending'
                          ? IconButton(
                              icon: const Icon(
                                Icons.delete_outline,
                                color: Colors.redAccent,
                              ),
                              onPressed: () => showDialog(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  title: const Text('确认取消任务？'),
                                  content: const Text('押金将退回您的钱包。'),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(ctx),
                                      child: const Text('取消'),
                                    ),
                                    TextButton(
                                      onPressed: () {
                                        Navigator.pop(ctx);
                                        _deleteTask(context, doc.id);
                                      },
                                      style: TextButton.styleFrom(
                                        foregroundColor: Colors.red,
                                      ),
                                      child: const Text('确认删除'),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          : null,
                    ),
                    if (acceptedCount > 0 && rawStatus != 'completed')
                      Padding(
                        padding: const EdgeInsets.only(
                          left: 16.0,
                          right: 16.0,
                          bottom: 8.0,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                icon: Icon(
                                  Icons.forum_outlined,
                                  size: 16,
                                  color: primaryColor,
                                ),
                                label: Text(
                                  '群聊沟通',
                                  style: TextStyle(color: primaryColor),
                                ),
                                style: OutlinedButton.styleFrom(
                                  side: BorderSide(color: primaryColor),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                onPressed: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => TaskChatPage(
                                      taskId: doc.id,
                                      taskDescription: desc,
                                      amount: double.tryParse(data['amount']?.toString() ?? '0') ?? 0,
                                      currentUserRole: 'employer',
                                      againstUid: acceptedUsers.isNotEmpty
                                          ? acceptedUsers.first.toString()
                                          : '',
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _TapScaleButton(
                                child: ElevatedButton.icon(
                                  icon: const Icon(
                                    Icons.check_circle_outline,
                                    size: 16,
                                  ),
                                  label: const Text('确认完工'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  onPressed: () => _showRatingAndCompleteDialog(
                                    context,
                                    doc.id,
                                    acceptedUsers,
                                    double.tryParse(
                                          data['amount']?.toString() ?? '0',
                                        ) ??
                                        0,
                                    desc,
                                    (data['urgentBonus'] ?? 0.0).toDouble(),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (rawStatus == 'pending')
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton.icon(
                            icon: Icon(
                              Icons.gavel,
                              size: 16,
                              color: primaryColor,
                            ),
                            label: Text(
                              '查看接单与谈判申请 >',
                              style: TextStyle(
                                color: primaryColor,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    ReviewApplicationsPage(taskId: doc.id),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

// ------------------------------------------------------------
// 🏃‍♂️ 我的任务 (接单人视角) - 已彻底修复排版错误！
// ------------------------------------------------------------
class _MyAcceptedTasksView extends StatelessWidget {
  final String currentUid;
  const _MyAcceptedTasksView({required this.currentUid});

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('tasks')
          .where('acceptedUsers', arrayContains: currentUid)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text('暂无接单'));
        }
        return ListView(
          padding: const EdgeInsets.all(16),
          children: snapshot.data!.docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final String taskStatus = data['status'] ?? 'pending';
            final desc = data['description'] ?? '无描述';
            final bool isCompleted = taskStatus == 'completed';

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              elevation: 0,
              color: isCompleted
                  ? Colors.grey[50]
                  : primaryColor.withValues(alpha: 0.08),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color: isCompleted
                      ? Colors.black12
                      : primaryColor.withValues(alpha: 0.3),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'RM ${data['amount']}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            color: Color(0xFF118C4F),
                          ),
                        ),
                        Text(
                          isCompleted ? '已完成 🥳' : '任务进行中 🏃',
                          style: TextStyle(
                            color: isCompleted ? Colors.green : primaryColor,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // 🚀 核心排版代码已重新梳理，绝不报错！
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        desc,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: isCompleted ? Colors.grey : Colors.black87,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    if (!isCompleted) ...[
                      const Divider(height: 24),
                      _TapScaleButton(
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.chat_bubble_outline, size: 16),
                          label: const Text(
                            '进入任务群聊沟通',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryColor,
                            foregroundColor: Colors.white,
                            minimumSize: const Size(double.infinity, 40),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => TaskChatPage(
                                taskId: doc.id,
                                taskDescription: desc,
                                amount: double.tryParse(data['amount']?.toString() ?? '0') ?? 0,
                                currentUserRole: 'taker',
                                againstUid: data['publisherId'] ?? '',
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}
