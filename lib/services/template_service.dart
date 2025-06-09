import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/activity_model.dart';

class TemplateService {
  static TemplateService? _instance;
  static TemplateService get instance => _instance ??= TemplateService._();
  TemplateService._();

  static const String _customTemplatesKey = 'custom_templates';
  static const String _hiddenTemplatesKey = 'hidden_templates';

  List<DiaryTemplate>? _cachedCustomTemplates;
  Set<String>? _cachedHiddenTemplates;
  DateTime? _cacheTime;
  static const Duration _cacheTimeout = Duration(minutes: 5);

  // 모든 활성 템플릿 가져오기 (기본 + 커스텀 - 숨김)
  Future<List<DiaryTemplate>> getAllActiveTemplates() async {
    final defaultTemplates = DefaultTemplates.defaultTemplates;
    final customTemplates = await getCustomTemplates();
    final hiddenTemplates = await getHiddenTemplates();

    final allTemplates = <DiaryTemplate>[];
    
    // 기본 템플릿 중 숨겨지지 않은 것들 추가
    for (final template in defaultTemplates) {
      if (!hiddenTemplates.contains(template.id)) {
        allTemplates.add(template);
      }
    }
    
    // 커스텀 템플릿 중 활성화된 것들 추가
    for (final template in customTemplates) {
      if (template.isActive) {
        allTemplates.add(template);
      }
    }

    return allTemplates;
  }

  // 커스텀 템플릿 목록 가져오기
  Future<List<DiaryTemplate>> getCustomTemplates() async {
    if (_cachedCustomTemplates != null && _cacheTime != null &&
        DateTime.now().difference(_cacheTime!).compareTo(_cacheTimeout) < 0) {
      return _cachedCustomTemplates!;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_customTemplatesKey);
      
      if (jsonString != null) {
        final List<dynamic> jsonList = json.decode(jsonString);
        _cachedCustomTemplates = jsonList.map((json) => DiaryTemplate.fromJson(json)).toList();
      } else {
        _cachedCustomTemplates = [];
      }
      
      _cacheTime = DateTime.now();
      return _cachedCustomTemplates!;
    } catch (e) {
      print('Error loading custom templates: $e');
      return [];
    }
  }

  // 숨겨진 템플릿 ID 목록 가져오기
  Future<Set<String>> getHiddenTemplates() async {
    if (_cachedHiddenTemplates != null && _cacheTime != null &&
        DateTime.now().difference(_cacheTime!).compareTo(_cacheTimeout) < 0) {
      return _cachedHiddenTemplates!;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final hiddenList = prefs.getStringList(_hiddenTemplatesKey) ?? [];
      _cachedHiddenTemplates = hiddenList.toSet();
      return _cachedHiddenTemplates!;
    } catch (e) {
      print('Error loading hidden templates: $e');
      return {};
    }
  }

  // 커스텀 템플릿 추가
  Future<bool> addCustomTemplate(DiaryTemplate template) async {
    try {
      final customTemplates = await getCustomTemplates();
      
      // 중복 이름 확인
      if (customTemplates.any((t) => t.name == template.name)) {
        return false; // 중복 이름
      }
      
      customTemplates.add(template);
      await _saveCustomTemplates(customTemplates);
      _clearCache();
      return true;
    } catch (e) {
      print('Error adding custom template: $e');
      return false;
    }
  }

  // 커스텀 템플릿 수정
  Future<bool> updateCustomTemplate(DiaryTemplate template) async {
    try {
      final customTemplates = await getCustomTemplates();
      final index = customTemplates.indexWhere((t) => t.id == template.id);
      
      if (index == -1) return false;
      
      customTemplates[index] = template;
      await _saveCustomTemplates(customTemplates);
      _clearCache();
      return true;
    } catch (e) {
      print('Error updating custom template: $e');
      return false;
    }
  }

  // 커스텀 템플릿 삭제
  Future<bool> deleteCustomTemplate(String templateId) async {
    try {
      final customTemplates = await getCustomTemplates();
      customTemplates.removeWhere((t) => t.id == templateId);
      await _saveCustomTemplates(customTemplates);
      _clearCache();
      return true;
    } catch (e) {
      print('Error deleting custom template: $e');
      return false;
    }
  }

  // 기본 템플릿 숨기기/보이기
  Future<bool> toggleDefaultTemplateVisibility(String templateId) async {
    try {
      final hiddenTemplates = await getHiddenTemplates();
      final prefs = await SharedPreferences.getInstance();
      
      if (hiddenTemplates.contains(templateId)) {
        hiddenTemplates.remove(templateId);
      } else {
        hiddenTemplates.add(templateId);
      }
      
      await prefs.setStringList(_hiddenTemplatesKey, hiddenTemplates.toList());
      _clearCache();
      return true;
    } catch (e) {
      print('Error toggling template visibility: $e');
      return false;
    }
  }

  // 템플릿 사용 횟수 증가
  Future<void> incrementTemplateUsage(String templateId) async {
    try {
      final customTemplates = await getCustomTemplates();
      final index = customTemplates.indexWhere((t) => t.id == templateId);
      
      if (index != -1) {
        final updatedTemplate = customTemplates[index].copyWith(
          usageCount: customTemplates[index].usageCount + 1,
          updatedAt: DateTime.now(),
        );
        customTemplates[index] = updatedTemplate;
        await _saveCustomTemplates(customTemplates);
        _clearCache();
      }
    } catch (e) {
      print('Error incrementing template usage: $e');
    }
  }

  // 커스텀 템플릿 저장
  Future<void> _saveCustomTemplates(List<DiaryTemplate> templates) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = templates.map((t) => t.toJson()).toList();
    await prefs.setString(_customTemplatesKey, json.encode(jsonList));
  }

  // 캐시 클리어
  void _clearCache() {
    _cachedCustomTemplates = null;
    _cachedHiddenTemplates = null;
    _cacheTime = null;
  }

  // 모든 데이터 초기화
  Future<bool> clearAllData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_customTemplatesKey);
      await prefs.remove(_hiddenTemplatesKey);
      _clearCache();
      return true;
    } catch (e) {
      print('Error clearing template data: $e');
      return false;
    }
  }

  // 템플릿 데이터 내보내기
  Future<Map<String, dynamic>> exportData() async {
    final customTemplates = await getCustomTemplates();
    final hiddenTemplates = await getHiddenTemplates();
    
    return {
      'customTemplates': customTemplates.map((t) => t.toJson()).toList(),
      'hiddenTemplates': hiddenTemplates.toList(),
      'exportDate': DateTime.now().toIso8601String(),
    };
  }

  // 템플릿 데이터 가져오기
  Future<bool> importData(Map<String, dynamic> data) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // 커스텀 템플릿 가져오기
      if (data['customTemplates'] != null) {
        final customTemplatesList = data['customTemplates'] as List;
        final templates = customTemplatesList.map((json) => DiaryTemplate.fromJson(json)).toList();
        await _saveCustomTemplates(templates);
      }
      
      // 숨겨진 템플릿 가져오기
      if (data['hiddenTemplates'] != null) {
        final hiddenList = (data['hiddenTemplates'] as List).cast<String>();
        await prefs.setStringList(_hiddenTemplatesKey, hiddenList);
      }
      
      _clearCache();
      return true;
    } catch (e) {
      print('Error importing template data: $e');
      return false;
    }
  }
} 