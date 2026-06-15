import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'raise_dispute_page.dart';

class TaskChatPage extends StatefulWidget {
  final String taskId;
  final String taskDescription;
  final double amount;
  final String currentUserRole; // 'employer' 或 'taker'
  final String againstUid;

  const TaskChatPage({
    super.key,
    required this.taskId,
    required this.taskDescription,
    required this.amount,
    required this.currentUserRole,
    required this.againstUid,
  });

  @override
  State<TaskChatPage> createState() => _TaskChatPageState();
}

class _TaskChatPageState extends State<TaskChatPage> {
  final TextEditingController _textController = TextEditingController();
  final user = FirebaseAuth.instance.currentUser;
  final ImagePicker _picker = ImagePicker();

  double? _myLat;
  double? _myLng;
  bool _isUploadingPhotos = false;

  // 💡 核心新增：专门为跑腿场景定制的常用快捷语
  final List<String> _quickPhrases = [
    '🚗 我已到达指定地点',
    '⏳ 路上遇到堵车，可能晚 5 分钟',
    '📦 物品已成功拿到，正在送过去',
    '📞 电话联系，我到你附近了',
  ];

  @override
  void initState() {
    super.initState();
    _fetchMyLocation();
  }

  Future<void> _fetchMyLocation() async {
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
        if (mounted) {
          setState(() {
            _myLat = pos.latitude;
            _myLng = pos.longitude;
          });
        }
      }
    } catch (_) {}
  }

  // 🚀 核心发送逻辑（通用版，支持直接发文字或发快捷语）
  void _sendMessage({String? customText}) async {
    final text = customText ?? _textController.text.trim();
    if (text.isEmpty || user == null) return;

    // 如果不是发快捷语，就清空输入框
    if (customText == null) {
      _textController.clear();
    }

    await FirebaseFirestore.instance
        .collection('tasks')
        .doc(widget.taskId)
        .collection('messages')
        .add({
          'senderId': user!.uid,
          'senderName': user!.displayName ?? 'XOLV 伙伴',
          'text': text,
          'createdAt': FieldValue.serverTimestamp(),
        });
  }

  // 📸 接单人上传完工证明照片（最多 3 张）
  Future<void> _uploadCompletionPhotos() async {
    if (user == null) return;

    final List<XFile> images = await _picker.pickMultiImage(
      imageQuality: 70,
      limit: 3,
    );
    if (images.isEmpty) return;

    setState(() => _isUploadingPhotos = true);

    try {
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('completion_photos')
          .child(widget.taskId)
          .child(user!.uid);

      final List<String> urls = [];
      for (int i = 0; i < images.length; i++) {
        final photoRef = storageRef.child('photo_$i.jpg');
        await photoRef.putFile(File(images[i].path));
        urls.add(await photoRef.getDownloadURL());
      }

      await FirebaseFirestore.instance
          .collection('tasks')
          .doc(widget.taskId)
          .update({
            'completionPhotos': urls,
            'completionPhotoUploadedAt': FieldValue.serverTimestamp(),
          });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ 完工证明照片已上传！'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('上传失败: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploadingPhotos = false);
    }
  }

  // 🖼️ 点击放大查看图片
  void _openPhotoViewer(String url) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(12),
        child: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: InteractiveViewer(
            child: Image.network(url, fit: BoxFit.contain),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Column(
          children: [
            const Text(
              '任务沟通群聊',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            Text(
              widget.taskDescription,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        backgroundColor: Colors.white,
        elevation: 0.5,
        foregroundColor: Colors.black,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(
              Icons.local_police,
              color: Colors.redAccent,
              size: 28,
            ),
            tooltip: '提交纠纷',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => RaiseDisputePage(
                    taskId: widget.taskId,
                    taskDescription: widget.taskDescription,
                    amount: widget.amount,
                    currentUserRole: widget.currentUserRole,
                    againstUid: widget.againstUid,
                  ),
                ),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('tasks')
            .doc(widget.taskId)
            .snapshots(),
        builder: (context, taskSnapshot) {
          String distanceText = "正在测算距离...";
          Map<String, dynamic> taskData = {};

          if (taskSnapshot.hasData && taskSnapshot.data!.exists) {
            taskData = taskSnapshot.data!.data() as Map<String, dynamic>;
            final double? taskLat = taskData['latitude'];
            final double? taskLng = taskData['longitude'];

            if (_myLat != null &&
                _myLng != null &&
                taskLat != null &&
                taskLng != null) {
              double meters = Geolocator.distanceBetween(
                _myLat!,
                _myLng!,
                taskLat,
                taskLng,
              );
              double km = meters / 1000;
              distanceText = km < 1.0
                  ? '📍 您当前距离任务地点：${(km * 1000).toInt()} 米'
                  : '📍 您当前距离任务地点：${km.toStringAsFixed(1)} km';
            } else {
              distanceText = "📍 无法获取位置或未授权 GPS";
            }
          }

          final List<dynamic> acceptedUsers = taskData['acceptedUsers'] ?? [];
          final List<dynamic> completionPhotos =
              taskData['completionPhotos'] ?? [];
          final bool canUploadPhotos =
              user != null && acceptedUsers.contains(user!.uid);

          return Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  vertical: 10,
                  horizontal: 16,
                ),
                color: Colors.green[50],
                child: Text(
                  distanceText,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.green,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ),

              if (completionPhotos.isNotEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  color: Colors.orange[50],
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '📸 接单人已上传完工证明',
                        style: TextStyle(
                          color: Colors.orange,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 80,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: completionPhotos.length,
                          itemBuilder: (context, index) {
                            final url = completionPhotos[index].toString();
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: GestureDetector(
                                onTap: () => _openPhotoViewer(url),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.network(
                                    url,
                                    width: 80,
                                    height: 80,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),

              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('tasks')
                      .doc(widget.taskId)
                      .collection('messages')
                      .orderBy('createdAt', descending: true)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(color: Colors.black),
                      );
                    }
                    final docs = snapshot.data?.docs ?? [];
                    return ListView.builder(
                      padding: const EdgeInsets.all(16),
                      reverse: true,
                      itemCount: docs.length,
                      itemBuilder: (context, index) {
                        final data = docs[index].data() as Map<String, dynamic>;
                        return _buildChatBubble(
                          name: data['senderName'] ?? '未知',
                          text: data['text'] ?? '',
                          isMe: data['senderId'] == user?.uid,
                        );
                      },
                    );
                  },
                ),
              ),

              // 🌟 核心升级：横向滑动的快捷短语胶囊舱
              Container(
                height: 48,
                color: Colors.white,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  itemCount: _quickPhrases.length,
                  itemBuilder: (context, index) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: ActionChip(
                        label: Text(
                          _quickPhrases[index],
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        backgroundColor: Colors.grey[100],
                        side: BorderSide.none,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        onPressed: () {
                          // 点一下直接走极速发送通道！
                          _sendMessage(customText: _quickPhrases[index]);
                        },
                      ),
                    );
                  },
                ),
              ),

              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      offset: const Offset(0, -2),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: SafeArea(
                  child: Row(
                    children: [
                      if (canUploadPhotos)
                        IconButton(
                          icon: _isUploadingPhotos
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.camera_alt_outlined),
                          tooltip: '上传完工证明照片',
                          onPressed: _isUploadingPhotos
                              ? null
                              : _uploadCompletionPhotos,
                        ),
                      Expanded(
                        child: TextField(
                          controller: _textController,
                          decoration: InputDecoration(
                            hintText: '发消息沟通细节...',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(24),
                              borderSide: BorderSide.none,
                            ),
                            filled: true,
                            fillColor: Colors.grey[100],
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 12,
                            ),
                          ),
                          onSubmitted: (_) => _sendMessage(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      CircleAvatar(
                        radius: 22,
                        backgroundColor: Colors.black,
                        child: IconButton(
                          icon: const Icon(
                            Icons.send,
                            color: Colors.white,
                            size: 18,
                          ),
                          onPressed: () => _sendMessage(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildChatBubble({
    required String name,
    required String text,
    required bool isMe,
  }) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        child: Column(
          crossAxisAlignment: isMe
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 4, right: 4, bottom: 4),
              child: Text(
                name,
                style: const TextStyle(fontSize: 11, color: Colors.grey),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isMe ? Colors.black : Colors.white,
                border: isMe ? null : Border.all(color: Colors.black12),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isMe ? 16 : 0),
                  bottomRight: Radius.circular(isMe ? 0 : 16),
                ),
              ),
              child: Text(
                text,
                style: TextStyle(
                  color: isMe ? Colors.white : Colors.black87,
                  fontSize: 15,
                  height: 1.3,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
