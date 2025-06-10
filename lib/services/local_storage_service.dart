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

  // ============ 성능 최적화된 통계 메서드들 ============

  // 월별 감정 통계 (캐시 활용)
  Future<Map<MoodType, int>> getMoodStatistics(DateTime month) async {
    final entries = await getMoodEntriesByMonth(month);
    final stats = <MoodType, int>{};
    
    // 모든 감정 타입 초기화
    for (final mood in MoodType.values) {
      stats[mood] = 0;
    }
    
    // 감정별 카운트
    for (final entry in entries) {
      stats[entry.mood] = (stats[entry.mood] ?? 0) + 1;
    }
    
    return stats;
  }

  // 현재 연속 기록 계산 (최적화)
  Future<int> getCurrentStreak() async {
    final allEntries = await getAllMoodEntries();
    if (allEntries.isEmpty) return 0;
    
    // 날짜별로 그룹화 (중복 날짜 제거)
    final entryDates = <DateTime>{};
    for (final entry in allEntries) {
      final date = DateTime(entry.date.year, entry.date.month, entry.date.day);
      entryDates.add(date);
    }
    
    final sortedDates = entryDates.toList()..sort((a, b) => b.compareTo(a));
    
    final today = DateTime.now();
    final todayNormalized = DateTime(today.year, today.month, today.day);
    
    int streak = 0;
    DateTime checkDate = todayNormalized;
    
    for (int i = 0; i < 365; i++) { // 최대 1년까지
      if (sortedDates.contains(checkDate)) {
        streak++;
        checkDate = checkDate.subtract(const Duration(days: 1));
      } else {
        break;
      }
    }
    
    return streak;
  }

  // 최장 연속 기록 계산 (최적화)
  Future<int> getLongestStreak() async {
    final allEntries = await getAllMoodEntries();
    if (allEntries.isEmpty) return 0;
    
    // 날짜별로 그룹화 (중복 날짜 제거)
    final entryDates = <DateTime>{};
    for (final entry in allEntries) {
      final date = DateTime(entry.date.year, entry.date.month, entry.date.day);
      entryDates.add(date);
    }
    
    final sortedDates = entryDates.toList()..sort();
    
    int longestStreak = 0;
    int currentStreak = 1;
    
    for (int i = 1; i < sortedDates.length; i++) {
      final diff = sortedDates[i].difference(sortedDates[i - 1]).inDays;
      
      if (diff == 1) {
        currentStreak++;
      } else {
        longestStreak = longestStreak > currentStreak ? longestStreak : currentStreak;
        currentStreak = 1;
      }
    }
    
    return longestStreak > currentStreak ? longestStreak : currentStreak;
  }

  // 주간 감정 트렌드 (최적화)
  Future<List<Map<String, dynamic>>> getWeeklyTrend() async {
    final now = DateTime.now();
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    
    final entries = await getAllMoodEntries();
    final weeklyData = <Map<String, dynamic>>[];
    
    for (int i = 0; i < 7; i++) {
      final date = weekStart.add(Duration(days: i));
      final dateNormalized = DateTime(date.year, date.month, date.day);
      
      final dayEntries = entries.where((entry) {
        final entryDate = DateTime(entry.date.year, entry.date.month, entry.date.day);
        return entryDate.isAtSameMomentAs(dateNormalized);
      }).toList();
      
      // 평균 감정 계산
      double avgMood = 0;
      if (dayEntries.isNotEmpty) {
        final total = dayEntries.fold<int>(0, (sum, entry) => sum + entry.mood.index);
        avgMood = total / dayEntries.length;
      }
      
      weeklyData.add({
        'date': dateNormalized,
        'avgMood': avgMood,
        'entryCount': dayEntries.length,
      });
    }
    
    return weeklyData;
  }

  // 활동별 감정 분석 (최적화)
  Future<Map<String, Map<MoodType, int>>> getActivityMoodAnalysis() async {
    final entries = await getAllMoodEntries();
    final analysis = <String, Map<MoodType, int>>{};
    
    for (final entry in entries) {
      for (final activityId in entry.activities) {
        analysis.putIfAbsent(activityId, () => <MoodType, int>{});
        analysis[activityId]!.putIfAbsent(entry.mood, () => 0);
        analysis[activityId]![entry.mood] = analysis[activityId]![entry.mood]! + 1;
      }
    }
    
    return analysis;
  }

  // 성능 최적화: 캐시 크기 제한
  void limitCacheSize() {
    if (_cachedEntries != null && _cachedEntries!.length > 1000) {
      // 최신 500개만 유지
      _cachedEntries!.sort((a, b) => b.date.compareTo(a.date));
      _cachedEntries = _cachedEntries!.take(500).toList();
      
      // 비동기로 저장 (성능 영향 최소화)
      Future.microtask(() => _saveAllEntries(_cachedEntries!));
    }
  }

  // 성능 최적화: 캐시 통계
  Map<String, dynamic> getCacheStats() {
    return {
      'cacheSize': _cachedEntries?.length ?? 0,
      'isValid': _isCacheValid(),
      'lastUpdate': _lastCacheUpdate?.toIso8601String(),
      'validDuration': _cacheValidDuration.inMinutes,
    };
  }

  // 성능 최적화: 강제 캐시 새로고침
  Future<void> refreshCache() async {
    _invalidateCache();
    await getAllMoodEntries(); // 캐시 다시 로드
  }

  // 성능 최적화: 배치 저장 (여러 일기 한번에 저장)
  Future<bool> saveMoodEntriesBatch(List<MoodEntry> entries) async {
    try {
      await init();
      
      final existingEntries = await getAllMoodEntries();
      final updatedEntries = List<MoodEntry>.from(existingEntries);
      
      // 배치로 업데이트
      for (final newEntry in entries) {
        final index = updatedEntries.indexWhere((e) => e.id == newEntry.id);
        if (index != -1) {
          updatedEntries[index] = newEntry;
        } else {
          updatedEntries.add(newEntry);
        }
      }
      
      final result = await _saveAllEntries(updatedEntries);
      if (result) {
        _invalidateCache();
      }
      return result;
    } catch (e) {
      return false;
    }
  }

  // 성능 최적화: 메모리 사용량 추정
  int getEstimatedMemoryUsage() {
    if (_cachedEntries == null) return 0;
    
    int totalSize = 0;
    for (final entry in _cachedEntries!) {
      // 대략적인 크기 계산 (문자열 길이 + 기본 객체 크기)
      totalSize += (entry.content.length * 2); // UTF-16
      totalSize += (entry.title?.length ?? 0) * 2;
      totalSize += entry.activities.length * 20; // 활동당 평균 20바이트
      totalSize += entry.imageUrls.length * 50; // 이미지 경로당 평균 50바이트
      totalSize += 100; // 기본 객체 오버헤드
    }
    
    return totalSize;
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

  // 페이지네이션된 일기 가져오기 (성능 최적화)
  Future<List<MoodEntry>> getMoodEntriesPaginated({
    int page = 0,
    int pageSize = 20,
    MoodType? filterMood,
    String? searchQuery,
    bool? favoritesOnly,
  }) async {
    final allEntries = await getAllMoodEntries();
    
    // 필터링 적용
    List<MoodEntry> filteredEntries = allEntries;
    
    if (filterMood != null) {
      filteredEntries = filteredEntries.where((entry) => entry.mood == filterMood).toList();
    }
    
    if (searchQuery != null && searchQuery.isNotEmpty) {
      final lowerQuery = searchQuery.toLowerCase();
      filteredEntries = filteredEntries.where((entry) {
        return (entry.title?.toLowerCase().contains(lowerQuery) ?? false) ||
               entry.content.toLowerCase().contains(lowerQuery);
      }).toList();
    }
    
    if (favoritesOnly == true) {
      filteredEntries = filteredEntries.where((entry) => entry.isFavorite).toList();
    }
    
    // 날짜순 정렬 (최신순)
    filteredEntries.sort((a, b) => b.date.compareTo(a.date));
    
    // 페이지네이션 적용
    final startIndex = page * pageSize;
    final endIndex = (startIndex + pageSize).clamp(0, filteredEntries.length);
    
    if (startIndex >= filteredEntries.length) {
      return [];
    }
    
    return filteredEntries.sublist(startIndex, endIndex);
  }

  // 총 일기 개수 (필터 적용)
  Future<int> getMoodEntriesCount({
    MoodType? filterMood,
    String? searchQuery,
    bool? favoritesOnly,
  }) async {
    final allEntries = await getAllMoodEntries();
    
    List<MoodEntry> filteredEntries = allEntries;
    
    if (filterMood != null) {
      filteredEntries = filteredEntries.where((entry) => entry.mood == filterMood).toList();
    }
    
    if (searchQuery != null && searchQuery.isNotEmpty) {
      final lowerQuery = searchQuery.toLowerCase();
      filteredEntries = filteredEntries.where((entry) {
        return (entry.title?.toLowerCase().contains(lowerQuery) ?? false) ||
               entry.content.toLowerCase().contains(lowerQuery);
      }).toList();
    }
    
    if (favoritesOnly == true) {
      filteredEntries = filteredEntries.where((entry) => entry.isFavorite).toList();
    }
    
    return filteredEntries.length;
  }

  // 최근 일기 가져오기 (홈 화면용)
  Future<List<MoodEntry>> getRecentMoodEntries({int limit = 5}) async {
    final allEntries = await getAllMoodEntries();
    allEntries.sort((a, b) => b.date.compareTo(a.date));
    return allEntries.take(limit).toList();
  }

  // Public 메서드들 (PerformanceService용)
  bool isCacheValid() => _isCacheValid();
} 