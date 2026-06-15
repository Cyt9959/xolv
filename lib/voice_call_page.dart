import 'dart:async';
import 'package:flutter/material.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:permission_handler/permission_handler.dart';
import 'call_shared.dart';

// 📞 语音通话页面（以 taskId 作为 Agora channel）
class VoiceCallPage extends StatefulWidget {
  final String channelName;
  final String callerName;
  final String receiverName;

  const VoiceCallPage({
    super.key,
    required this.channelName,
    required this.callerName,
    required this.receiverName,
  });

  @override
  State<VoiceCallPage> createState() => _VoiceCallPageState();
}

class _VoiceCallPageState extends State<VoiceCallPage> {
  RtcEngine? _engine;
  bool _isMuted = false;
  bool _isSpeakerOn = true;
  bool _isConnected = false;
  int _callDuration = 0;
  Timer? _timer;
  int? _remoteUid;

  @override
  void initState() {
    super.initState();
    _initAgora();
  }

  Future<void> _initAgora() async {
    await [Permission.microphone].request();

    _engine = createAgoraRtcEngine();
    await _engine!.initialize(RtcEngineContext(appId: agoraAppId));

    _engine!.registerEventHandler(
      RtcEngineEventHandler(
        onJoinChannelSuccess: (connection, elapsed) {
          if (!mounted) return;
          setState(() => _isConnected = true);
          _startTimer();
        },
        onUserJoined: (connection, remoteUid, elapsed) {
          if (!mounted) return;
          setState(() => _remoteUid = remoteUid);
        },
        onUserOffline: (connection, remoteUid, reason) {
          if (!mounted) return;
          setState(() => _remoteUid = null);
          _endCall();
        },
      ),
    );

    await _engine!.enableAudio();
    await _engine!.setClientRole(role: ClientRoleType.clientRoleBroadcaster);

    // 🔑 先向云端换取正式 Agora Token
    String agoraToken = '';
    try {
      final callable = FirebaseFunctions.instance.httpsCallable(
        'generateAgoraToken',
      );
      final result = await callable.call({
        'channelName': widget.channelName,
        'uid': 0,
      });
      agoraToken = result.data['token'] as String;
    } catch (e) {
      debugPrint('Token 获取失败: $e');
      if (mounted) Navigator.pop(context);
      return;
    }

    await _engine!.joinChannel(
      token: agoraToken,
      channelId: widget.channelName,
      uid: 0,
      options: const ChannelMediaOptions(
        channelProfile: ChannelProfileType.channelProfileCommunication,
        clientRoleType: ClientRoleType.clientRoleBroadcaster,
      ),
    );
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => _callDuration++);
    });
  }

  String get _formattedDuration {
    final m = (_callDuration ~/ 60).toString().padLeft(2, '0');
    final s = (_callDuration % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  void _toggleMute() {
    setState(() => _isMuted = !_isMuted);
    _engine?.muteLocalAudioStream(_isMuted);
  }

  void _toggleSpeaker() {
    setState(() => _isSpeakerOn = !_isSpeakerOn);
    _engine?.setEnableSpeakerphone(_isSpeakerOn);
  }

  void _endCall() async {
    _timer?.cancel();
    await _engine?.leaveChannel();
    await _engine?.release();
    if (mounted) Navigator.pop(context);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _engine?.leaveChannel();
    _engine?.release();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 60),
            // 头像
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
            // 对方名字
            Text(
              widget.receiverName,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            // 状态
            Text(
              _remoteUid != null
                  ? _formattedDuration
                  : _isConnected
                  ? '等待对方接听...'
                  : '连接中...',
              style: const TextStyle(color: Colors.white60, fontSize: 16),
            ),
            const Spacer(),
            // 控制按钮
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  CallButton(
                    icon: _isMuted ? Icons.mic_off : Icons.mic,
                    label: _isMuted ? '取消静音' : '静音',
                    color: _isMuted ? Colors.red : Colors.white24,
                    onTap: _toggleMute,
                  ),
                  // 结束通话
                  GestureDetector(
                    onTap: _endCall,
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
                  CallButton(
                    icon: _isSpeakerOn ? Icons.volume_up : Icons.volume_off,
                    label: '扬声器',
                    color: _isSpeakerOn
                        ? const Color(0xFFFF5E00)
                        : Colors.white24,
                    onTap: _toggleSpeaker,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 50),
          ],
        ),
      ),
    );
  }
}
