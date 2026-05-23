import 'dart:async'; // 🚀 引入时间引擎
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

class PublishTaskPage extends StatefulWidget {
  const PublishTaskPage({super.key});

  @override
  State<PublishTaskPage> createState() => _PublishTaskPageState();
}

class _ThemeColors {
  static const Color primary = Color(0xFFFF5E00); // ⚡️ 切换为闪电橙
}

class _PublishTaskPageState extends State<PublishTaskPage> {
  final _descController = TextEditingController();
  final _locationController = TextEditingController();
  final _amountController = TextEditingController();

  int _peopleCount = 1;
  int _timeValue = 1;
  String _timeUnit = '小时';

  double? _latitude;
  double? _longitude;

  bool _isLoading = false;
  bool _isFetchingLocation = false;
  bool _isGeocoding = false;
  bool _locationVerified = false;

  // 🌟 核心新增：灵感轮播引擎
  Timer? _hintTimer;
  int _currentHintIndex = 0;
  final List<String> _hintExamples = [
    '例如：人在国外，急需找人去老家看望父母...',
    '例如：帮我去夜市排队买一份炒粿条...',
    '例如：家里进了只大老鼠，急需勇士来抓！',
    '例如：文件落在家里了，帮我送去公司前台...',
    '例如：谁能帮我去取个快递，大概 5 公斤重...',
  ];

  @override
  void initState() {
    super.initState();
    // ⏰ 启动 3 秒轮播器
    _startHintTimer();
  }

  void _startHintTimer() {
    _hintTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (mounted) {
        setState(() {
          // 不断循环切换索引：0 -> 1 -> 2 -> 3 -> 4 -> 0
          _currentHintIndex = (_currentHintIndex + 1) % _hintExamples.length;
        });
      }
    });
  }

  @override
  void dispose() {
    // 🛡️ 防内存泄漏：页面关闭时，必须强行炸毁这个计时器！
    _hintTimer?.cancel();

    _descController.dispose();
    _locationController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  int get _calculatedTotalHours {
    if (_timeUnit == '天') return _timeValue * 24;
    return _timeValue;
  }

  String get _formattedTimeString {
    return '$_timeValue $_timeUnit';
  }

  // 📍 模式 1：获取我当前的 GPS
  Future<void> _getCurrentLocation() async {
    setState(() => _isFetchingLocation = true);
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) throw '请先打开 GPS 定位服务！';
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) throw '您拒绝了定位权限';
      }
      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );
      String address = '';
      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];
        address = [
          place.street,
          place.subLocality,
          place.locality,
          place.administrativeArea,
        ].where((e) => e != null && e.isNotEmpty).join(', ');
      }

      setState(() {
        _latitude = position.latitude;
        _longitude = position.longitude;
        _locationController.text = address.isNotEmpty ? address : '已获取当前坐标';
        _locationVerified = true;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ 当前位置已锁定！'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isFetchingLocation = false);
    }
  }

  // 🌍 模式 2：解析异地手写地址
  Future<void> _verifyRemoteAddress() async {
    final address = _locationController.text.trim();
    if (address.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('请先输入您想指定的城市或详细地址'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isGeocoding = true;
      _locationVerified = false;
    });

    try {
      List<Location> locations = await locationFromAddress(address);
      if (locations.isNotEmpty) {
        setState(() {
          _latitude = locations[0].latitude;
          _longitude = locations[0].longitude;
          _locationVerified = true;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ 异地雷达坐标已精准锁定！'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('❌ 找不到该地址坐标，请尝试输入更详细的街道或城市名'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isGeocoding = false);
    }
  }

  // 🚀 提交发布
  Future<void> _submitTask() async {
    final desc = _descController.text.trim();
    final location = _locationController.text.trim();
    final amount = _amountController.text.trim();

    if (desc.isEmpty || location.isEmpty || amount.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('老板，请填满描述、地点和金额哦！'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (!_locationVerified || _latitude == null || _longitude == null) {
      setState(() => _isLoading = true);
      try {
        List<Location> locations = await locationFromAddress(location);
        if (locations.isNotEmpty) {
          _latitude = locations[0].latitude;
          _longitude = locations[0].longitude;
        } else {
          throw '无法识别坐标';
        }
      } catch (e) {
        if (!mounted) return;

        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('坐标解析失败！请点击地址栏右侧的🔍放大镜验证地址。'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    }

    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      final String? uid = user?.uid;
      final String publisherName = user?.displayName ?? 'XOLV 雇主';

      await FirebaseFirestore.instance.collection('tasks').add({
        'description': desc,
        'location': location,
        'amount': amount,
        'peopleCount': _peopleCount,
        'acceptedCount': 0,
        'acceptedUsers': <String>[],
        'expectedTime': _formattedTimeString,
        'expectedTimeHours': _calculatedTotalHours,
        'latitude': _latitude,
        'longitude': _longitude,
        'publisherId': uid ?? 'anonymous',
        'publisherName': publisherName,
        'createdAt': FieldValue.serverTimestamp(),
        'status': 'pending',
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🎉 任务发布成功！'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('失败: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '发布组队委托',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black),
        ),
        backgroundColor: Colors.white,
        elevation: 0.5,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: _ThemeColors.primary),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    '任务描述',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),

                  // 🌟 核心升级：保留灵感轮播，彻底解决键盘断触 bug！
                  TextField(
                    controller: _descController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText:
                          _hintExamples[_currentHintIndex], // ⏰ 依然每3秒切换提示语
                      hintStyle: TextStyle(
                        color: Colors.grey[400],
                        fontSize: 14,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: Colors.black,
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _locationVerified
                          ? Colors.green[50]
                          : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: _locationVerified
                            ? Colors.green
                            : Colors.black12,
                        width: _locationVerified ? 2 : 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              '委托执行地点',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                            TextButton.icon(
                              icon: _isFetchingLocation
                                  ? const SizedBox(
                                      width: 14,
                                      height: 14,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(
                                      Icons.my_location,
                                      size: 15,
                                      color: Colors.blue,
                                    ),
                              label: const Text(
                                '用我当前位置',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.blue,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              onPressed: _getCurrentLocation,
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _locationController,
                          onChanged: (val) {
                            if (_locationVerified) {
                              setState(() {
                                _locationVerified = false;
                                _latitude = null;
                                _longitude = null;
                              });
                            }
                          },
                          decoration: InputDecoration(
                            hintText: '或手动输入异地地址 (如: 父母家)',
                            hintStyle: const TextStyle(fontSize: 14),
                            filled: true,
                            fillColor: Colors.white,
                            prefixIcon: const Icon(
                              Icons.travel_explore,
                              color: Colors.grey,
                            ),
                            suffixIcon: _isGeocoding
                                ? const Padding(
                                    padding: EdgeInsets.all(12),
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : IconButton(
                                    icon: Icon(
                                      _locationVerified
                                          ? Icons.check_circle
                                          : Icons.search,
                                      color: _locationVerified
                                          ? Colors.green
                                          : Colors.black,
                                    ),
                                    onPressed: _verifyRemoteAddress,
                                    tooltip: '解析该地址坐标',
                                  ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                        if (_locationVerified)
                          const Padding(
                            padding: EdgeInsets.only(top: 8.0, left: 4),
                            child: Text(
                              '✅ 坐标已锁定！广场接单员将以此地为中心看到您的委托。',
                              style: TextStyle(
                                color: Colors.green,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  _buildCounterCard(
                    title: '需要人数',
                    icon: Icons.people_outline,
                    displayWidget: Text(
                      '$_peopleCount 人',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    onMinus: _peopleCount > 1
                        ? () => setState(() => _peopleCount--)
                        : null,
                    onPlus: () => setState(() => _peopleCount++),
                  ),
                  const SizedBox(height: 16),

                  _buildCounterCard(
                    title: '希望完成时间',
                    icon: Icons.timer_outlined,
                    displayWidget: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '$_timeValue ',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                          ),
                        ),
                        DropdownButton<String>(
                          value: _timeUnit,
                          underline: const SizedBox(),
                          icon: const Icon(
                            Icons.arrow_drop_down,
                            color: Colors.blue,
                          ),
                          style: const TextStyle(
                            color: Colors.blue,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          items: const [
                            DropdownMenuItem(value: '小时', child: Text('小时')),
                            DropdownMenuItem(value: '天', child: Text('天')),
                          ],
                          onChanged: (val) {
                            if (val != null) {
                              setState(() {
                                _timeUnit = val;
                                _timeValue = 1;
                              });
                            }
                          },
                        ),
                      ],
                    ),
                    onMinus: _timeValue > 1
                        ? () => setState(() => _timeValue--)
                        : null,
                    onPlus: () => setState(() => _timeValue++),
                  ),
                  const SizedBox(height: 24),

                  TextField(
                    controller: _amountController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: '每人可得悬赏金额 (RM)',
                      prefixIcon: const Icon(Icons.attach_money),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),

                  ElevatedButton(
                    onPressed: _submitTask,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _ThemeColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      '立即发布委托',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildCounterCard({
    required String title,
    required IconData icon,
    required Widget displayWidget,
    required VoidCallback? onMinus,
    required VoidCallback onPlus,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black12),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.grey[700]),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
            ),
          ),
          IconButton(
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: onMinus,
            icon: Icon(
              Icons.remove_circle_outline,
              color: onMinus == null ? Colors.grey : _ThemeColors.primary,
              size: 28,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4.0),
            child: displayWidget,
          ),
          IconButton(
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: onPlus,
            icon: const Icon(
              Icons.add_circle_outline,
              color: _ThemeColors.primary,
              size: 28,
            ),
          ),
        ],
      ),
    );
  }
}
