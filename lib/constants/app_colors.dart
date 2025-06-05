import 'package:flutter/material.dart';

class AppColors {
  // 브랜드 핑크 컬러
  static const Color primary = Color(0xFFEC407A);
  static const Color primaryLight = Color(0xFFFFABD1);
  static const Color primaryDark = Color(0xFFB4004E);
  
  // 파스텔 핑크 서브 컬러들
  static const Color pastelPink1 = Color(0xFFFCE4EC);
  static const Color pastelPink2 = Color(0xFFF8BBD9);
  static const Color pastelPink3 = Color(0xFFF48FB1);
  
  // 액센트 컬러
  static const Color accent = Color(0xFFFF4081);
  static const Color accentDark = Color(0xFFE91E63);
  
  // 라이트 테마 컬러
  static const Color lightBackground = Color(0xFFFFFBFE);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurfaceVariant = Color(0xFFF7F2FA);
  static const Color lightOnSurface = Color(0xFF1D1B20);
  static const Color lightOnSurfaceVariant = Color(0xFF49454F);
  static const Color lightOutline = Color(0xFF79747E);
  static const Color lightOutlineVariant = Color(0xFFCAC4D0);
  
  // 다크 테마 컬러 (핑크 브랜드 유지)
  static const Color darkBackground = Color(0xFF10070B);
  static const Color darkSurface = Color(0xFF1D1B20);
  static const Color darkSurfaceVariant = Color(0xFF49454F);
  static const Color darkOnSurface = Color(0xFFE6E0E9);
  static const Color darkOnSurfaceVariant = Color(0xFFCAC4D0);
  static const Color darkOutline = Color(0xFF938F99);
  static const Color darkOutlineVariant = Color(0xFF49454F);
  
  // 감정별 컬러
  static const Color emotionBest = Color(0xFFFFD54F);      // 최고 - 노란색
  static const Color emotionGood = Color(0xFF81C784);      // 좋음 - 초록색
  static const Color emotionNeutral = Color(0xFF90A4AE);  // 그저그래 - 회색
  static const Color emotionBad = Color(0xFFFFB74D);      // 별로 - 주황색
  static const Color emotionWorst = Color(0xFFE57373);    // 최악 - 빨간색
  
  // 기능별 컬러
  static const Color success = Color(0xFF4CAF50);
  static const Color error = Color(0xFFE57373);
  static const Color warning = Color(0xFFFF9800);
  static const Color info = Color(0xFF2196F3);
  
  // 투명도 컬러
  static Color shimmerBase = Colors.grey[300]!;
  static Color shimmerHighlight = Colors.grey[100]!;
  static Color shimmerBaseDark = Colors.grey[700]!;
  static Color shimmerHighlightDark = Colors.grey[500]!;
  
  // 그라디언트
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primary, primaryLight],
  );
  
  static const LinearGradient cardGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFFFFBFE), Color(0xFFFCE4EC)],
  );
  
  static const LinearGradient darkCardGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF1D1B20), Color(0xFF2D1B2E)],
  );
}

class AppTheme {
  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    colorScheme: const ColorScheme.light(
      primary: AppColors.primary,
      onPrimary: Colors.white,
      secondary: AppColors.accent,
      onSecondary: Colors.white,
      background: AppColors.lightBackground,
      onBackground: AppColors.lightOnSurface,
      surface: AppColors.lightSurface,
      onSurface: AppColors.lightOnSurface,
      surfaceVariant: AppColors.lightSurfaceVariant,
      onSurfaceVariant: AppColors.lightOnSurfaceVariant,
      outline: AppColors.lightOutline,
      outlineVariant: AppColors.lightOutlineVariant,
      error: AppColors.error,
    ),
    scaffoldBackgroundColor: AppColors.lightBackground,
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.lightBackground,
      foregroundColor: AppColors.lightOnSurface,
      elevation: 0,
      centerTitle: true,
    ),
    cardTheme: const CardThemeData(
      color: AppColors.lightSurface,
      elevation: 2,
      shadowColor: AppColors.primary,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(16)),
      ),
    ),
  );
  
  static ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    colorScheme: const ColorScheme.dark(
      primary: AppColors.primary,
      onPrimary: Colors.white,
      secondary: AppColors.accent,
      onSecondary: Colors.white,
      background: AppColors.darkBackground,
      onBackground: AppColors.darkOnSurface,
      surface: AppColors.darkSurface,
      onSurface: AppColors.darkOnSurface,
      surfaceVariant: AppColors.darkSurfaceVariant,
      onSurfaceVariant: AppColors.darkOnSurfaceVariant,
      outline: AppColors.darkOutline,
      outlineVariant: AppColors.darkOutlineVariant,
      error: AppColors.error,
    ),
    scaffoldBackgroundColor: AppColors.darkBackground,
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.darkBackground,
      foregroundColor: AppColors.darkOnSurface,
      elevation: 0,
      centerTitle: true,
    ),
    cardTheme: const CardThemeData(
      color: AppColors.darkSurface,
      elevation: 2,
      shadowColor: AppColors.primary,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(16)),
      ),
    ),
  );
} 