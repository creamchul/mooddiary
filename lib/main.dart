import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
// Firebase???중???정 ?정
// import 'package:firebase_core/firebase_core.dart';
import 'constants/app_colors.dart';
import 'constants/app_typography.dart';
// import 'services/firebase_service.dart';
import 'screens/home_screen.dart';
import 'screens/activity_management_screen.dart';
import 'screens/template_management_screen.dart';
import 'screens/emotion_management_screen.dart';
import 'screens/pin_input_screen.dart';
import 'services/local_storage_service.dart';
import 'services/image_service.dart';
import 'services/theme_service.dart';
import 'services/notification_service.dart';
import 'services/security_service.dart';
import 'services/performance_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // ?국??로???초기??
  await initializeDateFormatting('ko_KR', null);
  
  // ?비???초기??(?능 최적??
  await _initializeServices();
  
  runApp(const MoodDiaryApp());
}

// ?능 최적?된 ?비???초기??
Future<void> _initializeServices() async {
  final performance = PerformanceService.instance;
  performance.init();
  
  try {
    // 병렬???비???초기??(?능 ?상)
    final initTasks = [
      performance.optimizedDataLoad('LocalStorage 초기화', () => LocalStorageService.instance.init()),
      performance.optimizedDataLoad('ImageService 초기화', () => ImageService.instance.init()),
      performance.optimizedDataLoad('ThemeService 초기화', () => ThemeService.instance.init()),
      performance.optimizedDataLoad('NotificationService 초기화', () => NotificationService.instance.init()),
    ];
    
    await Future.wait(initTasks);
    print('모든 서비스 초기화 완료 (최적화됨)');
    
  } catch (e) {
    print('서비스 초기화 오류: $e');
  }
  
  // Firebase???중???정 ?정
  // try {
  //   await Firebase.initializeApp();
  //   print('Firebase 초기???료');
  // } catch (e) {
  //   print('Firebase 초기???류: $e');
  // }
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
          
          // ?이???크 ?마 ?용
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: ThemeService.instance.flutterThemeMode,
          
          // ?국???정
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
          
          // ?우???정
          home: const SplashScreenWrapper(),
          routes: {
            '/home': (context) => const HomeScreen(),
            '/activity_management': (context) => const ActivityManagementScreen(),
            '/template_management': (context) => const TemplateManagementScreen(),
            '/emotion_management': (context) => const EmotionManagementScreen(),
          },
          
          debugShowCheckedModeBanner: false,
        );
      },
    );
  }
}

// 보안 체크 ?퍼
class SecurityWrapper extends StatefulWidget {
  const SecurityWrapper({super.key});

  @override
  State<SecurityWrapper> createState() => _SecurityWrapperState();
}

class _SecurityWrapperState extends State<SecurityWrapper> with WidgetsBindingObserver {
  bool _isAuthenticated = false;
  bool _isCheckingAuth = true;
  bool _isAppInBackground = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkAuthentication();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
        _isAppInBackground = true;
        break;
      case AppLifecycleState.resumed:
        if (_isAppInBackground) {
          _isAppInBackground = false;
          _checkAuthenticationOnResume();
        }
        break;
      case AppLifecycleState.detached:
        break;
      case AppLifecycleState.hidden:
        break;
    }
  }

  Future<void> _checkAuthentication() async {
    try {
      final isSecurityEnabled = await SecurityService.instance.isSecurityEnabled();
      
      if (!isSecurityEnabled) {
        // 보안??비활?화??경우 바로 ?으?
        setState(() {
          _isAuthenticated = true;
          _isCheckingAuth = false;
        });
        return;
      }

      // ?체?증 ?도
      final isBiometricEnabled = await SecurityService.instance.isBiometricEnabled();
      
      if (isBiometricEnabled) {
        final success = await SecurityService.instance.authenticateWithBiometric();
        if (success) {
          setState(() {
            _isAuthenticated = true;
            _isCheckingAuth = false;
          });
          return;
        }
      }

      // ?체?증 ?패 ?는 비활?화??PIN ?력 ?요
      setState(() {
        _isCheckingAuth = false;
      });
    } catch (e) {
      setState(() {
        _isCheckingAuth = false;
      });
    }
  }

  Future<void> _checkAuthenticationOnResume() async {
    final isSecurityEnabled = await SecurityService.instance.isSecurityEnabled();
    final isHideInBackground = await SecurityService.instance.isHideInBackgroundEnabled();
    
    if (isSecurityEnabled && isHideInBackground) {
      setState(() {
        _isAuthenticated = false;
      });
      _checkAuthentication();
    }
  }

  Future<void> _showPinInput() async {
    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const PinInputScreen(
          title: '앱 잠금 해제',
          subtitle: 'PIN을 입력하여 앱을 잠금 해제하세요',
        ),
        fullscreenDialog: true,
      ),
    );

    if (result == true) {
      setState(() {
        _isAuthenticated = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isCheckingAuth) {
      return const AnimatedSplashScreen();
    }

    if (!_isAuthenticated) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.lock_outline,
                size: 80,
                color: AppColors.primary,
              ),
              const SizedBox(height: 32),
              Text(
                '앱이 잠겨있습니다',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                '일기를 보려면 잠금을 해제하세요',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                ),
              ),
              const SizedBox(height: 48),
              ElevatedButton.icon(
                onPressed: _showPinInput,
                icon: const Icon(Icons.lock_open),
                label: const Text('잠금 해제'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 16,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return const HomeScreen();
  }
}

// ?플?시 ?면 ?퍼
class SplashScreenWrapper extends StatefulWidget {
  const SplashScreenWrapper({super.key});

  @override
  State<SplashScreenWrapper> createState() => _SplashScreenWrapperState();
}

class _SplashScreenWrapperState extends State<SplashScreenWrapper> {
  bool _showSplash = true;

  @override
  void initState() {
    super.initState();
    _initializeAndNavigate();
  }

  Future<void> _initializeAndNavigate() async {
    // 최소 1.5?플?시 ?시
    await Future.delayed(const Duration(milliseconds: 2500));
    
    if (mounted) {
      setState(() {
        _showSplash = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_showSplash) {
      return const AnimatedSplashScreen();
    } else {
      return const SecurityWrapper();
    }
  }
}

// ?니메이???플?시 ?면
class AnimatedSplashScreen extends StatefulWidget {
  const AnimatedSplashScreen({super.key});

  @override
  State<AnimatedSplashScreen> createState() => _AnimatedSplashScreenState();
}

class _AnimatedSplashScreenState extends State<AnimatedSplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _scaleController;
  late AnimationController _textController;
  
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _textFadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    
    // ?니메이??컨트롤러 초기??
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    
    _textController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    // ?니메이???의
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    ));

    _scaleAnimation = Tween<double>(
      begin: 0.5,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _scaleController,
      curve: Curves.elasticOut,
    ));

    _textFadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _textController,
      curve: Curves.easeInOut,
    ));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _textController,
      curve: Curves.easeOutBack,
    ));

    // ?차???니메이???행
    _startAnimations();
  }

  Future<void> _startAnimations() async {
    // ?이?인
    await _fadeController.forward();
    
    // 로고 ?????니메이??
    await _scaleController.forward();
    
    // ?스???니메이??(?간??지??
    await Future.delayed(const Duration(milliseconds: 200));
    await _textController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _scaleController.dispose();
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark 
              ? [
                  AppColors.primary.withOpacity(0.8),
                  AppColors.primary.withOpacity(0.3),
                  theme.colorScheme.background,
                ]
              : [
                  AppColors.primary.withOpacity(0.1),
                  AppColors.primary.withOpacity(0.05),
                  Colors.white,
                ],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 로고 ?역
              AnimatedBuilder(
                animation: Listenable.merge([_fadeAnimation, _scaleAnimation]),
                builder: (context, child) {
                  return FadeTransition(
                    opacity: _fadeAnimation,
                    child: ScaleTransition(
                      scale: _scaleAnimation,
                      child: Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              AppColors.primary,
                              AppColors.primary.withOpacity(0.7),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(30),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withOpacity(0.3),
                              blurRadius: 20,
                              spreadRadius: 5,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.favorite,
                          size: 64,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  );
                },
              ),
              
              const SizedBox(height: 32),
              
              // ???름
              AnimatedBuilder(
                animation: _textFadeAnimation,
                builder: (context, child) {
                  return SlideTransition(
                    position: _slideAnimation,
                    child: FadeTransition(
                      opacity: _textFadeAnimation,
                      child: Column(
                        children: [
                          Text(
                            'MoodDiary',
                            style: theme.textTheme.headlineLarge?.copyWith(
                              color: AppColors.primary,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.2,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            '감정을 기록하고 소중한 순간을 간직하세요',
                            style: theme.textTheme.bodyLarge?.copyWith(
                              color: theme.colorScheme.onSurface.withOpacity(0.7),
                              fontWeight: FontWeight.w300,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              
              const SizedBox(height: 48),
              
              // 로딩 ?디케?터
              AnimatedBuilder(
                animation: _textFadeAnimation,
                builder: (context, child) {
                  return FadeTransition(
                    opacity: _textFadeAnimation,
                    child: SizedBox(
                      width: 32,
                      height: 32,
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          AppColors.primary.withOpacity(0.7),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
