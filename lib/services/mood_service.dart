import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../models/mood_entry_model.dart';
import '../services/firebase_service.dart';

class MoodService {
  static final MoodService _instance = MoodService._internal();
  factory MoodService() => _instance;
  MoodService._internal();

  final FirebaseService _firebaseService = FirebaseService();
  final Uuid _uuid = const Uuid();

  // 감정일기 생성
  Future<String?> createMoodEntry(MoodEntry entry) async {
    try {
      final userId = _firebaseService.currentUserId;
      if (userId == null) throw Exception('사용자가 로그인되지 않았습니다.');

      final id = _uuid.v4();
      final now = DateTime.now();
      
      final newEntry = entry.copyWith(
        id: id,
        userId: userId,
        createdAt: now,
        updatedAt: now,
      );

      final collection = _firebaseService.getUserMoodEntriesCollection(userId);
      await collection.doc(id).set(newEntry.toFirestore());

      return id;
    } catch (e) {
      print('감정일기 생성 오류: $e');
      return null;
    }
  }

  // 감정일기 수정
  Future<bool> updateMoodEntry(MoodEntry entry) async {
    try {
      final userId = _firebaseService.currentUserId;
      if (userId == null) throw Exception('사용자가 로그인되지 않았습니다.');

      final updatedEntry = entry.copyWith(
        updatedAt: DateTime.now(),
      );

      final collection = _firebaseService.getUserMoodEntriesCollection(userId);
      await collection.doc(entry.id).update(updatedEntry.toFirestore());

      return true;
    } catch (e) {
      print('감정일기 수정 오류: $e');
      return false;
    }
  }

  // 감정일기 삭제
  Future<bool> deleteMoodEntry(String entryId) async {
    try {
      final userId = _firebaseService.currentUserId;
      if (userId == null) throw Exception('사용자가 로그인되지 않았습니다.');

      final collection = _firebaseService.getUserMoodEntriesCollection(userId);
      await collection.doc(entryId).delete();

      return true;
    } catch (e) {
      print('감정일기 삭제 오류: $e');
      return false;
    }
  }

  // 특정 감정일기 조회
  Future<MoodEntry?> getMoodEntry(String entryId) async {
    try {
      final userId = _firebaseService.currentUserId;
      if (userId == null) throw Exception('사용자가 로그인되지 않았습니다.');

      final collection = _firebaseService.getUserMoodEntriesCollection(userId);
      final doc = await collection.doc(entryId).get();

      if (doc.exists) {
        return MoodEntry.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      print('감정일기 조회 오류: $e');
      return null;
    }
  }

  // 모든 감정일기 조회 (최신순)
  Stream<List<MoodEntry>> getMoodEntriesStream({
    int limit = 50,
    DateTime? startDate,
    DateTime? endDate,
  }) {
    final userId = _firebaseService.currentUserId;
    if (userId == null) return Stream.value([]);

    try {
      final collection = _firebaseService.getUserMoodEntriesCollection(userId);
      Query query = collection.orderBy('date', descending: true);

      // 날짜 범위 필터링
      if (startDate != null) {
        query = query.where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate));
      }
      if (endDate != null) {
        query = query.where('date', isLessThanOrEqualTo: Timestamp.fromDate(endDate));
      }

      query = query.limit(limit);

      return query.snapshots().map((snapshot) {
        return snapshot.docs.map((doc) => MoodEntry.fromFirestore(doc)).toList();
      });
    } catch (e) {
      print('감정일기 스트림 오류: $e');
      return Stream.value([]);
    }
  }

  // 즐겨찾기 감정일기만 조회
  Stream<List<MoodEntry>> getFavoriteMoodEntriesStream() {
    final userId = _firebaseService.currentUserId;
    if (userId == null) return Stream.value([]);

    try {
      final collection = _firebaseService.getUserMoodEntriesCollection(userId);
      return collection
          .where('isFavorite', isEqualTo: true)
          .orderBy('date', descending: true)
          .snapshots()
          .map((snapshot) {
        return snapshot.docs.map((doc) => MoodEntry.fromFirestore(doc)).toList();
      });
    } catch (e) {
      print('즐겨찾기 감정일기 스트림 오류: $e');
      return Stream.value([]);
    }
  }

  // 특정 날짜의 감정일기 조회
  Future<MoodEntry?> getMoodEntryByDate(DateTime date) async {
    try {
      final userId = _firebaseService.currentUserId;
      if (userId == null) throw Exception('사용자가 로그인되지 않았습니다.');

      final startOfDay = DateTime(date.year, date.month, date.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));

      final collection = _firebaseService.getUserMoodEntriesCollection(userId);
      final querySnapshot = await collection
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .where('date', isLessThan: Timestamp.fromDate(endOfDay))
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        return MoodEntry.fromFirestore(querySnapshot.docs.first);
      }
      return null;
    } catch (e) {
      print('날짜별 감정일기 조회 오류: $e');
      return null;
    }
  }

  // 감정별 감정일기 조회
  Stream<List<MoodEntry>> getMoodEntriesByMoodStream(MoodType moodType) {
    final userId = _firebaseService.currentUserId;
    if (userId == null) return Stream.value([]);

    try {
      final collection = _firebaseService.getUserMoodEntriesCollection(userId);
      return collection
          .where('mood', isEqualTo: moodType.index)
          .orderBy('date', descending: true)
          .snapshots()
          .map((snapshot) {
        return snapshot.docs.map((doc) => MoodEntry.fromFirestore(doc)).toList();
      });
    } catch (e) {
      print('감정별 감정일기 스트림 오류: $e');
      return Stream.value([]);
    }
  }

  // 활동별 감정일기 조회
  Stream<List<MoodEntry>> getMoodEntriesByActivityStream(String activityId) {
    final userId = _firebaseService.currentUserId;
    if (userId == null) return Stream.value([]);

    try {
      final collection = _firebaseService.getUserMoodEntriesCollection(userId);
      return collection
          .where('activities', arrayContains: activityId)
          .orderBy('date', descending: true)
          .snapshots()
          .map((snapshot) {
        return snapshot.docs.map((doc) => MoodEntry.fromFirestore(doc)).toList();
      });
    } catch (e) {
      print('활동별 감정일기 스트림 오류: $e');
      return Stream.value([]);
    }
  }

  // 즐겨찾기 토글
  Future<bool> toggleFavorite(String entryId, bool isFavorite) async {
    try {
      final userId = _firebaseService.currentUserId;
      if (userId == null) throw Exception('사용자가 로그인되지 않았습니다.');

      final collection = _firebaseService.getUserMoodEntriesCollection(userId);
      await collection.doc(entryId).update({
        'isFavorite': isFavorite,
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });

      return true;
    } catch (e) {
      print('즐겨찾기 토글 오류: $e');
      return false;
    }
  }

  // 검색 (제목 및 내용)
  Stream<List<MoodEntry>> searchMoodEntriesStream(String searchQuery) {
    final userId = _firebaseService.currentUserId;
    if (userId == null || searchQuery.isEmpty) return Stream.value([]);

    try {
      final collection = _firebaseService.getUserMoodEntriesCollection(userId);
      
      // Firestore에서는 부분 텍스트 검색이 제한적이므로
      // 클라이언트 사이드에서 필터링
      return collection
          .orderBy('date', descending: true)
          .snapshots()
          .map((snapshot) {
        return snapshot.docs
            .map((doc) => MoodEntry.fromFirestore(doc))
            .where((entry) {
          final query = searchQuery.toLowerCase();
          final title = entry.title?.toLowerCase() ?? '';
          final content = entry.content.toLowerCase();
          return title.contains(query) || content.contains(query);
        }).toList();
      });
    } catch (e) {
      print('감정일기 검색 오류: $e');
      return Stream.value([]);
    }
  }

  // 월별 감정일기 조회
  Stream<List<MoodEntry>> getMonthlyMoodEntriesStream(DateTime month) {
    final startOfMonth = DateTime(month.year, month.month, 1);
    final endOfMonth = DateTime(month.year, month.month + 1, 1);
    
    return getMoodEntriesStream(
      startDate: startOfMonth,
      endDate: endOfMonth,
      limit: 100,
    );
  }

  // 연속 작성일 계산
  Future<int> calculateConsecutiveDays() async {
    try {
      final userId = _firebaseService.currentUserId;
      if (userId == null) return 0;

      final collection = _firebaseService.getUserMoodEntriesCollection(userId);
      final querySnapshot = await collection
          .orderBy('date', descending: true)
          .get();

      if (querySnapshot.docs.isEmpty) return 0;

      final entries = querySnapshot.docs
          .map((doc) => MoodEntry.fromFirestore(doc))
          .toList();

      // 날짜별로 그룹화
      final entryDates = entries
          .map((entry) => DateTime(entry.date.year, entry.date.month, entry.date.day))
          .toSet()
          .toList();

      entryDates.sort((a, b) => b.compareTo(a)); // 최신 날짜부터

      if (entryDates.isEmpty) return 0;

      int consecutiveDays = 1;
      DateTime currentDate = entryDates.first;

      for (int i = 1; i < entryDates.length; i++) {
        final previousDate = currentDate.subtract(const Duration(days: 1));
        
        if (entryDates[i].isAtSameMomentAs(previousDate)) {
          consecutiveDays++;
          currentDate = entryDates[i];
        } else {
          break;
        }
      }

      return consecutiveDays;
    } catch (e) {
      print('연속 작성일 계산 오류: $e');
      return 0;
    }
  }

  // 감정별 통계
  Future<Map<MoodType, int>> getMoodStatistics({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final userId = _firebaseService.currentUserId;
      if (userId == null) return {};

      final collection = _firebaseService.getUserMoodEntriesCollection(userId);
      Query query = collection;

      if (startDate != null) {
        query = query.where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate));
      }
      if (endDate != null) {
        query = query.where('date', isLessThanOrEqualTo: Timestamp.fromDate(endDate));
      }

      final querySnapshot = await query.get();
      final entries = querySnapshot.docs
          .map((doc) => MoodEntry.fromFirestore(doc))
          .toList();

      final Map<MoodType, int> statistics = {};
      for (final moodType in MoodType.values) {
        statistics[moodType] = 0;
      }

      for (final entry in entries) {
        statistics[entry.mood] = (statistics[entry.mood] ?? 0) + 1;
      }

      return statistics;
    } catch (e) {
      print('감정별 통계 조회 오류: $e');
      return {};
    }
  }
} 