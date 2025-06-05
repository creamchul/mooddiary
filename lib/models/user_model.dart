import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String id;
  final String email;
  final String? displayName;
  final String? photoUrl;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? lastLoginAt;
  final UserPreferences preferences;
  final UserStatistics statistics;

  UserModel({
    required this.id,
    required this.email,
    this.displayName,
    this.photoUrl,
    required this.createdAt,
    required this.updatedAt,
    this.lastLoginAt,
    required this.preferences,
    required this.statistics,
  });

  // Firestore 문서에서 UserModel 생성
  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    return UserModel(
      id: doc.id,
      email: data['email'] ?? '',
      displayName: data['displayName'],
      photoUrl: data['photoUrl'],
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: (data['updatedAt'] as Timestamp).toDate(),
      lastLoginAt: data['lastLoginAt'] != null 
          ? (data['lastLoginAt'] as Timestamp).toDate()
          : null,
      preferences: UserPreferences.fromMap(data['preferences'] ?? {}),
      statistics: UserStatistics.fromMap(data['statistics'] ?? {}),
    );
  }

  // Firestore에 저장할 Map 생성
  Map<String, dynamic> toFirestore() {
    return {
      'email': email,
      'displayName': displayName,
      'photoUrl': photoUrl,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'lastLoginAt': lastLoginAt != null 
          ? Timestamp.fromDate(lastLoginAt!)
          : null,
      'preferences': preferences.toMap(),
      'statistics': statistics.toMap(),
    };
  }

  // 복사본 생성
  UserModel copyWith({
    String? id,
    String? email,
    String? displayName,
    String? photoUrl,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? lastLoginAt,
    UserPreferences? preferences,
    UserStatistics? statistics,
  }) {
    return UserModel(
      id: id ?? this.id,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      photoUrl: photoUrl ?? this.photoUrl,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
      preferences: preferences ?? this.preferences,
      statistics: statistics ?? this.statistics,
    );
  }

  @override
  String toString() {
    return 'UserModel(id: $id, email: $email, displayName: $displayName)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is UserModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

// 사용자 환경설정
class UserPreferences {
  final bool isDarkMode;
  final String language;
  final bool enableNotifications;
  final bool enableBackup;
  final String defaultMoodReminderTime; // "HH:mm" 형식
  final List<String> favoriteActivities;
  final Map<String, dynamic> customSettings;

  UserPreferences({
    this.isDarkMode = false,
    this.language = 'ko',
    this.enableNotifications = true,
    this.enableBackup = true,
    this.defaultMoodReminderTime = '21:00',
    this.favoriteActivities = const [],
    this.customSettings = const {},
  });

  factory UserPreferences.fromMap(Map<String, dynamic> map) {
    return UserPreferences(
      isDarkMode: map['isDarkMode'] ?? false,
      language: map['language'] ?? 'ko',
      enableNotifications: map['enableNotifications'] ?? true,
      enableBackup: map['enableBackup'] ?? true,
      defaultMoodReminderTime: map['defaultMoodReminderTime'] ?? '21:00',
      favoriteActivities: List<String>.from(map['favoriteActivities'] ?? []),
      customSettings: Map<String, dynamic>.from(map['customSettings'] ?? {}),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'isDarkMode': isDarkMode,
      'language': language,
      'enableNotifications': enableNotifications,
      'enableBackup': enableBackup,
      'defaultMoodReminderTime': defaultMoodReminderTime,
      'favoriteActivities': favoriteActivities,
      'customSettings': customSettings,
    };
  }

  UserPreferences copyWith({
    bool? isDarkMode,
    String? language,
    bool? enableNotifications,
    bool? enableBackup,
    String? defaultMoodReminderTime,
    List<String>? favoriteActivities,
    Map<String, dynamic>? customSettings,
  }) {
    return UserPreferences(
      isDarkMode: isDarkMode ?? this.isDarkMode,
      language: language ?? this.language,
      enableNotifications: enableNotifications ?? this.enableNotifications,
      enableBackup: enableBackup ?? this.enableBackup,
      defaultMoodReminderTime: defaultMoodReminderTime ?? this.defaultMoodReminderTime,
      favoriteActivities: favoriteActivities ?? this.favoriteActivities,
      customSettings: customSettings ?? this.customSettings,
    );
  }
}

// 사용자 통계
class UserStatistics {
  final int totalEntries;
  final int consecutiveDays;
  final int maxConsecutiveDays;
  final Map<String, int> moodCounts; // MoodType별 개수
  final Map<String, int> activityCounts; // Activity별 개수
  final DateTime? firstEntryDate;
  final DateTime? lastEntryDate;
  final double averageMoodScore;
  final int totalPhotos;
  final int favoriteEntries;

  UserStatistics({
    this.totalEntries = 0,
    this.consecutiveDays = 0,
    this.maxConsecutiveDays = 0,
    this.moodCounts = const {},
    this.activityCounts = const {},
    this.firstEntryDate,
    this.lastEntryDate,
    this.averageMoodScore = 0.0,
    this.totalPhotos = 0,
    this.favoriteEntries = 0,
  });

  factory UserStatistics.fromMap(Map<String, dynamic> map) {
    return UserStatistics(
      totalEntries: map['totalEntries'] ?? 0,
      consecutiveDays: map['consecutiveDays'] ?? 0,
      maxConsecutiveDays: map['maxConsecutiveDays'] ?? 0,
      moodCounts: Map<String, int>.from(map['moodCounts'] ?? {}),
      activityCounts: Map<String, int>.from(map['activityCounts'] ?? {}),
      firstEntryDate: map['firstEntryDate'] != null
          ? (map['firstEntryDate'] as Timestamp).toDate()
          : null,
      lastEntryDate: map['lastEntryDate'] != null
          ? (map['lastEntryDate'] as Timestamp).toDate()
          : null,
      averageMoodScore: (map['averageMoodScore'] ?? 0.0).toDouble(),
      totalPhotos: map['totalPhotos'] ?? 0,
      favoriteEntries: map['favoriteEntries'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'totalEntries': totalEntries,
      'consecutiveDays': consecutiveDays,
      'maxConsecutiveDays': maxConsecutiveDays,
      'moodCounts': moodCounts,
      'activityCounts': activityCounts,
      'firstEntryDate': firstEntryDate != null
          ? Timestamp.fromDate(firstEntryDate!)
          : null,
      'lastEntryDate': lastEntryDate != null
          ? Timestamp.fromDate(lastEntryDate!)
          : null,
      'averageMoodScore': averageMoodScore,
      'totalPhotos': totalPhotos,
      'favoriteEntries': favoriteEntries,
    };
  }

  UserStatistics copyWith({
    int? totalEntries,
    int? consecutiveDays,
    int? maxConsecutiveDays,
    Map<String, int>? moodCounts,
    Map<String, int>? activityCounts,
    DateTime? firstEntryDate,
    DateTime? lastEntryDate,
    double? averageMoodScore,
    int? totalPhotos,
    int? favoriteEntries,
  }) {
    return UserStatistics(
      totalEntries: totalEntries ?? this.totalEntries,
      consecutiveDays: consecutiveDays ?? this.consecutiveDays,
      maxConsecutiveDays: maxConsecutiveDays ?? this.maxConsecutiveDays,
      moodCounts: moodCounts ?? this.moodCounts,
      activityCounts: activityCounts ?? this.activityCounts,
      firstEntryDate: firstEntryDate ?? this.firstEntryDate,
      lastEntryDate: lastEntryDate ?? this.lastEntryDate,
      averageMoodScore: averageMoodScore ?? this.averageMoodScore,
      totalPhotos: totalPhotos ?? this.totalPhotos,
      favoriteEntries: favoriteEntries ?? this.favoriteEntries,
    );
  }
} 