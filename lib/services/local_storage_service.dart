import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/mood_entry_model.dart';

class LocalStorageService {
  static const String _entriesKey = 'mood_entries';
  static const String _settingsKey = 'app_settings';
  
  static LocalStorageService? _instance;
  static LocalStorageService get instance => _instance ??= LocalStorageService._();
  LocalStorageService._();

  SharedPreferences? _prefs;
  List<MoodEntry>? _cachedEntries; // 메모리 캐시
  DateTime? _lastCacheUpdate;
  static const Duration _cacheValidDuration = Duration(minutes: 5);

  Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  // 캐시가 유효한지 확인
  bool _isCacheValid() {
    return _cachedEntries != null && 
           _lastCacheUpdate != null && 
           DateTime.now().difference(_lastCacheUpdate!) < _cacheValidDuration;
  }

  // 캐시 무효화
  void _invalidateCache() {
    _cachedEntries = null;
    _lastCacheUpdate = null;
  }

  // 일기 저장
  Future<bool> saveMoodEntry(MoodEntry entry) async {
    try {
      await init();
      
      final entries = await getAllMoodEntries();
      
      // 기존 항목 업데이트 또는 새 항목 추가
      final index = entries.indexWhere((e) => e.id == entry.id);
      if (index != -1) {
        entries[index] = entry;
      } else {
        entries.add(entry);
      }
      
      final result = await _saveAllEntries(entries);
      if (result) {
        _invalidateCache(); // 캐시 무효화
      }
      return result;
    } catch (e) {
      return false;
    }
  }

  // 일기 삭제
  Future<bool> deleteMoodEntry(String entryId) async {
    await init();
    final entries = await getAllMoodEntries();
    final originalLength = entries.length;
    entries.removeWhere((entry) => entry.id == entryId);
    
    if (entries.length != originalLength) {
      _invalidateCache(); // 캐시 무효화
      return await _saveAllEntries(entries);
    }
    return false;
  }

  // 모든 일기 가져오기 (캐시 적용)
  Future<List<MoodEntry>> getAllMoodEntries() async {
    try {
      await init();
      
      // 캐시가 유효하면 캐시된 데이터 반환
      if (_isCacheValid()) {
        return List.from(_cachedEntries!);
      }
      
      final jsonString = _prefs?.getString(_entriesKey);
      
      if (jsonString == null || jsonString.isEmpty) {
        _cachedEntries = [];
        _lastCacheUpdate = DateTime.now();
        return [];
      }
      
      final List<dynamic> jsonList = json.decode(jsonString);
      final entries = jsonList.map((json) => MoodEntry.fromJson(json)).toList();
      
      // 캐시 업데이트
      _cachedEntries = entries;
      _lastCacheUpdate = DateTime.now();
      
      return List.from(entries);
    } catch (e) {
      return [];
    }
  }

  // 특정 월의 일기 가져오기 (최적화)
  Future<List<MoodEntry>> getMoodEntriesByMonth(DateTime month) async {
    final allEntries = await getAllMoodEntries();
    return allEntries.where((entry) {
      return entry.date.year == month.year && entry.date.month == month.month;
    }).toList();
  }

  // 일기 검색 (최적화)
  Future<List<MoodEntry>> searchMoodEntries(String query) async {
    final allEntries = await getAllMoodEntries();
    final lowerQuery = query.toLowerCase();
    
    return allEntries.where((entry) {
      return (entry.title?.toLowerCase().contains(lowerQuery) ?? false) ||
             entry.content.toLowerCase().contains(lowerQuery);
    }).toList();
  }

  // 특정 감정의 일기 가져오기 (최적화)
  Future<List<MoodEntry>> getMoodEntriesByMood(MoodType mood) async {
    final allEntries = await getAllMoodEntries();
    return allEntries.where((entry) => entry.mood == mood).toList();
  }

  // 즐겨찾기 일기 가져오기 (최적화)
  Future<List<MoodEntry>> getFavoriteMoodEntries() async {
    final allEntries = await getAllMoodEntries();
    return allEntries.where((entry) => entry.isFavorite).toList();
  }

  // 모든 일기 저장 (최적화)
  Future<bool> _saveAllEntries(List<MoodEntry> entries) async {
    try {
      final jsonList = entries.map((entry) => entry.toJson()).toList();
      final jsonString = json.encode(jsonList);
      
      final result = await _prefs!.setString(_entriesKey, jsonString);
      
      // 저장 성공시 캐시 업데이트
      if (result) {
        _cachedEntries = List.from(entries);
        _lastCacheUpdate = DateTime.now();
      }
      
      return result;
    } catch (e) {
      return false;
    }
  }

  // 설정 저장
  Future<bool> saveSetting(String key, dynamic value) async {
    await init();
    try {
      final settings = await getSettings();
      settings[key] = value;
      final jsonString = json.encode(settings);
      return await _prefs!.setString(_settingsKey, jsonString);
    } catch (e) {
      return false;
    }
  }

  // 설정 가져오기
  Future<Map<String, dynamic>> getSettings() async {
    await init();
    final jsonString = _prefs?.getString(_settingsKey);
    if (jsonString == null) return {};
    
    try {
      return Map<String, dynamic>.from(json.decode(jsonString));
    } catch (e) {
      return {};
    }
  }

  // 특정 설정 가져오기
  Future<T?> getSetting<T>(String key, [T? defaultValue]) async {
    final settings = await getSettings();
    return settings[key] as T? ?? defaultValue;
  }

  // 모든 데이터 삭제
  Future<bool> clearAllData() async {
    try {
      await _prefs!.remove(_entriesKey);
      await _prefs!.remove(_settingsKey);
      _invalidateCache();
      print('모든 데이터가 삭제되었습니다');
      return true;
    } catch (e) {
      print('데이터 삭제 오류: $e');
      return false;
    }
  }

  // 데이터 내보내기 (JSON)
  Future<Map<String, dynamic>> exportData() async {
    final entries = await getAllMoodEntries();
    final settings = await getSettings();
    
    return {
      'version': '1.0.0',
      'exportDate': DateTime.now().toIso8601String(),
      'entries': entries.map((e) => e.toJson()).toList(),
      'settings': settings,
    };
  }

  // 데이터 가져오기 (JSON)
  Future<bool> importData(Map<String, dynamic> data) async {
    try {
      if (data['entries'] != null) {
        final List<dynamic> entriesJson = data['entries'];
        final entries = entriesJson.map((json) => MoodEntry.fromJson(json)).toList();
        await _saveAllEntries(entries);
      }
      
      if (data['settings'] != null) {
        final settings = Map<String, dynamic>.from(data['settings']);
        final jsonString = json.encode(settings);
        await _prefs!.setString(_settingsKey, jsonString);
      }
      
      _invalidateCache();
      return true;
    } catch (e) {
      return false;
    }
  }

  // 통계 관련 메소드들
  
  // 특정 월의 감정 통계 가져오기
  Future<Map<MoodType, int>> getMoodStatistics(DateTime month) async {
    final monthEntries = await getMoodEntriesByMonth(month);
    final moodCounts = <MoodType, int>{};
    
    // 모든 감정 타입 초기화
    for (final mood in MoodType.values) {
      moodCounts[mood] = 0;
    }
    
    // 실제 데이터 카운트
    for (final entry in monthEntries) {
      moodCounts[entry.mood] = (moodCounts[entry.mood] ?? 0) + 1;
    }
    
    return moodCounts;
  }

  // 현재 연속 기록 계산
  Future<int> getCurrentStreak() async {
    final allEntries = await getAllMoodEntries();
    if (allEntries.isEmpty) return 0;
    
    // 날짜별로 정렬
    allEntries.sort((a, b) => b.date.compareTo(a.date));
    
    int streak = 0;
    DateTime currentDate = DateTime.now();
    
    // 오늘부터 역순으로 확인
    for (int i = 0; i < 365; i++) { // 최대 1년까지만 확인
      final checkDate = currentDate.subtract(Duration(days: i));
      final hasEntry = allEntries.any((entry) => 
        entry.date.year == checkDate.year &&
        entry.date.month == checkDate.month &&
        entry.date.day == checkDate.day
      );
      
      if (hasEntry) {
        streak++;
      } else if (i == 0) {
        // 오늘 기록이 없으면 어제부터 확인
        continue;
      } else {
        // 연속 기록이 끊어짐
        break;
      }
    }
    
    return streak;
  }

  // 최장 연속 기록 계산
  Future<int> getLongestStreak() async {
    final allEntries = await getAllMoodEntries();
    if (allEntries.isEmpty) return 0;
    
    // 날짜별로 정렬
    allEntries.sort((a, b) => a.date.compareTo(b.date));
    
    // 날짜별로 그룹화
    final Set<String> entryDates = {};
    for (final entry in allEntries) {
      final dateKey = '${entry.date.year}-${entry.date.month.toString().padLeft(2, '0')}-${entry.date.day.toString().padLeft(2, '0')}';
      entryDates.add(dateKey);
    }
    
    if (entryDates.isEmpty) return 0;
    
    final sortedDates = entryDates.toList()..sort();
    
    int maxStreak = 1;
    int currentStreak = 1;
    
    for (int i = 1; i < sortedDates.length; i++) {
      final prevDate = DateTime.parse(sortedDates[i - 1]);
      final currentDate = DateTime.parse(sortedDates[i]);
      
      // 연속된 날짜인지 확인
      final difference = currentDate.difference(prevDate).inDays;
      
      if (difference == 1) {
        currentStreak++;
        maxStreak = maxStreak > currentStreak ? maxStreak : currentStreak;
      } else {
        currentStreak = 1;
      }
    }
    
    return maxStreak;
  }

  // 활동별 감정 분석
  Future<Map<String, List<MoodType>>> getActivityMoodAnalysis(DateTime month) async {
    final monthEntries = await getMoodEntriesByMonth(month);
    final activityMoodMap = <String, List<MoodType>>{};
    
    for (final entry in monthEntries) {
      for (final activityId in entry.activities) {
        activityMoodMap.putIfAbsent(activityId, () => []).add(entry.mood);
      }
    }
    
    return activityMoodMap;
  }

  // 월별 일기 작성 수 통계
  Future<Map<String, int>> getMonthlyEntryCount(int year) async {
    final allEntries = await getAllMoodEntries();
    final monthlyCount = <String, int>{};
    
    // 12개월 초기화
    for (int month = 1; month <= 12; month++) {
      final monthKey = '$year-${month.toString().padLeft(2, '0')}';
      monthlyCount[monthKey] = 0;
    }
    
    // 실제 데이터 카운트
    for (final entry in allEntries) {
      if (entry.date.year == year) {
        final monthKey = '${entry.date.year}-${entry.date.month.toString().padLeft(2, '0')}';
        monthlyCount[monthKey] = (monthlyCount[monthKey] ?? 0) + 1;
      }
    }
    
    return monthlyCount;
  }

  // 감정 점수 계산 (1-5점)
  int getMoodScore(MoodType mood) {
    switch (mood) {
      case MoodType.worst:
        return 1;
      case MoodType.bad:
        return 2;
      case MoodType.neutral:
        return 3;
      case MoodType.good:
        return 4;
      case MoodType.best:
        return 5;
    }
  }

  // 월별 평균 감정 점수
  Future<double> getAverageMoodScore(DateTime month) async {
    final monthEntries = await getMoodEntriesByMonth(month);
    if (monthEntries.isEmpty) return 0.0;
    
    final totalScore = monthEntries.map((entry) => getMoodScore(entry.mood)).reduce((a, b) => a + b);
    return totalScore / monthEntries.length;
  }

  // 데이터 내보내기용 통계
  Future<Map<String, dynamic>> getExportStatistics() async {
    final allEntries = await getAllMoodEntries();
    final currentMonth = DateTime.now();
    
    return {
      'total_entries': allEntries.length,
      'current_streak': await getCurrentStreak(),
      'longest_streak': await getLongestStreak(),
      'current_month_entries': (await getMoodEntriesByMonth(currentMonth)).length,
      'favorite_entries': (await getFavoriteMoodEntries()).length,
      'mood_distribution': await getMoodStatistics(currentMonth),
      'average_mood_score': await getAverageMoodScore(currentMonth),
      'generated_at': DateTime.now().toIso8601String(),
    };
  }
} 