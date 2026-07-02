// ==========================================
// 💀 AppSkeleton — 加载骨架屏组件
// 颜色/间距/圆角均取自 lib/theme/app_theme.dart 的设计系统 token
// ==========================================
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// 单个骨架占位块：带微光（shimmer）扫过动画的圆角矩形
class AppSkeleton extends StatefulWidget {
  const AppSkeleton({
    super.key,
    this.width = double.infinity,
    this.height = 16,
    this.borderRadius = AppRadius.sm,
  });

  final double width;
  final double height;
  final double borderRadius;

  @override
  State<AppSkeleton> createState() => _AppSkeletonState();
}

class _AppSkeletonState extends State<AppSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = isDark
        ? AppColors.surfaceVariantDark
        : AppColors.surfaceVariantLight;
    final highlightColor = isDark
        ? AppColors.borderDark
        : AppColors.borderLight;

    return ClipRRect(
      borderRadius: BorderRadius.circular(widget.borderRadius),
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return ShaderMask(
            blendMode: BlendMode.srcATop,
            shaderCallback: (bounds) {
              // 让高光沿水平方向来回扫过占位块
              final slide = _controller.value * 3 - 1.5;
              return LinearGradient(
                colors: [baseColor, highlightColor, baseColor],
                stops: const [0.35, 0.5, 0.65],
                begin: Alignment(-1 + slide, 0),
                end: Alignment(1 + slide, 0),
              ).createShader(bounds);
            },
            child: child,
          );
        },
        child: Container(
          width: widget.width,
          height: widget.height,
          color: baseColor,
        ),
      ),
    );
  }
}

/// 卡片形状的骨架块，用于模拟单张任务卡片的加载态
class _AppSkeletonCard extends StatelessWidget {
  const _AppSkeletonCard();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderColor = isDark ? AppColors.borderDark : AppColors.borderLight;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AppSkeleton(height: 18, width: 180),
          const SizedBox(height: AppSpacing.sm),
          const AppSkeleton(height: 14),
          const SizedBox(height: AppSpacing.xs),
          const AppSkeleton(height: 14, width: 220),
        ],
      ),
    );
  }
}

/// 纵向排列的骨架卡片列表，用于替代列表加载中的 CircularProgressIndicator
class AppSkeletonList extends StatelessWidget {
  const AppSkeletonList({super.key, this.itemCount = 5});

  final int itemCount;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(AppSpacing.md),
      itemCount: itemCount,
      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
      itemBuilder: (context, index) => const _AppSkeletonCard(),
    );
  }
}
