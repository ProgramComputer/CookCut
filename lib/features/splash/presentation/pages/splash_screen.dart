import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_state.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  bool _isAnimationComplete = false;

  @override
  void initState() {
    super.initState();
    // Start animation timer
    Future.delayed(AppTheme.animDurationLong, () {
      if (mounted) {
        setState(() {
          _isAnimationComplete = true;
        });
        _checkAuthAndNavigate();
      }
    });
  }

  void _checkAuthAndNavigate() {
    if (!mounted) return;
    final authState = context.read<AuthBloc>().state;

    if (authState.status == AuthStatus.authenticated) {
      context.go('/');
    } else if (authState.status == AuthStatus.unauthenticated) {
      context.go('/login');
    }
  }

  String get logoAsset {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark
        ? 'assets/icon/logo_dark_fixed.svg'
        : 'assets/icon/logo_fixed.svg';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark
        ? AppTheme.splashBackgroundDark // Dark mode splash background
        : AppTheme.splashBackground; // Light mode splash background

    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        // Only navigate after animation is complete
        if (!mounted || !_isAnimationComplete) return;

        if (state.status == AuthStatus.authenticated) {
          context.go('/');
        } else if (state.status == AuthStatus.unauthenticated) {
          context.go('/login');
        }
      },
      child: Scaffold(
        backgroundColor: backgroundColor,
        body: Stack(
          children: [
            Container(
              color: backgroundColor,
            ),
            Center(
              child: TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0.0, end: 1.0),
                duration: AppTheme.animDurationLong,
                curve: Curves.easeInOut,
                builder: (context, value, child) {
                  return Opacity(
                    opacity: value,
                    child: Transform.scale(
                      scale: 0.8 + (value * 0.2),
                      child: Hero(
                        tag: 'app_logo',
                        child: SizedBox(
                          width: 200,
                          height: 200,
                          child: SvgPicture.asset(
                            logoAsset,
                            width: 200,
                            height: 200,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
