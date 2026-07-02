// ==========================================
// 👆 AppTappable — 统一点击微交互反馈组件
// 用途：包裹任意可点击内容（卡片/按钮/图标等），按下时轻微缩放 + Material 涟漪，
//       替代裸用 GestureDetector 却没有任何视觉反馈的点击区域。
// 用法：AppTappable(onTap: () {...}, child: yourWidget)
// ==========================================
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class AppTappable extends StatefulWidget {
  const AppTappable({
    super.key,
    required this.child,
    required this.onTap,
    this.onLongPress,
    this.borderRadius = AppRadius.md,
  });

  final Widget child;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final double borderRadius;

  @override
  State<AppTappable> createState() => _AppTappableState();
}

class _AppTappableState extends State<AppTappable> {
  double _scale = 1.0;

  void _setScale(double value) => setState(() => _scale = value);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final rippleColor =
        (isDark ? AppColors.primaryDark : AppColors.primaryLight)
            .withValues(alpha: 0.12);
    final radius = BorderRadius.circular(widget.borderRadius);

    return AnimatedScale(
      scale: _scale,
      duration: const Duration(milliseconds: 100),
      curve: Curves.easeOut,
      child: Material(
        color: Colors.transparent,
        borderRadius: radius,
        child: InkWell(
          onTap: widget.onTap,
          onLongPress: widget.onLongPress,
          onTapDown: (_) => _setScale(0.97),
          onTapUp: (_) => _setScale(1.0),
          onTapCancel: () => _setScale(1.0),
          borderRadius: radius,
          splashColor: rippleColor,
          highlightColor: rippleColor,
          child: widget.child,
        ),
      ),
    );
  }
}
