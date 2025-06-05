import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_sizes.dart';
import '../services/theme_service.dart';
import '../services/backup_service.dart';
import '../services/local_storage_service.dart';
import '../services/notification_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _notificationsEnabled = true;
  String _selectedLanguage = 'ko';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      backgroundColor: theme.colorScheme.background,
      body: CustomScrollView(
        slivers: [
          _buildAppBar(),
          SliverPadding(
            padding: const EdgeInsets.all(AppSizes.paddingM),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _buildProfileSection(),
                const SizedBox(height: AppSizes.paddingM),
                _buildAppearanceSection(),
                const SizedBox(height: AppSizes.paddingM),
                _buildNotificationSection(),
                const SizedBox(height: AppSizes.paddingM),
                _buildDataSection(),
                const SizedBox(height: AppSizes.paddingM),
                _buildAboutSection(),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar() {
    final theme = Theme.of(context);
    
    return SliverAppBar(
      expandedHeight: 100,
      floating: false,
      pinned: true,
      backgroundColor: theme.colorScheme.surface,
      flexibleSpace: FlexibleSpaceBar(
        title: Text(
          '설정',
          style: theme.textTheme.titleLarge?.copyWith(
            color: theme.colorScheme.onSurface,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: false,
        titlePadding: const EdgeInsets.only(left: 16, bottom: 16),
      ),
    );
  }

  Widget _buildProfileSection() {
    final theme = Theme.of(context);
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.paddingL),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '프로필',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppSizes.paddingM),
            Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: AppColors.primary.withOpacity(0.2),
                  child: Icon(
                    Icons.person,
                    size: 32,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: AppSizes.paddingM),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '감정 기록자',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '매일 감정을 기록하고 있어요',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withOpacity(0.7),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () {
                    // TODO: 프로필 편집
                  },
                  icon: const Icon(Icons.edit),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppearanceSection() {
    final theme = Theme.of(context);
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.paddingL),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '화면 설정',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppSizes.paddingM),
            _buildSettingItem(
              '테마 설정',
              ThemeService.instance.themeModeText,
              Icons.palette,
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _showThemeDialog(),
            ),
            const Divider(),
            _buildSettingItem(
              '언어',
              '한국어',
              Icons.language,
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                // TODO: 언어 선택
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('언어 변경 기능은 곧 추가됩니다')),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showThemeDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('테마 설정'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: AppThemeMode.values.map((mode) {
            return RadioListTile<AppThemeMode>(
              title: Text(_getThemeModeText(mode)),
              subtitle: Text(_getThemeModeDescription(mode)),
              value: mode,
              groupValue: ThemeService.instance.themeMode,
              onChanged: (value) {
                if (value != null) {
                  ThemeService.instance.setThemeMode(value);
                  Navigator.pop(context);
                  setState(() {}); // UI 업데이트
                  
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('${_getThemeModeText(value)}로 변경되었습니다'),
                      backgroundColor: AppColors.success,
                    ),
                  );
                }
              },
              activeColor: AppColors.primary,
            );
          }).toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
        ],
      ),
    );
  }

  String _getThemeModeText(AppThemeMode mode) {
    switch (mode) {
      case AppThemeMode.system:
        return '시스템 설정';
      case AppThemeMode.light:
        return '라이트 모드';
      case AppThemeMode.dark:
        return '다크 모드';
    }
  }

  String _getThemeModeDescription(AppThemeMode mode) {
    switch (mode) {
      case AppThemeMode.system:
        return '기기 설정에 따라 자동 변경';
      case AppThemeMode.light:
        return '밝은 테마를 항상 사용';
      case AppThemeMode.dark:
        return '어두운 테마를 항상 사용';
    }
  }

  Widget _buildNotificationSection() {
    final theme = Theme.of(context);
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.paddingL),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '알림',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppSizes.paddingM),
            FutureBuilder<Map<String, dynamic>>(
              future: NotificationService.instance.getNotificationStatus(),
              builder: (context, snapshot) {
                final status = snapshot.data ?? {};
                final enabled = status['enabled'] ?? false;
                final timeString = status['timeString'] ?? '21:00';
                final supported = status['supported'] ?? false;
                
                return Column(
                  children: [
                    _buildSettingItem(
                      '일기 작성 알림',
                      supported ? '매일 $timeString에 알림' : '웹에서는 지원되지 않음',
                      Icons.notifications,
                      trailing: Switch(
                        value: enabled && supported,
                        onChanged: supported ? (value) => _toggleNotification(value) : null,
                        activeColor: AppColors.primary,
                      ),
                    ),
                    if (supported && enabled) ...[
                      const Divider(),
                      _buildSettingItem(
                        '알림 시간 설정',
                        timeString,
                        Icons.schedule,
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => _selectNotificationTime(),
                      ),
                      const Divider(),
                      _buildSettingItem(
                        '테스트 알림',
                        '알림이 정상 작동하는지 확인',
                        Icons.notifications_active,
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => _showTestNotification(),
                      ),
                    ],
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  // 알림 토글
  Future<void> _toggleNotification(bool enabled) async {
    try {
      if (enabled) {
        final time = await NotificationService.instance.getNotificationTime();
        final success = await NotificationService.instance.scheduleDailyNotification(time);
        
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('알림이 매일 ${time.hour}:${time.minute.toString().padLeft(2, '0')}에 설정되었습니다'),
              backgroundColor: AppColors.success,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('알림 설정에 실패했습니다'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      } else {
        await NotificationService.instance.cancelDailyNotification();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('알림이 비활성화되었습니다'),
            backgroundColor: AppColors.info,
          ),
        );
      }
      setState(() {}); // UI 새로고침
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('오류: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  // 알림 시간 선택
  Future<void> _selectNotificationTime() async {
    final currentTime = await NotificationService.instance.getNotificationTime();
    
    final selectedTime = await showTimePicker(
      context: context,
      initialTime: currentTime,
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

    if (selectedTime != null) {
      final success = await NotificationService.instance.scheduleDailyNotification(selectedTime);
      
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('알림 시간이 ${selectedTime.hour}:${selectedTime.minute.toString().padLeft(2, '0')}로 변경되었습니다'),
            backgroundColor: AppColors.success,
          ),
        );
        setState(() {}); // UI 새로고침
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('알림 시간 설정에 실패했습니다'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  // 테스트 알림
  Future<void> _showTestNotification() async {
    await NotificationService.instance.showTestNotification();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('테스트 알림을 전송했습니다!'),
        backgroundColor: AppColors.success,
      ),
    );
  }

  Widget _buildDataSection() {
    final theme = Theme.of(context);
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.paddingL),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '데이터 관리',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppSizes.paddingM),
            _buildSettingItem(
              '데이터 내보내기',
              'JSON 파일로 백업 및 공유',
              Icons.file_download,
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _exportData(),
            ),
            const Divider(),
            _buildSettingItem(
              '데이터 가져오기',
              '백업 파일에서 복원',
              Icons.file_upload,
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _importData(),
            ),
            const Divider(),
            _buildSettingItem(
              '백업 정보',
              '현재 저장된 데이터 확인',
              Icons.info_outline,
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _showBackupInfo(),
            ),
            const Divider(),
            _buildSettingItem(
              '모든 데이터 삭제',
              '복구할 수 없습니다',
              Icons.delete_forever,
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _showDeleteAllDialog(),
              textColor: AppColors.error,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAboutSection() {
    final theme = Theme.of(context);
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.paddingL),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '앱 정보',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppSizes.paddingM),
            _buildSettingItem(
              '버전',
              '1.0.0',
              Icons.info,
            ),
            const Divider(),
            _buildSettingItem(
              '개발자',
              'MoodDiary Team',
              Icons.code,
            ),
            const Divider(),
            _buildSettingItem(
              '개인정보 처리방침',
              '',
              Icons.privacy_tip,
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                // TODO: 개인정보 처리방침
              },
            ),
            const Divider(),
            _buildSettingItem(
              '이용약관',
              '',
              Icons.description,
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                // TODO: 이용약관
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingItem(
    String title,
    String subtitle,
    IconData icon, {
    Widget? trailing,
    VoidCallback? onTap,
    Color? textColor,
  }) {
    final theme = Theme.of(context);
    
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSizes.radiusS),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Icon(
              icon,
              color: textColor ?? AppColors.primary,
              size: 24,
            ),
            const SizedBox(width: AppSizes.paddingM),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w500,
                      color: textColor,
                    ),
                  ),
                  if (subtitle.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.7),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (trailing != null) trailing,
          ],
        ),
      ),
    );
  }

  void _showDeleteAllDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('모든 데이터 삭제'),
        content: const Text('정말로 모든 일기 데이터를 삭제하시겠어요?\n이 작업은 복구할 수 없습니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('삭제 기능은 아직 구현되지 않았습니다'),
                  backgroundColor: AppColors.error,
                ),
              );
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

  // 데이터 내보내기
  Future<void> _exportData() async {
    try {
      final success = await BackupService.instance.exportAndShare(context);
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('데이터가 성공적으로 내보내졌습니다!'),
            backgroundColor: AppColors.success,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('내보내기 중 오류가 발생했습니다.'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('오류: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  // 데이터 가져오기
  Future<void> _importData() async {
    try {
      final success = await BackupService.instance.importFromJson(context);
      if (success) {
        setState(() {}); // UI 새로고침
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('가져오기 중 오류: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  // 백업 정보 표시
  Future<void> _showBackupInfo() async {
    final stats = await BackupService.instance.getBackupStats();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('백업 정보'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoRow('총 일기 수', '${stats['total_entries'] ?? 0}개'),
            const SizedBox(height: 8),
            _buildInfoRow('기간', '${stats['date_range']?['start'] ?? '-'} ~ ${stats['date_range']?['end'] ?? '-'}'),
            const SizedBox(height: 16),
            const Text('감정별 분포:', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            ..._buildMoodDistribution(stats['mood_distribution'] ?? {}),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
      ],
    );
  }

  List<Widget> _buildMoodDistribution(Map<String, int> distribution) {
    return distribution.entries.map((entry) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('  ${entry.key}'),
            Text('${entry.value}개'),
          ],
        ),
      );
    }).toList();
  }
} 