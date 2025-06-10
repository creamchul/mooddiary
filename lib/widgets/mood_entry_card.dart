import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import '../constants/app_colors.dart';
import '../constants/app_sizes.dart';
import '../models/mood_entry_model.dart';
import '../models/activity_model.dart';
import '../services/image_service.dart';

class MoodEntryCard extends StatelessWidget {
  final MoodEntry entry;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onFavoriteToggle;

  const MoodEntryCard({
    super.key,
    required this.entry,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
    required this.onFavoriteToggle,
  });

  // 성능 최적화: 메모이제이션을 위한 키
  static ValueKey keyForEntry(String entryId) => ValueKey('mood_entry_$entryId');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final moodColor = _getMoodColor(entry.mood);
    
    return Card(
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSizes.radiusM),
        child: Padding(
          padding: const EdgeInsets.all(AppSizes.paddingM),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(theme, moodColor),
              const SizedBox(height: AppSizes.paddingS),
              _buildContent(theme),
              if (entry.imageUrls.isNotEmpty) ...[
                const SizedBox(height: AppSizes.paddingS),
                _buildImages(theme),
              ],
              if (entry.activities.isNotEmpty) ...[
                const SizedBox(height: AppSizes.paddingS),
                _buildActivities(theme),
              ],
              const SizedBox(height: AppSizes.paddingS),
              _buildFooter(theme),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme, Color moodColor) {
    return Row(
      children: [
        // 감정 표시
        Container(
          width: AppSizes.emotionIconL,
          height: AppSizes.emotionIconL,
          decoration: BoxDecoration(
            color: moodColor.withOpacity(0.2),
            borderRadius: BorderRadius.circular(AppSizes.radiusS),
            border: Border.all(
              color: moodColor.withOpacity(0.4),
            ),
          ),
          child: Center(
            child: Text(
              entry.mood.emoji,
              style: const TextStyle(fontSize: 20),
            ),
          ),
        ),
        const SizedBox(width: AppSizes.paddingM),
        
        // 제목과 날짜
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (entry.title != null && entry.title!.isNotEmpty) ...[
                Text(
                  entry.title!,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
              ],
              Text(
                DateFormat('MM월 dd일 (E)', 'ko_KR').format(entry.date),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.7),
                ),
              ),
            ],
          ),
        ),
        
        // 액션 버튼들
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              onPressed: onFavoriteToggle,
              icon: Icon(
                entry.isFavorite ? Icons.favorite : Icons.favorite_border,
                color: entry.isFavorite ? AppColors.error : null,
                size: AppSizes.iconS,
              ),
              constraints: const BoxConstraints(
                minWidth: 32,
                minHeight: 32,
              ),
              padding: EdgeInsets.zero,
            ),
            PopupMenuButton<String>(
              onSelected: (value) {
                switch (value) {
                  case 'edit':
                    onEdit();
                    break;
                  case 'delete':
                    onDelete();
                    break;
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      Icon(Icons.edit, size: 16),
                      SizedBox(width: 8),
                      Text('수정'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete, size: 16, color: AppColors.error),
                      SizedBox(width: 8),
                      Text('삭제', style: TextStyle(color: AppColors.error)),
                    ],
                  ),
                ),
              ],
              icon: Icon(
                Icons.more_vert,
                size: AppSizes.iconS,
                color: theme.colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildContent(ThemeData theme) {
    if (entry.content.isEmpty) return const SizedBox.shrink();
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSizes.paddingM),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
        borderRadius: BorderRadius.circular(AppSizes.radiusM),
        border: Border.all(
          color: theme.colorScheme.outline.withOpacity(0.1),
        ),
      ),
      child: Text(
        entry.content,
        style: theme.textTheme.bodyMedium?.copyWith(
          height: 1.5,
        ),
        // 전체 내용 표시 (maxLines 제거)
      ),
    );
  }

  Widget _buildImages(ThemeData theme) {
    return SizedBox(
      height: 80,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(), // 부드러운 스크롤
        itemCount: entry.imageUrls.length,
        itemBuilder: (context, index) {
          final imagePath = entry.imageUrls[index];
          return Container(
            margin: const EdgeInsets.only(right: AppSizes.paddingS),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppSizes.radiusS),
              child: AspectRatio(
                aspectRatio: 1,
                child: _buildImageWidget(imagePath, theme),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildImageWidget(String imagePath, ThemeData theme) {
    if (kIsWeb) {
      // 웹에서는 메모리에서 이미지 로드
      final imageData = ImageService.instance.getWebImageData(imagePath);
      if (imageData != null) {
        return Image.memory(
          imageData,
          fit: BoxFit.cover,
        );
      }
    } else {
      // 모바일/데스크톱에서는 파일에서 이미지 로드
      if (File(imagePath).existsSync()) {
        return Image.file(
          File(imagePath),
          fit: BoxFit.cover,
        );
      }
    }
    
    // 이미지를 로드할 수 없는 경우
    return Container(
      color: theme.colorScheme.surfaceVariant,
      child: Icon(
        Icons.broken_image,
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
  }

  Widget _buildActivities(ThemeData theme) {
    final activities = DefaultActivities.defaultActivities
        .where((activity) => entry.activities.contains(activity.id))
        .toList();

    return Wrap(
      spacing: AppSizes.paddingXS,
      runSpacing: AppSizes.paddingXS,
      children: activities.map((activity) {
        return Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSizes.paddingS,
            vertical: 2,
          ),
          decoration: BoxDecoration(
            color: _parseColor(activity.color).withOpacity(0.1),
            borderRadius: BorderRadius.circular(AppSizes.tagRadius),
            border: Border.all(
              color: _parseColor(activity.color).withOpacity(0.3),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                activity.emoji,
                style: const TextStyle(fontSize: 12),
              ),
              const SizedBox(width: 4),
              Text(
                activity.name,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontSize: 11,
                  color: _parseColor(activity.color),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildFooter(ThemeData theme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // 감정 라벨
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSizes.paddingS,
            vertical: 4,
          ),
          decoration: BoxDecoration(
            color: _getMoodColor(entry.mood).withOpacity(0.1),
            borderRadius: BorderRadius.circular(AppSizes.tagRadius),
          ),
          child: Text(
            entry.mood.label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: _getMoodColor(entry.mood),
              fontWeight: FontWeight.w500,
              fontSize: 11,
            ),
          ),
        ),
        
        // 작성 시간
        Text(
          DateFormat('HH:mm').format(entry.createdAt),
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withOpacity(0.5),
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  Color _getMoodColor(MoodType mood) {
    switch (mood) {
      case MoodType.best:
        return AppColors.emotionBest;
      case MoodType.good:
        return AppColors.emotionGood;
      case MoodType.neutral:
        return AppColors.emotionNeutral;
      case MoodType.bad:
        return AppColors.emotionBad;
      case MoodType.worst:
        return AppColors.emotionWorst;
    }
  }

  Color _parseColor(String colorHex) {
    try {
      return Color(int.parse(colorHex.replaceFirst('#', '0xFF')));
    } catch (e) {
      return AppColors.primary;
    }
  }
} 