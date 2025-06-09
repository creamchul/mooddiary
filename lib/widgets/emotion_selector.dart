import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_sizes.dart';
import '../models/mood_entry_model.dart';

class EmotionSelector extends StatelessWidget {
  final MoodType selectedMood;
  final Function(MoodType) onMoodSelected;

  const EmotionSelector({
    super.key,
    required this.selectedMood,
    required this.onMoodSelected,
  });

  @override
  Widget build(BuildContext context) {
    // 감정 순서: 최고 → 좋음 → 보통 → 나쁨 → 최악
    final orderedMoods = [
      MoodType.best,
      MoodType.good,
      MoodType.neutral,
      MoodType.bad,
      MoodType.worst,
    ];

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: orderedMoods.map((mood) {
        return _buildEmotionButton(mood);
      }).toList(),
    );
  }

  Widget _buildEmotionButton(MoodType mood) {
    final isSelected = selectedMood == mood;
    final color = _getMoodColor(mood);
    
    return GestureDetector(
      onTap: () => onMoodSelected(mood),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        width: AppSizes.emotionIconXL,
        height: AppSizes.emotionIconXL + 24,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: AppSizes.emotionIconXL,
              height: AppSizes.emotionIconXL,
              decoration: BoxDecoration(
                color: isSelected 
                    ? color
                    : color.withOpacity(0.2),
                borderRadius: BorderRadius.circular(AppSizes.radiusL),
                border: Border.all(
                  color: isSelected 
                      ? color
                      : color.withOpacity(0.4),
                  width: isSelected ? 3 : 2,
                ),
                boxShadow: isSelected 
                    ? [
                        BoxShadow(
                          color: color.withOpacity(0.3),
                          blurRadius: 8,
                          spreadRadius: 2,
                        ),
                      ]
                    : null,
              ),
              child: Center(
                child: Text(
                  mood.emoji,
                  style: const TextStyle(fontSize: 28),
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              mood.label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected ? color : Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
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
} 