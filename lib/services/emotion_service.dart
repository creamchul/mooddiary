import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/mood_entry_model.dart';

class EmotionService {
  static EmotionService? _instance;
  static EmotionService get instance => _instance ??= EmotionService._();
  EmotionService._();

  static const String _customEmotionsKey = 'custom_emotions';
  List<CustomEmotion>? _cachedEmotions;

  // 모든 커스텀 감정 가져오기
  Future<List<CustomEmotion>> getAllCustomEmotions() async {
    if (_cachedEmotions != null) return _cachedEmotions!;

    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_customEmotionsKey);
      
      if (jsonString != null) {
        final List<dynamic> jsonList = json.decode(jsonString);
        _cachedEmotions = jsonList.map((json) => CustomEmotion.fromJson(json)).toList();
      } else {
        // 처음 실행 시 기본 감정들 추가
        _cachedEmotions = DefaultCustomEmotions.defaultEmotions;
        await _saveEmotions(_cachedEmotions!);
      }
      
      return _cachedEmotions!;
    } catch (e) {
      return DefaultCustomEmotions.defaultEmotions;
    }
  }

  // 커스텀 감정 추가
  Future<bool> addCustomEmotion(CustomEmotion emotion) async {
    final emotions = await getAllCustomEmotions();
    
    // 중복 이름 확인
    if (emotions.any((e) => e.name == emotion.name)) {
      return false;
    }
    
    emotions.add(emotion);
    await _saveEmotions(emotions);
    _cachedEmotions = emotions;
    return true;
  }

  // 커스텀 감정 수정
  Future<bool> updateCustomEmotion(CustomEmotion emotion) async {
    final emotions = await getAllCustomEmotions();
    final index = emotions.indexWhere((e) => e.id == emotion.id);
    
    if (index == -1) return false;
    
    emotions[index] = emotion;
    await _saveEmotions(emotions);
    _cachedEmotions = emotions;
    return true;
  }

  // 커스텀 감정 삭제
  Future<bool> deleteCustomEmotion(String emotionId) async {
    final emotions = await getAllCustomEmotions();
    emotions.removeWhere((e) => e.id == emotionId);
    await _saveEmotions(emotions);
    _cachedEmotions = emotions;
    return true;
  }

  // 사용 횟수 증가
  Future<void> incrementUsage(String emotionId) async {
    final emotions = await getAllCustomEmotions();
    final index = emotions.indexWhere((e) => e.id == emotionId);
    
    if (index != -1) {
      emotions[index] = emotions[index].copyWith(
        usageCount: emotions[index].usageCount + 1,
        updatedAt: DateTime.now(),
      );
      await _saveEmotions(emotions);
      _cachedEmotions = emotions;
    }
  }

  Future<void> _saveEmotions(List<CustomEmotion> emotions) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = emotions.map((e) => e.toJson()).toList();
    await prefs.setString(_customEmotionsKey, json.encode(jsonList));
  }
} 