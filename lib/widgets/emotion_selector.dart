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

    return LayoutBuilder(
      builder: (context, constraints) {
        // 화면이 좁을 때는 작은 크기로 조정
        final isNarrow = constraints.maxWidth < 350;
        
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: orderedMoods.map((mood) {
            return Flexible(
              child: _buildEmotionButton(mood, isNarrow: isNarrow),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildEmotionButton(MoodType mood, {bool isNarrow = false}) {
    final isSelected = selectedMood == mood;
    final color = _getMoodColor(mood);
    
    // 화면 크기에 따른 동적 크기 조정
    final buttonSize = isNarrow ? AppSizes.emotionIconL : AppSizes.emotionIconXL;
    final fontSize = isNarrow ? 22.0 : 28.0;
    final labelSize = isNarrow ? 10.0 : 12.0;
    
    return GestureDetector(
      onTap: () => onMoodSelected(mood),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        constraints: BoxConstraints(
          maxWidth: buttonSize + 8, // 여백 추가
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: buttonSize,
              height: buttonSize,
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
                  style: TextStyle(fontSize: fontSize),
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              mood.label,
              style: TextStyle(
                fontSize: labelSize,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected ? color : Colors.grey[600],
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
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