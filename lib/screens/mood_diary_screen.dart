import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../constants/app_colors.dart';
import '../constants/app_sizes.dart';
import '../models/mood_entry_model.dart';
import '../models/activity_model.dart';
import '../widgets/mood_entry_card.dart';
import '../widgets/mini_calendar_widget.dart';
import '../services/local_storage_service.dart';
import '../services/image_service.dart';
import 'mood_entry_screen.dart';

class MoodDiaryScreen extends StatefulWidget {
  const MoodDiaryScreen({super.key});

  @override
  State<MoodDiaryScreen> createState() => MoodDiaryScreenState();
}

class MoodDiaryScreenState extends State<MoodDiaryScreen> 
    with AutomaticKeepAliveClientMixin, TickerProviderStateMixin {
  DateTime _selectedMonth = DateTime.now();
  String _searchQuery = '';
  MoodType? _filterMood;
  String? _filterActivity; // 활동별 필터
  bool _showFavoritesOnly = false; // 즐겨찾기만 보기
  bool _showSearchBar = false;
  bool _showAdvancedFilters = false; // 고급 필터 표시 여부
  bool _showMoodFilters = false; // 감정 필터 표시 여부
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();

  List<MoodEntry> _entries = [];
  List<MoodEntry> _filteredEntries = [];
  bool _isLoading = true;

  Timer? _searchDebounceTimer; // 검색 딜레이용 타이머
  
  // 성능 최적화용 캐시
  Map<String, List<MoodEntry>>? _groupedEntriesCache;
  String? _lastFilterState;
  
  // 애니메이션 컨트롤러 (부드러운 전환용)
  late AnimationController _filterAnimationController;
  late Animation<double> _filterAnimation;

  @override
  void initState() {
    super.initState();
    
    // 애니메이션 컨트롤러 초기화
    _filterAnimationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _filterAnimation = CurvedAnimation(
      parent: _filterAnimationController,
      curve: Curves.easeInOut,
    );
    
    _loadEntries();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    _searchDebounceTimer?.cancel();
    _filterAnimationController.dispose();
    super.dispose();
  }

  // 탭이 보여질 때마다 호출되도록 수정
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadEntries();
  }

  // 외부에서 새로고침할 수 있는 메소드
  void refreshData() {
    _loadEntries();
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
        setState(() {
          _entries = entries;
          _updateFilteredEntries();
          _isLoading = false;
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

  void _updateFilteredEntries() {
    // 필터 상태 문자열 생성 (캐시 키용)
    final currentFilterState = '$_filterMood|$_filterActivity|$_showFavoritesOnly|$_searchQuery';
    
    // 캐시가 유효한지 확인
    if (_lastFilterState == currentFilterState && _filteredEntries.isNotEmpty) {
      return; // 캐시된 결과 사용
    }
    
    _filteredEntries = _entries.where((entry) {
      // 감정 필터
      if (_filterMood != null && entry.mood != _filterMood) {
        return false;
      }
      
      // 활동별 필터
      if (_filterActivity != null && !entry.activities.contains(_filterActivity)) {
        return false;
      }
      
      // 즐겨찾기 필터
      if (_showFavoritesOnly && !entry.isFavorite) {
        return false;
      }
      
      // 검색 필터
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        return (entry.title?.toLowerCase().contains(query) ?? false) ||
               entry.content.toLowerCase().contains(query);
      }
      
      return true;
    }).toList();
    
    // 날짜 순으로 정렬 (최신순)
    _filteredEntries.sort((a, b) => b.date.compareTo(a.date));
    
    // 캐시 무효화
    _groupedEntriesCache = null;
    _lastFilterState = currentFilterState;
  }

  // 성능 최적화된 날짜별 그룹화 함수
  Map<String, List<MoodEntry>> _groupEntriesByDate() {
    // 캐시가 있고 유효하면 반환
    if (_groupedEntriesCache != null) {
      return _groupedEntriesCache!;
    }
    
    final groupedEntries = <String, List<MoodEntry>>{};
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    
    // 한 번의 순회로 그룹화와 정렬을 동시에 처리
    for (final entry in _filteredEntries) {
      final entryDate = DateTime(entry.date.year, entry.date.month, entry.date.day);
      
      String dateKey;
      if (entryDate == today) {
        dateKey = '오늘';
      } else if (entryDate == yesterday) {
        dateKey = '어제';
      } else {
        final difference = today.difference(entryDate).inDays;
        if (difference <= 7) {
          dateKey = '${difference}일 전';
        } else {
          dateKey = DateFormat('MM월 dd일 (E)', 'ko_KR').format(entry.date);
        }
      }
      
      groupedEntries.putIfAbsent(dateKey, () => <MoodEntry>[]).add(entry);
    }
    
    // 각 그룹 내에서 최신순 정렬 (이미 _filteredEntries가 정렬되어 있으므로 최소화)
    for (final entries in groupedEntries.values) {
      if (entries.length > 1) {
        entries.sort((a, b) => b.date.compareTo(a.date));
      }
    }
    
    // 캐시에 저장
    _groupedEntriesCache = groupedEntries;
    return groupedEntries;
  }

  void _onSearchChanged(String query) {
    _searchDebounceTimer?.cancel();
    _searchDebounceTimer = Timer(const Duration(milliseconds: 300), () {
      if (mounted) {
        setState(() {
          _searchQuery = query;
          _updateFilteredEntries();
        });
      }
    });
  }

  // 성능 최적화된 필터 토글
  void _toggleMoodFilter(MoodType? mood) {
    setState(() {
      _filterMood = mood;
      _updateFilteredEntries();
    });
    
    // 애니메이션 효과
    if (_showMoodFilters) {
      _filterAnimationController.forward();
    }
  }

  // 성능 최적화된 즐겨찾기 토글
  void _toggleFavoritesOnly() {
    setState(() {
      _showFavoritesOnly = !_showFavoritesOnly;
      _updateFilteredEntries();
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('감정 일기'),
        backgroundColor: theme.colorScheme.surface,
        actions: [
          // 감정 필터 버튼 추가
          IconButton(
            icon: Icon(
              _showMoodFilters ? Icons.filter_alt : Icons.filter_alt_outlined,
              color: _filterMood != null ? AppColors.primary : null,
            ),
            onPressed: () {
              setState(() {
                _showMoodFilters = !_showMoodFilters;
              });
            },
            tooltip: '감정 필터',
          ),
          IconButton(
            icon: Icon(
              _showAdvancedFilters ? Icons.tune : Icons.tune_outlined,
              color: (_filterActivity != null || _showFavoritesOnly) ? AppColors.primary : null,
            ),
            onPressed: () {
              setState(() {
                _showAdvancedFilters = !_showAdvancedFilters;
              });
            },
            tooltip: '고급 필터',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshData,
        child: CustomScrollView(
          slivers: [
            _buildSearchBar(),
            if (_showMoodFilters) _buildMoodFilterChips(),
            if (_showAdvancedFilters) _buildAdvancedFilters(),
            _buildActiveFiltersIndicator(),
            if (_isLoading)
              const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_filteredEntries.isEmpty)
              _buildEmptyState()
            else
              _buildMoodEntryList(),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return SliverToBoxAdapter(
      child: Container(
        margin: const EdgeInsets.all(AppSizes.paddingM),
        child: TextField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText: '일기 내용을 검색해보세요',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: _searchQuery.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _searchController.clear();
                      setState(() {
                        _searchQuery = '';
                        _updateFilteredEntries();
                      });
                    },
                  )
                : null,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppSizes.radiusL),
              borderSide: BorderSide.none,
            ),
            filled: true,
            fillColor: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
          ),
          onChanged: _onSearchChanged,
        ),
      ),
    );
  }

  Widget _buildMoodFilterChips() {
    return SliverToBoxAdapter(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: AppSizes.paddingM),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSizes.paddingM),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '감정별 필터',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: AppSizes.paddingM),
                                 Wrap(
                   spacing: AppSizes.paddingS,
                   runSpacing: AppSizes.paddingS,
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
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, MoodType? mood) {
    final isSelected = _filterMood == mood;
    final color = mood != null ? _getMoodColor(mood) : AppColors.primary;
    
    return FilterChip(
      label: Text(
        label, 
        style: TextStyle(
          fontSize: 13,
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
          color: isSelected ? color : null,
        )
      ),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _filterMood = selected ? mood : null;
          _updateFilteredEntries();
        });
      },
      selectedColor: color.withOpacity(0.2),
      checkmarkColor: color,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.comfortable,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    );
  }

  Widget _buildAdvancedFilters() {
    final theme = Theme.of(context);
    
    return SliverToBoxAdapter(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: AppSizes.paddingM),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSizes.paddingM),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '고급 필터',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: AppSizes.paddingM),
                
                // 즐겨찾기 필터
                Row(
                  children: [
                    Checkbox(
                      value: _showFavoritesOnly,
                      onChanged: (value) {
                        setState(() {
                          _showFavoritesOnly = value ?? false;
                          _updateFilteredEntries();
                        });
                      },
                      activeColor: AppColors.primary,
                    ),
                    const Text('즐겨찾기만 보기'),
                    const Spacer(),
                    if (_showFavoritesOnly)
                      Icon(
                        Icons.favorite,
                        color: AppColors.primary,
                        size: 20,
                      ),
                  ],
                ),
                
                const SizedBox(height: AppSizes.paddingS),
                
                // 활동별 필터
                Text(
                  '활동별 필터',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: AppSizes.paddingS),
                _buildActivityFilter(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActivityFilter() {
    return Wrap(
      spacing: AppSizes.paddingS,
      runSpacing: AppSizes.paddingS,
      children: [
        // 전체 활동 선택
        FilterChip(
          label: const Text('전체', style: TextStyle(fontSize: 12)),
          selected: _filterActivity == null,
          onSelected: (selected) {
            setState(() {
              _filterActivity = null;
              _updateFilteredEntries();
            });
          },
          selectedColor: AppColors.primary.withOpacity(0.2),
          checkmarkColor: AppColors.primary,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        // 각 활동별 필터
        ...DefaultActivities.defaultActivities.map((activity) => FilterChip(
          label: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(activity.emoji, style: const TextStyle(fontSize: 14)),
              const SizedBox(width: 4),
              Text(activity.name, style: const TextStyle(fontSize: 12)),
            ],
          ),
          selected: _filterActivity == activity.id,
          onSelected: (selected) {
            setState(() {
              _filterActivity = selected ? activity.id : null;
              _updateFilteredEntries();
            });
          },
          selectedColor: AppColors.primary.withOpacity(0.2),
          checkmarkColor: AppColors.primary,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        )),
      ],
    );
  }

  void _clearAllFilters() {
    setState(() {
      _filterMood = null;
      _filterActivity = null;
      _showFavoritesOnly = false;
      _searchQuery = '';
      _searchController.clear();
      _updateFilteredEntries();
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('모든 필터가 초기화되었습니다'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  Widget _buildActiveFiltersIndicator() {
    final activeFilters = <String>[];
    
    if (_filterMood != null) {
      activeFilters.add('감정: ${_getMoodLabel(_filterMood!)}');
    }
    
    if (_filterActivity != null) {
      final activity = DefaultActivities.defaultActivities
          .firstWhere((a) => a.id == _filterActivity);
      activeFilters.add('활동: ${activity.emoji} ${activity.name}');
    }
    
    if (_showFavoritesOnly) {
      activeFilters.add('즐겨찾기만');
    }
    
    if (_searchQuery.isNotEmpty) {
      activeFilters.add('검색: "$_searchQuery"');
    }
    
    if (activeFilters.isEmpty) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }
    
    return SliverToBoxAdapter(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: AppSizes.paddingM),
        child: Card(
          color: AppColors.primary.withOpacity(0.05),
          child: Padding(
            padding: const EdgeInsets.all(AppSizes.paddingS),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.filter_alt,
                      size: 16,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '적용된 필터 (${_filteredEntries.length}개 결과)',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: _clearAllFilters,
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        minimumSize: const Size(0, 32),
                      ),
                      child: const Text(
                        '초기화',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: activeFilters.map((filter) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.primary.withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      filter,
                      style: const TextStyle(fontSize: 11),
                    ),
                  )).toList(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _getMoodLabel(MoodType mood) {
    switch (mood) {
      case MoodType.best:
        return '최고';
      case MoodType.good:
        return '좋음';
      case MoodType.neutral:
        return '보통';
      case MoodType.bad:
        return '나쁨';
      case MoodType.worst:
        return '최악';
    }
  }

  Widget _buildEmptyState() {
    final theme = Theme.of(context);
    
    String title;
    String subtitle;
    IconData icon;
    
    if (_searchQuery.isNotEmpty) {
      title = '검색 결과가 없습니다';
      subtitle = '다른 키워드로 검색해보세요';
      icon = Icons.search_off;
    } else if (_showFavoritesOnly) {
      title = '즐겨찾기한 일기가 없습니다';
      subtitle = '하트를 눌러 일기를 즐겨찾기에 추가해보세요';
      icon = Icons.favorite_border;
    } else if (_filterMood != null || _filterActivity != null) {
      title = '조건에 맞는 일기가 없습니다';
      subtitle = '다른 필터를 선택하거나 필터를 초기화해보세요';
      icon = Icons.filter_alt_off;
    } else {
      title = '아직 작성된 일기가 없어요';
      subtitle = '첫 번째 감정 일기를 작성해보세요!';
      icon = Icons.article_outlined;
    }
    
    return SliverFillRemaining(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 64,
              color: theme.colorScheme.onSurface.withOpacity(0.3),
            ),
            const SizedBox(height: AppSizes.paddingL),
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.7),
              ),
            ),
            const SizedBox(height: AppSizes.paddingS),
            Text(
              subtitle,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.5),
              ),
              textAlign: TextAlign.center,
            ),
            if (_filterMood != null || _filterActivity != null || _showFavoritesOnly || _searchQuery.isNotEmpty) ...[
              const SizedBox(height: AppSizes.paddingL),
              ElevatedButton.icon(
                onPressed: _clearAllFilters,
                icon: const Icon(Icons.clear_all),
                label: const Text('필터 초기화'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMoodEntryList() {
    final groupedEntries = _groupEntriesByDate();
    
    return SliverPadding(
      padding: const EdgeInsets.all(AppSizes.paddingM),
      sliver: SliverList.builder(
        itemCount: groupedEntries.keys.length,
        itemBuilder: (context, index) {
          final dateKeys = groupedEntries.keys.toList();
          final dateKey = dateKeys[index];
          final entriesForDate = groupedEntries[dateKey]!;
          
          return RepaintBoundary(
            key: ValueKey('date_group_$dateKey'),
            child: Container(
              margin: const EdgeInsets.only(bottom: AppSizes.paddingL),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 날짜 헤더
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSizes.paddingM,
                      vertical: AppSizes.paddingS,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(AppSizes.radiusS),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.today,
                          size: 18,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          dateKey,
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${entriesForDate.length}개',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSizes.paddingS),
                  
                  // 해당 날짜의 일기들 (연결된 카드로 표시)
                  _buildConnectedEntryCards(entriesForDate),
                ],
              ),
            ),
          );
        },
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

  void _navigateToEntryDetail(MoodEntry entry) {
    // TODO: 일기 상세 화면으로 이동
    _navigateToEditEntry(entry);
  }

  void _navigateToEditEntry(MoodEntry entry) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => MoodEntryScreen(existingEntry: entry),
      ),
    ).then((result) {
      if (result == true) {
        _loadEntries(); // 데이터 새로고침
      }
    });
  }

  Future<void> _deleteEntry(MoodEntry entry) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('일기 삭제'),
        content: const Text('정말로 이 일기를 삭제하시겠어요?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();
              
              try {
                final storage = LocalStorageService.instance;
                final success = await storage.deleteMoodEntry(entry.id);
                
                if (success) {
                  await _loadEntries(); // 데이터 새로고침
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('일기가 삭제되었습니다'),
                        backgroundColor: AppColors.success,
                      ),
                    );
                  }
                } else {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('삭제 중 오류가 발생했습니다'),
                        backgroundColor: AppColors.error,
                      ),
                    );
                  }
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('삭제 중 오류: $e'),
                      backgroundColor: AppColors.error,
                    ),
                  );
                }
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

  Future<void> _toggleFavorite(MoodEntry entry) async {
    try {
      final storage = LocalStorageService.instance;
      final updatedEntry = entry.copyWith(isFavorite: !entry.isFavorite);
      final success = await storage.saveMoodEntry(updatedEntry);
      
      if (success) {
        await _loadEntries(); // 데이터 새로고침
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('즐겨찾기 설정 중 오류가 발생했습니다'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('즐겨찾기 설정 중 오류: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Widget _buildMiniCalendar() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(AppSizes.paddingM, 0, AppSizes.paddingM, AppSizes.paddingS),
        child: MiniCalendarWidget(
          onDateSelected: (date) {
            // 선택된 날짜의 일기들을 보여주기 위해 달력 탭으로 이동
            Navigator.of(context).pushNamed('/calendar');
          },
          monthsToShow: 2,
        ),
      ),
    );
  }

  Future<void> _refreshData() async {
    await _loadEntries();
  }

  Widget _buildConnectedEntryCards(List<MoodEntry> entries) {
    if (entries.isEmpty) return const SizedBox.shrink();
    
    return Column(
      children: entries.asMap().entries.map((entryData) {
        final index = entryData.key;
        final entry = entryData.value;
        final isFirst = index == 0;
        final isLast = index == entries.length - 1;
        
        return Container(
          margin: EdgeInsets.only(
            bottom: isLast ? 0 : 2, // 연결된 느낌을 위해 간격 줄임
          ),
          child: Card(
            elevation: isFirst ? 3 : 1, // 첫 번째 카드만 높은 elevation
            margin: EdgeInsets.zero,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(isFirst ? AppSizes.radiusL : AppSizes.radiusS),
                topRight: Radius.circular(isFirst ? AppSizes.radiusL : AppSizes.radiusS),
                bottomLeft: Radius.circular(isLast ? AppSizes.radiusL : AppSizes.radiusS),
                bottomRight: Radius.circular(isLast ? AppSizes.radiusL : AppSizes.radiusS),
              ),
            ),
            child: Container(
              decoration: BoxDecoration(
                border: !isLast ? Border(
                  bottom: BorderSide(
                    color: Theme.of(context).colorScheme.outline.withOpacity(0.1),
                    width: 1,
                  ),
                ) : null,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(isFirst ? AppSizes.radiusL : AppSizes.radiusS),
                  topRight: Radius.circular(isFirst ? AppSizes.radiusL : AppSizes.radiusS),
                  bottomLeft: Radius.circular(isLast ? AppSizes.radiusL : AppSizes.radiusS),
                  bottomRight: Radius.circular(isLast ? AppSizes.radiusL : AppSizes.radiusS),
                ),
              ),
              child: InkWell(
                onTap: () => _navigateToEntryDetail(entry),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(isFirst ? AppSizes.radiusL : AppSizes.radiusS),
                  topRight: Radius.circular(isFirst ? AppSizes.radiusL : AppSizes.radiusS),
                  bottomLeft: Radius.circular(isLast ? AppSizes.radiusL : AppSizes.radiusS),
                  bottomRight: Radius.circular(isLast ? AppSizes.radiusL : AppSizes.radiusS),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(AppSizes.paddingM),
                  child: _buildEntryContent(entry, index, entries.length),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildEntryContent(MoodEntry entry, int index, int totalCount) {
    final theme = Theme.of(context);
    final moodColor = _getMoodColor(entry.mood);
    final isFirst = index == 0;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 헤더 (첫 번째 카드에만 시간 표시)
        Row(
          children: [
            // 감정 아이콘 (더 작게)
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: moodColor.withOpacity(0.2),
                borderRadius: BorderRadius.circular(AppSizes.radiusS),
                border: Border.all(
                  color: moodColor.withOpacity(0.4),
                ),
              ),
              child: Center(
                child: Text(
                  entry.mood.emoji,
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ),
            const SizedBox(width: AppSizes.paddingM),
            
            // 제목과 정보
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (entry.title != null && entry.title!.isNotEmpty) ...[
                    Text(
                      entry.title!,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        fontSize: isFirst ? 16 : 15,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                  ],
                  Row(
                    children: [
                      // 감정 라벨
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: moodColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          entry.mood.label,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: moodColor,
                            fontWeight: FontWeight.w500,
                            fontSize: 10,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // 시간
                      Text(
                        DateFormat('HH:mm').format(entry.createdAt),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withOpacity(0.6),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            // 액션 버튼들
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  onPressed: () => _toggleFavorite(entry),
                  icon: Icon(
                    entry.isFavorite ? Icons.favorite : Icons.favorite_border,
                    color: entry.isFavorite ? AppColors.error : null,
                    size: 18,
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 28,
                    minHeight: 28,
                  ),
                  padding: EdgeInsets.zero,
                ),
                PopupMenuButton<String>(
                  onSelected: (value) {
                    switch (value) {
                      case 'edit':
                        _navigateToEditEntry(entry);
                        break;
                      case 'delete':
                        _deleteEntry(entry);
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
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete, size: 16, color: AppColors.error),
                          SizedBox(width: 8),
                          Text('삭제', style: TextStyle(color: AppColors.error)),
                        ],
                      ),
                    ),
                  ],
                  icon: Icon(
                    Icons.more_vert,
                    size: 18,
                    color: theme.colorScheme.onSurface.withOpacity(0.6),
                  ),
                ),
              ],
            ),
          ],
        ),
        
        // 내용
        if (entry.content.isNotEmpty) ...[
          const SizedBox(height: AppSizes.paddingM),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSizes.paddingM),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
              borderRadius: BorderRadius.circular(AppSizes.radiusM),
              border: Border.all(
                color: theme.colorScheme.outline.withOpacity(0.1),
              ),
            ),
            child: Text(
              entry.content,
              style: theme.textTheme.bodyMedium?.copyWith(
                height: 1.5,
              ),
            ),
          ),
        ],
        
        // 이미지
        if (entry.imageUrls.isNotEmpty) ...[
          const SizedBox(height: AppSizes.paddingM),
          SizedBox(
            height: 80,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: entry.imageUrls.length,
              itemBuilder: (context, imgIndex) {
                final imagePath = entry.imageUrls[imgIndex];
                return Container(
                  margin: const EdgeInsets.only(right: AppSizes.paddingS),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(AppSizes.radiusS),
                    child: AspectRatio(
                      aspectRatio: 1,
                      child: _buildImageWidget(imagePath, theme),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
        
        // 활동
        if (entry.activities.isNotEmpty) ...[
          const SizedBox(height: AppSizes.paddingM),
          _buildActivitiesWrap(entry.activities, theme),
        ],
      ],
    );
  }

  Widget _buildImageWidget(String imagePath, ThemeData theme) {
    if (kIsWeb) {
      final imageData = ImageService.instance.getWebImageData(imagePath);
      if (imageData != null) {
        return Image.memory(
          imageData,
          fit: BoxFit.cover,
        );
      }
    } else {
      if (File(imagePath).existsSync()) {
        return Image.file(
          File(imagePath),
          fit: BoxFit.cover,
        );
      }
    }
    
    return Container(
      color: theme.colorScheme.surfaceVariant,
      child: Icon(
        Icons.broken_image,
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
  }

  Widget _buildActivitiesWrap(List<String> activityIds, ThemeData theme) {
    final activities = DefaultActivities.defaultActivities
        .where((activity) => activityIds.contains(activity.id))
        .toList();

    return Wrap(
      spacing: AppSizes.paddingXS,
      runSpacing: AppSizes.paddingXS,
      children: activities.map((activity) {
        final color = _parseColor(activity.color);
        return Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSizes.paddingS,
            vertical: 2,
          ),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: color.withOpacity(0.3),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                activity.emoji,
                style: const TextStyle(fontSize: 12),
              ),
              const SizedBox(width: 4),
              Text(
                activity.name,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontSize: 11,
                  color: color,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Color _parseColor(String colorHex) {
    try {
      return Color(int.parse(colorHex.replaceFirst('#', '0xFF')));
    } catch (e) {
      return AppColors.primary;
    }
  }

  @override
  bool get wantKeepAlive => true;
} 