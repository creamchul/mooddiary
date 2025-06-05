import 'package:cloud_firestore/cloud_firestore.dart';

enum MoodType {
  best,    // 최고 ✨
  good,    // 좋음 😊
  neutral, // 그저그래 😐
  bad,     // 별로 😕
  worst    // 최악 😓
}

extension MoodTypeExtension on MoodType {
  String get emoji {
    switch (this) {
      case MoodType.best:
        return '✨';
      case MoodType.good:
        return '😊';
      case MoodType.neutral:
        return '😐';
      case MoodType.bad:
        return '😕';
      case MoodType.worst:
        return '😓';
    }
  }
  
  String get label {
    switch (this) {
      case MoodType.best:
        return '최고';
      case MoodType.good:
        return '좋음';
      case MoodType.neutral:
        return '그저그래';
      case MoodType.bad:
        return '별로';
      case MoodType.worst:
        return '최악';
    }
  }
  
  String get description {
    switch (this) {
      case MoodType.best:
        return '오늘은 정말 최고의 하루였어요!';
      case MoodType.good:
        return '기분 좋은 하루였어요';
      case MoodType.neutral:
        return '평범한 하루였어요';
      case MoodType.bad:
        return '조금 아쉬운 하루였어요';
      case MoodType.worst:
        return '힘든 하루였어요';
    }
  }
  
  int get value {
    switch (this) {
      case MoodType.best:
        return 5;
      case MoodType.good:
        return 4;
      case MoodType.neutral:
        return 3;
      case MoodType.bad:
        return 2;
      case MoodType.worst:
        return 1;
    }
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