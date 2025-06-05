import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../constants/app_colors.dart';
import '../constants/app_sizes.dart';
import '../models/mood_entry_model.dart';
import '../models/activity_model.dart';
import '../widgets/mood_entry_card.dart';
import '../services/local_storage_service.dart';
import 'mood_entry_screen.dart';

class MoodDiaryScreen extends StatefulWidget {
  const MoodDiaryScreen({super.key});

  @override
  State<MoodDiaryScreen> createState() => MoodDiaryScreenState();
}

class MoodDiaryScreenState extends State<MoodDiaryScreen> {
  DateTime _selectedMonth = DateTime.now();
  String _searchQuery = '';
  MoodType? _filterMood;
  String? _filterActivity; // 활동별 필터
  bool _showFavoritesOnly = false; // 즐겨찾기만 보기
  bool _showSearchBar = false;
  bool _showAdvancedFilters = false; // 고급 필터 표시 여부
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();

  List<MoodEntry> _entries = [];
  List<MoodEntry> _filteredEntries = [];
  bool _isLoading = true;

  Timer? _searchDebounceTimer; // 검색 딜레이용 타이머

  @override
  void initState() {
    super.initState();
    _loadEntries();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    _searchDebounceTimer?.cancel();
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
    _filteredEntries = _entries.where((entry) {
      // 월별 필터 제거 - 모든 일기를 보여줌
      
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
  }

  // 날짜별로 그룹화하는 함수 추가
  Map<String, List<MoodEntry>> _groupEntriesByDate() {
    final groupedEntries = <String, List<MoodEntry>>{};
    final now = DateTime.now();
    
    for (final entry in _filteredEntries) {
      final entryDate = DateTime(entry.date.year, entry.date.month, entry.date.day);
      final today = DateTime(now.year, now.month, now.day);
      final yesterday = today.subtract(const Duration(days: 1));
      
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
      
      groupedEntries.putIfAbsent(dateKey, () => []).add(entry);
    }
    
    // 각 그룹 내에서도 최신순 정렬
    groupedEntries.forEach((key, entries) {
      entries.sort((a, b) => b.date.compareTo(a.date));
    });
    
    return groupedEntries;
  }

  void _onSearchChanged(String query) {
    _searchDebounceTimer?.cancel();
    _searchDebounceTimer = Timer(const Duration(milliseconds: 300), () {
      setState(() {
        _searchQuery = query;
        _updateFilteredEntries();
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      backgroundColor: theme.colorScheme.background,
      body: CustomScrollView(
        controller: _scrollController,
        slivers: [
          _buildAppBar(),
          if (_showSearchBar) _buildSearchBar(),
          if (_showAdvancedFilters) _buildAdvancedFilters(),
          _buildFilterChips(),
          _buildActiveFiltersIndicator(),
          if (_isLoading)
            const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_filteredEntries.isEmpty)
            _buildEmptyState()
          else
            _buildEntriesList(),
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
          '감정 일기',
          style: theme.textTheme.titleLarge?.copyWith(
            color: theme.colorScheme.onSurface,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: false,
        titlePadding: const EdgeInsets.only(left: 16, bottom: 16),
      ),
      actions: [
        IconButton(
          icon: Icon(_showSearchBar ? Icons.close : Icons.search),
          onPressed: () {
            setState(() {
              _showSearchBar = !_showSearchBar;
              if (!_showSearchBar) {
                _searchController.clear();
                _searchQuery = '';
                _updateFilteredEntries();
              }
            });
          },
        ),
        IconButton(
          icon: Icon(
            Icons.filter_list,
            color: _showAdvancedFilters ? AppColors.primary : null,
          ),
          onPressed: () {
            setState(() {
              _showAdvancedFilters = !_showAdvancedFilters;
            });
          },
        ),
        PopupMenuButton<String>(
          onSelected: (value) {
            switch (value) {
              case 'clear_filters':
                _clearAllFilters();
                break;
              case 'export':
                // TODO: 내보내기 기능
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('내보내기 기능은 곧 추가됩니다')),
                );
                break;
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'clear_filters',
              child: Row(
                children: [
                  Icon(Icons.clear_all, size: 18),
                  SizedBox(width: 8),
                  Text('필터 초기화'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'export',
              child: Row(
                children: [
                  Icon(Icons.file_download, size: 18),
                  SizedBox(width: 8),
                  Text('내보내기'),
                ],
              ),
            ),
          ],
        ),
      ],
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

  Widget _buildFilterChips() {
    return SliverToBoxAdapter(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: AppSizes.paddingM),
        height: 60,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(vertical: 8),
          children: [
            const SizedBox(width: 4),
            _buildFilterChip('전체', null),
            const SizedBox(width: AppSizes.paddingS),
            _buildFilterChip('최고', MoodType.best),
            const SizedBox(width: AppSizes.paddingS),
            _buildFilterChip('좋음', MoodType.good),
            const SizedBox(width: AppSizes.paddingS),
            _buildFilterChip('그저그래', MoodType.neutral),
            const SizedBox(width: AppSizes.paddingS),
            _buildFilterChip('별로', MoodType.bad),
            const SizedBox(width: AppSizes.paddingS),
            _buildFilterChip('최악', MoodType.worst),
            const SizedBox(width: 4),
          ],
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
        return '그저그래';
      case MoodType.bad:
        return '별로';
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

  Widget _buildEntriesList() {
    final groupedEntries = _groupEntriesByDate();
    
    return SliverPadding(
      padding: const EdgeInsets.all(AppSizes.paddingM),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final dateKeys = groupedEntries.keys.toList();
            final dateKey = dateKeys[index];
            final entriesForDate = groupedEntries[dateKey]!;
            
            return Container(
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
                  
                  // 해당 날짜의 일기들
                  ...entriesForDate.map((entry) => Padding(
                    padding: const EdgeInsets.only(bottom: AppSizes.paddingS),
                    child: MoodEntryCard(
                      entry: entry,
                      onTap: () => _navigateToEntryDetail(entry),
                      onEdit: () => _navigateToEditEntry(entry),
                      onDelete: () => _deleteEntry(entry),
                      onFavoriteToggle: () => _toggleFavorite(entry),
                    ),
                  )),
                ],
              ),
            );
          },
          childCount: _groupEntriesByDate().keys.length,
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
} 