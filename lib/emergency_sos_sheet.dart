import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

class EmergencySOS {
  // 暴露一个全局调用的入口，任何页面都可以随时拉起这个救命弹窗
  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const _SOSBottomSheet(),
    );
  }
}

class _SOSBottomSheet extends StatefulWidget {
  const _SOSBottomSheet();
  @override
  State<_SOSBottomSheet> createState() => _SOSBottomSheetState();
}

class _SOSBottomSheetState extends State<_SOSBottomSheet> {
  bool _isLocating = false;

  // 📞 功能 1：一键拨打报警电话
  Future<void> _callPolice() async {
    final Uri telUrl = Uri.parse('tel:999'); // 马来西亚报警电话
    try {
      if (!await launchUrl(telUrl)) {
        throw '无法唤起拨号盘';
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('拨号失败: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // 📍 功能 2：获取当前坐标并生成带 Google Maps 链接的求救短信
  Future<void> _sendSOSLocation() async {
    setState(() => _isLocating = true);
    try {
      // 1. 强行抓取最高精度坐标
      Position pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.best,
        ),
      );

      // 2. 生成 Google Maps 精准雷达链接
      final String mapsUrl =
          'https://www.google.com/maps/search/?api=1&query=${pos.latitude},${pos.longitude}';

      // 3. 编写求救短信文案
      final String smsBody =
          '🚨 [XOLV 紧急求助] 我正在执行/发布委托，目前遇到紧急情况！这是我的精准位置，请立刻联系我或帮我报警：$mapsUrl';

      // 4. 唤起手机短信 App 并自动填入求救内容
      final Uri smsUrl = Uri(scheme: 'sms', queryParameters: {'body': smsBody});

      if (!await launchUrl(smsUrl)) {
        throw '无法唤起短信界面';
      }

      if (mounted) Navigator.pop(context); // 发送成功后自动收起弹窗
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('获取定位或发送短信失败: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLocating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      padding: EdgeInsets.only(
        top: 24,
        left: 24,
        right: 24,
        bottom: MediaQuery.of(context).padding.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 极具视觉冲击力的警告图标
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.warning_rounded,
              color: Colors.red,
              size: 50,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'SOS 紧急求助',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: Colors.red,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            '如果您感到人身安全受到威胁，请立刻使用以下功能！平台将全力配合警方调查。',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.black87, fontSize: 14, height: 1.5),
          ),
          const SizedBox(height: 32),

          // 按钮 1：发送定位短信
          ElevatedButton.icon(
            onPressed: _isLocating ? null : _sendSOSLocation,
            icon: _isLocating
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const Icon(Icons.sms_failed),
            label: Text(
              _isLocating ? '正在强行锁定坐标...' : '发送定位求救短信',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange[800],
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 56),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // 按钮 2：直接拨打 999
          ElevatedButton.icon(
            onPressed: _callPolice,
            icon: const Icon(Icons.phone_in_talk),
            label: const Text(
              '一键拨打 999 报警',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red[700],
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 56),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 16),

          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              '取消',
              style: TextStyle(
                color: Colors.grey,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
