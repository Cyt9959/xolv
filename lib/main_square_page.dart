import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'edit_profile_page.dart';
import 'publish_task_page.dart';
import 'settings_page.dart';
import 'task_detail_page.dart';
import 'review_applications_page.dart';
import 'task_chat_page.dart';
import 'wallet_page.dart';

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
        onTap: (index) {
          if (index == 1) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const PublishTaskPage()),
            );
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
        title: const Text(
          'XOLV 广场',
          style: TextStyle(letterSpacing: 2, fontWeight: FontWeight.bold),
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
                    const Row(
                      children: [
                        Icon(Icons.radar, size: 18, color: Colors.black87),
                        Text(
                          '  探测接单范围',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
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
                  final double? taskLat = data['latitude'];
                  final double? taskLng = data['longitude'];

                  if (_currentTakerPosition != null &&
                      taskLat != null &&
                      taskLng != null) {
                    distanceInKm =
                        Geolocator.distanceBetween(
                          _currentTakerPosition!.latitude,
                          _currentTakerPosition!.longitude,
                          taskLat,
                          taskLng,
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

                sortedFilteredTasks.sort((a, b) {
                  double distA = a['computedDistance'] ?? double.infinity;
                  double distB = b['computedDistance'] ?? double.infinity;
                  if (distA < 0) distA = double.infinity;
                  if (distB < 0) distB = double.infinity;
                  return distA.compareTo(distB);
                });

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

                    return InkWell(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => TaskDetailPage(
                            taskId: data['id'],
                            taskData: data,
                          ),
                        ),
                      ),
                      child: Card(
                        margin: const EdgeInsets.only(bottom: 16),
                        elevation: 0,
                        color: Colors.grey[50],
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
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'RM ${data['amount']}',
                                    style: TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.w900,
                                      color: primaryColor,
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: primaryColor.withValues(
                                        alpha: 0.1,
                                      ),
                                      borderRadius: BorderRadius.circular(12),
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
                                            color: primaryColor,
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold,
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
                                      fontWeight: FontWeight.bold,
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
// 👤 个人大厅
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
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 40,
                    backgroundColor: primaryColor.withValues(alpha: 0.1),
                    backgroundImage: user?.photoURL != null
                        ? NetworkImage(user!.photoURL!)
                        : null,
                    child: user?.photoURL == null
                        ? Icon(Icons.person, size: 40, color: primaryColor)
                        : null,
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user?.displayName ?? 'XOLV 贵宾',
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
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
                        const SizedBox(height: 8),
                        InkWell(
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const EditProfilePage(),
                            ),
                          ),
                          child: Text(
                            '编辑个人资料 >',
                            style: TextStyle(
                              color: primaryColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
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
                                  primaryColor.withValues(alpha: 0.8),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: primaryColor.withValues(alpha: 0.2),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.account_balance_wallet,
                                  color: Colors.white,
                                  size: 16,
                                ),
                                SizedBox(width: 8),
                                Text(
                                  '我的钱包: RM 45.00',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                                SizedBox(width: 4),
                                Icon(
                                  Icons.chevron_right,
                                  color: Colors.white,
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
// 💼 我的委托 (雇主视角：全面恢复了详细的控制面板卡片)
// ------------------------------------------------------------
class _MyPostedTasksView extends StatelessWidget {
  final String currentUid;
  const _MyPostedTasksView({required this.currentUid});

  Future<void> _deleteTask(BuildContext context, String docId) async {
    await FirebaseFirestore.instance.collection('tasks').doc(docId).delete();
  }

  void _showRatingAndCompleteDialog(
    BuildContext context,
    String taskId,
    List<dynamic> acceptedUsers,
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
                    children: List.generate(5, (index) {
                      return IconButton(
                        icon: Icon(
                          index < currentRating
                              ? Icons.star
                              : Icons.star_border,
                          color: Colors.amber,
                          size: 40,
                        ),
                        onPressed: () =>
                            setState(() => currentRating = index + 1),
                      );
                    }),
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
                      }
                      await batch.commit();
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
        // 💡 修复警告 3：加上了大括号
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
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: primaryColor,
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
                      // 💡 警告 2 消除：恢复了使用 _deleteTask 的删除按钮
                      trailing: rawStatus == 'pending'
                          ? IconButton(
                              icon: const Icon(
                                Icons.delete_outline,
                                color: Colors.redAccent,
                              ),
                              onPressed: () => _deleteTask(context, doc.id),
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
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
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
                          // 💡 警告 1 消除：恢复了使用 ReviewApplicationsPage 的按钮
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
// 🏃‍♂️ 我的任务 (接单人视角：全面恢复了进入群聊等高级卡片)
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
        // 💡 修复警告 4：加上了大括号
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
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            color: isCompleted
                                ? Colors.grey[700]
                                : primaryColor,
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
                      ElevatedButton.icon(
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
