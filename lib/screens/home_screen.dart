import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_sizes.dart';
import '../models/mood_entry_model.dart';
import '../services/local_storage_service.dart';
import 'mood_entry_screen.dart';
import 'mood_diary_screen.dart';
import 'calendar_screen.dart';
import 'statistics_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  int _selectedIndex = 0; // 일기 화면이 첫 번째가 됩니다
  final GlobalKey<MoodDiaryScreenState> _diaryKey = GlobalKey<MoodDiaryScreenState>();
  final GlobalKey<CalendarScreenState> _calendarKey = GlobalKey<CalendarScreenState>();
  final GlobalKey<StatisticsScreenState> _statisticsKey = GlobalKey<StatisticsScreenState>();
  
  // 성능 최적화: 화면 캐싱
  late final List<Widget> _screens;
  
  @override
  void initState() {
    super.initState();
    // 화면 미리 생성 (성능 최적화)
    _screens = [
      MoodDiaryScreen(key: _diaryKey),
      CalendarScreen(key: _calendarKey),
      StatisticsScreen(key: _statisticsKey),
      const SettingsScreen(),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: _screens,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: theme.shadowColor.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: (index) => setState(() => _selectedIndex = index),
          type: BottomNavigationBarType.fixed,
          backgroundColor: theme.colorScheme.surface,
          selectedItemColor: AppColors.primary,
          unselectedItemColor: theme.colorScheme.onSurface.withOpacity(0.6),
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600),
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.book_rounded),
              label: '일기',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.calendar_month_rounded),
              label: '달력',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.analytics_rounded),
              label: '통계',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.settings_rounded),
              label: '설정',
            ),
          ],
        ),
      ),
      floatingActionButton: (_selectedIndex == 0 || _selectedIndex == 1)
          ? FloatingActionButton(
              onPressed: () {
                _navigateToMoodEntry();
              },
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              child: const Icon(Icons.add),
            )
          : null,
    );
  }



  void _navigateToMoodEntry([MoodType? preselectedMood]) {
    DateTime? selectedDate;
    
    // 달력 탭에서 + 버튼을 눌렀을 때는 선택된 날짜 사용
    if (_selectedIndex == 1) {
      selectedDate = _calendarKey.currentState?.getSelectedDate();
    }
    
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => MoodEntryScreen(
          existingEntry: preselectedMood != null 
              ? MoodEntry(
                  id: '',
                  userId: '',
                  mood: preselectedMood,
                  content: '',
                  activities: [],
                  imageUrls: [],
                  date: DateTime.now(),
                  createdAt: DateTime.now(),
                  updatedAt: DateTime.now(),
                )
              : null,
          preselectedDate: selectedDate, // 달력에서 선택된 날짜 전달
        ),
      ),
    ).then((result) {
      if (result == true) {
        // 일기가 저장되었으면 모든 화면 새로고침
        _diaryKey.currentState?.refreshData();
        _calendarKey.currentState?.refreshData();
        _statisticsKey.currentState?.refreshData();
        setState(() {});
      }
    });
  }
} 