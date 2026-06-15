import 'package:flutter/material.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:permission_handler/permission_handler.dart';
import 'call_shared.dart';

// 📹 视频通话页面（以 taskId 作为 Agora channel）
class VideoCallPage extends StatefulWidget {
  final String channelName;
  final String callerName;
  final String receiverName;

  const VideoCallPage({
    super.key,
    required this.channelName,
    required this.callerName,
    required this.receiverName,
  });

  @override
  State<VideoCallPage> createState() => _VideoCallPageState();
}

class _VideoCallPageState extends State<VideoCallPage> {
  RtcEngine? _engine;
  int? _remoteUid;
  bool _localUserJoined = false;
  bool _isMuted = false;
  bool _isCameraOff = false;
  bool _isFrontCamera = true;

  @override
  void initState() {
    super.initState();
    _initAgora();
  }

  Future<void> _initAgora() async {
    await [Permission.microphone, Permission.camera].request();

    _engine = createAgoraRtcEngine();
    await _engine!.initialize(RtcEngineContext(appId: agoraAppId));

    _engine!.registerEventHandler(
      RtcEngineEventHandler(
        onJoinChannelSuccess: (connection, elapsed) {
          if (!mounted) return;
          setState(() => _localUserJoined = true);
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

    await _engine!.enableVideo();
    await _engine!.startPreview();
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

  void _toggleMute() {
    setState(() => _isMuted = !_isMuted);
    _engine?.muteLocalAudioStream(_isMuted);
  }

  void _toggleCamera() {
    setState(() => _isCameraOff = !_isCameraOff);
    _engine?.muteLocalVideoStream(_isCameraOff);
  }

  void _switchCamera() {
    setState(() => _isFrontCamera = !_isFrontCamera);
    _engine?.switchCamera();
  }

  void _endCall() async {
    await _engine?.leaveChannel();
    await _engine?.release();
    if (mounted) Navigator.pop(context);
  }

  @override
  void dispose() {
    _engine?.leaveChannel();
    _engine?.release();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final int? remoteUid = _remoteUid;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 远端视频（全屏）
          Center(
            child: remoteUid != null
                ? AgoraVideoView(
                    controller: VideoViewController.remote(
                      rtcEngine: _engine!,
                      canvas: VideoCanvas(uid: remoteUid),
                      connection: RtcConnection(channelId: widget.channelName),
                    ),
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const CircleAvatar(
                        radius: 50,
                        child: Icon(Icons.person, size: 50),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        widget.receiverName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        '等待对方接入视频...',
                        style: TextStyle(color: Colors.white60),
                      ),
                    ],
                  ),
          ),
          // 本地视频（小窗口右上角）
          Positioned(
            top: 60,
            right: 16,
            child: SizedBox(
              width: 100,
              height: 140,
              child: _localUserJoined && !_isCameraOff
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: AgoraVideoView(
                        controller: VideoViewController(
                          rtcEngine: _engine!,
                          canvas: const VideoCanvas(uid: 0),
                        ),
                      ),
                    )
                  : Container(
                      decoration: BoxDecoration(
                        color: Colors.grey[900],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.videocam_off,
                        color: Colors.white54,
                        size: 32,
                      ),
                    ),
            ),
          ),
          // 对方名字
          Positioned(
            top: 60,
            left: 20,
            child: Text(
              widget.receiverName,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
                shadows: [Shadow(blurRadius: 4, color: Colors.black)],
              ),
            ),
          ),
          // 控制按钮
          Positioned(
            bottom: 50,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                CallButton(
                  icon: _isMuted ? Icons.mic_off : Icons.mic,
                  label: '静音',
                  color: _isMuted ? Colors.red : Colors.white24,
                  onTap: _toggleMute,
                ),
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
                  icon: _isCameraOff ? Icons.videocam_off : Icons.videocam,
                  label: '摄像头',
                  color: _isCameraOff ? Colors.red : Colors.white24,
                  onTap: _toggleCamera,
                ),
                CallButton(
                  icon: Icons.flip_camera_ios,
                  label: '翻转',
                  color: Colors.white24,
                  onTap: _switchCamera,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
