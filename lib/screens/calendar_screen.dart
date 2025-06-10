import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import '../constants/app_colors.dart';
import '../constants/app_sizes.dart';
import '../models/mood_entry_model.dart';
import '../services/local_storage_service.dart';
import 'mood_entry_screen.dart';
import '../widgets/mood_entry_card.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => CalendarScreenState();
}

class CalendarScreenState extends State<CalendarScreen> 
    with TickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  
  List<MoodEntry> _entries = [];
  Map<DateTime, List<MoodEntry>> _entriesByDate = {};
  bool _isLoading = true;
  
  // 필터링 관련
  MoodType? _selectedMoodFilter;
  bool _showFilters = false;
  
  // 애니메이션 컨트롤러
  late AnimationController _filterAnimationController;
  late Animation<double> _filterAnimation;
  
  // 성능 최적화를 위한 캐시
  Map<String, Widget>? _markerCache;
  Map<String, Map<MoodType, int>>? _statsCache;

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _loadEntries();
    
    // 애니메이션 초기화
    _filterAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _filterAnimation = CurvedAnimation(
      parent: _filterAnimationController,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _filterAnimationController.dispose();
    super.dispose();
  }

  @override
  bool get wantKeepAlive => true;

  // 외부에서 새로고침할 수 있는 메소드
  void refreshData() {
    _loadEntries();
  }

  // 현재 선택된 날짜를 반환하는 메서드
  DateTime? getSelectedDate() {
    return _selectedDay;
  }

  Future<void> _loadEntries() async {
    if (!mounted) return;
    
    setState(() {
      _isLoading = true;
    });

    try {
      final storage = LocalStorageService.instance;
      final entries = await storage.getAllMoodEntries();
      
      if (mounted) {
        // 점진적 캐시 초기화 (UI 블로킹 방지)
        _markerCache?.clear();
        _statsCache?.clear();
        
        setState(() {
          _entries = entries;
          _entriesByDate = _groupEntriesByDate(entries);
          _isLoading = false;
        });
        
        // 비동기로 캐시 예열 (화면 표시 후)
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _preloadCurrentMonthCache();
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('데이터 로딩 중 오류: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  // 현재 월의 캐시를 미리 로드 (성능 최적화)
  void _preloadCurrentMonthCache() {
    if (!mounted) return;
    
    final currentMonth = DateTime(_focusedDay.year, _focusedDay.month);
    final nextMonth = DateTime(_focusedDay.year, _focusedDay.month + 1);
    
    // 현재 월의 일기들을 미리 캐시에 로드
    final monthEntries = _entries.where((entry) {
      return entry.date.isAfter(currentMonth.subtract(const Duration(days: 1))) &&
             entry.date.isBefore(nextMonth);
    }).toList();
    
    // 마커 캐시 예열
    for (final entry in monthEntries) {
      final date = DateTime(entry.date.year, entry.date.month, entry.date.day);
      final dayEntries = _entriesByDate[date] ?? [];
      if (dayEntries.isNotEmpty) {
        _buildMultipleMoodMarkers(dayEntries); // 캐시에 저장됨
      }
    }
  }

  Map<DateTime, List<MoodEntry>> _groupEntriesByDate(List<MoodEntry> entries) {
    final Map<DateTime, List<MoodEntry>> data = {};
    
    for (final entry in entries) {
      final date = DateTime(entry.date.year, entry.date.month, entry.date.day);
      if (data[date] != null) {
        data[date]!.add(entry);
      } else {
        data[date] = [entry];
      }
    }
    
    return data;
  }

  List<MoodEntry> _getEntriesForDay(DateTime day) {
    final normalizedDay = DateTime(day.year, day.month, day.day);
    final dayEntries = _entriesByDate[normalizedDay] ?? [];
    
    // 필터가 적용된 경우
    if (_selectedMoodFilter != null) {
      return dayEntries.where((entry) => entry.mood == _selectedMoodFilter).toList();
    }
    
    return dayEntries;
  }

  // 월별 감정 통계 계산 (캐시 사용)
  Map<MoodType, int> _getMonthlyMoodStats() {
    final cacheKey = '${_focusedDay.year}-${_focusedDay.month}';
    
    // 캐시에서 확인
    if (_statsCache != null && _statsCache!.containsKey(cacheKey)) {
      return _statsCache![cacheKey]!;
    }
    
    final currentMonth = DateTime(_focusedDay.year, _focusedDay.month);
    final nextMonth = DateTime(_focusedDay.year, _focusedDay.month + 1);
    
    final monthEntries = _entries.where((entry) {
      return entry.date.isAfter(currentMonth.subtract(const Duration(days: 1))) &&
             entry.date.isBefore(nextMonth);
    }).toList();
    
    final stats = <MoodType, int>{};
    for (final mood in MoodType.values) {
      stats[mood] = monthEntries.where((entry) => entry.mood == mood).length;
    }
    
    // 캐시에 저장
    _statsCache ??= {};
    _statsCache![cacheKey] = stats;
    
    return stats;
  }

  // 연속 기록 계산
  int _getCurrentStreak() {
    if (_entries.isEmpty) return 0;
    
    final sortedEntries = _entries.toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    
    final today = DateTime.now();
    final todayNormalized = DateTime(today.year, today.month, today.day);
    
    int streak = 0;
    DateTime checkDate = todayNormalized;
    
    for (int i = 0; i < 365; i++) { // 최대 1년까지만 체크
      final hasEntry = sortedEntries.any((entry) {
        final entryDate = DateTime(entry.date.year, entry.date.month, entry.date.day);
        return entryDate.isAtSameMomentAs(checkDate);
      });
      
      if (hasEntry) {
        streak++;
        checkDate = checkDate.subtract(const Duration(days: 1));
      } else {
        break;
      }
    }
    
    return streak;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // AutomaticKeepAliveClientMixin용
    final theme = Theme.of(context);
    
    return Scaffold(
      backgroundColor: theme.colorScheme.background,
      body: CustomScrollView(
        // 스크롤 성능 최적화
        cacheExtent: 1000, // 캐시 범위 증가
        physics: const BouncingScrollPhysics(), // 부드러운 스크롤
        slivers: [
          _buildAppBar(),
          if (_isLoading)
            const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            )
          else ...[
            SliverToBoxAdapter(child: _buildMonthlyStats()),
            if (_showFilters) SliverToBoxAdapter(child: _buildFilterSection()),
            SliverToBoxAdapter(child: _buildCalendar()),
            SliverToBoxAdapter(child: _buildSelectedDayEntries()),
          ],
        ],
      ),
    );
  }

  Widget _buildAppBar() {
    final theme = Theme.of(context);
    final streak = _getCurrentStreak();
    
    return SliverAppBar(
      expandedHeight: 120,
      floating: false,
      pinned: true,
      backgroundColor: theme.colorScheme.surface,
      flexibleSpace: FlexibleSpaceBar(
        title: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '감정 달력',
              style: theme.textTheme.titleLarge?.copyWith(
                color: theme.colorScheme.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (streak > 0)
              Text(
                '🔥 $streak일 연속 기록',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w500,
                ),
              ),
          ],
        ),
        centerTitle: false,
        titlePadding: const EdgeInsets.only(left: 16, bottom: 16),
      ),
      actions: [
        IconButton(
          icon: Icon(_showFilters ? Icons.filter_list : Icons.filter_list_outlined),
          onPressed: () {
            setState(() {
              _showFilters = !_showFilters;
            });
            if (_showFilters) {
              _filterAnimationController.forward();
            } else {
              _filterAnimationController.reverse();
            }
          },
          tooltip: '필터',
        ),
        IconButton(
          icon: const Icon(Icons.today),
          onPressed: () {
            setState(() {
              _focusedDay = DateTime.now();
              _selectedDay = DateTime.now();
            });
          },
          tooltip: '오늘로 이동',
        ),
      ],
    );
  }

  Widget _buildMonthlyStats() {
    final theme = Theme.of(context);
    final stats = _getMonthlyMoodStats();
    final totalEntries = stats.values.fold(0, (sum, count) => sum + count);
    
    if (totalEntries == 0) return const SizedBox.shrink();
    
    return Container(
      margin: const EdgeInsets.fromLTRB(AppSizes.paddingM, AppSizes.paddingS, AppSizes.paddingM, 0),
      padding: const EdgeInsets.all(AppSizes.paddingM),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppSizes.radiusL),
        boxShadow: [
          BoxShadow(
            color: theme.shadowColor.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.analytics, size: 20, color: AppColors.primary),
              const SizedBox(width: AppSizes.paddingS),
              Text(
                '${DateFormat('M월', 'ko_KR').format(_focusedDay)} 감정 통계',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Text(
                '총 ${totalEntries}일',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.7),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSizes.paddingM),
          Row(
            children: MoodType.values.reversed.map((mood) { // 최고부터 표시
              final count = stats[mood] ?? 0;
              final percentage = totalEntries > 0 ? (count / totalEntries) : 0.0;
              
              return Expanded(
                flex: (percentage * 100).round().clamp(1, 100),
                child: Container(
                  height: 8,
                  margin: const EdgeInsets.only(right: 2),
                  decoration: BoxDecoration(
                    color: count > 0 ? _getMoodColor(mood) : Colors.transparent,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: AppSizes.paddingS),
          Wrap(
            spacing: AppSizes.paddingM,
            children: MoodType.values.reversed.map((mood) {
              final count = stats[mood] ?? 0;
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: _getMoodColor(mood),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${mood.label} $count일',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterSection() {
    return AnimatedBuilder(
      animation: _filterAnimation,
      builder: (context, child) {
        if (!_showFilters) return const SizedBox.shrink();
        
        return SizeTransition(
          sizeFactor: _filterAnimation,
          child: Container(
            margin: const EdgeInsets.fromLTRB(AppSizes.paddingM, AppSizes.paddingS, AppSizes.paddingM, 0),
            padding: const EdgeInsets.all(AppSizes.paddingM),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(AppSizes.radiusL),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '감정별 필터',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: AppSizes.paddingS),
                Wrap(
                  spacing: AppSizes.paddingS,
                  children: [
                    _buildFilterChip('전체', null),
                    ...MoodType.values.reversed.map((mood) => 
                      _buildFilterChip('${mood.emoji} ${mood.label}', mood)
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildFilterChip(String label, MoodType? mood) {
    final isSelected = _selectedMoodFilter == mood;
    
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _selectedMoodFilter = selected ? mood : null;
        });
      },
      selectedColor: mood != null ? _getMoodColor(mood).withOpacity(0.3) : AppColors.primary.withOpacity(0.3),
      checkmarkColor: mood != null ? _getMoodColor(mood) : AppColors.primary,
    );
  }

  Color _getMoodColor(MoodType mood) {
    switch (mood) {
      case MoodType.worst:
        return AppColors.emotionWorst;
      case MoodType.bad:
        return AppColors.emotionBad;
      case MoodType.neutral:
        return AppColors.emotionNeutral;
      case MoodType.good:
        return AppColors.emotionGood;
      case MoodType.best:
        return AppColors.emotionBest;
    }
  }

  Widget _buildCalendar() {
    final theme = Theme.of(context);
    final today = DateTime.now();
    
    return Container(
      margin: const EdgeInsets.all(AppSizes.paddingM),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppSizes.radiusL),
        boxShadow: [
          BoxShadow(
            color: theme.shadowColor.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: GestureDetector(
        // 달력 터치는 가능하되, 수직 드래그 시에는 스크롤 허용
        behavior: HitTestBehavior.deferToChild,
        child: TableCalendar<MoodEntry>(
        firstDay: DateTime.utc(2020, 1, 1),
        lastDay: today, // 오늘까지만 선택 가능
        focusedDay: _focusedDay,
        calendarFormat: CalendarFormat.month, // 월간 보기로 고정
        eventLoader: _getEntriesForDay,
        startingDayOfWeek: StartingDayOfWeek.monday,
        locale: 'ko_KR',
        
        // 제스처 설정 - 수직 드래그 비활성화
        availableGestures: AvailableGestures.horizontalSwipe,
        
        // 선택된 날짜
        selectedDayPredicate: (day) {
          return isSameDay(_selectedDay, day);
        },
        
        // 날짜 선택 가능 여부 확인
        enabledDayPredicate: (day) {
          // 오늘 또는 과거 날짜만 선택 가능
          final normalizedDay = DateTime(day.year, day.month, day.day);
          final normalizedToday = DateTime(today.year, today.month, today.day);
          return normalizedDay.isBefore(normalizedToday) || normalizedDay.isAtSameMomentAs(normalizedToday);
        },
        
        onDaySelected: (selectedDay, focusedDay) {
          // 미래 날짜는 선택하지 못하게 함
          final normalizedSelectedDay = DateTime(selectedDay.year, selectedDay.month, selectedDay.day);
          final normalizedToday = DateTime(today.year, today.month, today.day);
          
          if (normalizedSelectedDay.isAfter(normalizedToday)) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('미래 날짜는 선택할 수 없습니다'),
                duration: Duration(seconds: 2),
              ),
            );
            return;
          }
          
          if (!isSameDay(_selectedDay, selectedDay)) {
            // 선택된 날짜만 업데이트 (성능 최적화)
            _selectedDay = selectedDay;
            _focusedDay = focusedDay;
            
            // 선택된 날짜 엔트리 부분만 리빌드
            if (mounted) {
              setState(() {});
            }
          }
        },
        
        onPageChanged: (focusedDay) {
          if (_focusedDay.month != focusedDay.month || _focusedDay.year != focusedDay.year) {
            _focusedDay = focusedDay;
            
            // 월이 변경된 경우에만 리빌드
            if (mounted) {
              setState(() {});
            }
          }
        },
        
        // 달력 스타일
        calendarStyle: CalendarStyle(
          outsideDaysVisible: false,
          weekendTextStyle: TextStyle(color: AppColors.error),
          holidayTextStyle: TextStyle(color: AppColors.error),
          
          // 선택된 날짜 스타일
          selectedDecoration: BoxDecoration(
            color: AppColors.primary,
            shape: BoxShape.circle,
          ),
          selectedTextStyle: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
          
          // 오늘 날짜 스타일
          todayDecoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.3),
            shape: BoxShape.circle,
          ),
          todayTextStyle: TextStyle(
            color: AppColors.primary,
            fontWeight: FontWeight.w600,
          ),
          
          // 기본 날짜 스타일
          defaultTextStyle: TextStyle(
            color: theme.colorScheme.onSurface,
          ),
          
          // 비활성화된 날짜 스타일 (미래 날짜)
          disabledTextStyle: TextStyle(
            color: theme.colorScheme.onSurface.withOpacity(0.3),
          ),
          
          // 마커 스타일 제거 (커스텀 빌더 사용)
          markersMaxCount: 0,
        ),
        
        // 헤더 스타일
        headerStyle: HeaderStyle(
          formatButtonVisible: false,
          titleCentered: true,
          leftChevronIcon: Icon(
            Icons.chevron_left,
            color: theme.colorScheme.onSurface,
          ),
          rightChevronIcon: Icon(
            Icons.chevron_right,
            color: theme.colorScheme.onSurface,
          ),
          titleTextStyle: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ) ?? const TextStyle(),
        ),
        
        // 요일 헤더 스타일
        daysOfWeekStyle: DaysOfWeekStyle(
          weekdayStyle: TextStyle(
            color: theme.colorScheme.onSurface.withOpacity(0.7),
            fontWeight: FontWeight.w500,
          ),
          weekendStyle: TextStyle(
            color: AppColors.error.withOpacity(0.7),
            fontWeight: FontWeight.w500,
          ),
        ),
        
        // 커스텀 빌더
        calendarBuilders: CalendarBuilders(
          // 다중 감정 마커 빌더
          markerBuilder: (context, date, entries) {
            if (entries.isEmpty) return const SizedBox.shrink();
            
            return Positioned(
              bottom: 2,
              child: _buildMultipleMoodMarkers(entries),
            );
          },
        ),
        ),
      ),
    );
  }

  // 여러 감정을 겹쳐서 표시하는 위젯 (캐시 사용)
  Widget _buildMultipleMoodMarkers(List<MoodEntry> entries) {
    if (entries.isEmpty) return const SizedBox.shrink();
    
    // 캐시 키 생성 (날짜 + 감정 타입들)
    final cacheKey = entries.map((e) => '${e.date.day}-${e.mood.index}').join(',');
    
    // 캐시에서 확인
    if (_markerCache != null && _markerCache!.containsKey(cacheKey)) {
      return _markerCache![cacheKey]!;
    }
    
    final entryCount = entries.length;
    
    Widget markerWidget;
    
    // 감정 개수에 따른 크기 및 배치 설정
    if (entryCount == 1) {
      // 1개일 때는 크게 표시
      markerWidget = Container(
        width: 12,
        height: 12,
        decoration: BoxDecoration(
          color: _getMoodColor(entries.first.mood),
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.white,
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: _getMoodColor(entries.first.mood).withOpacity(0.3),
              blurRadius: 2,
              offset: const Offset(0, 1),
            ),
          ],
        ),
      );
    } else {
      // 여러 개일 때는 작게 겹쳐서 표시
      final displayEntries = entries.take(4).toList();
      final markerSize = entryCount == 2 ? 10.0 : (entryCount == 3 ? 8.0 : 6.0);
      final offsetStep = entryCount == 2 ? 6.0 : (entryCount == 3 ? 4.0 : 3.0);
      
      markerWidget = SizedBox(
        width: 20,
        height: 12,
        child: Stack(
          children: [
            for (int i = 0; i < displayEntries.length && i < 3; i++)
              Positioned(
                left: i * offsetStep,
                child: Container(
                  width: markerSize,
                  height: markerSize,
                  decoration: BoxDecoration(
                    color: _getMoodColor(displayEntries[i].mood),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white,
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: _getMoodColor(displayEntries[i].mood).withOpacity(0.3),
                        blurRadius: 1,
                        offset: const Offset(0, 0.5),
                      ),
                    ],
                  ),
                ),
              ),
            // 4개 이상이면 "+" 표시
            if (entryCount > 3)
              Positioned(
                right: 0,
                child: Container(
                  width: markerSize,
                  height: markerSize,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white,
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withOpacity(0.3),
                        blurRadius: 1,
                        offset: const Offset(0, 0.5),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      '+',
                      style: TextStyle(
                        fontSize: markerSize * 0.5,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      );
    }
    
    // 캐시에 저장
    _markerCache ??= {};
    _markerCache![cacheKey] = markerWidget;
    
    return markerWidget;
  }

  Widget _buildSelectedDayEntries() {
    if (_selectedDay == null) return const SizedBox.shrink();
    
    final entries = _getEntriesForDay(_selectedDay!);
    final theme = Theme.of(context);
    
    return Container(
      margin: const EdgeInsets.fromLTRB(
        AppSizes.paddingM,
        0,
        AppSizes.paddingM,
        AppSizes.paddingM,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSizes.paddingM),
            child: Row(
              children: [
                Text(
                  DateFormat('MM월 dd일 (E)', 'ko_KR').format(_selectedDay!),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                if (entries.isEmpty)
                  TextButton.icon(
                    onPressed: () => _navigateToMoodEntry(_selectedDay!),
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('일기 작성'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.primary,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: AppSizes.paddingS),
          
          if (entries.isEmpty)
            _buildEmptyDayState()
          else
            ...entries.map((entry) => Padding(
              padding: const EdgeInsets.only(bottom: AppSizes.paddingS),
              child: MoodEntryCard(
                entry: entry,
                onTap: () => _navigateToMoodEntry(_selectedDay!, entry),
                onEdit: () => _navigateToMoodEntry(_selectedDay!, entry),
                onDelete: () => _deleteEntry(entry),
                onFavoriteToggle: () => _toggleFavorite(entry),
              ),
            )),
        ],
      ),
    );
  }

  Widget _buildEmptyDayState() {
    final theme = Theme.of(context);
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSizes.paddingL),
      margin: const EdgeInsets.symmetric(horizontal: AppSizes.paddingM),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppSizes.radiusL),
        border: Border.all(
          color: theme.colorScheme.outline.withOpacity(0.2),
        ),
      ),
      child: Column(
        children: [
          Icon(
            Icons.event_note_outlined,
            size: 48,
            color: theme.colorScheme.onSurface.withOpacity(0.3),
          ),
          const SizedBox(height: AppSizes.paddingM),
          Text(
            '이 날의 감정 기록이 없습니다',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
          const SizedBox(height: AppSizes.paddingS),
          Text(
            '오늘의 감정을 기록해보세요',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.4),
            ),
          ),
        ],
      ),
    );
  }

  void _navigateToMoodEntry(DateTime date, [MoodEntry? existingEntry]) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => MoodEntryScreen(
          existingEntry: existingEntry,
          preselectedDate: existingEntry == null ? date : null,
        ),
      ),
    ).then((result) {
      if (result == true) {
        refreshData();
      }
    });
  }

  Future<void> _deleteEntry(MoodEntry entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('일기 삭제'),
        content: const Text('이 일기를 삭제하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('삭제'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await LocalStorageService.instance.deleteMoodEntry(entry.id);
        refreshData();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('일기가 삭제되었습니다')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('삭제 중 오류가 발생했습니다: $e'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    }
  }

  Future<void> _toggleFavorite(MoodEntry entry) async {
    try {
      final updatedEntry = entry.copyWith(isFavorite: !entry.isFavorite);
      await LocalStorageService.instance.saveMoodEntry(updatedEntry);
      refreshData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('즐겨찾기 설정 중 오류가 발생했습니다: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }
} 