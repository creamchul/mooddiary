import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../constants/app_colors.dart';
import '../constants/app_sizes.dart';
import '../models/activity_model.dart';
import '../services/activity_service.dart';

class ActivityManagementScreen extends StatefulWidget {
  const ActivityManagementScreen({super.key});

  @override
  State<ActivityManagementScreen> createState() => _ActivityManagementScreenState();
}

class _ActivityManagementScreenState extends State<ActivityManagementScreen> with TickerProviderStateMixin {
  late TabController _tabController;
  final ActivityService _activityService = ActivityService.instance;
  
  List<Activity> _defaultActivities = [];
  List<Activity> _customActivities = [];
  Set<String> _hiddenActivities = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_onTabChanged);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    
    try {
      final defaultActivities = DefaultActivities.defaultActivities;
      final customActivities = await _activityService.getCustomActivities();
      final hiddenActivities = await _activityService.getHiddenActivities();
      
      if (mounted) {
        setState(() {
          _defaultActivities = defaultActivities;
          _customActivities = customActivities;
          _hiddenActivities = hiddenActivities;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showErrorSnackBar('데이터 로딩 중 오류가 발생했습니다: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      backgroundColor: theme.colorScheme.background,
      appBar: AppBar(
        title: const Text('활동 관리'),
        backgroundColor: theme.colorScheme.surface,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: '기본 활동'),
            Tab(text: '내 활동'),
          ],
          labelColor: AppColors.primary,
          unselectedLabelColor: theme.colorScheme.onSurface.withOpacity(0.6),
          indicatorColor: AppColors.primary,
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildDefaultActivitiesTab(),
                _buildCustomActivitiesTab(),
              ],
            ),
      floatingActionButton: _tabController.index == 1
          ? FloatingActionButton(
              onPressed: _showAddActivityDialog,
              backgroundColor: AppColors.primary,
              child: const Icon(Icons.add),
            )
          : null,
    );
  }

  Widget _buildDefaultActivitiesTab() {
    return Padding(
      padding: const EdgeInsets.all(AppSizes.paddingM),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSizes.paddingM),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: AppColors.info),
                  const SizedBox(width: AppSizes.paddingM),
                  Expanded(
                    child: Text(
                      '기본 활동은 숨기거나 보이게 할 수 있습니다.\n숨긴 활동은 일기 작성 시 표시되지 않습니다.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSizes.paddingM),
          Expanded(
            child: ListView.builder(
              itemCount: _defaultActivities.length,
              itemBuilder: (context, index) {
                final activity = _defaultActivities[index];
                final isHidden = _hiddenActivities.contains(activity.id);
                
                return Card(
                  margin: const EdgeInsets.only(bottom: AppSizes.paddingS),
                  child: ListTile(
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Color(int.parse(activity.color.substring(1), radix: 16) + 0xFF000000)
                            .withOpacity(isHidden ? 0.3 : 0.2),
                        borderRadius: BorderRadius.circular(AppSizes.radiusS),
                      ),
                      child: Center(
                        child: Text(
                          activity.emoji,
                          style: TextStyle(
                            fontSize: 20,
                            color: isHidden ? Colors.grey : null,
                          ),
                        ),
                      ),
                    ),
                    title: Text(
                      activity.name,
                      style: TextStyle(
                        color: isHidden ? Colors.grey : null,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    subtitle: activity.description != null
                        ? Text(
                            activity.description!,
                            style: TextStyle(
                              color: isHidden ? Colors.grey.withOpacity(0.7) : null,
                            ),
                          )
                        : null,
                    trailing: Switch(
                      value: !isHidden,
                      onChanged: (value) => _toggleDefaultActivity(activity.id),
                      activeColor: AppColors.primary,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomActivitiesTab() {
    return Padding(
      padding: const EdgeInsets.all(AppSizes.paddingM),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_customActivities.isEmpty)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.add_circle_outline,
                      size: 64,
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
                    ),
                    const SizedBox(height: AppSizes.paddingM),
                    Text(
                      '아직 추가된 활동이 없습니다',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                      ),
                    ),
                    const SizedBox(height: AppSizes.paddingS),
                    Text(
                      '+ 버튼을 눌러 나만의 활동을 추가해보세요',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            Expanded(
              child: ListView.builder(
                itemCount: _customActivities.length,
                itemBuilder: (context, index) {
                  final activity = _customActivities[index];
                  
                  return Card(
                    margin: const EdgeInsets.only(bottom: AppSizes.paddingS),
                    child: ListTile(
                      leading: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Color(int.parse(activity.color.substring(1), radix: 16) + 0xFF000000)
                              .withOpacity(0.2),
                          borderRadius: BorderRadius.circular(AppSizes.radiusS),
                        ),
                        child: Center(
                          child: Text(
                            activity.emoji,
                            style: const TextStyle(fontSize: 20),
                          ),
                        ),
                      ),
                      title: Text(
                        activity.name,
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (activity.description != null && activity.description!.isNotEmpty)
                            Text(activity.description!),
                          Text(
                            '사용 횟수: ${activity.usageCount}회',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                            ),
                          ),
                        ],
                      ),
                      trailing: PopupMenuButton<String>(
                        onSelected: (value) {
                          switch (value) {
                            case 'edit':
                              _showEditActivityDialog(activity);
                              break;
                            case 'delete':
                              _showDeleteConfirmDialog(activity);
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
                          PopupMenuItem(
                            value: 'delete',
                            child: Row(
                              children: [
                                Icon(Icons.delete, size: 16, color: AppColors.error),
                                const SizedBox(width: 8),
                                Text('삭제', style: TextStyle(color: AppColors.error)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _toggleDefaultActivity(String activityId) async {
    final success = await _activityService.toggleDefaultActivityVisibility(activityId);
    if (success) {
      await _loadData();
    } else {
      _showErrorSnackBar('활동 설정 변경에 실패했습니다');
    }
  }

  void _showAddActivityDialog() {
    _showActivityDialog();
  }

  void _showEditActivityDialog(Activity activity) {
    _showActivityDialog(activity: activity);
  }

  void _showActivityDialog({Activity? activity}) {
    final isEditing = activity != null;
    final nameController = TextEditingController(text: activity?.name ?? '');
    final descriptionController = TextEditingController(text: activity?.description ?? '');
    String selectedEmoji = activity?.emoji ?? '📝';
    Color selectedColor = activity != null
        ? Color(int.parse(activity.color.substring(1), radix: 16) + 0xFF000000)
        : AppColors.primary;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(isEditing ? '활동 수정' : '새 활동 추가'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: '활동 이름',
                    hintText: '예: 독서, 산책, 요리 등',
                  ),
                  maxLength: 20,
                ),
                const SizedBox(height: AppSizes.paddingM),
                TextField(
                  controller: descriptionController,
                  decoration: const InputDecoration(
                    labelText: '설명 (선택사항)',
                    hintText: '이 활동에 대한 간단한 설명',
                  ),
                  maxLength: 50,
                  maxLines: 2,
                ),
                const SizedBox(height: AppSizes.paddingM),
                Row(
                  children: [
                    const Text('이모지: '),
                    const SizedBox(width: AppSizes.paddingS),
                    GestureDetector(
                      onTap: () => _showEmojiPicker(context, (emoji) {
                        setDialogState(() => selectedEmoji = emoji);
                      }),
                      child: Container(
                        padding: const EdgeInsets.all(AppSizes.paddingS),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey),
                          borderRadius: BorderRadius.circular(AppSizes.radiusS),
                        ),
                        child: Text(selectedEmoji, style: const TextStyle(fontSize: 24)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSizes.paddingM),
                Row(
                  children: [
                    const Text('색상: '),
                    const SizedBox(width: AppSizes.paddingS),
                    GestureDetector(
                      onTap: () => _showColorPicker(context, selectedColor, (color) {
                        setDialogState(() => selectedColor = color);
                      }),
                      child: Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          color: selectedColor,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.grey),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('취소'),
            ),
            TextButton(
              onPressed: () => _saveActivity(
                context,
                activity?.id,
                nameController.text,
                descriptionController.text,
                selectedEmoji,
                selectedColor,
                activity?.usageCount ?? 0,
                activity?.createdAt,
              ),
              child: Text(isEditing ? '수정' : '추가'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEmojiPicker(BuildContext context, Function(String) onEmojiSelected) {
    final emojis = ['📝', '💼', '🏃‍♀️', '📚', '👥', '🎨', '✈️', '🍽️', '😴', '🛍️', 
                   '🎬', '🎵', '🎮', '📱', '🚗', '🏠', '⚽', '🎯', '💰', '❤️',
                   '🌟', '🔥', '⭐', '🎉', '🎊', '💎', '🌈', '🌸', '🍀', '🎭'];
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('이모지 선택'),
        content: SizedBox(
          width: 300,
          height: 200,
          child: GridView.builder(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 6,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
            ),
            itemCount: emojis.length,
            itemBuilder: (context, index) => GestureDetector(
              onTap: () {
                onEmojiSelected(emojis[index]);
                Navigator.pop(context);
              },
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.withOpacity(0.3)),
                  borderRadius: BorderRadius.circular(AppSizes.radiusS),
                ),
                child: Center(
                  child: Text(emojis[index], style: const TextStyle(fontSize: 24)),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showColorPicker(BuildContext context, Color currentColor, Function(Color) onColorSelected) {
    final colors = [
      AppColors.primary, AppColors.emotionBest, AppColors.emotionGood,
      AppColors.emotionNeutral, AppColors.emotionBad, AppColors.emotionWorst,
      Colors.red, Colors.pink, Colors.purple, Colors.deepPurple,
      Colors.indigo, Colors.blue, Colors.lightBlue, Colors.cyan,
      Colors.teal, Colors.green, Colors.lightGreen, Colors.lime,
      Colors.yellow, Colors.amber, Colors.orange, Colors.deepOrange,
      Colors.brown, Colors.grey, Colors.blueGrey,
    ];
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('색상 선택'),
        content: SizedBox(
          width: 300,
          height: 200,
          child: GridView.builder(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 6,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
            ),
            itemCount: colors.length,
            itemBuilder: (context, index) => GestureDetector(
              onTap: () {
                onColorSelected(colors[index]);
                Navigator.pop(context);
              },
              child: Container(
                decoration: BoxDecoration(
                  color: colors[index],
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: currentColor == colors[index] ? Colors.black : Colors.grey,
                    width: currentColor == colors[index] ? 3 : 1,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _saveActivity(
    BuildContext context,
    String? activityId,
    String name,
    String description,
    String emoji,
    Color color,
    int usageCount,
    DateTime? createdAt,
  ) async {
    if (name.trim().isEmpty) {
      _showErrorSnackBar('활동 이름을 입력해주세요');
      return;
    }

    final now = DateTime.now();
    final activity = Activity(
      id: activityId ?? const Uuid().v4(),
      name: name.trim(),
      description: description.trim().isEmpty ? null : description.trim(),
      emoji: emoji,
      color: '#${color.value.toRadixString(16).substring(2).toUpperCase()}',
      isDefault: false,
      userId: 'local_user',
      usageCount: usageCount,
      createdAt: createdAt ?? now,
      updatedAt: now,
      isActive: true,
    );

    bool success;
    if (activityId != null) {
      success = await _activityService.updateCustomActivity(activity);
    } else {
      success = await _activityService.addCustomActivity(activity);
    }

    if (success) {
      Navigator.pop(context);
      await _loadData();
      _showSuccessSnackBar(activityId != null ? '활동이 수정되었습니다' : '활동이 추가되었습니다');
    } else {
      _showErrorSnackBar('같은 이름의 활동이 이미 존재합니다');
    }
  }

  void _showDeleteConfirmDialog(Activity activity) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('활동 삭제'),
        content: Text('\'${activity.name}\' 활동을 삭제하시겠습니까?\n이 작업은 되돌릴 수 없습니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => _deleteActivity(context, activity),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteActivity(BuildContext context, Activity activity) async {
    Navigator.pop(context);
    
    final success = await _activityService.deleteCustomActivity(activity.id);
    if (success) {
      await _loadData();
      _showSuccessSnackBar('활동이 삭제되었습니다');
    } else {
      _showErrorSnackBar('활동 삭제에 실패했습니다');
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.error,
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.success,
      ),
    );
  }
} 