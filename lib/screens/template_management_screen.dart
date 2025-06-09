import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../constants/app_colors.dart';
import '../constants/app_sizes.dart';
import '../models/activity_model.dart';
import '../services/template_service.dart';

class TemplateManagementScreen extends StatefulWidget {
  const TemplateManagementScreen({super.key});

  @override
  State<TemplateManagementScreen> createState() => _TemplateManagementScreenState();
}

class _TemplateManagementScreenState extends State<TemplateManagementScreen> with TickerProviderStateMixin {
  late TabController _tabController;
  final TemplateService _templateService = TemplateService.instance;
  
  List<DiaryTemplate> _defaultTemplates = [];
  List<DiaryTemplate> _customTemplates = [];
  Set<String> _hiddenTemplates = {};
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
      final defaultTemplates = DefaultTemplates.defaultTemplates;
      final customTemplates = await _templateService.getCustomTemplates();
      final hiddenTemplates = await _templateService.getHiddenTemplates();
      
      if (mounted) {
        setState(() {
          _defaultTemplates = defaultTemplates;
          _customTemplates = customTemplates;
          _hiddenTemplates = hiddenTemplates;
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
        title: const Text('템플릿 관리'),
        backgroundColor: theme.colorScheme.surface,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: '기본 템플릿'),
            Tab(text: '내 템플릿'),
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
                _buildDefaultTemplatesTab(),
                _buildCustomTemplatesTab(),
              ],
            ),
      floatingActionButton: _tabController.index == 1
          ? FloatingActionButton(
              onPressed: _showAddTemplateDialog,
              backgroundColor: AppColors.primary,
              child: const Icon(Icons.add),
            )
          : null,
    );
  }

  Widget _buildDefaultTemplatesTab() {
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
                      '기본 템플릿은 숨기거나 보이게 할 수 있습니다.\n숨긴 템플릿은 일기 작성 시 표시되지 않습니다.',
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
              itemCount: _defaultTemplates.length,
              itemBuilder: (context, index) {
                final template = _defaultTemplates[index];
                final isHidden = _hiddenTemplates.contains(template.id);
                
                return Card(
                  margin: const EdgeInsets.only(bottom: AppSizes.paddingS),
                  child: ExpansionTile(
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(isHidden ? 0.1 : 0.2),
                        borderRadius: BorderRadius.circular(AppSizes.radiusS),
                      ),
                      child: Icon(
                        Icons.article,
                        color: isHidden ? Colors.grey : AppColors.primary,
                      ),
                    ),
                    title: Text(
                      template.name,
                      style: TextStyle(
                        color: isHidden ? Colors.grey : null,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    subtitle: Text(
                      template.description ?? '',
                      style: TextStyle(
                        color: isHidden ? Colors.grey.withOpacity(0.7) : null,
                      ),
                    ),
                    trailing: Switch(
                      value: !isHidden,
                      onChanged: (value) => _toggleDefaultTemplate(template.id),
                      activeColor: AppColors.primary,
                    ),
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(AppSizes.paddingM),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(AppSizes.paddingM),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(AppSizes.radiusS),
                          ),
                          child: Text(
                            template.content,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              fontFamily: 'monospace',
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomTemplatesTab() {
    return Padding(
      padding: const EdgeInsets.all(AppSizes.paddingM),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_customTemplates.isEmpty)
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
                      '아직 추가된 템플릿이 없습니다',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                      ),
                    ),
                    const SizedBox(height: AppSizes.paddingS),
                    Text(
                      '+ 버튼을 눌러 나만의 템플릿을 추가해보세요',
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
                itemCount: _customTemplates.length,
                itemBuilder: (context, index) {
                  final template = _customTemplates[index];
                  
                  return Card(
                    margin: const EdgeInsets.only(bottom: AppSizes.paddingS),
                    child: ExpansionTile(
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
                          if (template.description != null && template.description!.isNotEmpty)
                            Text(template.description!),
                          Text(
                            '사용 횟수: ${template.usageCount}회',
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
                              _showEditTemplateDialog(template);
                              break;
                            case 'delete':
                              _showDeleteConfirmDialog(template);
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
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(AppSizes.paddingM),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(AppSizes.paddingM),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
                              borderRadius: BorderRadius.circular(AppSizes.radiusS),
                            ),
                            child: Text(
                              template.content,
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                fontFamily: 'monospace',
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _toggleDefaultTemplate(String templateId) async {
    final success = await _templateService.toggleDefaultTemplateVisibility(templateId);
    if (success) {
      await _loadData();
    } else {
      _showErrorSnackBar('템플릿 설정 변경에 실패했습니다');
    }
  }

  void _showAddTemplateDialog() {
    _showTemplateDialog();
  }

  void _showEditTemplateDialog(DiaryTemplate template) {
    _showTemplateDialog(template: template);
  }

  void _showTemplateDialog({DiaryTemplate? template}) {
    final isEditing = template != null;
    final nameController = TextEditingController(text: template?.name ?? '');
    final descriptionController = TextEditingController(text: template?.description ?? '');
    final contentController = TextEditingController(text: template?.content ?? '');

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(isEditing ? '템플릿 수정' : '새 템플릿 추가'),
          content: SingleChildScrollView(
            child: SizedBox(
              width: MediaQuery.of(context).size.width * 0.8,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: '템플릿 이름',
                      hintText: '예: 감사 일기, 성장 기록 등',
                    ),
                    maxLength: 30,
                  ),
                  const SizedBox(height: AppSizes.paddingM),
                  TextField(
                    controller: descriptionController,
                    decoration: const InputDecoration(
                      labelText: '설명 (선택사항)',
                      hintText: '이 템플릿에 대한 간단한 설명',
                    ),
                    maxLength: 100,
                    maxLines: 2,
                  ),
                  const SizedBox(height: AppSizes.paddingM),
                  TextField(
                    controller: contentController,
                    decoration: const InputDecoration(
                      labelText: '템플릿 내용',
                      hintText: '일기 작성에 도움이 될 질문이나 구조를 입력하세요',
                      alignLabelWithHint: true,
                    ),
                    maxLines: 8,
                    maxLength: 1000,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('취소'),
            ),
            TextButton(
              onPressed: () => _saveTemplate(
                context,
                template?.id,
                nameController.text,
                descriptionController.text,
                contentController.text,
                template?.usageCount ?? 0,
                template?.createdAt,
              ),
              child: Text(isEditing ? '수정' : '추가'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveTemplate(
    BuildContext context,
    String? templateId,
    String name,
    String description,
    String content,
    int usageCount,
    DateTime? createdAt,
  ) async {
    if (name.trim().isEmpty) {
      _showErrorSnackBar('템플릿 이름을 입력해주세요');
      return;
    }

    if (content.trim().isEmpty) {
      _showErrorSnackBar('템플릿 내용을 입력해주세요');
      return;
    }

    final now = DateTime.now();
    final template = DiaryTemplate(
      id: templateId ?? const Uuid().v4(),
      name: name.trim(),
      description: description.trim().isEmpty ? null : description.trim(),
      content: content.trim(),
      isDefault: false,
      userId: 'local_user',
      usageCount: usageCount,
      createdAt: createdAt ?? now,
      updatedAt: now,
      isActive: true,
    );

    bool success;
    if (templateId != null) {
      success = await _templateService.updateCustomTemplate(template);
    } else {
      success = await _templateService.addCustomTemplate(template);
    }

    if (success) {
      Navigator.pop(context);
      await _loadData();
      _showSuccessSnackBar(templateId != null ? '템플릿이 수정되었습니다' : '템플릿이 추가되었습니다');
    } else {
      _showErrorSnackBar('같은 이름의 템플릿이 이미 존재합니다');
    }
  }

  void _showDeleteConfirmDialog(DiaryTemplate template) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('템플릿 삭제'),
        content: Text('\'${template.name}\' 템플릿을 삭제하시겠습니까?\n이 작업은 되돌릴 수 없습니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => _deleteTemplate(context, template),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteTemplate(BuildContext context, DiaryTemplate template) async {
    Navigator.pop(context);
    
    final success = await _templateService.deleteCustomTemplate(template.id);
    if (success) {
      await _loadData();
      _showSuccessSnackBar('템플릿이 삭제되었습니다');
    } else {
      _showErrorSnackBar('템플릿 삭제에 실패했습니다');
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