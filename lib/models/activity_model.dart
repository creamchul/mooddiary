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