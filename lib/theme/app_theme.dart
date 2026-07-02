// ==========================================
// 🎨 XOLV 全局设计系统（Design System）
// 唯一颜色 / 间距 / 圆角 / 阴影 / 字体来源
// ==========================================
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ------------------------------------------
// 🎨 AppColors — 品牌色 / 语义色 / 中性色阶
// ------------------------------------------
class AppColors {
  AppColors._();

  // 品牌主色（闪电橙）
  static const Color primaryLight = Color(0xFFFF5E00);
  // 暗色模式下提亮/降饱和，避免在深色背景上过于刺眼，同时维持对比度
  static const Color primaryDark = Color(0xFFFF8A4C);

  static const Color onPrimaryLight = Color(0xFFFFFFFF);
  static const Color onPrimaryDark = Color(0xFF1A1A1A);

  // 语义色 — Light
  static const Color successLight = Color(0xFF15803D);
  static const Color warningLight = Color(0xFFB45309);
  static const Color errorLight = Color(0xFFB91C1C);
  static const Color infoLight = Color(0xFF2563EB);

  // 语义色 — Dark（提亮版，保证在深色背景上的可读性）
  static const Color successDark = Color(0xFF4ADE80);
  static const Color warningDark = Color(0xFFFBBF24);
  static const Color errorDark = Color(0xFFF87171);
  static const Color infoDark = Color(0xFF60A5FA);

  // 中性色阶 — Light
  static const Color backgroundLight = Color(0xFFFFFFFF);
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color surfaceVariantLight = Color(0xFFF5F5F7);
  static const Color borderLight = Color(0xFFE5E7EB);
  static const Color textPrimaryLight = Color(0xFF1A1A1A);
  static const Color textSecondaryLight = Color(0xFF6B7280);
  static const Color textTertiaryLight = Color(0xFF9CA3AF);

  // 中性色阶 — Dark（深灰分层，而非纯黑）
  static const Color backgroundDark = Color(0xFF121212);
  static const Color surfaceDark = Color(0xFF1E1E1E);
  static const Color surfaceVariantDark = Color(0xFF2A2A2A);
  static const Color borderDark = Color(0xFF3A3A3A);
  static const Color textPrimaryDark = Color(0xFFF5F5F5);
  static const Color textSecondaryDark = Color(0xFFB0B0B0);
  static const Color textTertiaryDark = Color(0xFF7A7A7A);
}

// ------------------------------------------
// 📐 AppSpacing — 全局间距刻度（唯一允许使用的间距值）
// ------------------------------------------
class AppSpacing {
  AppSpacing._();

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
}

// ------------------------------------------
// ⭕ AppRadius — 全局圆角刻度
// ------------------------------------------
class AppRadius {
  AppRadius._();

  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double full = 999;
}

// ------------------------------------------
// 🌑 AppShadows — 阴影层级（卡片 / 悬浮 / 模态）
// 暗色模式下阴影不可见于纯黑背景，因此改用更低透明度以保留层次感
// ------------------------------------------
class AppShadows {
  AppShadows._();

  static List<BoxShadow> card(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    return [
      BoxShadow(
        color: Colors.black.withValues(alpha: isDark ? 0.24 : 0.06),
        offset: const Offset(0, 2),
        blurRadius: 8,
      ),
    ];
  }

  static List<BoxShadow> elevated(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    return [
      BoxShadow(
        color: Colors.black.withValues(alpha: isDark ? 0.32 : 0.10),
        offset: const Offset(0, 4),
        blurRadius: 16,
      ),
    ];
  }

  static List<BoxShadow> modal(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    return [
      BoxShadow(
        color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.16),
        offset: const Offset(0, 8),
        blurRadius: 32,
      ),
    ];
  }
}

// ------------------------------------------
// 🔤 AppTextStyles — 文字层级
// 主标题沿用现有的 Montserrat ExtraBold，正文使用系统默认字体保证可读性与性能
// ------------------------------------------
class AppTextStyles {
  AppTextStyles._();

  // 大标题（页面级） — Montserrat ExtraBold
  static TextStyle h1(Color color) => GoogleFonts.montserrat(
    fontSize: 28,
    fontWeight: FontWeight.w900,
    letterSpacing: -0.5,
    color: color,
  );

  // 区块标题 — Montserrat ExtraBold
  static TextStyle h2(Color color) => GoogleFonts.montserrat(
    fontSize: 22,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.3,
    color: color,
  );

  // 卡片/组件标题 — Montserrat SemiBold
  static TextStyle h3(Color color) => GoogleFonts.montserrat(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: color,
  );

  static TextStyle bodyLarge(Color color) => TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    height: 1.4,
    color: color,
  );

  static TextStyle body(Color color) => TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1.4,
    color: color,
  );

  static TextStyle caption(Color color) => TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    height: 1.3,
    color: color,
  );

  static TextStyle button(Color color) => TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.2,
    color: color,
  );
}

// ------------------------------------------
// 🏗️ AppTheme — 组装 ColorScheme / TextTheme / 组件默认样式
// ------------------------------------------
class AppTheme {
  AppTheme._();

  static ThemeData get lightTheme => _build(Brightness.light);
  static ThemeData get darkTheme => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;

    final primary = isDark ? AppColors.primaryDark : AppColors.primaryLight;
    final onPrimary = isDark
        ? AppColors.onPrimaryDark
        : AppColors.onPrimaryLight;
    final background = isDark
        ? AppColors.backgroundDark
        : AppColors.backgroundLight;
    final surface = isDark ? AppColors.surfaceDark : AppColors.surfaceLight;
    final surfaceVariant = isDark
        ? AppColors.surfaceVariantDark
        : AppColors.surfaceVariantLight;
    final border = isDark ? AppColors.borderDark : AppColors.borderLight;
    final textPrimary = isDark
        ? AppColors.textPrimaryDark
        : AppColors.textPrimaryLight;
    final textSecondary = isDark
        ? AppColors.textSecondaryDark
        : AppColors.textSecondaryLight;
    final error = isDark ? AppColors.errorDark : AppColors.errorLight;

    final colorScheme = ColorScheme(
      brightness: brightness,
      primary: primary,
      onPrimary: onPrimary,
      secondary: primary,
      onSecondary: onPrimary,
      error: error,
      onError: isDark ? const Color(0xFF1A1A1A) : Colors.white,
      surface: surface,
      onSurface: textPrimary,
      surfaceContainerHighest: surfaceVariant,
      onSurfaceVariant: textSecondary,
      outline: border,
      outlineVariant: border,
    );

    final textTheme = TextTheme(
      headlineLarge: AppTextStyles.h1(textPrimary),
      headlineMedium: AppTextStyles.h2(textPrimary),
      headlineSmall: AppTextStyles.h3(textPrimary),
      titleLarge: AppTextStyles.h2(textPrimary),
      titleMedium: AppTextStyles.h3(textPrimary),
      bodyLarge: AppTextStyles.bodyLarge(textPrimary),
      bodyMedium: AppTextStyles.body(textPrimary),
      bodySmall: AppTextStyles.caption(textSecondary),
      labelLarge: AppTextStyles.button(onPrimary),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: background,
      textTheme: textTheme,
      dividerColor: border,
      appBarTheme: AppBarTheme(
        backgroundColor: surface,
        foregroundColor: textPrimary,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: AppTextStyles.h3(textPrimary),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          side: BorderSide(color: border, width: 1),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: onPrimary,
          disabledBackgroundColor: surfaceVariant,
          elevation: 0,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          textStyle: AppTextStyles.button(onPrimary),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primary,
          side: BorderSide(color: border),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          textStyle: AppTextStyles.button(primary),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primary,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          textStyle: AppTextStyles.button(primary),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceVariant,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.md,
        ),
        hintStyle: AppTextStyles.body(textSecondary),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: error, width: 1.5),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        titleTextStyle: AppTextStyles.h3(textPrimary),
        contentTextStyle: AppTextStyles.body(textSecondary),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadius.lg),
          ),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: textPrimary,
        contentTextStyle: AppTextStyles.body(background),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        behavior: SnackBarBehavior.floating,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: surfaceVariant,
        labelStyle: AppTextStyles.caption(textPrimary),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.full),
          side: BorderSide.none,
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: surface,
        selectedItemColor: primary,
        unselectedItemColor: textSecondary,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: primary,
        foregroundColor: onPrimary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.macOS: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.windows: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.linux: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.fuchsia: FadeUpwardsPageTransitionsBuilder(),
        },
      ),
    );
  }
}
