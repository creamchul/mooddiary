import 'package:flutter/material.dart';
import '../models/mood_entry_model.dart';
import '../services/local_storage_service.dart';
import '../constants/app_colors.dart';
import '../constants/app_sizes.dart';
import '../widgets/optimized_image_widget.dart';
import 'package:fl_chart/fl_chart.dart';

// 최적화된 홈 요약 카드
class OptimizedHomeSummaryCard extends StatefulWidget {
  const OptimizedHomeSummaryCard({super.key});

  @override
  State<OptimizedHomeSummaryCard> createState() => _OptimizedHomeSummaryCardState();
}

class _OptimizedHomeSummaryCardState extends State<OptimizedHomeSummaryCard>
    with AutomaticKeepAliveClientMixin {
  
  @override
  bool get wantKeepAlive => true;

  int _totalEntries = 0;
  int _currentStreak = 0;
  int _longestStreak = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSummaryData();
  }

  Future<void> _loadSummaryData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final results = await Future.wait([
        LocalStorageService.instance.getMoodEntriesCount(),
        LocalStorageService.instance.getCurrentStreak(),
        LocalStorageService.instance.getLongestStreak(),
      ]);

      if (mounted) {
        setState(() {
          _totalEntries = results[0] as int;
          _currentStreak = results[1] as int;
          _longestStreak = results[2] as int;
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
      return Card(
        child: Container(
          height: 120,
          padding: const EdgeInsets.all(AppSizes.paddingL),
          child: const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
            ),
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
              '나의 감정 기록',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppSizes.paddingM),
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    '총 일기',
                    '$_totalEntries개',
                    Icons.article,
                    AppColors.primary,
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    '연속 기록',
                    '$_currentStreak일',
                    Icons.local_fire_department,
                    AppColors.warning,
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    '최장 기록',
                    '$_longestStreak일',
                    Icons.emoji_events,
                    AppColors.success,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon, Color color) {
    final theme = Theme.of(context);
    
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: AppSizes.paddingS),
        Text(
          value,
          style: theme.textTheme.titleMedium?.copyWith(
            color: color,
            fontWeight: FontWeight.w600,
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
}

// 최적화된 최근 일기 위젯
class OptimizedRecentEntries extends StatefulWidget {
  final Function(MoodEntry)? onEntryTap;

  const OptimizedRecentEntries({
    super.key,
    this.onEntryTap,
  });

  @override
  State<OptimizedRecentEntries> createState() => _OptimizedRecentEntriesState();
}

class _OptimizedRecentEntriesState extends State<OptimizedRecentEntries>
    with AutomaticKeepAliveClientMixin {
  
  @override
  bool get wantKeepAlive => true;

  List<MoodEntry> _recentEntries = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRecentEntries();
  }

  Future<void> _loadRecentEntries() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final entries = await LocalStorageService.instance.getRecentMoodEntries(limit: 5);
      
      if (mounted) {
        setState(() {
          _recentEntries = entries;
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

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.paddingL),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '최근 일기',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (_recentEntries.isNotEmpty)
                  TextButton(
                    onPressed: () {
                      // TODO: 전체 일기 목록으로 이동
                    },
                    child: const Text('더보기'),
                  ),
              ],
            ),
            const SizedBox(height: AppSizes.paddingM),
            if (_isLoading)
              const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                ),
              )
            else if (_recentEntries.isEmpty)
              _buildEmptyState()
            else
              ..._recentEntries.map((entry) => _buildEntryItem(entry)),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    final theme = Theme.of(context);
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSizes.paddingL),
      child: Column(
        children: [
          Icon(
            Icons.article_outlined,
            size: 48,
            color: theme.colorScheme.onSurface.withOpacity(0.3),
          ),
          const SizedBox(height: AppSizes.paddingM),
          Text(
            '아직 작성된 일기가 없어요',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEntryItem(MoodEntry entry) {
    final theme = Theme.of(context);
    
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSizes.paddingS),
      child: InkWell(
        onTap: () => widget.onEntryTap?.call(entry),
        borderRadius: BorderRadius.circular(AppSizes.radiusM),
        child: Padding(
          padding: const EdgeInsets.all(AppSizes.paddingS),
          child: Row(
            children: [
              // 감정 아이콘
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: entry.mood.color.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(AppSizes.radiusS),
                ),
                child: Icon(
                  entry.mood.icon,
                  color: entry.mood.color,
                  size: 20,
                ),
              ),
              const SizedBox(width: AppSizes.paddingM),
              
              // 일기 내용
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (entry.title?.isNotEmpty == true)
                      Text(
                        entry.title!,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    Text(
                      entry.content,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.7),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              
              // 이미지 썸네일 (있는 경우)
              if (entry.images.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(left: AppSizes.paddingS),
                  child: OptimizedListImage(
                    imagePath: entry.images.first,
                    size: 32,
                  ),
                ),
              
              // 날짜
              Text(
                '${entry.date.month}/${entry.date.day}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.5),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// 최적화된 주간 감정 차트
class OptimizedWeeklyChart extends StatefulWidget {
  const OptimizedWeeklyChart({super.key});

  @override
  State<OptimizedWeeklyChart> createState() => _OptimizedWeeklyChartState();
}

class _OptimizedWeeklyChartState extends State<OptimizedWeeklyChart>
    with AutomaticKeepAliveClientMixin {
  
  @override
  bool get wantKeepAlive => true;

  List<Map<String, dynamic>> _weeklyData = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadWeeklyData();
  }

  Future<void> _loadWeeklyData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final data = await LocalStorageService.instance.getWeeklyTrend();
      
      if (mounted) {
        setState(() {
          _weeklyData = data;
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

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.paddingL),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '이번 주 감정 트렌드',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppSizes.paddingM),
            if (_isLoading)
              const SizedBox(
                height: 200,
                child: Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                  ),
                ),
              )
            else if (_weeklyData.isEmpty)
              const SizedBox(
                height: 200,
                child: Center(
                  child: Text('이번 주 데이터가 없습니다'),
                ),
              )
            else
              SizedBox(
                height: 200,
                child: LineChart(
                  LineChartData(
                    gridData: FlGridData(show: false),
                    titlesData: FlTitlesData(
                      leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (value, meta) {
                            const days = ['월', '화', '수', '목', '금', '토', '일'];
                            if (value.toInt() >= 0 && value.toInt() < days.length) {
                              return Text(
                                days[value.toInt()],
                                style: theme.textTheme.bodySmall,
                              );
                            }
                            return const Text('');
                          },
                          reservedSize: 30,
                        ),
                      ),
                    ),
                    borderData: FlBorderData(show: false),
                    lineBarsData: [
                      LineChartBarData(
                        spots: _weeklyData.asMap().entries.map((entry) {
                          final index = entry.key;
                          final data = entry.value;
                          return FlSpot(index.toDouble(), data['avgMood'] ?? 0);
                        }).toList(),
                        isCurved: true,
                        color: AppColors.primary,
                        barWidth: 3,
                        dotData: FlDotData(
                          show: true,
                          getDotPainter: (spot, percent, barData, index) {
                            return FlDotCirclePainter(
                              radius: 4,
                              color: AppColors.primary,
                              strokeColor: AppColors.primary,
                              strokeWidth: 2,
                            );
                          },
                        ),
                        belowBarData: BarAreaData(
                          show: true,
                          color: AppColors.primary.withOpacity(0.1),
                        ),
                      ),
                    ],
                    minY: 0,
                    maxY: 4,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
} 