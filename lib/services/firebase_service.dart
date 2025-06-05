import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

class FirebaseService {
  static final FirebaseService _instance = FirebaseService._internal();
  factory FirebaseService() => _instance;
  FirebaseService._internal();

  // Firebase 인스턴스들
  FirebaseFirestore get firestore => FirebaseFirestore.instance;
  FirebaseAuth get auth => FirebaseAuth.instance;

  // 현재 사용자 ID
  String? get currentUserId => auth.currentUser?.uid;

  // 현재 사용자
  User? get currentUser => auth.currentUser;

  // Firebase 초기화
  static Future<void> initialize() async {
    await Firebase.initializeApp();
  }

  // 컬렉션 참조들
  CollectionReference get usersCollection => firestore.collection('users');
  CollectionReference get moodEntriesCollection => firestore.collection('mood_entries');
  CollectionReference get activitiesCollection => firestore.collection('activities');

  // 사용자별 감정일기 컬렉션
  CollectionReference getUserMoodEntriesCollection(String userId) {
    return usersCollection.doc(userId).collection('mood_entries');
  }

  // 사용자별 활동 컬렉션
  CollectionReference getUserActivitiesCollection(String userId) {
    return usersCollection.doc(userId).collection('activities');
  }

  // 익명 로그인
  Future<UserCredential?> signInAnonymously() async {
    try {
      return await auth.signInAnonymously();
    } catch (e) {
      print('익명 로그인 오류: $e');
      return null;
    }
  }

  // 로그아웃
  Future<void> signOut() async {
    try {
      await auth.signOut();
    } catch (e) {
      print('로그아웃 오류: $e');
    }
  }

  // 문서 존재 여부 확인
  Future<bool> documentExists(DocumentReference docRef) async {
    try {
      final doc = await docRef.get();
      return doc.exists;
    } catch (e) {
      print('문서 존재 확인 오류: $e');
      return false;
    }
  }

  // 배치 쓰기
  WriteBatch createBatch() {
    return firestore.batch();
  }

  // 트랜잭션 실행
  Future<T> runTransaction<T>(
    Future<T> Function(Transaction transaction) updateFunction,
  ) async {
    return await firestore.runTransaction(updateFunction);
  }

  // 실시간 리스너 해제를 위한 유틸리티
  void cancelStreamSubscription(StreamSubscription? subscription) {
    subscription?.cancel();
  }

  // 날짜 범위로 쿼리 생성
  Query buildDateRangeQuery(
    CollectionReference collection,
    DateTime startDate,
    DateTime endDate, {
    String dateField = 'date',
  }) {
    return collection
        .where(dateField, isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
        .where(dateField, isLessThan: Timestamp.fromDate(endDate));
  }

  // 페이지네이션을 위한 쿼리
  Query buildPaginatedQuery(
    CollectionReference collection, {
    int limit = 20,
    DocumentSnapshot? lastDocument,
    String orderByField = 'createdAt',
    bool descending = true,
  }) {
    Query query = collection
        .orderBy(orderByField, descending: descending)
        .limit(limit);

    if (lastDocument != null) {
      query = query.startAfterDocument(lastDocument);
    }

    return query;
  }

  // 에러 핸들링 유틸리티
  String getFirebaseErrorMessage(dynamic error) {
    if (error is FirebaseException) {
      switch (error.code) {
        case 'permission-denied':
          return '접근 권한이 없습니다.';
        case 'unavailable':
          return '서비스를 사용할 수 없습니다. 잠시 후 다시 시도해주세요.';
        case 'deadline-exceeded':
          return '요청 시간이 초과되었습니다.';
        case 'not-found':
          return '요청한 데이터를 찾을 수 없습니다.';
        default:
          return '오류가 발생했습니다: ${error.message}';
      }
    }
    return '알 수 없는 오류가 발생했습니다.';
  }

  // 연결 상태 체크
  Stream<bool> get connectivityStream {
    return firestore.enableNetwork().asStream().map((_) => true)
        .handleError((error) => false);
  }

  // 오프라인 모드 활성화
  Future<void> enableOfflineMode() async {
    try {
      await firestore.disableNetwork();
    } catch (e) {
      print('오프라인 모드 활성화 오류: $e');
    }
  }

  // 온라인 모드 활성화
  Future<void> enableOnlineMode() async {
    try {
      await firestore.enableNetwork();
    } catch (e) {
      print('온라인 모드 활성화 오류: $e');
    }
  }
} 