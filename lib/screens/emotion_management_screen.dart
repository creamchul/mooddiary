import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../constants/app_colors.dart';
import '../constants/app_sizes.dart';
import '../models/mood_entry_model.dart';
import '../services/emotion_service.dart';

class EmotionManagementScreen extends StatefulWidget {
  const EmotionManagementScreen({super.key});

  @override
  State<EmotionManagementScreen> createState() => _EmotionManagementScreenState();
}

class _EmotionManagementScreenState extends State<EmotionManagementScreen> {
  final EmotionService _emotionService = EmotionService.instance;
  List<CustomEmotion> _emotions = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadEmotions();
  }

  Future<void> _loadEmotions() async {
    setState(() => _isLoading = true);
    final emotions = await _emotionService.getAllCustomEmotions();
    setState(() {
      _emotions = emotions;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('감정 관리'),
        backgroundColor: Theme.of(context).colorScheme.surface,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              padding: const EdgeInsets.all(AppSizes.paddingM),
              itemCount: _emotions.length,
              itemBuilder: (context, index) {
                final emotion = _emotions[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: AppSizes.paddingS),
                  child: ListTile(
                    leading: Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: Color(int.parse(emotion.color.substring(1), radix: 16) + 0xFF000000).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(25),
                      ),
                      child: Center(
                        child: Text(emotion.emoji, style: const TextStyle(fontSize: 24)),
                      ),
                    ),
                    title: Text(emotion.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (emotion.description != null) Text(emotion.description!),
                        Text('강도: ${emotion.value}/10 • 사용: ${emotion.usageCount}회'),
                      ],
                    ),
                    trailing: PopupMenuButton(
                      itemBuilder: (context) => [
                        const PopupMenuItem(value: 'edit', child: Text('수정')),
                        const PopupMenuItem(value: 'delete', child: Text('삭제')),
                      ],
                      onSelected: (value) {
                        if (value == 'edit') _showEditDialog(emotion);
                        if (value == 'delete') _deleteEmotion(emotion.id);
                      },
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddDialog,
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showAddDialog() => _showEmotionDialog();
  void _showEditDialog(CustomEmotion emotion) => _showEmotionDialog(emotion: emotion);

  void _showEmotionDialog({CustomEmotion? emotion}) {
    final isEdit = emotion != null;
    final nameController = TextEditingController(text: emotion?.name);
    final descController = TextEditingController(text: emotion?.description);
    String selectedEmoji = emotion?.emoji ?? '😊';
    Color selectedColor = emotion != null
        ? Color(int.parse(emotion.color.substring(1), radix: 16) + 0xFF000000)
        : AppColors.primary;
    int selectedValue = emotion?.value ?? 5;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(isEdit ? '감정 수정' : '감정 추가'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: '감정 이름'),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: descController,
                  decoration: const InputDecoration(labelText: '설명 (선택)'),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Text('이모지: '),
                    GestureDetector(
                      onTap: () => _showEmojiPicker((emoji) => setDialogState(() => selectedEmoji = emoji)),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(selectedEmoji, style: const TextStyle(fontSize: 32)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text('강도: $selectedValue/10'),
                Slider(
                  value: selectedValue.toDouble(),
                  min: 1,
                  max: 10,
                  divisions: 9,
                  onChanged: (value) => setDialogState(() => selectedValue = value.round()),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소')),
            TextButton(
              onPressed: () => _saveEmotion(
                context, emotion?.id, nameController.text, descController.text,
                selectedEmoji, selectedColor, selectedValue, emotion?.usageCount ?? 0,
              ),
              child: Text(isEdit ? '수정' : '추가'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEmojiPicker(Function(String) onSelected) {
    final emojis = ['😊', '😢', '😡', '😰', '🤩', '😌', '😴', '🤔', '😍', '🥳', '😎', '🤯', '🥺', '😤', '🙄'];
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('이모지 선택'),
        content: Wrap(
          children: emojis.map((emoji) => GestureDetector(
            onTap: () {
              onSelected(emoji);
              Navigator.pop(context);
            },
            child: Container(
              margin: const EdgeInsets.all(4),
              padding: const EdgeInsets.all(8),
              child: Text(emoji, style: const TextStyle(fontSize: 32)),
            ),
          )).toList(),
        ),
      ),
    );
  }

  Future<void> _saveEmotion(BuildContext context, String? id, String name, String desc, 
      String emoji, Color color, int value, int usageCount) async {
    if (name.trim().isEmpty) return;

    final emotion = CustomEmotion(
      id: id ?? const Uuid().v4(),
      name: name.trim(),
      emoji: emoji,
      color: '#${color.value.toRadixString(16).substring(2).toUpperCase()}',
      description: desc.trim().isEmpty ? null : desc.trim(),
      value: value,
      userId: 'local_user',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      usageCount: usageCount,
    );

    final success = id != null 
        ? await _emotionService.updateCustomEmotion(emotion)
        : await _emotionService.addCustomEmotion(emotion);

    if (success) {
      Navigator.pop(context);
      _loadEmotions();
    }
  }

  Future<void> _deleteEmotion(String id) async {
    await _emotionService.deleteCustomEmotion(id);
    _loadEmotions();
  }
} 