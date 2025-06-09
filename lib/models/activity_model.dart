import 'package:cloud_firestore/cloud_firestore.dart';

class Activity {
  final String id;
  final String name;
  final String? description;
  final String emoji;
  final String color; // 색상 hex 코드
  final bool isDefault; // 기본 제공 활동인지 여부
  final String userId; // 사용자 정의 활동의 경우 userId
  final int usageCount; // 사용 횟수
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isActive; // 활성화 여부

  Activity({
    required this.id,
    required this.name,
    this.description,
    required this.emoji,
    required this.color,
    this.isDefault = false,
    this.userId = '',
    this.usageCount = 0,
    required this.createdAt,
    required this.updatedAt,
    this.isActive = true,
  });

  // Firestore 문서에서 Activity 생성
  factory Activity.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    return Activity(
      id: doc.id,
      name: data['name'] ?? '',
      description: data['description'],
      emoji: data['emoji'] ?? '📝',
      color: data['color'] ?? '#EC407A',
      isDefault: data['isDefault'] ?? false,
      userId: data['userId'] ?? '',
      usageCount: data['usageCount'] ?? 0,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: (data['updatedAt'] as Timestamp).toDate(),
      isActive: data['isActive'] ?? true,
    );
  }

  // Firestore에 저장할 Map 생성
  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'description': description,
      'emoji': emoji,
      'color': color,
      'isDefault': isDefault,
      'userId': userId,
      'usageCount': usageCount,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'isActive': isActive,
    };
  }

  // 복사본 생성
  Activity copyWith({
    String? id,
    String? name,
    String? description,
    String? emoji,
    String? color,
    bool? isDefault,
    String? userId,
    int? usageCount,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isActive,
  }) {
    return Activity(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      emoji: emoji ?? this.emoji,
      color: color ?? this.color,
      isDefault: isDefault ?? this.isDefault,
      userId: userId ?? this.userId,
      usageCount: usageCount ?? this.usageCount,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isActive: isActive ?? this.isActive,
    );
  }

  // JSON 직렬화
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'emoji': emoji,
      'color': color,
      'isDefault': isDefault,
      'userId': userId,
      'usageCount': usageCount,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'isActive': isActive,
    };
  }

  // JSON에서 Activity 생성
  factory Activity.fromJson(Map<String, dynamic> json) {
    return Activity(
      id: json['id'],
      name: json['name'],
      description: json['description'],
      emoji: json['emoji'],
      color: json['color'],
      isDefault: json['isDefault'],
      userId: json['userId'],
      usageCount: json['usageCount'],
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: DateTime.parse(json['updatedAt']),
      isActive: json['isActive'],
    );
  }

  @override
  String toString() {
    return 'Activity(id: $id, name: $name, emoji: $emoji)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Activity && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

// 기본 제공 활동들
class DefaultActivities {
  static List<Activity> get defaultActivities {
    final now = DateTime.now();
    
    return [
      Activity(
        id: 'work',
        name: '일',
        description: '직장이나 업무 관련 활동',
        emoji: '💼',
        color: '#EC407A',
        isDefault: true,
        createdAt: now,
        updatedAt: now,
      ),
      Activity(
        id: 'exercise',
        name: '운동',
        description: '신체 활동이나 운동',
        emoji: '🏃‍♀️',
        color: '#4CAF50',
        isDefault: true,
        createdAt: now,
        updatedAt: now,
      ),
      Activity(
        id: 'study',
        name: '공부',
        description: '학습이나 자기계발',
        emoji: '📚',
        color: '#2196F3',
        isDefault: true,
        createdAt: now,
        updatedAt: now,
      ),
      Activity(
        id: 'meeting',
        name: '만남',
        description: '친구나 가족과의 만남',
        emoji: '👥',
        color: '#FF9800',
        isDefault: true,
        createdAt: now,
        updatedAt: now,
      ),
      Activity(
        id: 'hobby',
        name: '취미',
        description: '개인적인 취미 활동',
        emoji: '🎨',
        color: '#9C27B0',
        isDefault: true,
        createdAt: now,
        updatedAt: now,
      ),
      Activity(
        id: 'travel',
        name: '여행',
        description: '여행이나 나들이',
        emoji: '✈️',
        color: '#00BCD4',
        isDefault: true,
        createdAt: now,
        updatedAt: now,
      ),
      Activity(
        id: 'food',
        name: '음식',
        description: '맛있는 음식을 먹은 경험',
        emoji: '🍽️',
        color: '#FF5722',
        isDefault: true,
        createdAt: now,
        updatedAt: now,
      ),
      Activity(
        id: 'rest',
        name: '휴식',
        description: '쉬거나 편안한 시간',
        emoji: '😴',
        color: '#607D8B',
        isDefault: true,
        createdAt: now,
        updatedAt: now,
      ),
      Activity(
        id: 'shopping',
        name: '쇼핑',
        description: '쇼핑이나 구매 활동',
        emoji: '🛍️',
        color: '#E91E63',
        isDefault: true,
        createdAt: now,
        updatedAt: now,
      ),
      Activity(
        id: 'entertainment',
        name: '엔터테인먼트',
        description: '영화, 게임, TV 등',
        emoji: '🎬',
        color: '#673AB7',
        isDefault: true,
        createdAt: now,
        updatedAt: now,
      ),
    ];
  }
}

// 일기 템플릿 모델
class DiaryTemplate {
  final String id;
  final String name;
  final String content; // 템플릿 내용 (placeholder들 포함)
  final String? description;
  final bool isDefault; // 기본 제공 템플릿 여부
  final String userId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int usageCount; // 사용 횟수
  final bool isActive;

  DiaryTemplate({
    required this.id,
    required this.name,
    required this.content,
    this.description,
    this.isDefault = false,
    required this.userId,
    required this.createdAt,
    required this.updatedAt,
    this.usageCount = 0,
    this.isActive = true,
  });

  DiaryTemplate copyWith({
    String? id,
    String? name,
    String? content,
    String? description,
    bool? isDefault,
    String? userId,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? usageCount,
    bool? isActive,
  }) {
    return DiaryTemplate(
      id: id ?? this.id,
      name: name ?? this.name,
      content: content ?? this.content,
      description: description ?? this.description,
      isDefault: isDefault ?? this.isDefault,
      userId: userId ?? this.userId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      usageCount: usageCount ?? this.usageCount,
      isActive: isActive ?? this.isActive,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'content': content,
      'description': description,
      'isDefault': isDefault,
      'userId': userId,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'usageCount': usageCount,
      'isActive': isActive,
    };
  }

  factory DiaryTemplate.fromJson(Map<String, dynamic> json) {
    return DiaryTemplate(
      id: json['id'],
      name: json['name'],
      content: json['content'],
      description: json['description'],
      isDefault: json['isDefault'] ?? false,
      userId: json['userId'],
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: DateTime.parse(json['updatedAt']),
      usageCount: json['usageCount'] ?? 0,
      isActive: json['isActive'] ?? true,
    );
  }
}

// 기본 제공 템플릿들
class DefaultTemplates {
  static List<DiaryTemplate> get defaultTemplates {
    final now = DateTime.now();
    return [
      DiaryTemplate(
        id: 'template_daily_reflection',
        name: '하루 돌아보기',
        content: '''오늘 하루는 어땠나요?

🌅 오늘 아침 기분: 

💫 오늘의 하이라이트:

📚 배운 것이나 깨달은 것:

🎯 내일 하고 싶은 일:

💭 추가로 기록하고 싶은 것:''',
        description: '하루를 차근차근 되돌아보는 템플릿',
        isDefault: true,
        userId: 'system',
        createdAt: now,
        updatedAt: now,
      ),
      DiaryTemplate(
        id: 'template_gratitude',
        name: '감사 일기',
        content: '''오늘 감사했던 일들을 적어보세요 🙏

1. 

2. 

3. 

✨ 특별히 고마웠던 사람이 있다면:

🌈 오늘 나에게 일어난 작은 기적:''',
        description: '감사한 마음을 기록하는 템플릿',
        isDefault: true,
        userId: 'system',
        createdAt: now,
        updatedAt: now,
      ),
      DiaryTemplate(
        id: 'template_growth',
        name: '성장 일기',
        content: '''오늘의 성장 기록 📈

🎯 오늘 달성한 목표:

🚀 새롭게 시도한 것:

💪 극복한 어려움:

📖 배운 교훈:

⭐ 내일 더 성장하기 위한 계획:''',
        description: '개인 성장을 추적하는 템플릿',
        isDefault: true,
        userId: 'system',
        createdAt: now,
        updatedAt: now,
      ),
      DiaryTemplate(
        id: 'template_mood_tracking',
        name: '감정 추적',
        content: '''오늘의 감정 여행 🎭

🌅 아침 기분: 

🌞 점심 기분:

🌙 저녁 기분:

🤔 기분 변화의 이유:

💡 감정 관리 방법:

🎯 내일 더 좋은 하루를 위한 계획:''',
        description: '하루 동안의 감정 변화를 추적하는 템플릿',
        isDefault: true,
        userId: 'system',
        createdAt: now,
        updatedAt: now,
      ),
      DiaryTemplate(
        id: 'template_simple',
        name: '간단 일기',
        content: '''오늘은...

기분: 

한 일: 

생각: ''',
        description: '간단하게 쓰는 일기 템플릿',
        isDefault: true,
        userId: 'system',
        createdAt: now,
        updatedAt: now,
      ),
    ];
  }
} 