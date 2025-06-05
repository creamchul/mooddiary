import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppThemeMode {
  system,
  light,
  dark,
}

class ThemeService extends ChangeNotifier {
  static ThemeService? _instance;
  static ThemeService get instance => _instance ??= ThemeService._();
  ThemeService._();

  AppThemeMode _themeMode = AppThemeMode.system;
  SharedPreferences? _prefs;

  AppThemeMode get themeMode => _themeMode;

  ThemeMode get flutterThemeMode {
    switch (_themeMode) {
      case AppThemeMode.system:
        return ThemeMode.system;
      case AppThemeMode.light:
        return ThemeMode.light;
      case AppThemeMode.dark:
        return ThemeMode.dark;
    }
  }

  String get themeModeText {
    switch (_themeMode) {
      case AppThemeMode.system:
        return '시스템 설정';
      case AppThemeMode.light:
        return '라이트 모드';
      case AppThemeMode.dark:
        return '다크 모드';
    }
  }

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    await _loadThemeMode();
  }

  Future<void> _loadThemeMode() async {
    try {
      final themeModeIndex = _prefs?.getInt('theme_mode') ?? 0;
      _themeMode = AppThemeMode.values[themeModeIndex];
      notifyListeners();
    } catch (e) {
      print('테마 설정 로드 오류: $e');
      _themeMode = AppThemeMode.system;
    }
  }

  Future<void> setThemeMode(AppThemeMode mode) async {
    try {
      _themeMode = mode;
      await _prefs?.setInt('theme_mode', mode.index);
      notifyListeners();
      print('테마 모드 변경: ${mode.name}');
    } catch (e) {
      print('테마 설정 저장 오류: $e');
    }
  }

  // 현재 밝기 상태 반환 (시스템 모드일 때 사용)
  bool isDarkMode(BuildContext context) {
    switch (_themeMode) {
      case AppThemeMode.system:
        return Theme.of(context).brightness == Brightness.dark;
      case AppThemeMode.light:
        return false;
      case AppThemeMode.dark:
        return true;
    }
  }
} 