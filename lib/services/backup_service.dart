import 'dart:convert';
import 'dart:io';
import 'dart:html' as html;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import '../models/mood_entry_model.dart';
import 'local_storage_service.dart';

class BackupService {
  static BackupService? _instance;
  static BackupService get instance => _instance ??= BackupService._();
  BackupService._();

  // JSON으로 데이터 내보내기
  Future<String?> exportToJson() async {
    try {
      final storage = LocalStorageService.instance;
      final entries = await storage.getAllMoodEntries();
      
      final backupData = {
        'app_name': 'MoodDiary',
        'version': '1.0.0',
        'export_date': DateTime.now().toIso8601String(),
        'total_entries': entries.length,
        'entries': entries.map((entry) => entry.toJson()).toList(),
      };
      
      final jsonString = const JsonEncoder.withIndent('  ').convert(backupData);
      return jsonString;
    } catch (e) {
      print('JSON 내보내기 오류: $e');
      return null;
    }
  }

  // 파일로 저장하고 공유하기
  Future<bool> exportAndShare(BuildContext context) async {
    try {
      final jsonString = await exportToJson();
      if (jsonString == null) return false;
      
      final fileName = 'mood_diary_backup_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.json';
      
      if (kIsWeb) {
        // 웹에서는 다운로드
        await _downloadOnWeb(jsonString, fileName);
      } else {
        // 모바일에서는 임시 파일 생성 후 공유
        final tempDir = await getTemporaryDirectory();
        final file = File('${tempDir.path}/$fileName');
        await file.writeAsString(jsonString);
        
        await Share.shareXFiles(
          [XFile(file.path)],
          text: 'MoodDiary 백업 파일',
          subject: 'MoodDiary 백업',
        );
      }
      
      return true;
    } catch (e) {
      print('내보내기 및 공유 오류: $e');
      return false;
    }
  }

  // 웹에서 파일 다운로드
  Future<void> _downloadOnWeb(String content, String fileName) async {
    // 웹 환경에서는 브라우저 다운로드 사용
    final bytes = utf8.encode(content);
    final blob = html.Blob([bytes]);
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.AnchorElement(href: url)
      ..setAttribute('download', fileName)
      ..click();
    html.Url.revokeObjectUrl(url);
  }

  // JSON 파일에서 데이터 가져오기
  Future<bool> importFromJson(BuildContext context) async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (result != null) {
        String jsonString;
        
        if (kIsWeb) {
          // 웹에서는 bytes 사용
          final bytes = result.files.single.bytes;
          if (bytes == null) return false;
          jsonString = utf8.decode(bytes);
        } else {
          // 모바일에서는 파일 경로 사용
          final file = File(result.files.single.path!);
          jsonString = await file.readAsString();
        }

        return await _processImportData(jsonString, context);
      }
      return false;
    } catch (e) {
      print('가져오기 오류: $e');
      return false;
    }
  }

  // 가져온 데이터 처리
  Future<bool> _processImportData(String jsonString, BuildContext context) async {
    try {
      final Map<String, dynamic> backupData = jsonDecode(jsonString);
      
      // 데이터 유효성 검증
      if (!_validateBackupData(backupData)) {
        _showErrorDialog(context, '유효하지 않은 백업 파일입니다.');
        return false;
      }

      final List<dynamic> entriesJson = backupData['entries'] ?? [];
      final List<MoodEntry> entries = entriesJson
          .map((json) => MoodEntry.fromJson(json))
          .toList();

      // 중복 확인 다이얼로그
      final shouldMerge = await _showImportDialog(context, entries.length);
      if (shouldMerge == null) return false;

      final storage = LocalStorageService.instance;
      
      if (!shouldMerge) {
        // 기존 데이터 삭제 후 가져오기
        await storage.clearAllData();
      }

      // 데이터 저장
      for (final entry in entries) {
        await storage.saveMoodEntry(entry);
      }

      _showSuccessDialog(context, entries.length, shouldMerge);
      return true;
    } catch (e) {
      print('데이터 처리 오류: $e');
      _showErrorDialog(context, '백업 파일을 읽는 중 오류가 발생했습니다.');
      return false;
    }
  }

  // 백업 데이터 유효성 검증
  bool _validateBackupData(Map<String, dynamic> data) {
    return data.containsKey('app_name') &&
           data.containsKey('entries') &&
           data['app_name'] == 'MoodDiary';
  }

  // 가져오기 옵션 다이얼로그
  Future<bool?> _showImportDialog(BuildContext context, int entryCount) async {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('데이터 가져오기'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$entryCount개의 일기를 찾았습니다.'),
            const SizedBox(height: 16),
            const Text('어떻게 가져오시겠어요?'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('기존 데이터와 합치기'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('기존 데이터 교체'),
          ),
        ],
      ),
    );
  }

  // 성공 다이얼로그
  void _showSuccessDialog(BuildContext context, int count, bool merged) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('가져오기 완료'),
        content: Text(
          merged 
            ? '$count개의 일기가 성공적으로 합쳐졌습니다.'
            : '$count개의 일기가 성공적으로 가져와졌습니다.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }

  // 오류 다이얼로그
  void _showErrorDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('오류'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }

  // 백업 데이터 통계
  Future<Map<String, dynamic>> getBackupStats() async {
    try {
      final storage = LocalStorageService.instance;
      final entries = await storage.getAllMoodEntries();
      
      final stats = {
        'total_entries': entries.length,
        'date_range': _getDateRange(entries),
        'mood_distribution': _getMoodDistribution(entries),
        'last_backup': null, // TODO: 마지막 백업 시간 저장
      };
      
      return stats;
    } catch (e) {
      return {};
    }
  }

  Map<String, String> _getDateRange(List<MoodEntry> entries) {
    if (entries.isEmpty) return {'start': '-', 'end': '-'};
    
    entries.sort((a, b) => a.date.compareTo(b.date));
    return {
      'start': DateFormat('yyyy.MM.dd').format(entries.first.date),
      'end': DateFormat('yyyy.MM.dd').format(entries.last.date),
    };
  }

  Map<String, int> _getMoodDistribution(List<MoodEntry> entries) {
    final distribution = <String, int>{};
    for (final entry in entries) {
      final mood = entry.mood.label;
      distribution[mood] = (distribution[mood] ?? 0) + 1;
    }
    return distribution;
  }
} 