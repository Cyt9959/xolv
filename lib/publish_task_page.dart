import 'dart:async'; // 🚀 引入时间引擎
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:geocoding/geocoding.dart';
import 'package:image_picker/image_picker.dart';
import 'kyc_page.dart';
import 'select_location_page.dart';

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

  final List<File> _selectedImages = [];
  final ImagePicker _imagePicker = ImagePicker();

  bool _isLoading = false;
  bool _locationVerified = false;
  bool _isPriceSuggesting = false;
  bool _isUrgent = false;

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
    _startHintTimer();
    _amountController.addListener(_onAmountChanged);
  }

  void _onAmountChanged() {
    if (mounted) setState(() {});
  }

  void _startHintTimer() {
    _hintTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (mounted) {
        setState(() {
          _currentHintIndex = (_currentHintIndex + 1) % _hintExamples.length;
        });
      }
    });
  }

  @override
  void dispose() {
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

  Future<void> _openLocationPicker() async {
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (_) => SelectLocationPage(
          initialLatitude: _latitude,
          initialLongitude: _longitude,
        ),
      ),
    );
    if (result == null) return;

    setState(() {
      _locationController.text = result['address'] as String;
      _latitude = result['latitude'] as double;
      _longitude = result['longitude'] as double;
      _locationVerified = true;
    });
  }

  // ========================================
  // ✨ AI 建议定价
  // ========================================
  Future<void> _suggestPrice() async {
    final desc = _descController.text.trim();
    final loc = _locationController.text.trim();
    if (desc.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先填写任务描述！')),
      );
      return;
    }
    setState(() => _isPriceSuggesting = true);
    try {
      final callable = FirebaseFunctions.instance.httpsCallable(
        'suggestTaskPrice',
      );
      final result = await callable.call({
        'description': desc,
        'location': loc,
      });
      final min = result.data['min'];
      final max = result.data['max'];
      final suggestion = result.data['suggestion'];
      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: const Text('✨ AI 定价建议'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '建议范围：RM $min – RM $max',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Text(suggestion, style: const TextStyle(color: Colors.grey)),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('参考一下'),
              ),
              ElevatedButton(
                onPressed: () {
                  _amountController.text = max.toString();
                  Navigator.pop(ctx);
                },
                child: const Text('用这个金额'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('建议失败: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isPriceSuggesting = false);
    }
  }

  // ========================================
  // 🖼️ 任务附图：选择 / 移除
  // ========================================
  Future<void> _pickImage() async {
    if (_selectedImages.length >= 5) return;

    final XFile? picked = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );
    if (picked == null) return;

    setState(() => _selectedImages.add(File(picked.path)));
  }

  void _removeImage(int index) {
    setState(() => _selectedImages.removeAt(index));
  }

  // ========================================
  // ☁️ 上传任务附图到 Firebase Storage，返回下载链接列表
  // ========================================
  Future<List<String>> _uploadTaskImages(String taskId) async {
    final List<String> imageUrls = [];

    for (int i = 0; i < _selectedImages.length; i++) {
      final ref = FirebaseStorage.instance.ref(
        'task_images/$taskId/image_$i.jpg',
      );
      await ref.putFile(_selectedImages[i]);
      final url = await ref.getDownloadURL();
      imageUrls.add(url);
    }

    return imageUrls;
  }

  // =================================================================
  // 🚨 核心升级：带有“查余额+扣钱”的金融级原子提交引擎！
  // =================================================================
  // ========================================
  // 🛡️ KYC 双轨容错验证（与其他页面保持一致）
  // ========================================
  Future<String> _getKycStatus() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return 'none';

    // 轨道 A：查 users 总表
    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();
    String kycStatus = (userDoc.data()?['kyc_status'] ?? 'none')
        .toString()
        .trim()
        .toLowerCase();

    // 轨道 B：总表未通过则深度扫描申请表
    if (kycStatus != 'approved') {
      final kycAppDoc = await FirebaseFirestore.instance
          .collection('kyc_applications')
          .doc(user.uid)
          .get();
      if (kycAppDoc.exists) {
        final appStatus = (kycAppDoc.data()?['status'] ?? 'none')
            .toString()
            .trim()
            .toLowerCase();
        if (appStatus == 'approved') {
          kycStatus = 'approved';
        } else if (appStatus == 'pending' && kycStatus == 'none') {
          kycStatus = 'pending';
        } else if (appStatus == 'rejected' && kycStatus == 'none') {
          kycStatus = 'rejected';
        }
      }
    }

    return kycStatus;
  }

  // ========================================
  // 🚨 实名认证安全拦截弹窗
  // ========================================
  void _showKYCDialog(String message, bool showGoToKYC) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.gpp_bad, color: primaryColor, size: 28),
            const SizedBox(width: 8),
            const Text(
              '安全拦截',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ],
        ),
        content: Text(message, style: const TextStyle(height: 1.5, fontSize: 14)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('稍后再说', style: TextStyle(color: Colors.grey)),
          ),
          if (showGoToKYC)
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const KYCPage()),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
              child: const Text(
                '立即前往认证',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _submitTask() async {
    // 🚨 第 0 步：KYC 双轨验证 —— 未通过实名认证不可发布悬赏
    final kycStatus = await _getKycStatus();
    if (!mounted) return;
    if (kycStatus != 'approved') {
      if (kycStatus == 'pending') {
        _showKYCDialog('【审核中】\n您的实名资料正在人工审核中，通过后即可发布悬赏！', false);
      } else if (kycStatus == 'rejected') {
        _showKYCDialog('【认证失败】\n您的实名资料不符合要求，请重新拍摄清晰的证件。', true);
      } else if (kycStatus == 'revoked') {
        _showKYCDialog('您的实名认证已被平台撤销，请联系客服了解详情。', false);
      } else {
        _showKYCDialog('【平台安全合规】\n为了保障交易资金安全，发布悬赏前必须完成大马卡实名建档！', true);
      }
      return;
    }

    final desc = _descController.text.trim();
    final location = _locationController.text.trim();
    final amountText = _amountController.text.trim();

    if (desc.isEmpty || location.isEmpty || amountText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('老板，请填满描述、地点和金额哦！'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final double perPersonAmount = double.tryParse(amountText) ?? 0.0;
    if (perPersonAmount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('金额必须大于 0 呀！'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // 💡 1. 计算要扣除的总金额（含急单附加费）
    final double urgentFee = _isUrgent ? 5.0 : 0.0;
    final double depositCost = perPersonAmount * _peopleCount;
    final double totalCost = depositCost + urgentFee;

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
            content: Text('坐标解析失败！请点击放大镜验证。'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    }

    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw '请先登录！';

      final userRef = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid);
      final newTaskRef = FirebaseFirestore.instance.collection('tasks').doc();
      final newTxRef = FirebaseFirestore.instance
          .collection('transactions')
          .doc();

      // 💡 1.5 上传任务附图（选填，最多 5 张）
      final List<String> imageUrls = await _uploadTaskImages(newTaskRef.id);

      // 💡 2. 启动金融级交易锁 (Transaction)
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        // 第一步：去云端查老板的账本
        final userDoc = await transaction.get(userRef);
        final double currentBalance = (userDoc.data()?['wallet_balance'] ?? 0.0)
            .toDouble();

        // 第二步：余额拦截器
        if (currentBalance < totalCost) {
          throw Exception('INSUFFICIENT_FUNDS'); // 如果钱不够，立刻抛出异常，中断所有操作！
        }

        // 第三步：扣除余额
        transaction.update(userRef, {
          'wallet_balance': currentBalance - totalCost,
        });

        // 第四步：把任务写上广场
        transaction.set(newTaskRef, {
          'description': desc,
          'location': location,
          'amount': perPersonAmount.toStringAsFixed(2),
          'peopleCount': _peopleCount,
          'acceptedCount': 0,
          'acceptedUsers': <String>[],
          'expectedTime': _formattedTimeString,
          'expectedTimeHours': _calculatedTotalHours,
          'latitude': _latitude,
          'longitude': _longitude,
          'publisherId': user.uid,
          'publisherName': user.displayName ?? 'XOLV 雇主',
          'createdAt': FieldValue.serverTimestamp(),
          'status': 'pending',
          'imageUrls': imageUrls,
          'isUrgent': _isUrgent,
          'urgentFee': urgentFee,
          'urgentBonus': _isUrgent ? 2.0 : 0.0,
          'platformFee': _isUrgent ? 3.0 : 0.0,
        });

        // 第五步：在钱包里写一条扣款流水
        transaction.set(newTxRef, {
          'userId': user.uid,
          'title':
              '发布任务押金 - ${desc.length > 5 ? '${desc.substring(0, 5)}...' : desc}',
          'amount': -depositCost, // 负数代表扣款
          'type': 'fee',
          'createdAt': FieldValue.serverTimestamp(),
          'status': '系统扣除',
        });

        // 第六步：急单附加费流水（单独一条）
        if (_isUrgent) {
          final urgentFeeRef = FirebaseFirestore.instance
              .collection('transactions')
              .doc();
          transaction.set(urgentFeeRef, {
            'userId': user.uid,
            'title': '🔥 急单附加费',
            'amount': -urgentFee,
            'type': 'urgent_fee',
            'status': '已扣除',
            'taskId': newTaskRef.id,
            'createdAt': FieldValue.serverTimestamp(),
          });
        }
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('publish_success'.tr()),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context); // 退出发布页面，回到广场
      }
    } catch (e) {
      if (mounted) {
        if (e.toString().contains('INSUFFICIENT_FUNDS')) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '❌ ${'insufficient_funds'.tr()}啦！发布此任务共需 RM ${totalCost.toStringAsFixed(2)}，请先充值！',
              ),
              backgroundColor: Colors.red,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('失败: $e'), backgroundColor: Colors.red),
          );
        }
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'publish_task'.tr(),
          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black),
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
                  Text(
                    'task_desc'.tr(),
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _descController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: _hintExamples[_currentHintIndex],
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

                  // ========================================
                  // 🖼️ 任务附图（选填，最多 5 张）
                  // ========================================
                  const Text(
                    '任务附图（选填，最多 5 张）',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 90,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount:
                          _selectedImages.length +
                          (_selectedImages.length < 5 ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index == _selectedImages.length) {
                          return GestureDetector(
                            onTap: _pickImage,
                            child: Container(
                              width: 90,
                              height: 90,
                              margin: const EdgeInsets.only(right: 8),
                              decoration: BoxDecoration(
                                color: Colors.grey[50],
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.black12),
                              ),
                              child: const Icon(
                                Icons.add_a_photo_outlined,
                                color: Colors.grey,
                              ),
                            ),
                          );
                        }

                        return Stack(
                          children: [
                            Container(
                              width: 90,
                              height: 90,
                              margin: const EdgeInsets.only(right: 8),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                image: DecorationImage(
                                  image: FileImage(_selectedImages[index]),
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                            Positioned(
                              top: 2,
                              right: 10,
                              child: GestureDetector(
                                onTap: () => _removeImage(index),
                                child: Container(
                                  padding: const EdgeInsets.all(2),
                                  decoration: const BoxDecoration(
                                    color: Colors.black54,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.close,
                                    color: Colors.white,
                                    size: 14,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 24),

                  Text(
                    'task_location'.tr(),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: _openLocationPicker,
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
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
                      child: Row(
                        children: [
                          Icon(
                            Icons.location_on,
                            color: _locationVerified
                                ? Colors.green
                                : Colors.grey,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _locationController.text.isEmpty
                                  ? '点击在地图上选择委托执行地点'
                                  : _locationController.text,
                              style: TextStyle(
                                color: _locationController.text.isEmpty
                                    ? Colors.grey
                                    : Colors.black,
                                fontWeight: _locationController.text.isEmpty
                                    ? FontWeight.normal
                                    : FontWeight.bold,
                              ),
                            ),
                          ),
                          const Icon(
                            Icons.chevron_right,
                            color: Colors.grey,
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (_locationVerified)
                    const Padding(
                      padding: EdgeInsets.only(top: 8.0, left: 4),
                      child: Text(
                        '✅ 坐标已锁定！',
                        style: TextStyle(
                          color: Colors.green,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  const SizedBox(height: 24),

                  _buildCounterCard(
                    title: 'task_people'.tr(),
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
                    title: 'task_time'.tr(),
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

                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _amountController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: InputDecoration(
                            labelText: '${'task_amount'.tr()} (RM)',
                            prefixIcon: const Icon(Icons.attach_money),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        height: 56,
                        child: OutlinedButton(
                          onPressed: _isPriceSuggesting ? null : _suggestPrice,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: _ThemeColors.primary,
                            side: const BorderSide(
                              color: _ThemeColors.primary,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: _isPriceSuggesting
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text('✨ AI 建议'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // ========================================
                  // 🔥 急单模式
                  // ========================================
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.black12),
                    ),
                    child: SwitchListTile(
                      title: const Text(
                        '🔥 急单模式',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('附加费 RM 5（系统将立即推送给附近接单人）'),
                          if (_isUrgent)
                            const Text(
                              '接单人额外可得 RM 2 急单奖励',
                              style: TextStyle(
                                color: Colors.green,
                                fontSize: 12,
                              ),
                            ),
                        ],
                      ),
                      value: _isUrgent,
                      activeThumbColor: Colors.red,
                      onChanged: (val) => setState(() => _isUrgent = val),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ========================================
                  // 💰 费用明细
                  // ========================================
                  Builder(
                    builder: (context) {
                      final double amount =
                          double.tryParse(_amountController.text.trim()) ??
                          0.0;
                      return Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.grey[50],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.black12),
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                const Text('悬赏金额'),
                                const Spacer(),
                                Text('RM ${amount.toStringAsFixed(2)}'),
                              ],
                            ),
                            if (_isUrgent) ...[
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  const Text('🔥 急单附加费'),
                                  const Spacer(),
                                  Text(
                                    'RM 5',
                                    style: TextStyle(color: Colors.red),
                                  ),
                                ],
                              ),
                              const Divider(),
                              Row(
                                children: [
                                  const Text(
                                    '总扣款',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const Spacer(),
                                  Text(
                                    'RM ${(amount + 5).toStringAsFixed(2)}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      );
                    },
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
                    child: Text(
                      'submit_task'.tr(),
                      style: const TextStyle(
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
