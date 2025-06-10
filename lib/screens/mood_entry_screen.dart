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
import '../services/activity_service.dart';
import '../services/template_service.dart';

class MoodEntryScreen extends StatefulWidget {
  final MoodEntry? existingEntry; // 수정할 기존 일기 (없으면 새 일기)
  final DateTime? preselectedDate; // 미리 선택된 날짜
  
  const MoodEntryScreen({
    super.key,
    this.existingEntry,
    this.preselectedDate,
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
  List<Activity> _availableActivities = [];
  List<DiaryTemplate> _availableTemplates = []; // 템플릿 목록 추가
  bool _isSaving = false;
  bool _isLoadingActivities = false;
  bool _isLoadingTemplates = false; // 템플릿 로딩 상태 추가

  @override
  void initState() {
    super.initState();
    _initializeFields();
    _loadActivities();
    _loadTemplates(); // 템플릿 로드 추가
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
    } else if (widget.preselectedDate != null) {
      // 새 일기 작성 시 미리 선택된 날짜 사용
      _selectedDate = widget.preselectedDate!;
    }
  }

  Future<void> _loadActivities() async {
    setState(() => _isLoadingActivities = true);
    try {
      final activities = await ActivityService.instance.getAllActiveActivities();
      if (mounted) {
        setState(() {
          _availableActivities = activities;
          _isLoadingActivities = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingActivities = false);
      }
    }
  }

  // 템플릿 로드 메서드 추가
  Future<void> _loadTemplates() async {
    setState(() => _isLoadingTemplates = true);
    try {
      final templates = await TemplateService.instance.getAllActiveTemplates();
      if (mounted) {
        setState(() {
          _availableTemplates = templates;
          _isLoadingTemplates = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingTemplates = false);
      }
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
                Expanded(
                  child: Text(
                    '오늘 하루는 어땠나요?',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                // 템플릿 선택 버튼 추가
                TextButton.icon(
                  onPressed: _showTemplateDialog,
                  icon: const Icon(Icons.article, size: 16),
                  label: const Text('템플릿'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    minimumSize: Size.zero,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSizes.paddingS,
                      vertical: AppSizes.paddingXS,
                    ),
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
            
            // 이미지 추가 버튼들
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _pickImageFromGallery(),
                    icon: const Icon(Icons.photo_library),
                    label: const Text('갤러리'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppSizes.radiusM),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppSizes.paddingM),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _pickImageFromCamera(),
                    icon: const Icon(Icons.camera_alt),
                    label: const Text('카메라'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.secondary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppSizes.radiusM),
                      ),
                    ),
                  ),
                ),
              ],
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

  // 갤러리에서 이미지 선택
  Future<void> _pickImageFromGallery() async {
    try {
      print('갤러리에서 이미지 선택 시작');
      
      final imageService = ImageService.instance;
      final imagePath = await imageService.pickImageFromGallery();
      
      if (imagePath != null && imagePath.isNotEmpty) {
        setState(() {
          _imageUrls.add(imagePath);
        });
        print('갤러리에서 이미지가 성공적으로 추가되었습니다: $imagePath');
        
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('📸 갤러리에서 사진을 추가했습니다!'),
              backgroundColor: AppColors.success,
              duration: Duration(seconds: 2),
            ),
          );
        }
      } else {
        print('갤러리에서 이미지 선택이 취소되었습니다');
      }
    } catch (e) {
      print('갤러리 이미지 선택 오류: $e');
      
      if (context.mounted) {
        String errorMessage = '갤러리에서 사진을 선택할 수 없습니다.';
        if (e.toString().contains('권한')) {
          errorMessage = '갤러리 접근 권한이 필요합니다. 설정에서 권한을 허용해주세요.';
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: AppColors.error,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  // 카메라로 사진 촬영
  Future<void> _pickImageFromCamera() async {
    try {
      print('카메라로 사진 촬영 시작');
      
      final imageService = ImageService.instance;
      final imagePath = await imageService.pickImageFromCamera();
      
      if (imagePath != null && imagePath.isNotEmpty) {
        setState(() {
          _imageUrls.add(imagePath);
        });
        print('카메라에서 이미지가 성공적으로 추가되었습니다: $imagePath');
        
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('📷 카메라로 사진을 촬영했습니다!'),
              backgroundColor: AppColors.success,
              duration: Duration(seconds: 2),
            ),
          );
        }
      } else {
        print('카메라에서 사진 촬영이 취소되었습니다');
      }
    } catch (e) {
      print('카메라 사진 촬영 오류: $e');
      
      if (context.mounted) {
        String errorMessage = '카메라로 사진을 촬영할 수 없습니다.';
        if (e.toString().contains('권한')) {
          errorMessage = '카메라 접근 권한이 필요합니다. 설정에서 권한을 허용해주세요.';
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: AppColors.error,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _addImage() async {
    try {
      print('사진 추가 버튼이 눌렸습니다');
      
      final imageService = ImageService.instance;
      print('ImageService 인스턴스 가져오기 완료');
      
      final imagePath = await imageService.showImagePickerDialog(context);
      print('이미지 선택 다이얼로그 결과: $imagePath');
      
      if (imagePath != null && imagePath.isNotEmpty) {
        setState(() {
          _imageUrls.add(imagePath);
        });
        print('이미지가 성공적으로 추가되었습니다: $imagePath');
        
        // 성공 메시지 표시
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('📸 사진이 추가되었습니다!'),
              backgroundColor: AppColors.success,
              duration: Duration(seconds: 2),
            ),
          );
        }
      } else {
        print('이미지 선택이 취소되었거나 실패했습니다');
      }
    } catch (e) {
      print('이미지 추가 중 오류 발생: $e');
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('사진 추가 실패: $e'),
            backgroundColor: AppColors.error,
            duration: const Duration(seconds: 3),
          ),
        );
      }
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
                Expanded(
                  child: Text(
                    '오늘 한 활동들',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: () => _navigateToActivityManagement(),
                  icon: const Icon(Icons.settings, size: 16),
                  label: const Text('관리'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    minimumSize: Size.zero,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSizes.paddingS,
                      vertical: AppSizes.paddingXS,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSizes.paddingM),
            
            if (_isLoadingActivities)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(AppSizes.paddingM),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_availableActivities.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSizes.paddingM),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(AppSizes.radiusM),
                  border: Border.all(
                    color: theme.colorScheme.outline.withOpacity(0.2),
                  ),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.add_circle_outline,
                      size: 32,
                      color: theme.colorScheme.onSurface.withOpacity(0.4),
                    ),
                    const SizedBox(height: AppSizes.paddingS),
                    Text(
                      '활동이 없습니다',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.6),
                      ),
                    ),
                    const SizedBox(height: AppSizes.paddingXS),
                    Text(
                      '관리 버튼을 눌러 활동을 추가해보세요',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.4),
                      ),
                    ),
                  ],
                ),
              )
            else
              Wrap(
                spacing: AppSizes.paddingS,
                runSpacing: AppSizes.paddingS,
                children: _availableActivities.map((activity) {
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

  void _navigateToActivityManagement() async {
    final result = await Navigator.of(context).pushNamed('/activity_management');
    if (result == true) {
      // 활동 목록이 변경되었으면 다시 로드
      _loadActivities();
    }
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
        // 활동 사용 횟수 증가 (비동기로 처리하여 UI 블로킹 방지)
        ActivityService.instance.incrementActivityUsage(activityId);
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

  // 템플릿 선택 다이얼로그 추가
  void _showTemplateDialog() {
    if (_availableTemplates.isEmpty && !_isLoadingTemplates) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('사용 가능한 템플릿이 없습니다')),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.5,
        expand: false,
        builder: (context, scrollController) => Container(
          padding: const EdgeInsets.all(AppSizes.paddingM),
          child: Column(
            children: [
              // 핸들바
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: AppSizes.paddingM),
              Row(
                children: [
                  Icon(Icons.article, color: AppColors.primary),
                  const SizedBox(width: AppSizes.paddingS),
                  const Text(
                    '템플릿 선택',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('취소'),
                  ),
                ],
              ),
              const SizedBox(height: AppSizes.paddingM),
              Expanded(
                child: _isLoadingTemplates
                    ? const Center(child: CircularProgressIndicator())
                    : ListView.builder(
                        controller: scrollController,
                        itemCount: _availableTemplates.length,
                        itemBuilder: (context, index) {
                          final template = _availableTemplates[index];
                          return Card(
                            margin: const EdgeInsets.only(bottom: AppSizes.paddingS),
                            child: ListTile(
                              leading: Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(AppSizes.radiusS),
                                ),
                                child: const Icon(
                                  Icons.article,
                                  color: AppColors.primary,
                                ),
                              ),
                              title: Text(
                                template.name,
                                style: const TextStyle(fontWeight: FontWeight.w500),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (template.description != null)
                                    Text(template.description!),
                                ],
                              ),
                              onTap: () => _applyTemplate(template),
                              trailing: const Icon(Icons.chevron_right),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 템플릿 적용 메서드 추가
  void _applyTemplate(DiaryTemplate template) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${template.name} 템플릿 적용'),
        content: Text('현재 작성 중인 내용이 템플릿으로 대체됩니다.\n계속하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context); // 다이얼로그 닫기
              Navigator.pop(context); // 템플릿 선택 닫기
              
              setState(() {
                _contentController.text = template.content;
              });
              
              // 템플릿 사용 횟수 증가
              TemplateService.instance.incrementTemplateUsage(template.id);
              
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('${template.name} 템플릿이 적용되었습니다'),
                  backgroundColor: AppColors.success,
                ),
              );
            },
            child: const Text('적용'),
          ),
        ],
      ),
    );
  }
} 