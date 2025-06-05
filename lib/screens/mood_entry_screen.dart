import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'dart:io';
import '../constants/app_colors.dart';
import '../constants/app_sizes.dart';
import '../models/mood_entry_model.dart';
import '../models/activity_model.dart';
import '../widgets/emotion_selector.dart';
import '../widgets/activity_chip.dart';
import '../services/local_storage_service.dart';
import '../services/image_service.dart';

class MoodEntryScreen extends StatefulWidget {
  final MoodEntry? existingEntry; // 수정할 기존 일기 (없으면 새 일기)
  
  const MoodEntryScreen({
    super.key,
    this.existingEntry,
  });

  @override
  State<MoodEntryScreen> createState() => _MoodEntryScreenState();
}

class _MoodEntryScreenState extends State<MoodEntryScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  
  MoodType _selectedMood = MoodType.neutral;
  DateTime _selectedDate = DateTime.now();
  List<String> _selectedActivities = [];
  List<String> _imageUrls = []; // 이미지 경로 목록
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _initializeFields();
  }

  void _initializeFields() {
    if (widget.existingEntry != null) {
      final entry = widget.existingEntry!;
      _titleController.text = entry.title ?? '';
      _contentController.text = entry.content;
      _selectedMood = entry.mood;
      _selectedDate = entry.date;
      _selectedActivities = List.from(entry.activities);
      _imageUrls = List.from(entry.imageUrls); // 기존 이미지들 로드
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isEditing = widget.existingEntry != null;
    
    return Scaffold(
      backgroundColor: theme.colorScheme.background,
      appBar: AppBar(
        title: Text(isEditing ? '일기 수정' : '새 일기 작성'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => _handleBackPressed(),
        ),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _saveEntry,
            child: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(
                    '저장',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.all(AppSizes.paddingM),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  _buildDateSection(),
                  const SizedBox(height: AppSizes.paddingL),
                  _buildMoodSection(),
                  const SizedBox(height: AppSizes.paddingL),
                  _buildTitleSection(),
                  const SizedBox(height: AppSizes.paddingM),
                  _buildContentSection(),
                  const SizedBox(height: AppSizes.paddingL),
                  _buildImageSection(),
                  const SizedBox(height: AppSizes.paddingL),
                  _buildActivitySection(),
                  const SizedBox(height: AppSizes.paddingXXL),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateSection() {
    final theme = Theme.of(context);
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.paddingM),
        child: Row(
          children: [
            Icon(
              Icons.calendar_today,
              color: AppColors.primary,
              size: AppSizes.iconM,
            ),
            const SizedBox(width: AppSizes.paddingM),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '날짜',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.7),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    DateFormat('yyyy년 MM월 dd일 EEEE', 'ko_KR').format(_selectedDate),
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: _selectDate,
              icon: const Icon(Icons.edit),
              color: AppColors.primary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMoodSection() {
    final theme = Theme.of(context);
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.paddingM),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.emoji_emotions,
                  color: AppColors.primary,
                  size: AppSizes.iconM,
                ),
                const SizedBox(width: AppSizes.paddingM),
                Text(
                  '오늘 기분은 어땠나요?',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSizes.paddingM),
            EmotionSelector(
              selectedMood: _selectedMood,
              onMoodSelected: (mood) {
                setState(() {
                  _selectedMood = mood;
                });
              },
            ),
            const SizedBox(height: AppSizes.paddingS),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSizes.paddingM),
              decoration: BoxDecoration(
                color: _getMoodColor(_selectedMood).withOpacity(0.1),
                borderRadius: BorderRadius.circular(AppSizes.radiusM),
                border: Border.all(
                  color: _getMoodColor(_selectedMood).withOpacity(0.3),
                ),
              ),
              child: Text(
                _selectedMood.description,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: _getMoodColor(_selectedMood),
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTitleSection() {
    final theme = Theme.of(context);
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.paddingM),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.title,
                  color: AppColors.primary,
                  size: AppSizes.iconM,
                ),
                const SizedBox(width: AppSizes.paddingM),
                Text(
                  '제목 (선택사항)',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSizes.paddingM),
            TextFormField(
              controller: _titleController,
              decoration: InputDecoration(
                hintText: '오늘 하루를 한 줄로 표현해보세요',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppSizes.radiusM),
                  borderSide: BorderSide(
                    color: theme.colorScheme.outline.withOpacity(0.3),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppSizes.radiusM),
                  borderSide: const BorderSide(
                    color: AppColors.primary,
                    width: 2,
                  ),
                ),
                contentPadding: const EdgeInsets.all(AppSizes.paddingM),
              ),
              maxLength: 50,
              style: theme.textTheme.bodyLarge,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContentSection() {
    final theme = Theme.of(context);
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.paddingM),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.edit_note,
                  color: AppColors.primary,
                  size: AppSizes.iconM,
                ),
                const SizedBox(width: AppSizes.paddingM),
                Text(
                  '오늘 하루는 어땠나요?',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                Text(
                  '(선택사항)',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.6),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSizes.paddingM),
            TextFormField(
              controller: _contentController,
              decoration: InputDecoration(
                hintText: '오늘 있었던 일들, 느낀 감정들을 자유롭게 적어보세요...\n(내용을 입력하지 않아도 저장됩니다)',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppSizes.radiusM),
                  borderSide: BorderSide(
                    color: theme.colorScheme.outline.withOpacity(0.3),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppSizes.radiusM),
                  borderSide: const BorderSide(
                    color: AppColors.primary,
                    width: 2,
                  ),
                ),
                contentPadding: const EdgeInsets.all(AppSizes.paddingM),
              ),
              maxLines: 8,
              minLines: 5,
              style: theme.textTheme.bodyLarge,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageSection() {
    final theme = Theme.of(context);
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.paddingM),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.image,
                  color: AppColors.primary,
                  size: AppSizes.iconM,
                ),
                const SizedBox(width: AppSizes.paddingM),
                Text(
                  '오늘 하루의 사진',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                Text(
                  '(선택사항)',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.6),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSizes.paddingM),
            
            // 이미지 추가 버튼
            InkWell(
              onTap: _addImage,
              borderRadius: BorderRadius.circular(AppSizes.radiusM),
              child: Container(
                width: double.infinity,
                height: 100,
                decoration: BoxDecoration(
                  border: Border.all(
                    color: theme.colorScheme.outline.withOpacity(0.3),
                    style: BorderStyle.solid,
                  ),
                  borderRadius: BorderRadius.circular(AppSizes.radiusM),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.add_photo_alternate,
                      size: 32,
                      color: theme.colorScheme.onSurface.withOpacity(0.6),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '사진 추가',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.6),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            // 선택된 이미지들 표시
            if (_imageUrls.isNotEmpty) ...[
              const SizedBox(height: AppSizes.paddingM),
              SizedBox(
                height: 120,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _imageUrls.length,
                  itemBuilder: (context, index) {
                    return Container(
                      margin: const EdgeInsets.only(right: AppSizes.paddingS),
                      child: _buildImageThumbnail(_imageUrls[index], index),
                    );
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildImageThumbnail(String imagePath, int index) {
    return Stack(
      children: [
        Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppSizes.radiusM),
            image: _buildImageDecoration(imagePath),
          ),
          child: _buildImageDecoration(imagePath) == null 
              ? Icon(
                  Icons.broken_image,
                  color: Colors.grey,
                  size: 40,
                )
              : null,
        ),
        Positioned(
          top: 4,
          right: 4,
          child: GestureDetector(
            onTap: () => _removeImage(index),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.6),
                shape: BoxShape.circle,
              ),
              padding: const EdgeInsets.all(4),
              child: const Icon(
                Icons.close,
                color: Colors.white,
                size: 16,
              ),
            ),
          ),
        ),
      ],
    );
  }

  DecorationImage? _buildImageDecoration(String imagePath) {
    if (kIsWeb) {
      // 웹에서는 메모리에서 이미지 로드
      final imageData = ImageService.instance.getWebImageData(imagePath);
      if (imageData != null) {
        return DecorationImage(
          image: MemoryImage(imageData),
          fit: BoxFit.cover,
        );
      }
    } else {
      // 모바일/데스크톱에서는 파일에서 이미지 로드
      final file = File(imagePath);
      if (file.existsSync()) {
        return DecorationImage(
          image: FileImage(file),
          fit: BoxFit.cover,
        );
      }
    }
    return null;
  }

  Future<void> _addImage() async {
    final imageService = ImageService.instance;
    final imagePath = await imageService.showImagePickerDialog(context);
    
    if (imagePath != null) {
      setState(() {
        _imageUrls.add(imagePath);
      });
    }
  }

  void _removeImage(int index) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('사진 삭제'),
        content: const Text('이 사진을 삭제하시겠어요?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              
              final imagePath = _imageUrls[index];
              setState(() {
                _imageUrls.removeAt(index);
              });
              
              // 이미지 파일 삭제 (기존 일기가 아닌 경우에만)
              if (widget.existingEntry == null) {
                await ImageService.instance.deleteImage(imagePath);
              }
            },
            style: TextButton.styleFrom(
              foregroundColor: AppColors.error,
            ),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
  }

  Widget _buildActivitySection() {
    final theme = Theme.of(context);
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.paddingM),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.local_activity,
                  color: AppColors.primary,
                  size: AppSizes.iconM,
                ),
                const SizedBox(width: AppSizes.paddingM),
                Text(
                  '오늘 한 활동들',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSizes.paddingM),
            Wrap(
              spacing: AppSizes.paddingS,
              runSpacing: AppSizes.paddingS,
              children: DefaultActivities.defaultActivities.map((activity) {
                final isSelected = _selectedActivities.contains(activity.id);
                return ActivityChip(
                  activity: activity,
                  isSelected: isSelected,
                  onTap: () => _toggleActivity(activity.id),
                );
              }).toList(),
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

  void _toggleActivity(String activityId) {
    setState(() {
      if (_selectedActivities.contains(activityId)) {
        _selectedActivities.remove(activityId);
      } else {
        _selectedActivities.add(activityId);
      }
    });
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
              primary: AppColors.primary,
            ),
          ),
          child: child!,
        );
      },
    );
    
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  void _handleBackPressed() {
    if (_hasUnsavedChanges()) {
      _showDiscardDialog();
    } else {
      Navigator.of(context).pop();
    }
  }

  bool _hasUnsavedChanges() {
    if (widget.existingEntry == null) {
      return _titleController.text.isNotEmpty || 
             _contentController.text.isNotEmpty ||
             _selectedActivities.isNotEmpty ||
             _imageUrls.isNotEmpty ||
             _selectedMood != MoodType.neutral;
    } else {
      final entry = widget.existingEntry!;
      return _titleController.text != (entry.title ?? '') ||
             _contentController.text != entry.content ||
             _selectedMood != entry.mood ||
             !_listsEqual(_selectedActivities, entry.activities) ||
             !_listsEqual(_imageUrls, entry.imageUrls);
    }
  }

  bool _listsEqual(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (!b.contains(a[i])) return false;
    }
    return true;
  }

  void _showDiscardDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('변경사항 취소'),
        content: const Text('작성 중인 내용이 있습니다. 정말 나가시겠어요?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('계속 작성'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop();
            },
            style: TextButton.styleFrom(
              foregroundColor: AppColors.error,
            ),
            child: const Text('나가기'),
          ),
        ],
      ),
    );
  }

  Future<void> _saveEntry() async {
    setState(() {
      _isSaving = true;
    });

    try {
      final storage = LocalStorageService.instance;
      final now = DateTime.now();
      
      final entry = MoodEntry(
        id: widget.existingEntry?.id ?? const Uuid().v4(),
        userId: 'local_user',
        mood: _selectedMood,
        title: _titleController.text.trim().isEmpty ? null : _titleController.text.trim(),
        content: _contentController.text.trim(),
        activities: _selectedActivities,
        imageUrls: _imageUrls,
        date: _selectedDate,
        createdAt: widget.existingEntry?.createdAt ?? now,
        updatedAt: now,
        isFavorite: widget.existingEntry?.isFavorite ?? false,
      );
      
      final success = await storage.saveMoodEntry(entry);
      
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
        
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(widget.existingEntry == null ? '일기가 저장되었습니다!' : '일기가 수정되었습니다!'),
              backgroundColor: AppColors.success,
              duration: const Duration(seconds: 2),
            ),
          );
          
          Navigator.of(context).pop(true);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('저장에 실패했습니다. 다시 시도해주세요.'),
              backgroundColor: AppColors.error,
              duration: Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('저장 중 오류가 발생했습니다: $e'),
            backgroundColor: AppColors.error,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }
} 