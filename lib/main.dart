import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
// Firebase는 나중에 설정 예정
// import 'package:firebase_core/firebase_core.dart';
import 'constants/app_colors.dart';
import 'constants/app_typography.dart';
// import 'services/firebase_service.dart';
import 'screens/home_screen.dart';
import 'services/local_storage_service.dart';
import 'services/image_service.dart';
import 'services/theme_service.dart';
import 'services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 한국어 로케일 초기화
  await initializeDateFormatting('ko_KR', null);
  
  // 서비스 초기화
  await LocalStorageService.instance.init();
  await ImageService.instance.init();
  await ThemeService.instance.init();
  await NotificationService.instance.init();
  print('모든 서비스 초기화 완료');
  
  // Firebase는 나중에 설정 예정
  // try {
  //   await Firebase.initializeApp();
  //   print('Firebase 초기화 완료');
  // } catch (e) {
  //   print('Firebase 초기화 오류: $e');
  // }
  
  runApp(const MoodDiaryApp());
}

class MoodDiaryApp extends StatelessWidget {
  const MoodDiaryApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ThemeService.instance,
      builder: (context, child) {
        return MaterialApp(
          title: 'MoodDiary',
          
          // 라이트/다크 테마 적용
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: ThemeService.instance.flutterThemeMode,
          
          // 다국어 설정
          locale: const Locale('ko', 'KR'),
          supportedLocales: const [
            Locale('ko', 'KR'),
            Locale('en', 'US'),
          ],
          
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          
          home: const HomeScreen(),
          debugShowCheckedModeBanner: false,
        );
      },
    );
  }
}

// 인증 래퍼는 나중에 Firebase 설정 후 사용 예정
// class AuthWrapper extends StatefulWidget {
//   const AuthWrapper({super.key});

//   @override
//   State<AuthWrapper> createState() => _AuthWrapperState();
// }

// class _AuthWrapperState extends State<AuthWrapper> {
//   final FirebaseService _firebaseService = FirebaseService();
//   bool _isInitializing = true;

//   @override
//   void initState() {
//     super.initState();
//     _initializeAuth();
//   }

//   Future<void> _initializeAuth() async {
//     try {
//       // 익명 로그인 시도
//       final credential = await _firebaseService.signInAnonymously();
//       if (credential != null) {
//         print('익명 로그인 성공: ${credential.user?.uid}');
//       }
//     } catch (e) {
//       print('인증 초기화 오류: $e');
//     } finally {
//       if (mounted) {
//         setState(() {
//           _isInitializing = false;
//         });
//       }
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     if (_isInitializing) {
//       return const SplashScreen();
//     }

//     return StreamBuilder(
//       stream: _firebaseService.auth.authStateChanges(),
//       builder: (context, snapshot) {
//         if (snapshot.connectionState == ConnectionState.waiting) {
//           return const SplashScreen();
//         }

//         if (snapshot.hasData) {
//           return const HomeScreen();
//         }

//         // 로그인이 필요한 경우 다시 익명 로그인 시도
//         _initializeAuth();
//         return const SplashScreen();
//       },
//     );
//   }
// }

// 스플래시 화면 (나중에 사용 예정)
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: isDark ? AppColors.darkCardGradient : AppColors.cardGradient,
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 로고 영역
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: AppColors.primary.withOpacity(0.3),
                    width: 2,
                  ),
                ),
                child: const Icon(
                  Icons.favorite,
                  size: 64,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 32),
              
              // 앱 제목
              Text(
                'MoodDiary',
                style: theme.textTheme.headlineLarge?.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              
              Text(
                '감정을 기록하고 소중한 순간을 간직하세요',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.7),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),
              
              // 로딩 인디케이터
              const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
