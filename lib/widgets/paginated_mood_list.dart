import 'package:flutter/material.dart';
import '../models/mood_entry_model.dart';
import '../services/local_storage_service.dart';
import '../widgets/mood_entry_card.dart';
import '../constants/app_colors.dart';
import '../constants/app_sizes.dart';

class PaginatedMoodList extends StatefulWidget {
  final MoodType? filterMood;
  final String? searchQuery;
  final bool? favoritesOnly;
  final Function(MoodEntry)? onEntryTap;
  final Function(MoodEntry)? onEntryEdit;
  final Function(MoodEntry)? onEntryDelete;
  final Function(MoodEntry)? onFavoriteToggle;
  final int pageSize;
  final bool shrinkWrap;

  const PaginatedMoodList({
    super.key,
    this.filterMood,
    this.searchQuery,
    this.favoritesOnly,
    this.onEntryTap,
    this.onEntryEdit,
    this.onEntryDelete,
    this.onFavoriteToggle,
    this.pageSize = 20,
    this.shrinkWrap = false,
  });

  @override
  State<PaginatedMoodList> createState() => _PaginatedMoodListState();
}

class _PaginatedMoodListState extends State<PaginatedMoodList> {
  final ScrollController _scrollController = ScrollController();
  final List<MoodEntry> _entries = [];
  
  int _currentPage = 0;
  bool _isLoading = false;
  bool _hasMore = true;
  bool _isInitialLoad = true;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadInitialData();
  }

  @override
  void didUpdateWidget(PaginatedMoodList oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // 필터가 변경되면 리스트 초기화
    if (oldWidget.filterMood != widget.filterMood ||
        oldWidget.searchQuery != widget.searchQuery ||
        oldWidget.favoritesOnly != widget.favoritesOnly) {
      _resetList();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _loadMoreData();
    }
  }

  Future<void> _loadInitialData() async {
    setState(() {
      _isInitialLoad = true;
      _isLoading = true;
    });

    await _loadMoreData();

    setState(() {
      _isInitialLoad = false;
    });
  }

  Future<void> _loadMoreData() async {
    if (_isLoading || !_hasMore) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final newEntries = await LocalStorageService.instance.getMoodEntriesPaginated(
        page: _currentPage,
        pageSize: widget.pageSize,
        filterMood: widget.filterMood,
        searchQuery: widget.searchQuery,
        favoritesOnly: widget.favoritesOnly,
      );

      if (mounted) {
        setState(() {
          if (newEntries.length < widget.pageSize) {
            _hasMore = false;
          }
          
          _entries.addAll(newEntries);
          _currentPage++;
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

  void _resetList() {
    setState(() {
      _entries.clear();
      _currentPage = 0;
      _hasMore = true;
      _isLoading = false;
    });
    _loadInitialData();
  }

  // 외부에서 호출 가능한 새로고침 메서드
  Future<void> refresh() async {
    _resetList();
  }

  // 항목 업데이트 (외부에서 호출 가능)
  void updateEntry(MoodEntry updatedEntry) {
    setState(() {
      final index = _entries.indexWhere((e) => e.id == updatedEntry.id);
      if (index != -1) {
        _entries[index] = updatedEntry;
      }
    });
  }

  // 항목 제거 (외부에서 호출 가능)
  void removeEntry(String entryId) {
    setState(() {
      _entries.removeWhere((e) => e.id == entryId);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isInitialLoad) {
      return _buildInitialLoader();
    }

    if (_entries.isEmpty && !_isLoading) {
      return _buildEmptyState();
    }

    return RefreshIndicator(
      onRefresh: refresh,
      color: AppColors.primary,
      child: ListView.builder(
        controller: widget.shrinkWrap ? null : _scrollController,
        shrinkWrap: widget.shrinkWrap,
        physics: widget.shrinkWrap 
          ? const NeverScrollableScrollPhysics() 
          : const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppSizes.paddingM),
        itemCount: _entries.length + (_hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == _entries.length) {
            return _buildLoadingIndicator();
          }

          final entry = _entries[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: AppSizes.paddingS),
            child: MoodEntryCard(
              entry: entry,
              onTap: () => widget.onEntryTap?.call(entry),
              onEdit: () => widget.onEntryEdit?.call(entry),
              onDelete: () => widget.onEntryDelete?.call(entry),
              onFavoriteToggle: () => widget.onFavoriteToggle?.call(entry),
            ),
          );
        },
      ),
    );
  }

  Widget _buildInitialLoader() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(AppSizes.paddingL),
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
        ),
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: AppSizes.paddingM),
      child: Center(
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    final theme = Theme.of(context);
    
    String title;
    String subtitle;
    IconData icon;
    
    if (widget.searchQuery?.isNotEmpty == true) {
      title = '검색 결과가 없습니다';
      subtitle = '다른 키워드로 검색해보세요';
      icon = Icons.search_off;
    } else if (widget.favoritesOnly == true) {
      title = '즐겨찾기한 일기가 없습니다';
      subtitle = '하트를 눌러 일기를 즐겨찾기에 추가해보세요';
      icon = Icons.favorite_border;
    } else if (widget.filterMood != null) {
      title = '조건에 맞는 일기가 없습니다';
      subtitle = '다른 필터를 선택해보세요';
      icon = Icons.filter_alt_off;
    } else {
      title = '아직 작성된 일기가 없어요';
      subtitle = '첫 번째 감정 일기를 작성해보세요!';
      icon = Icons.article_outlined;
    }
    
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.paddingXL),
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
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSizes.paddingS),
            Text(
              subtitle,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.5),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// 성능 최적화된 일기 카운터 위젯
class MoodEntryCounter extends StatefulWidget {
  final MoodType? filterMood;
  final String? searchQuery;
  final bool? favoritesOnly;

  const MoodEntryCounter({
    super.key,
    this.filterMood,
    this.searchQuery,
    this.favoritesOnly,
  });

  @override
  State<MoodEntryCounter> createState() => _MoodEntryCounterState();
}

class _MoodEntryCounterState extends State<MoodEntryCounter> {
  int _count = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCount();
  }

  @override
  void didUpdateWidget(MoodEntryCounter oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    if (oldWidget.filterMood != widget.filterMood ||
        oldWidget.searchQuery != widget.searchQuery ||
        oldWidget.favoritesOnly != widget.favoritesOnly) {
      _loadCount();
    }
  }

  Future<void> _loadCount() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final count = await LocalStorageService.instance.getMoodEntriesCount(
        filterMood: widget.filterMood,
        searchQuery: widget.searchQuery,
        favoritesOnly: widget.favoritesOnly,
      );

      if (mounted) {
        setState(() {
          _count = count;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _count = 0;
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }

    return Text(
      '$_count개',
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
        color: AppColors.primary,
        fontWeight: FontWeight.w500,
      ),
    );
  }
} 