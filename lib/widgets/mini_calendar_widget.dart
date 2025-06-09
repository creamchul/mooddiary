import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import '../constants/app_colors.dart';
import '../constants/app_sizes.dart';
import '../models/mood_entry_model.dart';
import '../services/local_storage_service.dart';

class MiniCalendarWidget extends StatefulWidget {
  final Function(DateTime)? onDateSelected;
  final int monthsToShow;
  final double? height;

  const MiniCalendarWidget({
    super.key,
    this.onDateSelected,
    this.monthsToShow = 1,
    this.height,
  });

  @override
  State<MiniCalendarWidget> createState() => _MiniCalendarWidgetState();
}

class _MiniCalendarWidgetState extends State<MiniCalendarWidget> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  List<MoodEntry> _entries = [];
  Map<DateTime, List<MoodEntry>> _entriesByDate = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _selectedDay = DateTime.now();
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
          _entriesByDate = _groupEntriesByDate(entries);
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
    return _entriesByDate[normalizedDay] ?? [];
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final today = DateTime.now();
    
    if (_isLoading) {
      return Container(
        height: widget.height ?? 200,
        child: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }
    
    return Container(
      height: widget.height ?? 200,
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
        children: [
          // 헤더
          Padding(
            padding: const EdgeInsets.all(AppSizes.paddingM),
            child: Row(
              children: [
                Icon(
                  Icons.calendar_today,
                  size: 20,
                  color: AppColors.primary,
                ),
                const SizedBox(width: AppSizes.paddingS),
                Text(
                  '최근 감정 기록',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () {
                    if (widget.onDateSelected != null) {
                      widget.onDateSelected!(DateTime.now());
                    }
                  },
                  child: const Text(
                    '전체 보기',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
          
          // 미니 캘린더
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSizes.paddingM),
              child: TableCalendar<MoodEntry>(
                firstDay: DateTime.now().subtract(const Duration(days: 365)),
                lastDay: today,
                focusedDay: _focusedDay,
                calendarFormat: CalendarFormat.week, // 주간 보기
                eventLoader: _getEntriesForDay,
                startingDayOfWeek: StartingDayOfWeek.monday,
                locale: 'ko_KR',
                
                selectedDayPredicate: (day) {
                  return isSameDay(_selectedDay, day);
                },
                
                enabledDayPredicate: (day) {
                  final normalizedDay = DateTime(day.year, day.month, day.day);
                  final normalizedToday = DateTime(today.year, today.month, today.day);
                  return normalizedDay.isBefore(normalizedToday) || 
                         normalizedDay.isAtSameMomentAs(normalizedToday);
                },
                
                onDaySelected: (selectedDay, focusedDay) {
                  final normalizedSelectedDay = DateTime(selectedDay.year, selectedDay.month, selectedDay.day);
                  final normalizedToday = DateTime(today.year, today.month, today.day);
                  
                  if (normalizedSelectedDay.isAfter(normalizedToday)) {
                    return;
                  }
                  
                  setState(() {
                    _selectedDay = selectedDay;
                    _focusedDay = focusedDay;
                  });
                  
                  if (widget.onDateSelected != null) {
                    widget.onDateSelected!(selectedDay);
                  }
                },
                
                onPageChanged: (focusedDay) {
                  setState(() {
                    _focusedDay = focusedDay;
                  });
                },
                
                calendarStyle: CalendarStyle(
                  outsideDaysVisible: false,
                  weekendTextStyle: TextStyle(
                    color: AppColors.error,
                    fontSize: 12,
                  ),
                  holidayTextStyle: TextStyle(
                    color: AppColors.error,
                    fontSize: 12,
                  ),
                  
                  selectedDecoration: BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                  selectedTextStyle: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                  
                  todayDecoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.3),
                    shape: BoxShape.circle,
                  ),
                  todayTextStyle: TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                  
                  defaultTextStyle: TextStyle(
                    color: theme.colorScheme.onSurface,
                    fontSize: 12,
                  ),
                  
                  disabledTextStyle: TextStyle(
                    color: theme.colorScheme.onSurface.withOpacity(0.3),
                    fontSize: 12,
                  ),
                  
                  markersMaxCount: 0,
                  cellMargin: const EdgeInsets.all(2),
                ),
                
                headerStyle: HeaderStyle(
                  formatButtonVisible: false,
                  titleCentered: true,
                  headerPadding: const EdgeInsets.only(bottom: 8),
                  leftChevronIcon: Icon(
                    Icons.chevron_left,
                    color: theme.colorScheme.onSurface,
                    size: 20,
                  ),
                  rightChevronIcon: Icon(
                    Icons.chevron_right,
                    color: theme.colorScheme.onSurface,
                    size: 20,
                  ),
                  titleTextStyle: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ) ?? const TextStyle(),
                ),
                
                daysOfWeekStyle: DaysOfWeekStyle(
                  weekdayStyle: TextStyle(
                    color: theme.colorScheme.onSurface.withOpacity(0.7),
                    fontWeight: FontWeight.w500,
                    fontSize: 11,
                  ),
                  weekendStyle: TextStyle(
                    color: AppColors.error.withOpacity(0.7),
                    fontWeight: FontWeight.w500,
                    fontSize: 11,
                  ),
                ),
                
                calendarBuilders: CalendarBuilders(
                  markerBuilder: (context, date, entries) {
                    if (entries.isEmpty) return const SizedBox.shrink();
                    
                    return Positioned(
                      bottom: 1,
                      child: _buildMoodMarker(entries),
                    );
                  },
                ),
              ),
            ),
          ),
          
          const SizedBox(height: AppSizes.paddingS),
        ],
      ),
    );
  }

  Widget _buildMoodMarker(List<MoodEntry> entries) {
    if (entries.isEmpty) return const SizedBox.shrink();
    
    final entryCount = entries.length;
    
    if (entryCount == 1) {
      return Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          color: _getMoodColor(entries.first.mood),
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.white,
            width: 1,
          ),
        ),
      );
    } else {
      // 여러 개일 때는 작게 겹쳐서 표시
      final displayEntries = entries.take(3).toList();
      
      return SizedBox(
        width: 12,
        height: 8,
        child: Stack(
          children: [
            for (int i = 0; i < displayEntries.length && i < 2; i++)
              Positioned(
                left: i * 3.0,
                child: Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: _getMoodColor(displayEntries[i].mood),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white,
                      width: 0.5,
                    ),
                  ),
                ),
              ),
            if (entryCount > 2)
              Positioned(
                right: 0,
                child: Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white,
                      width: 0.5,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      '+',
                      style: TextStyle(
                        fontSize: 4,
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
  }
} 