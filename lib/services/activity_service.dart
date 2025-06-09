import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/activity_model.dart';

class ActivityService {
  static ActivityService? _instance;
  static ActivityService get instance => _instance ??= ActivityService._();
  ActivityService._();

  static const String _customActivitiesKey = 'custom_activities';
  static const String _hiddenActivitiesKey = 'hidden_activities';

  List<Activity>? _cachedCustomActivities;
  Set<String>? _cachedHiddenActivities;
  DateTime? _cacheTime;
  static const Duration _cacheTimeout = Duration(minutes: 5);

  // 모든 활성 활동 가져오기 (기본 + 커스텀 - 숨김)
  Future<List<Activity>> getAllActiveActivities() async {
    final defaultActivities = DefaultActivities.defaultActivities;
    final customActivities = await getCustomActivities();
    final hiddenActivities = await getHiddenActivities();

    final allActivities = <Activity>[];
    
    // 기본 활동 중 숨겨지지 않은 것들 추가
    for (final activity in defaultActivities) {
      if (!hiddenActivities.contains(activity.id)) {
        allActivities.add(activity);
      }
    }
    
    // 커스텀 활동 중 활성화된 것들 추가
    for (final activity in customActivities) {
      if (activity.isActive) {
        allActivities.add(activity);
      }
    }

    return allActivities;
  }

  // 커스텀 활동 목록 가져오기
  Future<List<Activity>> getCustomActivities() async {
    if (_cachedCustomActivities != null && _cacheTime != null &&
        DateTime.now().difference(_cacheTime!).compareTo(_cacheTimeout) < 0) {
      return _cachedCustomActivities!;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_customActivitiesKey);
      
      if (jsonString != null) {
        final List<dynamic> jsonList = json.decode(jsonString);
        _cachedCustomActivities = jsonList.map((json) => Activity.fromJson(json)).toList();
      } else {
        _cachedCustomActivities = [];
      }
      
      _cacheTime = DateTime.now();
      return _cachedCustomActivities!;
    } catch (e) {
      print('Error loading custom activities: $e');
      return [];
    }
  }

  // 숨겨진 활동 ID 목록 가져오기
  Future<Set<String>> getHiddenActivities() async {
    if (_cachedHiddenActivities != null && _cacheTime != null &&
        DateTime.now().difference(_cacheTime!).compareTo(_cacheTimeout) < 0) {
      return _cachedHiddenActivities!;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final hiddenList = prefs.getStringList(_hiddenActivitiesKey) ?? [];
      _cachedHiddenActivities = hiddenList.toSet();
      return _cachedHiddenActivities!;
    } catch (e) {
      print('Error loading hidden activities: $e');
      return {};
    }
  }

  // 커스텀 활동 추가
  Future<bool> addCustomActivity(Activity activity) async {
    try {
      final customActivities = await getCustomActivities();
      
      // 중복 이름 확인
      if (customActivities.any((a) => a.name == activity.name)) {
        return false; // 중복 이름
      }
      
      customActivities.add(activity);
      await _saveCustomActivities(customActivities);
      _clearCache();
      return true;
    } catch (e) {
      print('Error adding custom activity: $e');
      return false;
    }
  }

  // 커스텀 활동 수정
  Future<bool> updateCustomActivity(Activity activity) async {
    try {
      final customActivities = await getCustomActivities();
      final index = customActivities.indexWhere((a) => a.id == activity.id);
      
      if (index == -1) return false;
      
      customActivities[index] = activity;
      await _saveCustomActivities(customActivities);
      _clearCache();
      return true;
    } catch (e) {
      print('Error updating custom activity: $e');
      return false;
    }
  }

  // 커스텀 활동 삭제
  Future<bool> deleteCustomActivity(String activityId) async {
    try {
      final customActivities = await getCustomActivities();
      customActivities.removeWhere((a) => a.id == activityId);
      await _saveCustomActivities(customActivities);
      _clearCache();
      return true;
    } catch (e) {
      print('Error deleting custom activity: $e');
      return false;
    }
  }

  // 기본 활동 숨기기/보이기
  Future<bool> toggleDefaultActivityVisibility(String activityId) async {
    try {
      final hiddenActivities = await getHiddenActivities();
      final prefs = await SharedPreferences.getInstance();
      
      if (hiddenActivities.contains(activityId)) {
        hiddenActivities.remove(activityId);
      } else {
        hiddenActivities.add(activityId);
      }
      
      await prefs.setStringList(_hiddenActivitiesKey, hiddenActivities.toList());
      _clearCache();
      return true;
    } catch (e) {
      print('Error toggling activity visibility: $e');
      return false;
    }
  }

  // 활동 사용 횟수 증가
  Future<void> incrementActivityUsage(String activityId) async {
    try {
      final customActivities = await getCustomActivities();
      final index = customActivities.indexWhere((a) => a.id == activityId);
      
      if (index != -1) {
        final updatedActivity = customActivities[index].copyWith(
          usageCount: customActivities[index].usageCount + 1,
          updatedAt: DateTime.now(),
        );
        customActivities[index] = updatedActivity;
        await _saveCustomActivities(customActivities);
        _clearCache();
      }
    } catch (e) {
      print('Error incrementing activity usage: $e');
    }
  }

  // 커스텀 활동 저장
  Future<void> _saveCustomActivities(List<Activity> activities) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = activities.map((a) => a.toJson()).toList();
    await prefs.setString(_customActivitiesKey, json.encode(jsonList));
  }

  // 캐시 클리어
  void _clearCache() {
    _cachedCustomActivities = null;
    _cachedHiddenActivities = null;
    _cacheTime = null;
  }

  // 모든 데이터 초기화 (설정에서 사용)
  Future<bool> clearAllData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_customActivitiesKey);
      await prefs.remove(_hiddenActivitiesKey);
      _clearCache();
      return true;
    } catch (e) {
      print('Error clearing activity data: $e');
      return false;
    }
  }

  // 활동 데이터 내보내기
  Future<Map<String, dynamic>> exportData() async {
    final customActivities = await getCustomActivities();
    final hiddenActivities = await getHiddenActivities();
    
    return {
      'customActivities': customActivities.map((a) => a.toJson()).toList(),
      'hiddenActivities': hiddenActivities.toList(),
      'exportDate': DateTime.now().toIso8601String(),
    };
  }

  // 활동 데이터 가져오기
  Future<bool> importData(Map<String, dynamic> data) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // 커스텀 활동 가져오기
      if (data['customActivities'] != null) {
        final customActivitiesList = data['customActivities'] as List;
        final activities = customActivitiesList.map((json) => Activity.fromJson(json)).toList();
        await _saveCustomActivities(activities);
      }
      
      // 숨겨진 활동 가져오기
      if (data['hiddenActivities'] != null) {
        final hiddenList = (data['hiddenActivities'] as List).cast<String>();
        await prefs.setStringList(_hiddenActivitiesKey, hiddenList);
      }
      
      _clearCache();
      return true;
    } catch (e) {
      print('Error importing activity data: $e');
      return false;
    }
  }
} 