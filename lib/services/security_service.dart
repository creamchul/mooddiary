import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SecurityService {
  static final SecurityService _instance = SecurityService._internal();
  factory SecurityService() => _instance;
  SecurityService._internal();

  static SecurityService get instance => _instance;

  final LocalAuthentication _localAuth = LocalAuthentication();
  static const String _securityEnabledKey = 'security_enabled';
  static const String _pinCodeKey = 'pin_code';
  static const String _useBiometricKey = 'use_biometric';
  static const String _hideInBackgroundKey = 'hide_in_background';

  // 보안 설정 상태
  Future<bool> isSecurityEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_securityEnabledKey) ?? false;
  }

  Future<void> setSecurityEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_securityEnabledKey, enabled);
  }

  // PIN 코드 관리
  Future<String?> getPinCode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_pinCodeKey);
  }

  Future<void> setPinCode(String pinCode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_pinCodeKey, pinCode);
  }

  Future<bool> verifyPinCode(String inputPin) async {
    final savedPin = await getPinCode();
    return savedPin != null && savedPin == inputPin;
  }

  // 생체인증 설정
  Future<bool> isBiometricEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_useBiometricKey) ?? false;
  }

  Future<void> setBiometricEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_useBiometricKey, enabled);
  }

  // 백그라운드 숨기기 설정
  Future<bool> isHideInBackgroundEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_hideInBackgroundKey) ?? true;
  }

  Future<void> setHideInBackgroundEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_hideInBackgroundKey, enabled);
  }

  // 생체인증 가능 여부 확인
  Future<bool> isBiometricAvailable() async {
    try {
      final isAvailable = await _localAuth.canCheckBiometrics;
      final isDeviceSupported = await _localAuth.isDeviceSupported();
      return isAvailable && isDeviceSupported;
    } catch (e) {
      return false;
    }
  }

  // 사용 가능한 생체인증 방법들
  Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      return await _localAuth.getAvailableBiometrics();
    } catch (e) {
      return [];
    }
  }

  // 생체인증 실행
  Future<bool> authenticateWithBiometric() async {
    try {
      final isAvailable = await isBiometricAvailable();
      if (!isAvailable) return false;

      return await _localAuth.authenticate(
        localizedReason: '일기 앱에 접근하기 위해 생체인증을 진행해주세요',
        options: const AuthenticationOptions(
          biometricOnly: false,
          stickyAuth: true,
        ),
      );
    } catch (e) {
      return false;
    }
  }

  // PIN 인증 또는 생체인증
  Future<bool> authenticate() async {
    final isSecurityEnabled = await this.isSecurityEnabled();
    if (!isSecurityEnabled) return true;

    final isBiometricEnabled = await this.isBiometricEnabled();
    
    if (isBiometricEnabled) {
      final biometricResult = await authenticateWithBiometric();
      if (biometricResult) return true;
    }

    // 생체인증 실패 시 PIN으로 대체
    return false; // PIN 입력 화면으로 이동해야 함
  }

  // 보안 설정 초기화
  Future<void> clearSecuritySettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_securityEnabledKey);
    await prefs.remove(_pinCodeKey);
    await prefs.remove(_useBiometricKey);
    await prefs.remove(_hideInBackgroundKey);
  }

  // 앱 잠금 설정
  Future<void> setupAppLock({
    required String pinCode,
    bool useBiometric = false,
  }) async {
    await setPinCode(pinCode);
    await setBiometricEnabled(useBiometric);
    await setSecurityEnabled(true);
  }

  // 보안 설정 요약 정보
  Future<Map<String, dynamic>> getSecurityStatus() async {
    final isEnabled = await isSecurityEnabled();
    final hasPinCode = await getPinCode() != null;
    final isBiometricEnabled = await this.isBiometricEnabled();
    final isBiometricAvailable = await this.isBiometricAvailable();
    final isHideInBackground = await isHideInBackgroundEnabled();

    return {
      'isEnabled': isEnabled,
      'hasPinCode': hasPinCode,
      'isBiometricEnabled': isBiometricEnabled,
      'isBiometricAvailable': isBiometricAvailable,
      'isHideInBackground': isHideInBackground,
    };
  }
} 