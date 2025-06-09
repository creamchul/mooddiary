import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../constants/app_colors.dart';
import '../constants/app_sizes.dart';
import '../services/security_service.dart';

class PinInputScreen extends StatefulWidget {
  final bool isSetup; // PIN 설정 모드인지 확인 모드인지
  final String? title;
  final String? subtitle;

  const PinInputScreen({
    super.key,
    this.isSetup = false,
    this.title,
    this.subtitle,
  });

  @override
  State<PinInputScreen> createState() => _PinInputScreenState();
}

class _PinInputScreenState extends State<PinInputScreen>
    with TickerProviderStateMixin {
  String _currentPin = '';
  String _confirmPin = '';
  bool _isConfirmMode = false;
  bool _isLoading = false;
  String? _errorMessage;

  late AnimationController _shakeController;
  late AnimationController _fadeController;
  late Animation<double> _shakeAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _shakeAnimation = Tween<double>(
      begin: 0,
      end: 10,
    ).animate(CurvedAnimation(
      parent: _shakeController,
      curve: Curves.elasticIn,
    ));

    _fadeAnimation = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    ));

    _fadeController.forward();
  }

  @override
  void dispose() {
    _shakeController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  void _onNumberPress(String number) {
    if (_currentPin.length < 6) {
      setState(() {
        _currentPin += number;
        _errorMessage = null;
      });

      // 진동 피드백
      HapticFeedback.lightImpact();

      if (_currentPin.length == 6) {
        _handlePinComplete();
      }
    }
  }

  void _onBackspace() {
    if (_currentPin.isNotEmpty) {
      setState(() {
        _currentPin = _currentPin.substring(0, _currentPin.length - 1);
        _errorMessage = null;
      });
      HapticFeedback.selectionClick();
    }
  }

  Future<void> _handlePinComplete() async {
    if (widget.isSetup) {
      // PIN 설정 모드
      if (!_isConfirmMode) {
        // 첫 번째 입력
        setState(() {
          _confirmPin = _currentPin;
          _currentPin = '';
          _isConfirmMode = true;
        });
      } else {
        // 두 번째 입력 (확인)
        if (_currentPin == _confirmPin) {
          await _setupPin();
        } else {
          _showError('PIN이 일치하지 않습니다');
          setState(() {
            _currentPin = '';
            _confirmPin = '';
            _isConfirmMode = false;
          });
        }
      }
    } else {
      // PIN 확인 모드
      await _verifyPin();
    }
  }

  Future<void> _setupPin() async {
    setState(() {
      _isLoading = true;
    });

    try {
      await SecurityService.instance.setPinCode(_currentPin);
      await SecurityService.instance.setSecurityEnabled(true);

      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      _showError('PIN 설정 중 오류가 발생했습니다');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _verifyPin() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final isValid = await SecurityService.instance.verifyPinCode(_currentPin);
      
      if (isValid) {
        if (mounted) {
          Navigator.of(context).pop(true);
        }
      } else {
        _showError('잘못된 PIN입니다');
        setState(() {
          _currentPin = '';
        });
      }
    } catch (e) {
      _showError('PIN 확인 중 오류가 발생했습니다');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showError(String message) {
    setState(() {
      _errorMessage = message;
      _currentPin = '';
    });
    _shakeController.forward().then((_) {
      _shakeController.reverse();
    });
    HapticFeedback.heavyImpact();
  }

  void _onBiometricPress() async {
    if (!widget.isSetup) {
      final success = await SecurityService.instance.authenticateWithBiometric();
      if (success && mounted) {
        Navigator.of(context).pop(true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      backgroundColor: theme.colorScheme.background,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Padding(
            padding: const EdgeInsets.all(AppSizes.paddingL),
            child: Column(
              children: [
                const Spacer(),
                _buildHeader(),
                const SizedBox(height: AppSizes.paddingXL * 2),
                _buildPinDots(),
                const SizedBox(height: AppSizes.paddingL),
                if (_errorMessage != null) _buildErrorMessage(),
                const Spacer(),
                _buildKeypad(),
                const SizedBox(height: AppSizes.paddingL),
                if (!widget.isSetup) _buildBiometricButton(),
                const SizedBox(height: AppSizes.paddingL),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final theme = Theme.of(context);
    
    String title;
    String subtitle;
    
    if (widget.isSetup) {
      if (_isConfirmMode) {
        title = 'PIN 확인';
        subtitle = 'PIN을 다시 한 번 입력해주세요';
      } else {
        title = 'PIN 설정';
        subtitle = '6자리 PIN을 설정해주세요';
      }
    } else {
      title = widget.title ?? 'PIN 입력';
      subtitle = widget.subtitle ?? 'PIN을 입력해주세요';
    }
    
    return Column(
      children: [
        Icon(
          Icons.lock_outline,
          size: 64,
          color: AppColors.primary,
        ),
        const SizedBox(height: AppSizes.paddingL),
        Text(
          title,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.onBackground,
          ),
        ),
        const SizedBox(height: AppSizes.paddingS),
        Text(
          subtitle,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onBackground.withOpacity(0.7),
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildPinDots() {
    return AnimatedBuilder(
      animation: _shakeAnimation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(_shakeAnimation.value, 0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(6, (index) {
              final isFilled = index < _currentPin.length;
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 8),
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isFilled ? AppColors.primary : Colors.transparent,
                  border: Border.all(
                    color: AppColors.primary,
                    width: 2,
                  ),
                ),
              );
            }),
          ),
        );
      },
    );
  }

  Widget _buildErrorMessage() {
    final theme = Theme.of(context);
    
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.paddingM,
        vertical: AppSizes.paddingS,
      ),
      decoration: BoxDecoration(
        color: AppColors.error.withOpacity(0.1),
        borderRadius: BorderRadius.circular(AppSizes.radiusM),
      ),
      child: Text(
        _errorMessage!,
        style: theme.textTheme.bodySmall?.copyWith(
          color: AppColors.error,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildKeypad() {
    const numbers = [
      ['1', '2', '3'],
      ['4', '5', '6'],
      ['7', '8', '9'],
      ['', '0', 'backspace'],
    ];

    return Column(
      children: numbers.map((row) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: row.map((item) {
              if (item.isEmpty) return const SizedBox(width: 80, height: 80);
              
              if (item == 'backspace') {
                return _buildKeypadButton(
                  child: const Icon(Icons.backspace_outlined, size: 24),
                  onPressed: _onBackspace,
                );
              }
              
              return _buildKeypadButton(
                child: Text(
                  item,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                onPressed: () => _onNumberPress(item),
              );
            }).toList(),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildKeypadButton({
    required Widget child,
    required VoidCallback onPressed,
  }) {
    final theme = Theme.of(context);
    
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: theme.colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: theme.shadowColor.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(40),
          onTap: onPressed,
          child: Center(child: child),
        ),
      ),
    );
  }

  Widget _buildBiometricButton() {
    return FutureBuilder<bool>(
      future: SecurityService.instance.isBiometricAvailable(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || !snapshot.data!) {
          return const SizedBox.shrink();
        }
        
        return TextButton.icon(
          onPressed: _onBiometricPress,
          icon: const Icon(Icons.fingerprint, size: 24),
          label: const Text('생체인증 사용'),
          style: TextButton.styleFrom(
            foregroundColor: AppColors.primary,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSizes.paddingL,
              vertical: AppSizes.paddingM,
            ),
          ),
        );
      },
    );
  }
} 