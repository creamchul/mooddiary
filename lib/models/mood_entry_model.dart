import 'package:cloud_firestore/cloud_firestore.dart';

enum MoodType {
  worst,
  bad,
  neutral,
  good,
  best,
}

extension MoodTypeExtension on MoodType {
  String get emoji {
    switch (this) {
      case MoodType.worst:
        return '😭';
      case MoodType.bad:
        return '😔';
      case MoodType.neutral:
        return '😐';
      case MoodType.good:
        return '😊';
      case MoodType.best:
        return '😍';
    }
  }

  String get label {
    switch (this) {
      case MoodType.worst:
        return '최악';
      case MoodType.bad:
        return '나쁨';
      case MoodType.neutral:
        return '보통';
      case MoodType.good:
        return '좋음';
      case MoodType.best:
        return '최고';
    }
  }

  String get description {
    switch (this) {
      case MoodType.worst:
        return '정말 힘들고 우울한 하루였어요';
      case MoodType.bad:
        return '기분이 좋지 않은 하루였어요';
      case MoodType.neutral:
        return '그저 그런 평범한 하루였어요';
      case MoodType.good:
        return '기분 좋은 하루였어요';
      case MoodType.best:
        return '정말 행복하고 완벽한 하루였어요';
    }
  }

  int get value {
    switch (this) {
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
}

// 커스텀 감정 클래스
class CustomEmotion {
  final String id;
  final String name;
  final String emoji;
  final String color; // hex 색상
  final String? description;
  final int value; // 1-10 범위의 감정 강도
  final String userId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int usageCount;
  final bool isActive;

  CustomEmotion({
    required this.id,
    required this.name,
    required this.emoji,
    required this.color,
    this.description,
    required this.value,
    required this.userId,
    required this.createdAt,
    required this.updatedAt,
    this.usageCount = 0,
    this.isActive = true,
  });

  CustomEmotion copyWith({
    String? id,
    String? name,
    String? emoji,
    String? color,
    String? description,
    int? value,
    String? userId,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? usageCount,
    bool? isActive,
  }) {
    return CustomEmotion(
      id: id ?? this.id,
      name: name ?? this.name,
      emoji: emoji ?? this.emoji,
      color: color ?? this.color,
      description: description ?? this.description,
      value: value ?? this.value,
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
      'emoji': emoji,
      'color': color,
      'description': description,
      'value': value,
      'userId': userId,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'usageCount': usageCount,
      'isActive': isActive,
    };
  }

  factory CustomEmotion.fromJson(Map<String, dynamic> json) {
    return CustomEmotion(
      id: json['id'],
      name: json['name'],
      emoji: json['emoji'],
      color: json['color'],
      description: json['description'],
      value: json['value'],
      userId: json['userId'],
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: DateTime.parse(json['updatedAt']),
      usageCount: json['usageCount'] ?? 0,
      isActive: json['isActive'] ?? true,
    );
  }

  @override
  String toString() {
    return 'CustomEmotion(id: $id, name: $name, emoji: $emoji, value: $value)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CustomEmotion && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

// 기본 제공 커스텀 감정들 (사용자가 추가할 수 있는 예시)
class DefaultCustomEmotions {
  static List<CustomEmotion> get defaultEmotions {
    final now = DateTime.now();
    return [
      CustomEmotion(
        id: 'excited',
        name: '신남',
        emoji: '🤩',
        color: '#FF6B35',
        description: '정말 신나고 들뜬 기분',
        value: 8,
        userId: 'system',
        createdAt: now,
        updatedAt: now,
      ),
      CustomEmotion(
        id: 'calm',
        name: '평온',
        emoji: '😌',
        color: '#4ECDC4',
        description: '마음이 차분하고 평온한 상태',
        value: 6,
        userId: 'system',
        createdAt: now,
        updatedAt: now,
      ),
      CustomEmotion(
        id: 'anxious',
        name: '불안',
        emoji: '😰',
        color: '#FFE66D',
        description: '걱정되고 불안한 마음',
        value: 3,
        userId: 'system',
        createdAt: now,
        updatedAt: now,
      ),
      CustomEmotion(
        id: 'grateful',
        name: '감사',
        emoji: '🙏',
        color: '#A8E6CF',
        description: '고마운 마음이 가득한 상태',
        value: 7,
        userId: 'system',
        createdAt: now,
        updatedAt: now,
      ),
      CustomEmotion(
        id: 'angry',
        name: '화남',
        emoji: '😠',
        color: '#FF8B94',
        description: '화가 나고 짜증나는 기분',
        value: 2,
        userId: 'system',
        createdAt: now,
        updatedAt: now,
      ),
    ];
  }
}

class MoodEntry {
  final String id;
  final String userId;
  final MoodType mood;
  final String? title;
  final String content;
  final List<String> activities;
  final List<String> imageUrls;
  final DateTime date;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isFavorite;
  final Map<String, dynamic>? metadata;

  MoodEntry({
    required this.id,
    required this.userId,
    required this.mood,
    this.title,
    required this.content,
    required this.activities,
    required this.imageUrls,
    required this.date,
    required this.createdAt,
    required this.updatedAt,
    this.isFavorite = false,
    this.metadata,
  });

  // Firestore 문서에서 MoodEntry 생성
  factory MoodEntry.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    return MoodEntry(
      id: doc.id,
      userId: data['userId'] ?? '',
      mood: MoodType.values[data['mood'] ?? 0],
      title: data['title'],
      content: data['content'] ?? '',
      activities: List<String>.from(data['activities'] ?? []),
      imageUrls: List<String>.from(data['imageUrls'] ?? []),
      date: (data['date'] as Timestamp).toDate(),
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: (data['updatedAt'] as Timestamp).toDate(),
      isFavorite: data['isFavorite'] ?? false,
      metadata: data['metadata'],
    );
  }

  // Firestore에 저장할 Map 생성
  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'mood': mood.index,
      'title': title,
      'content': content,
      'activities': activities,
      'imageUrls': imageUrls,
      'date': Timestamp.fromDate(date),
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'isFavorite': isFavorite,
      'metadata': metadata,
    };
  }

  // 복사본 생성 (수정 시 사용)
  MoodEntry copyWith({
    String? id,
    String? userId,
    MoodType? mood,
    String? title,
    String? content,
    List<String>? activities,
    List<String>? imageUrls,
    DateTime? date,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isFavorite,
    Map<String, dynamic>? metadata,
  }) {
    return MoodEntry(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      mood: mood ?? this.mood,
      title: title ?? this.title,
      content: content ?? this.content,
      activities: activities ?? this.activities,
      imageUrls: imageUrls ?? this.imageUrls,
      date: date ?? this.date,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isFavorite: isFavorite ?? this.isFavorite,
      metadata: metadata ?? this.metadata,
    );
  }

  // JSON 직렬화
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'mood': mood.index,
      'title': title,
      'content': content,
      'activities': activities,
      'imageUrls': imageUrls,
      'date': date.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'isFavorite': isFavorite,
    };
  }

  // JSON에서 MoodEntry 생성
  factory MoodEntry.fromJson(Map<String, dynamic> json) {
    return MoodEntry(
      id: json['id'],
      userId: json['userId'],
      mood: MoodType.values[json['mood']],
      title: json['title'],
      content: json['content'],
      activities: List<String>.from(json['activities']),
      imageUrls: List<String>.from(json['imageUrls']),
      date: DateTime.parse(json['date']),
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: DateTime.parse(json['updatedAt']),
      isFavorite: json['isFavorite'] ?? false,
    );
  }

  @override
  String toString() {
    return 'MoodEntry(id: $id, mood: ${mood.label}, title: $title, date: $date)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is MoodEntry && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
} 