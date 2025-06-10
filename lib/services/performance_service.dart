import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'local_storage_service.dart';
import 'image_service.dart';

class PerformanceService {
  static final PerformanceService _instance = PerformanceService._internal();
  factory PerformanceService() => _instance;
  PerformanceService._internal();

  static PerformanceService get instance => _instance;

  // 성능 메트릭
  final Map<String, int> _performanceMetrics = {};
  final List<String> _performanceLogs = [];
  
  // 메모리 사용량 추적
  int _maxMemoryUsage = 0;
  int _currentMemoryUsage = 0;
  
  // 앱 시작 시간
  DateTime? _appStartTime;
  final Map<String, DateTime> _operationStartTimes = {};

  void init() {
    _appStartTime = DateTime.now();
    _logPerformance('앱 시작', '서비스 초기화 완료');
    
    // 메모리 사용량 주기적 체크 (디버그 모드에서만)
    if (kDebugMode) {
      _startMemoryMonitoring();
    }
  }

  // 작업 시작 시간 기록
  void startOperation(String operationName) {
    _operationStartTimes[operationName] = DateTime.now();
  }

  // 작업 완료 시간 기록 및 성능 로그
  void endOperation(String operationName) {
    final startTime = _operationStartTimes[operationName];
    if (startTime != null) {
      final duration = DateTime.now().difference(startTime);
      _performanceMetrics[operationName] = duration.inMilliseconds;
      _logPerformance(operationName, '${duration.inMilliseconds}ms');
      _operationStartTimes.remove(operationName);
      
      // 성능 경고 (500ms 이상)
      if (duration.inMilliseconds > 500) {
        _logPerformance('성능 경고', '$operationName이 ${duration.inMilliseconds}ms 소요됨');
      }
    }
  }

  // 성능 로그 기록
  void _logPerformance(String category, String message) {
    final timestamp = DateTime.now().toIso8601String();
    final logMessage = '[$timestamp] $category: $message';
    _performanceLogs.add(logMessage);
    
    // 로그 크기 제한 (최대 100개)
    if (_performanceLogs.length > 100) {
      _performanceLogs.removeAt(0);
    }
    
    if (kDebugMode) {
      print('[Performance] $logMessage');
    }
  }

  // 메모리 모니터링 시작
  void _startMemoryMonitoring() {
    // 실제 메모리 사용량은 플랫폼별로 다르게 측정해야 함
    // 여기서는 간단한 예시
    SystemChannels.lifecycle.setMessageHandler((message) async {
      if (message == AppLifecycleState.resumed.toString()) {
        _checkMemoryUsage();
      }
      return null;
    });
  }

  // 메모리 사용량 체크
  void _checkMemoryUsage() {
    // 실제 메모리 사용량 측정은 플랫폼별 네이티브 코드 필요
    // 여기서는 캐시 크기 등을 기반으로 추정
    try {
      // 예상 메모리 사용량 계산
      final estimatedUsage = _calculateEstimatedMemoryUsage();
      _currentMemoryUsage = estimatedUsage;
      
      if (estimatedUsage > _maxMemoryUsage) {
        _maxMemoryUsage = estimatedUsage;
      }
      
      // 메모리 사용량이 높으면 정리 수행
      if (estimatedUsage > 50 * 1024 * 1024) { // 50MB
        _performMemoryCleanup();
      }
      
      _logPerformance('메모리', '현재: ${(estimatedUsage / 1024 / 1024).toStringAsFixed(1)}MB, 최대: ${(_maxMemoryUsage / 1024 / 1024).toStringAsFixed(1)}MB');
    } catch (e) {
      _logPerformance('메모리 체크 오류', e.toString());
    }
  }

  // 추정 메모리 사용량 계산
  int _calculateEstimatedMemoryUsage() {
    int totalSize = 0;
    
    // 기본 앱 메모리 (추정)
    totalSize += 10 * 1024 * 1024; // 10MB 기본
    
    // 이미지 캐시 크기 추정 - public getter 사용
    totalSize += ImageService.instance.imageCacheSize * 100 * 1024; // 이미지당 평균 100KB
    
    return totalSize;
  }

  // 메모리 정리 수행
  void _performMemoryCleanup() {
    _logPerformance('메모리 정리', '정리 작업 시작');
    
    // 이미지 캐시 크기 제한 (완전 정리 대신)
    ImageService.instance.limitImageCacheSize(maxSize: 30);
    
    // LocalStorage 캐시 크기 제한
    LocalStorageService.instance.limitCacheSize();
    
    // Garbage Collection 강제 실행 (가능한 경우)
    if (kDebugMode) {
      // 개발 모드에서만 GC 힌트
      SystemChannels.platform.invokeMethod('System.gc');
    }
    
    _logPerformance('메모리 정리', '정리 작업 완료');
  }

  // 데이터 로딩 성능 최적화
  Future<T> optimizedDataLoad<T>(
    String operationName,
    Future<T> Function() operation, {
    Duration? timeout,
  }) async {
    startOperation(operationName);
    
    try {
      final result = timeout != null
          ? await operation().timeout(timeout)
          : await operation();
      
      endOperation(operationName);
      return result;
    } catch (e) {
      endOperation(operationName);
      _logPerformance('오류', '$operationName 실패: $e');
      rethrow;
    }
  }

  // 배치 작업 최적화
  Future<List<T>> optimizedBatchOperation<T>(
    String operationName,
    List<Future<T> Function()> operations, {
    int? batchSize,
    Duration? delayBetweenBatches,
  }) async {
    startOperation(operationName);
    
    final results = <T>[];
    final effectiveBatchSize = batchSize ?? 10;
    
    try {
      for (int i = 0; i < operations.length; i += effectiveBatchSize) {
        final batch = operations.skip(i).take(effectiveBatchSize);
        final batchResults = await Future.wait(batch.map((op) => op()));
        results.addAll(batchResults);
        
        // 배치 간 지연 (메모리 압박 방지)
        if (delayBetweenBatches != null && i + effectiveBatchSize < operations.length) {
          await Future.delayed(delayBetweenBatches);
        }
      }
      
      endOperation(operationName);
      return results;
    } catch (e) {
      endOperation(operationName);
      _logPerformance('오류', '$operationName 배치 작업 실패: $e');
      rethrow;
    }
  }

  // 성능 보고서 생성
  Map<String, dynamic> generatePerformanceReport() {
    final appUptime = _appStartTime != null 
        ? DateTime.now().difference(_appStartTime!).inMinutes
        : 0;
    
    return {
      'appUptime': '$appUptime분',
      'currentMemoryUsage': '${(_currentMemoryUsage / 1024 / 1024).toStringAsFixed(1)}MB',
      'maxMemoryUsage': '${(_maxMemoryUsage / 1024 / 1024).toStringAsFixed(1)}MB',
      'operationMetrics': Map.from(_performanceMetrics),
      'recentLogs': _performanceLogs.take(20).toList(),
      'cacheStats': {
        'imageCacheSize': ImageService.instance.imageCacheSize,
        'localStorageCacheValid': LocalStorageService.instance.isCacheValid(),
      },
    };
  }

  // 성능 최적화 팁 제공
  List<String> getOptimizationTips() {
    final tips = <String>[];
    
    // 메모리 사용량 기반 팁
    if (_currentMemoryUsage > 30 * 1024 * 1024) {
      tips.add('메모리 사용량이 높습니다. 앱을 재시작하면 성능이 개선됩니다.');
    }
    
    // 느린 작업 기반 팁
    final slowOperations = _performanceMetrics.entries
        .where((entry) => entry.value > 1000)
        .map((entry) => entry.key)
        .toList();
    
    if (slowOperations.isNotEmpty) {
      tips.add('일부 작업이 느립니다: ${slowOperations.join(', ')}');
    }
    
    // 캐시 상태 기반 팁
    if (ImageService.instance.imageCacheSize > 40) {
      tips.add('이미지 캐시가 많습니다. 자동으로 정리됩니다.');
    }
    
    return tips;
  }

  // 성능 통계 리셋
  void resetPerformanceStats() {
    _performanceMetrics.clear();
    _performanceLogs.clear();
    _maxMemoryUsage = 0;
    _currentMemoryUsage = 0;
    _appStartTime = DateTime.now();
    _logPerformance('리셋', '성능 통계가 초기화되었습니다');
  }

  // 디버그 정보 출력
  void printDebugInfo() {
    if (kDebugMode) {
      print('=== 성능 디버그 정보 ===');
      print('앱 실행 시간: ${_appStartTime != null ? DateTime.now().difference(_appStartTime!).toString() : '알 수 없음'}');
      print('현재 메모리 사용량: ${(_currentMemoryUsage / 1024 / 1024).toStringAsFixed(1)}MB');
      print('최대 메모리 사용량: ${(_maxMemoryUsage / 1024 / 1024).toStringAsFixed(1)}MB');
      print('이미지 캐시 크기: ${ImageService.instance.imageCacheSize}');
      print('작업 성능:');
      _performanceMetrics.forEach((operation, duration) {
        print('  $operation: ${duration}ms');
      });
      print('==================');
    }
  }
} 