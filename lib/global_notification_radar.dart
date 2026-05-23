import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'overlay_notification.dart';

class GlobalNotificationRadar extends StatefulWidget {
  final Widget child;
  const GlobalNotificationRadar({super.key, required this.child});

  @override
  State<GlobalNotificationRadar> createState() =>
      _GlobalNotificationRadarState();
}

class _GlobalNotificationRadarState extends State<GlobalNotificationRadar> {
  final DateTime _appLaunchTime = DateTime.now();
  final List<dynamic> _subscriptions = [];

  @override
  void initState() {
    super.initState();
    _startNotificationRadar();
  }

  @override
  void dispose() {
    for (var sub in _subscriptions) {
      sub.cancel();
    }
    super.dispose();
  }

  void _startNotificationRadar() {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;
    final String currentUid = currentUser.uid;

    // 📢 雷达 1 号：新委托
    final taskSub = FirebaseFirestore.instance
        .collection('tasks')
        .snapshots()
        .listen((snapshot) {
          for (var change in snapshot.docChanges) {
            if (change.type == DocumentChangeType.added) {
              final data = change.doc.data() as Map<String, dynamic>;
              if (data['publisherId'] == currentUid) continue;

              if (_isRealNewDoc(data['createdAt'])) {
                // 💡 洁癖修复：加上 mounted 保护，防止在异步流里直接使用 context 导致崩溃危险
                if (mounted) {
                  OverlayNotification.show(
                    context,
                    title: '📢 广场新委托上架啦！',
                    body:
                        '【${data['publisherName'] ?? '神秘雇主'}】发出了 RM ${data['amount']} 的新需求：“${data['description']}”',
                    icon: Icons.flash_on,
                    iconColor: Colors.amber,
                  );
                }
              }
            }
          }
        });
    _subscriptions.add(taskSub);

    // 👥 雷达 2 号：接单/谈判申请
    final appSub = FirebaseFirestore.instance
        .collectionGroup('applications')
        .snapshots()
        .listen((snapshot) async {
          for (var change in snapshot.docChanges) {
            if (change.type == DocumentChangeType.added) {
              final data = change.doc.data() as Map<String, dynamic>;
              if (data['takerId'] == currentUid) continue;

              if (_isRealNewDoc(data['createdAt'])) {
                final taskDoc = await change.doc.reference.parent.parent!.get();
                if (taskDoc.exists) {
                  final taskData = taskDoc.data() as Map<String, dynamic>;
                  if (taskData['publisherId'] == currentUid) {
                    final bool isNeg = data['type'] == 'negotiation';
                    // 💡 洁癖修复：await 之后使用 context 必须经过 mounted 审查
                    if (mounted) {
                      OverlayNotification.show(
                        context,
                        title: isNeg ? '⚖️ 收到新的出价谈判！' : '🎉 有人申请抢您的委托！',
                        body:
                            '【${data['takerName']}】向您出价 RM ${data['proposedAmount']}，留言：“${data['reason']}”',
                        icon: isNeg ? Icons.gavel : Icons.person_add,
                        iconColor: isNeg ? Colors.blue : Colors.green,
                      );
                    }
                  }
                }
              }
            }
          }
        });
    _subscriptions.add(appSub);

    // 💬 雷达 3 号：新群聊消息
    final msgSub = FirebaseFirestore.instance
        .collectionGroup('messages')
        .snapshots()
        .listen((snapshot) async {
          for (var change in snapshot.docChanges) {
            if (change.type == DocumentChangeType.added) {
              final data = change.doc.data() as Map<String, dynamic>;
              if (data['senderId'] == currentUid) continue;

              if (_isRealNewDoc(data['createdAt'])) {
                final taskDoc = await change.doc.reference.parent.parent!.get();
                if (taskDoc.exists) {
                  final taskData = taskDoc.data() as Map<String, dynamic>;
                  final publisherId = taskData['publisherId'];
                  final List<dynamic> acceptedUsers =
                      taskData['acceptedUsers'] ?? [];

                  if (currentUid == publisherId ||
                      acceptedUsers.contains(currentUid)) {
                    // 💡 洁癖修复：加锁保护
                    if (mounted) {
                      OverlayNotification.show(
                        context,
                        title: '💬 任务群聊有新消息',
                        body: '${data['senderName']}：${data['text']}',
                        icon: Icons.chat_bubble,
                        iconColor: Colors.purple,
                      );
                    }
                  }
                }
              }
            }
          }
        });
    _subscriptions.add(msgSub);
  }

  bool _isRealNewDoc(dynamic createdAt) {
    if (createdAt == null) return false;
    if (createdAt is Timestamp) {
      final docTime = createdAt.toDate();
      return docTime.isAfter(
        _appLaunchTime.subtract(const Duration(seconds: 2)),
      );
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
