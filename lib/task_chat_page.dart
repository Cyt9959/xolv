import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';
import 'raise_dispute_page.dart';
import 'voice_call_page.dart';
import 'video_call_page.dart';

class TaskChatPage extends StatefulWidget {
  final String taskId;
  // 💡 以下参数均可选：不传时会在 initState 里用 taskId 自行查询 Firestore 补全
  // （例如从推送通知点击跳转进来，事先并不知道这些细节）
  final String? taskDescription;
  final double? amount;
  final String? currentUserRole; // 'employer' 或 'taker'
  final String? againstUid;

  const TaskChatPage({
    super.key,
    required this.taskId,
    this.taskDescription,
    this.amount,
    this.currentUserRole,
    this.againstUid,
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
  bool _isUploadingMedia = false;
  String _otherPartyName = 'XOLV 伙伴';
  StreamSubscription<DocumentSnapshot>? _callSub;

  // 🎨 聊天室拍照/拍视频功能的强调色
  static const Color _brandColor = Color(0xFFFF5E00);

  // 💡 任务元数据：有 widget 参数就直接用，否则用 taskId 自行从 Firestore 拉取
  bool _isLoadingTaskMeta = true;
  String _taskDescription = '';
  double _amount = 0;
  String _currentUserRole = 'taker';
  String _againstUid = '';

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
    _initTaskMeta();
    _fetchMyLocation();
    _markAsRead();
  }

  // 💡 补全聊天室所需的任务元数据：优先用 widget 传入的参数，否则用 taskId 自行查询
  Future<void> _initTaskMeta() async {
    if (widget.taskDescription != null &&
        widget.amount != null &&
        widget.currentUserRole != null &&
        widget.againstUid != null) {
      _taskDescription = widget.taskDescription!;
      _amount = widget.amount!;
      _currentUserRole = widget.currentUserRole!;
      _againstUid = widget.againstUid!;
      if (mounted) setState(() => _isLoadingTaskMeta = false);
      _fetchOtherPartyName();
      return;
    }

    try {
      final doc = await FirebaseFirestore.instance
          .collection('tasks')
          .doc(widget.taskId)
          .get();
      final data = doc.data() ?? {};
      final String publisherId = data['publisherId'] ?? '';
      final List<dynamic> acceptedUsers = data['acceptedUsers'] ?? [];
      final bool isPublisher = user != null && user!.uid == publisherId;

      _taskDescription = data['description'] ?? '任务沟通';
      _amount = double.tryParse(data['amount']?.toString() ?? '0') ?? 0;
      _currentUserRole = isPublisher ? 'employer' : 'taker';
      _againstUid = isPublisher
          ? (acceptedUsers.isNotEmpty ? acceptedUsers.first.toString() : '')
          : publisherId;
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isLoadingTaskMeta = false);
      _fetchOtherPartyName();
    }
  }

  // 👁️ 进入聊天室即视为已读，记录我最后读到的时间
  Future<void> _markAsRead() async {
    if (user == null) return;
    await FirebaseFirestore.instance
        .collection('tasks')
        .doc(widget.taskId)
        .update({'lastReadBy.${user!.uid}': FieldValue.serverTimestamp()});
  }

  // 🪪 拉取通话对象的实名/昵称，用于通话页面展示
  Future<void> _fetchOtherPartyName() async {
    if (_againstUid.isEmpty) return;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(_againstUid)
          .get();
      final data = doc.data();
      final String name = (data?['verifiedName'] ?? data?['name'] ?? '')
          .toString()
          .trim();
      if (name.isNotEmpty && mounted) {
        setState(() => _otherPartyName = name);
      }
    } catch (_) {}
  }

  // 📞 发起通话：先在 Firestore 建立通话记录（触发对方来电推送），再进入通话界面
  Future<void> _startCall(String type) async {
    if (user == null) return;

    final callRef = FirebaseFirestore.instance.collection('calls').doc();
    await callRef.set({
      'callerId': user!.uid,
      'callerName': user!.displayName ?? 'XOLV 用户',
      'receiverId': _againstUid,
      'receiverName': _otherPartyName,
      'taskId': widget.taskId,
      'type': type,
      'status': 'ringing',
      'createdAt': FieldValue.serverTimestamp(),
    });

    // 📡 监听对方是否接听
    _callSub?.cancel();
    _callSub = callRef.snapshots().listen((snap) {
      final status = snap.data()?['status'];
      if (status == 'rejected') {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('对方拒绝了通话'),
              backgroundColor: Colors.red,
            ),
          );
          Navigator.pop(context);
        }
      } else if (status == 'timeout') {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('对方无响应'),
              backgroundColor: Colors.orange,
            ),
          );
          Navigator.pop(context);
        }
      }
    });

    // 拨号方直接进入通话界面（等待对方接听）
    if (!mounted) return;
    if (type == 'video') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => VideoCallPage(
            channelName: widget.taskId,
            callerName: user!.displayName ?? '我',
            receiverName: _otherPartyName,
          ),
        ),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => VoiceCallPage(
            channelName: widget.taskId,
            callerName: user!.displayName ?? '我',
            receiverName: _otherPartyName,
          ),
        ),
      );
    }
  }

  @override
  void dispose() {
    _callSub?.cancel();
    super.dispose();
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

    final taskRef = FirebaseFirestore.instance
        .collection('tasks')
        .doc(widget.taskId);

    await taskRef.collection('messages').add({
      'senderId': user!.uid,
      'senderName': user!.displayName ?? 'XOLV 伙伴',
      'text': text,
      'createdAt': FieldValue.serverTimestamp(),
    });

    // 📛 同步更新最后发言时间 & 自己的已读时间，用于任务卡片未读小红点
    await taskRef.update({
      'lastMessageAt': FieldValue.serverTimestamp(),
      'lastReadBy.${user!.uid}': FieldValue.serverTimestamp(),
    });
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

  // ➕ 弹出媒体选择面板：拍照 / 拍视频 / 从相册选择
  void _showMediaPicker() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _brandColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.camera_alt, color: _brandColor),
                ),
                title: const Text(
                  '拍照',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: const Text('立即拍摄一张照片'),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickChatMedia(ImageSource.camera, isVideo: false);
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.purple.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.videocam, color: Colors.purple),
                ),
                title: const Text(
                  '拍视频',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: const Text('录制一段视频（最长 60 秒）'),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickChatMedia(ImageSource.camera, isVideo: true);
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.photo_library, color: Colors.blue),
                ),
                title: const Text(
                  '从相册选择',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: const Text('选取照片或视频'),
                onTap: () {
                  Navigator.pop(ctx);
                  _showGalleryPicker();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 🖼️ 从相册中选择图片或视频
  void _showGalleryPicker() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.image),
              title: const Text('选择照片'),
              onTap: () {
                Navigator.pop(ctx);
                _pickChatMedia(ImageSource.gallery, isVideo: false);
              },
            ),
            ListTile(
              leading: const Icon(Icons.video_library),
              title: const Text('选择视频'),
              onTap: () {
                Navigator.pop(ctx);
                _pickChatMedia(ImageSource.gallery, isVideo: true);
              },
            ),
          ],
        ),
      ),
    );
  }

  // 📤 拍摄/选取一段聊天媒体（图片或视频），上传后写入消息
  Future<void> _pickChatMedia(ImageSource source, {required bool isVideo}) async {
    if (user == null) return;

    XFile? file;
    if (isVideo) {
      file = await _picker.pickVideo(
        source: source,
        maxDuration: const Duration(seconds: 60),
      );
    } else {
      file = await _picker.pickImage(source: source, imageQuality: 80);
    }
    if (file == null) return;
    if (!mounted) return;

    setState(() => _isUploadingMedia = true);

    try {
      final ext = isVideo ? 'mp4' : 'jpg';
      final fileName = '${DateTime.now().millisecondsSinceEpoch}.$ext';
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('chat_media')
          .child(widget.taskId)
          .child(fileName);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isVideo ? '📹 视频上传中...' : '📷 图片上传中...'),
          duration: const Duration(seconds: 30),
        ),
      );

      await storageRef.putFile(File(file.path));
      final downloadUrl = await storageRef.getDownloadURL();

      final taskRef = FirebaseFirestore.instance
          .collection('tasks')
          .doc(widget.taskId);

      await taskRef.collection('messages').add({
        'senderId': user!.uid,
        'senderName': user!.displayName ?? 'XOLV 伙伴',
        'type': isVideo ? 'video' : 'image',
        'mediaUrl': downloadUrl,
        'text': isVideo ? '[视频]' : '[图片]',
        'createdAt': FieldValue.serverTimestamp(),
      });

      await taskRef.update({
        'lastMessageAt': FieldValue.serverTimestamp(),
        'lastReadBy.${user!.uid}': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isVideo ? '✅ 视频已发送' : '✅ 图片已发送'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('上传失败: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploadingMedia = false);
    }
  }

  // 🎬 全屏播放聊天视频
  void _openVideoPlayer(String url) {
    final controller = VideoPlayerController.networkUrl(Uri.parse(url));
    showDialog(
      context: context,
      barrierColor: Colors.black,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            controller.initialize().then((_) {
              setDialogState(() {});
              controller.play();
            });
            return Stack(
              children: [
                Center(
                  child: AspectRatio(
                    aspectRatio: controller.value.isInitialized
                        ? controller.value.aspectRatio
                        : 16 / 9,
                    child: controller.value.isInitialized
                        ? VideoPlayer(controller)
                        : const Center(
                            child: CircularProgressIndicator(
                              color: Colors.white,
                            ),
                          ),
                  ),
                ),
                Positioned(
                  top: 40,
                  right: 16,
                  child: IconButton(
                    icon: const Icon(
                      Icons.close,
                      color: Colors.white,
                      size: 32,
                    ),
                    onPressed: () {
                      controller.dispose();
                      Navigator.pop(ctx);
                    },
                  ),
                ),
                if (controller.value.isInitialized)
                  Positioned(
                    bottom: 40,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: IconButton(
                        icon: Icon(
                          controller.value.isPlaying
                              ? Icons.pause
                              : Icons.play_arrow,
                          color: Colors.white,
                          size: 48,
                        ),
                        onPressed: () {
                          setDialogState(() {
                            controller.value.isPlaying
                                ? controller.pause()
                                : controller.play();
                          });
                        },
                      ),
                    ),
                  ),
              ],
            );
          },
        );
      },
    ).then((_) => controller.dispose());
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingTaskMeta) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: Colors.black)),
      );
    }

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
              _taskDescription,
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
          // 📞 语音通话
          IconButton(
            icon: const Icon(Icons.call, color: Colors.green),
            tooltip: '语音通话',
            onPressed: () => _startCall('voice'),
          ),
          // 📹 视频通话
          IconButton(
            icon: const Icon(Icons.videocam, color: Color(0xFFFF5E00)),
            tooltip: '视频通话',
            onPressed: () => _startCall('video'),
          ),
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
                    taskDescription: _taskDescription,
                    amount: _amount,
                    currentUserRole: _currentUserRole,
                    againstUid: _againstUid,
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

          final List<dynamic> completionPhotos =
              taskData['completionPhotos'] ?? [];

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
                          type: data['type'] ?? 'text',
                          mediaUrl: data['mediaUrl'],
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
                      IconButton(
                        icon: _isUploadingMedia
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.add_circle_outline),
                        color: _brandColor,
                        onPressed: _isUploadingMedia ? null : _showMediaPicker,
                      ),
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
    String type = 'text',
    String? mediaUrl,
  }) {
    Widget content;
    if (type == 'image' && mediaUrl != null) {
      content = GestureDetector(
        onTap: () => _openPhotoViewer(mediaUrl),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.network(
            mediaUrl,
            width: 200,
            height: 200,
            fit: BoxFit.cover,
            loadingBuilder: (ctx, child, progress) => progress == null
                ? child
                : const SizedBox(
                    width: 200,
                    height: 200,
                    child: Center(child: CircularProgressIndicator()),
                  ),
          ),
        ),
      );
    } else if (type == 'video' && mediaUrl != null) {
      content = GestureDetector(
        onTap: () => _openVideoPlayer(mediaUrl),
        child: Container(
          width: 200,
          height: 150,
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: const BoxDecoration(
                  color: Colors.white24,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.play_arrow,
                  color: Colors.white,
                  size: 32,
                ),
              ),
              const Positioned(
                bottom: 8,
                left: 12,
                child: Text(
                  '▶ 点击播放视频',
                  style: TextStyle(color: Colors.white70, fontSize: 11),
                ),
              ),
            ],
          ),
        ),
      );
    } else {
      content = Container(
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
      );
    }

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
            content,
          ],
        ),
      ),
    );
  }
}
