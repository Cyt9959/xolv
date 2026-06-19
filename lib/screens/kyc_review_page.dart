import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

class KycReviewPage extends StatelessWidget {
  const KycReviewPage({super.key});

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFFFF5E00); // 闪电橙

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          '👑 KYC 老板审核大厅',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0.5,
      ),
      body: Column(
        children: [
          Expanded(
            flex: 3,
            child: StreamBuilder<QuerySnapshot>(
              // 🚨 实时监听：只抓取全网状态为 'pending' (待审核) 的申请表
              stream: FirebaseFirestore.instance
                  .collection('kyc_applications')
                  .where('status', isEqualTo: 'pending')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: primaryColor),
                  );
                }

                // 如果没有积压的申请，显示超爽的清空状态
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.check_circle_outline,
                          size: 60,
                          color: Colors.green,
                        ),
                        SizedBox(height: 16),
                        Text(
                          '汇报老板：全网目前没有积压申请！',
                          style: TextStyle(
                            fontSize: 15,
                            color: Colors.grey,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                final docs = snapshot.data!.docs;

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final doc = docs[index];
                    final data = doc.data() as Map<String, dynamic>;
                    final String userId = data['userId'] ?? doc.id;
                    final String icFrontUrl = data['icFrontUrl'] ?? '';
                    final String icBackUrl = data['icBackUrl'] ?? '';
                    final String selfieUrl = data['selfieUrl'] ?? '';

                    String timeText = '未知时间';
                    if (data['submittedAt'] != null) {
                      final DateTime date = (data['submittedAt'] as Timestamp)
                          .toDate();
                      timeText =
                          '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
                    }

                    return Card(
                      margin: const EdgeInsets.only(bottom: 20),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 0,
                      color: Colors.white,
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.black12),
                        ),
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // 👤 用户头部信息
                            Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  '申请人 UID: ${userId.substring(0, 8)}...',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    letterSpacing: -0.5,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.orange[50],
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Text(
                                    '待审核',
                                    style: TextStyle(
                                      color: Colors.orange,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '提交时间: $timeText',
                              style: const TextStyle(
                                color: Colors.grey,
                                fontSize: 12,
                              ),
                            ),
                            const Divider(height: 24),

                            // 📸 照片比对区 (黄金人脸核验排版)
                            const Text(
                              '证件与自拍照核验：',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 12),

                            // 🌟 第一排：核心人脸对比 (IC 正面 vs 实时自拍)
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    children: [
                                      const Text(
                                        '🪪 IC 正面照',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(
                                          12,
                                        ),
                                        child: icFrontUrl.isNotEmpty
                                            ? GestureDetector(
                                                onTap: () => _showFullImage(context, icFrontUrl),
                                                child: Image.network(
                                                  icFrontUrl,
                                                  height: 130,
                                                  width: double.infinity,
                                                  fit: BoxFit.cover,
                                                  errorBuilder: (_, _, _) =>
                                                      Container(
                                                        height: 130,
                                                        color: Colors.grey[100],
                                                        child: const Icon(
                                                          Icons.broken_image,
                                                          color: Colors.grey,
                                                        ),
                                                      ),
                                                ),
                                              )
                                            : Container(
                                                height: 130,
                                                color: Colors.grey[100],
                                                child: const Icon(
                                                  Icons.image,
                                                  color: Colors.grey,
                                                ),
                                              ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    children: [
                                      const Text(
                                        '🤳 实时自拍照',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.blue,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(
                                          12,
                                        ),
                                        child: selfieUrl.isNotEmpty
                                            ? GestureDetector(
                                                onTap: () => _showFullImage(context, selfieUrl),
                                                child: Image.network(
                                                  selfieUrl,
                                                  height: 130,
                                                  width: double.infinity,
                                                  fit: BoxFit.cover,
                                                  errorBuilder: (_, _, _) =>
                                                      Container(
                                                        height: 130,
                                                        color: Colors.grey[100],
                                                        child: const Icon(
                                                          Icons.broken_image,
                                                          color: Colors.grey,
                                                        ),
                                                      ),
                                                ),
                                              )
                                            : Container(
                                                height: 130,
                                                color: Colors.grey[100],
                                                child: const Icon(
                                                  Icons.face,
                                                  color: Colors.grey,
                                                ),
                                              ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 16),

                            // 🌟 第二排：辅助资料核对 (IC 反面照)
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  '📋 IC 反面档案',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: icBackUrl.isNotEmpty
                                      ? GestureDetector(
                                          onTap: () => _showFullImage(context, icBackUrl),
                                          child: Image.network(
                                            icBackUrl,
                                            height: 120,
                                            width: double.infinity,
                                            fit: BoxFit.cover,
                                            errorBuilder: (_, _, _) => Container(
                                              height: 120,
                                              color: Colors.grey[100],
                                              child: const Icon(
                                                Icons.broken_image,
                                                color: Colors.grey,
                                              ),
                                            ),
                                          ),
                                        )
                                      : Container(
                                          height: 120,
                                          color: Colors.grey[100],
                                          child: const Icon(
                                            Icons.image,
                                            color: Colors.grey,
                                          ),
                                        ),
                                ),
                              ],
                            ),

                            const Divider(height: 24),

                            // ⚖️ 审判按钮区
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    icon: const Icon(
                                      Icons.close_rounded,
                                      color: Colors.red,
                                      size: 18,
                                    ),
                                    label: const Text(
                                      '拒绝驳回',
                                      style: TextStyle(
                                        color: Colors.red,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    style: OutlinedButton.styleFrom(
                                      side: const BorderSide(
                                        color: Colors.red,
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 14,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(
                                          12,
                                        ),
                                      ),
                                    ),
                                    onPressed: () =>
                                        _handleReview(context, userId, false),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: ElevatedButton.icon(
                                    icon: const Icon(
                                      Icons.check_rounded,
                                      color: Colors.white,
                                      size: 18,
                                    ),
                                    label: const Text(
                                      '批准通过',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.green,
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 14,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(
                                          12,
                                        ),
                                      ),
                                    ),
                                    onPressed: () => _handleReview(
                                      context,
                                      userId,
                                      true,
                                      icFrontUrl: icFrontUrl,
                                      selfieUrl: selfieUrl,
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
          ),
          const Divider(height: 1, thickness: 1),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                Icon(Icons.verified_user, color: Colors.green, size: 18),
                SizedBox(width: 6),
                Text(
                  '已认证用户（可撤销资格）',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: StreamBuilder<QuerySnapshot>(
              // ✅ 实时监听：状态为 'approved' (已通过) 的申请表，供老板随时撤销资格
              stream: FirebaseFirestore.instance
                  .collection('kyc_applications')
                  .where('status', isEqualTo: 'approved')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: primaryColor),
                  );
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(
                    child: Text(
                      '暂无已认证用户',
                      style: TextStyle(color: Colors.grey, fontSize: 13),
                    ),
                  );
                }

                final docs = snapshot.data!.docs;

                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final doc = docs[index];
                    final data = doc.data() as Map<String, dynamic>;
                    final String userId = data['userId'] ?? doc.id;

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                      color: Colors.white,
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.black12),
                        ),
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'UID: ${userId.substring(0, 8)}...',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.green[50],
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Text(
                                      '✅ 已认证',
                                      style: TextStyle(
                                        color: Colors.green,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            if (data['status'] == 'approved')
                              OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.red,
                                  side: const BorderSide(color: Colors.red),
                                ),
                                child: const Text('撤销认证'),
                                onPressed: () => _revokeKYC(context, userId),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          const Divider(height: 1, thickness: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                Icon(Icons.verified, color: primaryColor),
                const SizedBox(width: 8),
                const Text(
                  '完工证明审查',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: StreamBuilder<QuerySnapshot>(
              // 📸 实时监听：状态为 'in_progress' 且已上传完工证明照片的任务
              stream: FirebaseFirestore.instance
                  .collection('tasks')
                  .where('status', isEqualTo: 'in_progress')
                  .where('completionPhotos', isNotEqualTo: [])
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: primaryColor),
                  );
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(
                    child: Text(
                      '暂无待审查的完工证明',
                      style: TextStyle(color: Colors.grey, fontSize: 13),
                    ),
                  );
                }

                final docs = snapshot.data!.docs;

                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final doc = docs[index];
                    final data = doc.data() as Map<String, dynamic>;
                    final String desc = (data['description'] ?? '').toString();
                    final String shortDesc = desc.length > 30
                        ? '${desc.substring(0, 30)}...'
                        : desc;
                    final List<dynamic> acceptedUsers =
                        data['acceptedUsers'] ?? [];
                    final String takerUid = acceptedUsers.isNotEmpty
                        ? acceptedUsers.first.toString()
                        : '';
                    final List<dynamic> photos = data['completionPhotos'] ?? [];
                    final bool reviewed = data['completionReviewed'] == true;

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                      color: Colors.white,
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.black12),
                        ),
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              shortDesc.isEmpty ? '任务沟通' : shortDesc,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 4),
                            if (takerUid.isNotEmpty)
                              FutureBuilder<DocumentSnapshot>(
                                future: FirebaseFirestore.instance
                                    .collection('users')
                                    .doc(takerUid)
                                    .get(),
                                builder: (context, userSnap) {
                                  String name = '加载中...';
                                  if (userSnap.hasData &&
                                      userSnap.data!.exists) {
                                    final userData =
                                        userSnap.data!.data()
                                            as Map<String, dynamic>;
                                    name =
                                        (userData['verifiedName'] ??
                                                userData['name'] ??
                                                '未知用户')
                                            .toString();
                                  }
                                  return Text(
                                    '接单人: $name',
                                    style: const TextStyle(
                                      color: Colors.grey,
                                      fontSize: 12,
                                    ),
                                  );
                                },
                              ),
                            const SizedBox(height: 8),
                            SizedBox(
                              height: 90,
                              child: ListView.builder(
                                scrollDirection: Axis.horizontal,
                                itemCount: photos.length,
                                itemBuilder: (ctx, i) => GestureDetector(
                                  onTap: () => _showFullImage(
                                    context,
                                    photos[i].toString(),
                                  ),
                                  child: Container(
                                    width: 90,
                                    height: 90,
                                    margin: const EdgeInsets.only(right: 8),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(8),
                                      image: DecorationImage(
                                        image: NetworkImage(
                                          photos[i].toString(),
                                        ),
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            reviewed
                                ? Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.green[50],
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Text(
                                      '✅ 已审查',
                                      style: TextStyle(
                                        color: Colors.green,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  )
                                : OutlinedButton.icon(
                                    icon: const Icon(
                                      Icons.task_alt,
                                      size: 16,
                                    ),
                                    label: const Text('标记已审查'),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: primaryColor,
                                      side: const BorderSide(
                                        color: primaryColor,
                                      ),
                                    ),
                                    onPressed: () => doc.reference.update({
                                      'completionReviewed': true,
                                    }),
                                  ),
                          ],
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

  // ⚡ 金融级联动的审批原子逻辑 (高容错写入升级版)
  Future<void> _handleReview(
    BuildContext context,
    String userId,
    bool isApproved, {
    String icFrontUrl = '',
    String selfieUrl = '',
  }) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final batch = FirebaseFirestore.instance.batch();
      final kycRef = FirebaseFirestore.instance
          .collection('kyc_applications')
          .doc(userId);
      final userRef = FirebaseFirestore.instance
          .collection('users')
          .doc(userId);

      final String statusString = isApproved ? 'approved' : 'rejected';

      // 🚨 核心升级：采用 SetOptions(merge: true)
      // 这意味着：如果云端没有档案，系统会自动建档；如果有档案，就只修改 status 字段。绝不报错！
      batch.set(kycRef, {'status': statusString}, SetOptions(merge: true));
      batch.set(userRef, {'kyc_status': statusString}, SetOptions(merge: true));

      await batch.commit();

      // ✅ 立刻关闭 loading 并显示成功提示，不等 IC 提取
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isApproved ? '✅ 该用户已成功通过实名认证！' : '❌ 已驳回该用户的申请。'),
            backgroundColor: isApproved ? Colors.green : Colors.red,
          ),
        );
      }

      // 🤖 IC 提取改为完全背景执行（不 await，不阻塞 UI）
      if (isApproved) {
        debugPrint('开始提取 IC 资料: uid=$userId, icFrontUrl=$icFrontUrl');
        FirebaseFunctions.instance
            .httpsCallable(
              'extractICData',
              options: HttpsCallableOptions(timeout: const Duration(seconds: 30)),
            )
            .call({
              'uid': userId,
              'icFrontUrl': icFrontUrl,
              'selfieUrl': selfieUrl,
            })
            .then((result) => debugPrint('IC 提取结果: ${result.data}'))
            .catchError((e) => debugPrint('IC 资料提取失败: $e'));
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('审批失败: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showFullImage(BuildContext context, String imageUrl) {
    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (ctx) => Stack(
        children: [
          InteractiveViewer(
            minScale: 0.5,
            maxScale: 4.0,
            child: Center(
              child: Image.network(imageUrl, fit: BoxFit.contain),
            ),
          ),
          Positioned(
            top: 40,
            right: 16,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white, size: 32),
              onPressed: () => Navigator.pop(ctx),
            ),
          ),
        ],
      ),
    );
  }

  // 🚫 撤销实名认证（管理员操作）：弹窗确认后，三步联动写入
  Future<void> _revokeKYC(BuildContext context, String uid) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('撤销认证', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text(
          '确定要撤销此用户的实名认证吗？用户将无法发单和接单，直到重新通过审核。',
          style: TextStyle(height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              '确定撤销',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    if (!context.mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final batch = FirebaseFirestore.instance.batch();
      final kycRef = FirebaseFirestore.instance
          .collection('kyc_applications')
          .doc(uid);
      final userRef = FirebaseFirestore.instance.collection('users').doc(uid);
      final txRef = FirebaseFirestore.instance.collection('transactions').doc();

      // 1️⃣ 申请表打上撤销标记
      batch.set(kycRef, {
        'status': 'revoked',
        'revokedAt': FieldValue.serverTimestamp(),
        'revokedBy': 'admin',
      }, SetOptions(merge: true));

      // 2️⃣ 清空用户总表的实名认证资料
      batch.set(userRef, {
        'kyc_status': 'revoked',
        'verifiedName': '',
        'verifiedAge': 0,
        'verifiedAvatarUrl': '',
      }, SetOptions(merge: true));

      // 3️⃣ 写入系统通知，告知用户
      batch.set(txRef, {
        'userId': uid,
        'title': '⚠️ 实名认证已被平台撤销',
        'type': 'system',
        'createdAt': FieldValue.serverTimestamp(),
      });

      await batch.commit();

      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ 已撤销该用户的实名认证。'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('撤销失败: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
}
