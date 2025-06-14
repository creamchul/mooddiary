import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../constants/app_colors.dart';
import '../constants/app_sizes.dart';
import '../models/mood_entry_model.dart';
import '../models/activity_model.dart';
import '../services/local_storage_service.dart';

class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({super.key});

  @override
  State<StatisticsScreen> createState() => StatisticsScreenState();
}

class StatisticsScreenState extends State<StatisticsScreen> with AutomaticKeepAliveClientMixin {
  DateTime _selectedMonth = DateTime.now();
  List<MoodEntry> _entries = [];
  Map<MoodType, int> _moodCounts = {};
  bool _isLoading = true;
  int _currentStreak = 0;
  int _longestStreak = 0;
  
  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadStatistics();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadStatistics();
  }

  // 외부에서 새로고침할 수 있는 메서드 추가
  void refreshData() {
    _loadStatistics();
  }

  Future<void> _loadStatistics() async {
    if (!mounted) return;
    
    setState(() {
      _isLoading = true;
    });

    try {
      final storage = LocalStorageService.instance;
      final allEntries = await storage.getAllMoodEntries();
      final monthEntries = await storage.getMoodEntriesByMonth(_selectedMonth);
      final moodStats = await storage.getMoodStatistics(_selectedMonth);
      final currentStreak = await storage.getCurrentStreak();
      final longestStreak = await storage.getLongestStreak();
      
      if (mounted) {
        setState(() {
          _entries = allEntries;
          _moodCounts = moodStats;
          _currentStreak = currentStreak;
          _longestStreak = longestStreak;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);
    
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    
    final totalEntries = _moodCounts.values.fold(0, (sum, count) => sum + count);
    
    return Scaffold(
      backgroundColor: theme.colorScheme.background,
      body: CustomScrollView(
        slivers: [
          _buildAppBar(),
          _buildMonthSelector(),
          SliverPadding(
            padding: const EdgeInsets.all(AppSizes.paddingM),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _buildOverviewCards(),
                const SizedBox(height: AppSizes.paddingM),
                _buildMoodChart(),
                const SizedBox(height: AppSizes.paddingM),
                _buildTrendChart(),
                const SizedBox(height: AppSizes.paddingM),
                _buildActivityAnalysis(),
                const SizedBox(height: AppSizes.paddingM),
                _buildStreakCards(),
                const SizedBox(height: AppSizes.paddingM),
                _buildMonthlyComparison(),
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
          '감정 통계',
          style: theme.textTheme.titleLarge?.copyWith(
            color: theme.colorScheme.onSurface,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: false,
        titlePadding: const EdgeInsets.only(left: 16, bottom: 16),
      ),
      actions: [
        PopupMenuButton<String>(
          onSelected: (value) {
            switch (value) {
              case 'export':
                _exportStatistics();
                break;
              case 'refresh':
                _loadStatistics();
                break;
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'refresh',
              child: Row(
                children: [
                  Icon(Icons.refresh, size: 18),
                  SizedBox(width: 8),
                  Text('새로고침'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'export',
              child: Row(
                children: [
                  Icon(Icons.file_download, size: 18),
                  SizedBox(width: 8),
                  Text('통계 내보내기'),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMonthSelector() {
    final theme = Theme.of(context);
    
    return SliverToBoxAdapter(
      child: Container(
        margin: const EdgeInsets.all(AppSizes.paddingM),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSizes.paddingM),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  onPressed: () {
                    setState(() {
                      _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month - 1);
                    });
                    _loadStatistics();
                  },
                  icon: const Icon(Icons.chevron_left),
                ),
                Text(
                  DateFormat('yyyy년 MM월', 'ko_KR').format(_selectedMonth),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                IconButton(
                  onPressed: _selectedMonth.month < DateTime.now().month || _selectedMonth.year < DateTime.now().year
                      ? () {
                          setState(() {
                            _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1);
                          });
                          _loadStatistics();
                        }
                      : null,
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOverviewCards() {
    final theme = Theme.of(context);
    final totalEntries = _moodCounts.values.fold(0, (sum, count) => sum + count);
    final avgMood = _calculateAverageMood();
    final favoriteCount = _entries.where((e) => 
      e.date.year == _selectedMonth.year && 
      e.date.month == _selectedMonth.month && 
      e.isFavorite
    ).length;
    
    return Column(
      children: [
        // 첫 번째 행
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                '총 일기 수',
                '$totalEntries개',
                Icons.book,
                AppColors.primary,
                totalEntries == 0 ? '아직 일기가 없어요' : null,
              ),
            ),
            const SizedBox(width: AppSizes.paddingM),
            Expanded(
              child: _buildStatCard(
                '평균 기분',
                totalEntries > 0 ? avgMood.label : '-',
                Icons.emoji_emotions,
                totalEntries > 0 ? _getMoodColor(avgMood) : Colors.grey,
                totalEntries == 0 ? '데이터가 없어요' : null,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSizes.paddingM),
        // 두 번째 행
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                '즐겨찾기',
                '${favoriteCount}개',
                Icons.favorite,
                AppColors.emotionBest,
                favoriteCount == 0 ? '즐겨찾기가 없어요' : null,
              ),
            ),
            const SizedBox(width: AppSizes.paddingM),
            Expanded(
              child: _buildStatCard(
                '이번 달 작성률',
                '${((totalEntries / DateTime.now().day) * 100).toInt()}%',
                Icons.timeline,
                AppColors.emotionGood,
                null,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color, String? subtitle) {
    final theme = Theme.of(context);
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.paddingM),
        child: Column(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                borderRadius: BorderRadius.circular(AppSizes.radiusM),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: AppSizes.paddingS),
            Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.7),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.5),
                  fontSize: 10,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMoodChart() {
    final theme = Theme.of(context);
    final totalEntries = _moodCounts.values.fold(0, (sum, count) => sum + count);
    
    if (totalEntries == 0) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(AppSizes.paddingL),
          child: Column(
            children: [
              Text(
                '감정 분포',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: AppSizes.paddingL),
              Icon(
                Icons.pie_chart_outline,
                size: 80,
                color: theme.colorScheme.onSurface.withOpacity(0.3),
              ),
              const SizedBox(height: AppSizes.paddingM),
              Text(
                '데이터가 없습니다',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.7),
                ),
              ),
            ],
          ),
        ),
      );
    }
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.paddingL),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '감정 분포',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppSizes.paddingL),
            SizedBox(
              height: 200,
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: PieChart(
                      PieChartData(
                        sectionsSpace: 2,
                        centerSpaceRadius: 40,
                        sections: _generatePieChartSections(),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSizes.paddingM),
                  Expanded(
                    flex: 1,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: MoodType.values.map((mood) {
                        final count = _moodCounts[mood] ?? 0;
                        final percentage = totalEntries > 0 ? (count / totalEntries * 100) : 0.0;
                        
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Row(
                            children: [
                              Container(
                                width: 12,
                                height: 12,
                                decoration: BoxDecoration(
                                  color: _getMoodColor(mood),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  '${mood.emoji} ${mood.label} ${percentage.toInt()}%',
                                  style: theme.textTheme.bodySmall,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<PieChartSectionData> _generatePieChartSections() {
    final totalEntries = _moodCounts.values.fold(0, (sum, count) => sum + count);
    
    return MoodType.values.map((mood) {
      final count = _moodCounts[mood] ?? 0;
      final percentage = totalEntries > 0 ? (count / totalEntries * 100) : 0.0;
      
      return PieChartSectionData(
        color: _getMoodColor(mood),
        value: count.toDouble(),
        title: count > 0 ? '${percentage.toInt()}%' : '',
        radius: 60,
        titleStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      );
    }).where((section) => section.value > 0).toList();
  }

  Widget _buildTrendChart() {
    final theme = Theme.of(context);
    final monthEntries = _entries.where((entry) =>
      entry.date.year == _selectedMonth.year &&
      entry.date.month == _selectedMonth.month
    ).toList();
    
    if (monthEntries.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(AppSizes.paddingL),
          child: Column(
            children: [
              Text(
                '감정 변화 추이',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: AppSizes.paddingL),
              Icon(
                Icons.show_chart,
                size: 80,
                color: theme.colorScheme.onSurface.withOpacity(0.3),
              ),
              const SizedBox(height: AppSizes.paddingM),
              Text(
                '데이터가 없습니다',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.7),
                ),
              ),
            ],
          ),
        ),
      );
    }
    
    monthEntries.sort((a, b) => a.date.compareTo(b.date));
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.paddingL),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '감정 변화 추이',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppSizes.paddingL),
            SizedBox(
              height: 200,
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(show: true),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        interval: 1,
                        getTitlesWidget: (value, meta) {
                          switch (value.toInt()) {
                            case 1:
                              return Text(MoodType.worst.emoji, style: const TextStyle(fontSize: 16));
                            case 2:
                              return Text(MoodType.bad.emoji, style: const TextStyle(fontSize: 16));
                            case 3:
                              return Text(MoodType.neutral.emoji, style: const TextStyle(fontSize: 16));
                            case 4:
                              return Text(MoodType.good.emoji, style: const TextStyle(fontSize: 16));
                            case 5:
                              return Text(MoodType.best.emoji, style: const TextStyle(fontSize: 16));
                            default:
                              return const Text('');
                          }
                        },
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 30,
                        getTitlesWidget: (value, meta) {
                          if (value.toInt() < monthEntries.length) {
                            final entry = monthEntries[value.toInt()];
                            return Text(
                              '${entry.date.day}',
                              style: theme.textTheme.bodySmall,
                            );
                          }
                          return const Text('');
                        },
                      ),
                    ),
                    topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(show: true),
                  minX: 0,
                  maxX: (monthEntries.length - 1).toDouble(),
                  minY: 1,
                  maxY: 5,
                  lineBarsData: [
                    LineChartBarData(
                      spots: monthEntries.asMap().entries.map((entry) {
                        return FlSpot(
                          entry.key.toDouble(),
                          _getMoodValue(entry.value.mood),
                        );
                      }).toList(),
                      isCurved: true,
                      color: AppColors.primary,
                      barWidth: 3,
                      isStrokeCapRound: true,
                      dotData: FlDotData(
                        show: true,
                        getDotPainter: (spot, percent, barData, index) {
                          return FlDotCirclePainter(
                            radius: 4,
                            color: _getMoodColor(monthEntries[index].mood),
                            strokeWidth: 2,
                            strokeColor: Colors.white,
                          );
                        },
                      ),
                      belowBarData: BarAreaData(
                        show: true,
                        color: AppColors.primary.withOpacity(0.1),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActivityAnalysis() {
    final theme = Theme.of(context);
    final monthEntries = _entries.where((entry) =>
      entry.date.year == _selectedMonth.year &&
      entry.date.month == _selectedMonth.month
    ).toList();
    
    if (monthEntries.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(AppSizes.paddingL),
          child: Column(
            children: [
              Text(
                '활동별 감정 분석',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: AppSizes.paddingL),
              Icon(
                Icons.analytics_outlined,
                size: 80,
                color: theme.colorScheme.onSurface.withOpacity(0.3),
              ),
              const SizedBox(height: AppSizes.paddingM),
              Text(
                '데이터가 없습니다',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.7),
                ),
              ),
            ],
          ),
        ),
      );
    }
    
    // 활동별 감정 분석
    final activityMoodMap = <String, List<MoodType>>{};
    for (final entry in monthEntries) {
      for (final activityId in entry.activities) {
        activityMoodMap.putIfAbsent(activityId, () => []).add(entry.mood);
      }
    }
    
    final sortedActivities = activityMoodMap.entries.toList()
      ..sort((a, b) => b.value.length.compareTo(a.value.length));
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.paddingL),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '활동별 감정 분석',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppSizes.paddingM),
            ...sortedActivities.take(5).map((entry) {
              final activity = DefaultActivities.defaultActivities
                  .firstWhere((a) => a.id == entry.key, orElse: () => Activity(
                    id: entry.key,
                    name: '알 수 없음',
                    emoji: '❓',
                    color: '#666666',
                    createdAt: DateTime.now(),
                    updatedAt: DateTime.now(),
                  ));
              
              final moods = entry.value;
              final avgMoodValue = moods.map(_getMoodValue).reduce((a, b) => a + b) / moods.length;
              final avgMood = _getMoodFromValue(avgMoodValue.round());
              
              return Padding(
                padding: const EdgeInsets.only(bottom: AppSizes.paddingM),
                child: Row(
                  children: [
                    Text(activity.emoji, style: const TextStyle(fontSize: 24)),
                    const SizedBox(width: AppSizes.paddingM),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                activity.name,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: _getMoodColor(avgMood).withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  '${avgMood.emoji} ${avgMood.label}',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: _getMoodColor(avgMood),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${moods.length}회 기록',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurface.withOpacity(0.7),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildStreakCards() {
    final theme = Theme.of(context);
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.paddingL),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '연속 기록',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppSizes.paddingM),
            Row(
              children: [
                Expanded(
                  child: _buildStreakItem(
                    '현재 연속',
                    '$_currentStreak일',
                    Icons.local_fire_department,
                    AppColors.emotionBest,
                  ),
                ),
                const SizedBox(width: AppSizes.paddingM),
                Expanded(
                  child: _buildStreakItem(
                    '최장 연속',
                    '$_longestStreak일',
                    Icons.emoji_events,
                    AppColors.emotionGood,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStreakItem(String label, String value, IconData icon, Color color) {
    final theme = Theme.of(context);
    
    return Column(
      children: [
        Icon(icon, size: 32, color: color),
        const SizedBox(height: AppSizes.paddingS),
        Text(
          value,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withOpacity(0.7),
          ),
        ),
      ],
    );
  }

  Widget _buildMonthlyComparison() {
    final theme = Theme.of(context);
    final currentMonth = DateTime.now();
    final lastMonth = DateTime(currentMonth.year, currentMonth.month - 1);
    
    final currentMonthEntries = _entries.where((entry) =>
      entry.date.year == currentMonth.year &&
      entry.date.month == currentMonth.month
    ).length;
    
    final lastMonthEntries = _entries.where((entry) =>
      entry.date.year == lastMonth.year &&
      entry.date.month == lastMonth.month
    ).length;
    
    final difference = currentMonthEntries - lastMonthEntries;
    final isIncrease = difference > 0;
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.paddingL),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '월별 비교',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppSizes.paddingM),
            Row(
              children: [
                Expanded(
                  child: _buildComparisonItem(
                    '이번 달',
                    '$currentMonthEntries개',
                    AppColors.primary,
                  ),
                ),
                const SizedBox(width: AppSizes.paddingM),
                Expanded(
                  child: _buildComparisonItem(
                    '지난 달',
                    '$lastMonthEntries개',
                    Colors.grey,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSizes.paddingM),
            Container(
              padding: const EdgeInsets.all(AppSizes.paddingM),
              decoration: BoxDecoration(
                color: (isIncrease ? AppColors.emotionGood : AppColors.emotionBad).withOpacity(0.1),
                borderRadius: BorderRadius.circular(AppSizes.radiusM),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    isIncrease ? Icons.trending_up : Icons.trending_down,
                    color: isIncrease ? AppColors.emotionGood : AppColors.emotionBad,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '지난 달 대비 ${difference.abs()}개 ${isIncrease ? '증가' : '감소'}',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: isIncrease ? AppColors.emotionGood : AppColors.emotionBad,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildComparisonItem(String label, String value, Color color) {
    final theme = Theme.of(context);
    
    return Container(
      padding: const EdgeInsets.all(AppSizes.paddingM),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(AppSizes.radiusM),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: theme.textTheme.titleLarge?.copyWith(
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  double _getMoodValue(MoodType mood) {
    switch (mood) {
      case MoodType.worst:
        return 1.0;
      case MoodType.bad:
        return 2.0;
      case MoodType.neutral:
        return 3.0;
      case MoodType.good:
        return 4.0;
      case MoodType.best:
        return 5.0;
    }
  }

  MoodType _getMoodFromValue(int value) {
    switch (value) {
      case 1:
        return MoodType.worst;
      case 2:
        return MoodType.bad;
      case 3:
        return MoodType.neutral;
      case 4:
        return MoodType.good;
      case 5:
        return MoodType.best;
      default:
        return MoodType.neutral;
    }
  }

  MoodType _calculateAverageMood() {
    int total = 0;
    int weightedSum = 0;
    
    _moodCounts.forEach((mood, count) {
      total += count;
      weightedSum += mood.value * count;
    });
    
    if (total == 0) return MoodType.neutral;
    
    final average = weightedSum / total;
    
    if (average >= 4.5) return MoodType.best;
    if (average >= 3.5) return MoodType.good;
    if (average >= 2.5) return MoodType.neutral;
    if (average >= 1.5) return MoodType.bad;
    return MoodType.worst;
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

  void _exportStatistics() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('통계 내보내기 기능은 곧 추가됩니다'),
        duration: Duration(seconds: 2),
      ),
    );
  }
} 