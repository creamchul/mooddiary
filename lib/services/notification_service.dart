import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;

class NotificationService {
  static NotificationService? _instance;
  static NotificationService get instance => _instance ??= NotificationService._();
  NotificationService._();

  FlutterLocalNotificationsPlugin? _notifications;
  SharedPreferences? _prefs;
  
  static const String _notificationEnabledKey = 'notification_enabled';
  static const String _notificationTimeKey = 'notification_time';
  static const int _dailyNotificationId = 1;

  Future<void> init() async {
    if (kIsWeb) {
      // 웹에서는 알림 기능 제한
      print('웹 환경에서는 로컬 알림이 지원되지 않습니다');
      return;
    }

    // timezone 초기화
    tz.initializeTimeZones();

    _prefs = await SharedPreferences.getInstance();
    _notifications = FlutterLocalNotificationsPlugin();

    // Android 초기화 설정
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    
    // iOS 초기화 설정
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications!.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // 권한 요청
    await _requestPermissions();
  }

  // 권한 요청
  Future<void> _requestPermissions() async {
    if (kIsWeb) return;

    // Android 13+ 알림 권한
    final status = await Permission.notification.request();
    print('알림 권한 상태: $status');

    // iOS 권한
    await _notifications!
        .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
  }

  // 알림 탭 처리
  void _onNotificationTapped(NotificationResponse response) {
    print('알림이 탭되었습니다: ${response.payload}');
    // TODO: 알림 탭시 일기 작성 화면으로 이동
  }

  // 일일 알림 설정
  Future<bool> scheduleDailyNotification(TimeOfDay time) async {
    if (kIsWeb || _notifications == null) return false;

    try {
      await _notifications!.cancel(_dailyNotificationId);

      await _notifications!.zonedSchedule(
        _dailyNotificationId,
        '오늘 하루는 어땠나요?',
        '감정을 기록하고 소중한 순간을 간직해보세요 💝',
        _nextInstanceOfTime(time),
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'daily_mood_reminder',
            '일일 감정 기록 알림',
            channelDescription: '매일 정해진 시간에 감정 기록을 알려주는 알림',
            importance: Importance.high,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
          ),
          iOS: DarwinNotificationDetails(
            sound: 'default.wav',
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
      );

      // 설정 저장
      await _saveNotificationTime(time);
      await setNotificationEnabled(true);

      print('일일 알림이 ${time.hour}:${time.minute}에 설정되었습니다');
      return true;
    } catch (e) {
      print('알림 설정 오류: $e');
      return false;
    }
  }

  // 다음 알림 시간 계산 (TZDateTime 반환)
  tz.TZDateTime _nextInstanceOfTime(TimeOfDay time) {
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    tz.TZDateTime scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      time.hour,
      time.minute,
    );

    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    return scheduledDate;
  }

  // 일일 알림 취소
  Future<void> cancelDailyNotification() async {
    if (kIsWeb || _notifications == null) return;

    try {
      await _notifications!.cancel(_dailyNotificationId);
      await setNotificationEnabled(false);
      print('일일 알림이 취소되었습니다');
    } catch (e) {
      print('알림 취소 오류: $e');
    }
  }

  // 즉시 테스트 알림
  Future<void> showTestNotification() async {
    if (kIsWeb || _notifications == null) return;

    try {
      await _notifications!.show(
        999,
        '테스트 알림',
        '알림이 정상적으로 작동합니다! 🎉',
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'test_notification',
            '테스트 알림',
            channelDescription: '알림 기능 테스트',
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(),
        ),
      );
    } catch (e) {
      print('테스트 알림 오류: $e');
    }
  }

  // 연속 기록 축하 알림
  Future<void> showStreakNotification(int streak) async {
    if (kIsWeb || _notifications == null || !await isNotificationEnabled()) return;

    try {
      String title = '';
      String body = '';

      if (streak == 7) {
        title = '일주일 연속 기록! 🎉';
        body = '7일 연속으로 감정을 기록했어요. 정말 대단해요!';
      } else if (streak == 30) {
        title = '한 달 연속 기록! 🏆';
        body = '30일 연속 기록 달성! 꾸준함이 만든 기적이에요!';
      } else if (streak % 100 == 0) {
        title = '$streak일 연속 기록! 🌟';
        body = '놀라운 기록이에요! 당신의 노력이 빛나고 있어요!';
      } else if (streak % 10 == 0) {
        title = '$streak일 연속 기록! ✨';
        body = '꾸준한 기록이 쌓여가고 있어요. 계속 화이팅!';
      } else {
        return; // 특별한 날짜가 아니면 알림 없음
      }

      await _notifications!.show(
        streak + 1000, // 고유 ID
        title,
        body,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'streak_notification',
            '연속 기록 축하 알림',
            channelDescription: '연속 기록 달성시 축하 알림',
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(),
        ),
      );
    } catch (e) {
      print('연속 기록 알림 오류: $e');
    }
  }

  // 알림 활성화 상태 확인
  Future<bool> isNotificationEnabled() async {
    return _prefs?.getBool(_notificationEnabledKey) ?? false;
  }

  // 알림 활성화 설정
  Future<void> setNotificationEnabled(bool enabled) async {
    await _prefs?.setBool(_notificationEnabledKey, enabled);
  }

  // 저장된 알림 시간 가져오기
  Future<TimeOfDay> getNotificationTime() async {
    final timeString = _prefs?.getString(_notificationTimeKey);
    if (timeString != null) {
      final parts = timeString.split(':');
      return TimeOfDay(
        hour: int.parse(parts[0]),
        minute: int.parse(parts[1]),
      );
    }
    return const TimeOfDay(hour: 21, minute: 0); // 기본값: 오후 9시
  }

  // 알림 시간 저장
  Future<void> _saveNotificationTime(TimeOfDay time) async {
    final timeString = '${time.hour}:${time.minute}';
    await _prefs?.setString(_notificationTimeKey, timeString);
  }

  // 알림 상태 정보
  Future<Map<String, dynamic>> getNotificationStatus() async {
    final enabled = await isNotificationEnabled();
    final time = await getNotificationTime();
    
    return {
      'enabled': enabled,
      'time': time,
      'timeString': '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}',
      'supported': !kIsWeb,
    };
  }
} 