import 'dart:async';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'voice_call_page.dart';
import 'video_call_page.dart';

// 📲 来电邀请页面：接听 / 拒绝
class IncomingCallPage extends StatefulWidget {
  final String callId;
  final String callerName;
  final String taskId;
  final String callType; // 'voice' or 'video'

  const IncomingCallPage({
    super.key,
    required this.callId,
    required this.callerName,
    required this.taskId,
    required this.callType,
  });

  @override
  State<IncomingCallPage> createState() => _IncomingCallPageState();
}

class _IncomingCallPageState extends State<IncomingCallPage> {
  StreamSubscription<DocumentSnapshot>? _callSub;
  bool _handled = false;

  @override
  void initState() {
    super.initState();
    // 📡 监听通话状态，若对方挂断或超时则自动关闭来电界面
    _callSub = FirebaseFirestore.instance
        .collection('calls')
        .doc(widget.callId)
        .snapshots()
        .listen((snap) {
          final status = snap.data()?['status'];
          if (!_handled &&
              (status == 'timeout' ||
                  status == 'ended' ||
                  status == 'rejected')) {
            _handled = true;
            if (mounted) Navigator.pop(context);
          }
        });
  }

  Future<void> _acceptCall() async {
    _handled = true;
    await FirebaseFirestore.instance
        .collection('calls')
        .doc(widget.callId)
        .update({'status': 'accepted'});

    if (!mounted) return;
    Navigator.pop(context);

    if (widget.callType == 'video') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => VideoCallPage(
            channelName: widget.taskId,
            callerName: '我',
            receiverName: widget.callerName,
          ),
        ),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => VoiceCallPage(
            channelName: widget.taskId,
            callerName: '我',
            receiverName: widget.callerName,
          ),
        ),
      );
    }
  }

  Future<void> _rejectCall() async {
    _handled = true;
    await FirebaseFirestore.instance
        .collection('calls')
        .doc(widget.callId)
        .update({'status': 'rejected'});
    if (mounted) Navigator.pop(context);
  }

  @override
  void dispose() {
    _callSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isVideo = widget.callType == 'video';
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      body: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Spacer(),
            CircleAvatar(
              radius: 60,
              backgroundColor: const Color(0xFFFF5E00).withValues(alpha: 0.2),
              child: const Icon(
                Icons.person,
                size: 60,
                color: Color(0xFFFF5E00),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              widget.callerName,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isVideo ? '📹 视频通话邀请' : '📞 语音通话邀请',
              style: const TextStyle(color: Colors.white60, fontSize: 16),
            ),
            const Spacer(),
            // 接听/拒绝按钮
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 60),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // 拒绝
                  Column(
                    children: [
                      GestureDetector(
                        onTap: _rejectCall,
                        child: Container(
                          width: 70,
                          height: 70,
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.call_end,
                            color: Colors.white,
                            size: 32,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text('拒绝', style: TextStyle(color: Colors.white60)),
                    ],
                  ),
                  // 接听
                  Column(
                    children: [
                      GestureDetector(
                        onTap: _acceptCall,
                        child: Container(
                          width: 70,
                          height: 70,
                          decoration: const BoxDecoration(
                            color: Colors.green,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            isVideo ? Icons.videocam : Icons.call,
                            color: Colors.white,
                            size: 32,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text('接听', style: TextStyle(color: Colors.white60)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 60),
          ],
        ),
      ),
    );
  }
}
