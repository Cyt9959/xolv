import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class KYCPage extends StatefulWidget {
  const KYCPage({super.key});

  @override
  State<KYCPage> createState() => _KYCPageState();
}

class _KYCPageState extends State<KYCPage> {
  File? _icFront;
  File? _icBack;
  File? _selfie; // 👈 核心新增：自拍照
  bool _isLoading = false;

  final ImagePicker _picker = ImagePicker();
  final primaryColor = const Color(0xFFFF5E00); // XOLV 闪电橙

  // 📸 通用拍照/选图功能
  Future<void> _pickImage(int type) async {
    // 弹窗让用户选择：拍照 还是 从相册选
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('使用相机拍照'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('从相册选择'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );

    if (source == null) return;

    // 💡 针对自拍，默认使用前置摄像头 (如果支持的话)
    final XFile? image = await _picker.pickImage(
      source: source,
      imageQuality: 70, // 压缩一下，省流量和云端存储费
      preferredCameraDevice: type == 3 ? CameraDevice.front : CameraDevice.rear,
    );

    if (image != null) {
      setState(() {
        if (type == 1) {
          _icFront = File(image.path);
        } else if (type == 2) {
          _icBack = File(image.path);
        } else if (type == 3) {
          _selfie = File(image.path);
        }
      });
    }
  }

  // 🚀 金融级三重上传引擎
  Future<void> _submitKYC() async {
    if (_icFront == null || _icBack == null || _selfie == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('老板，请完成所有 3 张照片的拍摄！'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw '用户未登录';

      final String uid = user.uid;

      // 1. 准备金库 (Storage) 的存放路径
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('kyc_uploads')
          .child(uid);

      // 2. 依次上传 3 张照片
      final frontTask = await storageRef
          .child('ic_front.jpg')
          .putFile(_icFront!);
      final backTask = await storageRef.child('ic_back.jpg').putFile(_icBack!);
      final selfieTask = await storageRef.child('selfie.jpg').putFile(_selfie!);

      // 3. 拿到 3 张照片的取件码 (URL)
      final frontUrl = await frontTask.ref.getDownloadURL();
      final backUrl = await backTask.ref.getDownloadURL();
      final selfieUrl = await selfieTask.ref.getDownloadURL();

      // 4. 开启总账本原子锁：同时更新两张表
      final batch = FirebaseFirestore.instance.batch();
      final kycRef = FirebaseFirestore.instance
          .collection('kyc_applications')
          .doc(uid);
      final userRef = FirebaseFirestore.instance.collection('users').doc(uid);

      batch.set(kycRef, {
        'userId': uid,
        'icFrontUrl': frontUrl,
        'icBackUrl': backUrl,
        'selfieUrl': selfieUrl, // 👈 存入自拍照链接
        'status': 'pending',
        'submittedAt': FieldValue.serverTimestamp(),
      });

      batch.update(userRef, {'kyc_status': 'pending'});

      await batch.commit();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🎉 资料上传成功！请等待系统审核。'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context); // 传完自动退回个人中心
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('上传失败: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          '实名认证 (KYC)',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black),
        ),
        backgroundColor: Colors.white,
        elevation: 0.5,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: primaryColor),
                  const SizedBox(height: 16),
                  const Text(
                    '正在加密上传至云端金库...',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.security, color: Colors.blue),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            '为保障平台交易安全，我们需要核实您的真实身份。您的资料将受到最高级别加密保护。',
                            style: TextStyle(fontSize: 13, color: Colors.blue),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 30),

                  // 📸 步骤 1：身份证正面
                  _buildPhotoCard(
                    title: '1. 拍摄身份证 (正 面)',
                    subtitle: '请确保姓名、身份证号清晰可见，无反光',
                    imageFile: _icFront,
                    icon: Icons.badge_outlined,
                    onTap: () => _pickImage(1),
                  ),
                  const SizedBox(height: 20),

                  // 📸 步骤 2：身份证反面
                  _buildPhotoCard(
                    title: '2. 拍摄身份证 (反 面)',
                    subtitle: '请确保背面所有信息清晰可见',
                    imageFile: _icBack,
                    icon: Icons.credit_card_outlined,
                    onTap: () => _pickImage(2),
                  ),
                  const SizedBox(height: 20),

                  // 📸 步骤 3：实时自拍
                  _buildPhotoCard(
                    title: '3. 本人实时自拍',
                    subtitle: '请正对屏幕，摘下墨镜/口罩，确保光线充足',
                    imageFile: _selfie,
                    icon: Icons.face_retouching_natural,
                    onTap: () => _pickImage(3),
                  ),

                  const SizedBox(height: 40),
                  ElevatedButton(
                    onPressed: _submitKYC,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      '确认提交审核',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
    );
  }

  // 通用的相框组件
  Widget _buildPhotoCard({
    required String title,
    required String subtitle,
    required File? imageFile,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: const TextStyle(color: Colors.grey, fontSize: 12),
        ),
        const SizedBox(height: 12),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            height: 180,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: imageFile != null ? primaryColor : Colors.grey[300]!,
                width: imageFile != null ? 2 : 1,
              ),
            ),
            child: imageFile != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Image.file(
                      imageFile,
                      fit: BoxFit.cover,
                      width: double.infinity,
                    ),
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(icon, size: 48, color: Colors.grey[400]),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: primaryColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '点击拍摄 / 上传',
                          style: TextStyle(
                            color: primaryColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }
}
