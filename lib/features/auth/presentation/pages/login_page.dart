import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/presentation/widgets/platform_page.dart';
import '../../../../core/theme/app_theme.dart';
import '../bloc/auth_bloc.dart';
import '../bloc/auth_event.dart';
import '../bloc/auth_state.dart';
import '../widgets/loading_overlay.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isSignUp = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _handleSubmit() {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      // Show error
      return;
    }

    if (_isSignUp) {
      context.read<AuthBloc>().add(
            SignUpWithEmailAndPasswordRequested(
              email: email,
              password: password,
            ),
          );
    } else {
      context.read<AuthBloc>().add(
            SignInWithEmailAndPasswordRequested(
              email: email,
              password: password,
            ),
          );
    }
  }

  void _handleGoogleSignIn() {
    context.read<AuthBloc>().add(const SignInWithGoogleRequested());
  }

  String get logoAsset {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? 'assets/icon/logo_dark.svg' : 'assets/icon/logo.svg';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark
        ? const Color(0xFF001A2F) // Dark mode background
        : const Color(0xFFFAFAFA); // Light mode background
    final surfaceColor = isDark
        ? const Color(0xFF002542) // Dark mode surface
        : const Color(0xFFF5F5F5); // Light mode surface
    final textColor = isDark
        ? const Color(0xFFE4F2FD) // Dark mode text
        : const Color(0xFF263238); // Light mode text
    final secondaryTextColor = isDark
        ? const Color(0xFFBAE2F6) // Dark mode secondary text
        : const Color(0xFF37474F); // Light mode secondary text

    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state.status == AuthStatus.authenticated) {
          context.go('/');
        }
      },
      child: PlatformPage(
        title: _isSignUp ? 'Create Account' : 'Sign In',
        useCupertino: true,
        automaticallyImplyLeading: false,
        backgroundColor: backgroundColor,
        body: LoadingOverlay(
          isLoading:
              context.watch<AuthBloc>().state.status == AuthStatus.loading,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppTheme.spaceLG),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 48),
                Hero(
                  tag: 'app_logo',
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    child: SvgPicture.asset(
                      logoAsset,
                      width: 100,
                      height: 100,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                Text(
                  _isSignUp ? 'Create Your Account' : 'Welcome Back',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 28,
                    fontWeight: FontWeight.w600,
                    color: textColor,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  _isSignUp
                      ? 'Start your creative journey with CookCut'
                      : 'Sign in to continue creating amazing content',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 16,
                    color: secondaryTextColor,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                CupertinoTextField(
                  controller: _emailController,
                  placeholder: 'Email',
                  keyboardType: TextInputType.emailAddress,
                  padding: const EdgeInsets.all(AppTheme.spaceMD),
                  style: TextStyle(color: textColor),
                  placeholderStyle:
                      TextStyle(color: secondaryTextColor.withOpacity(0.7)),
                  decoration: BoxDecoration(
                    color: surfaceColor,
                    border: Border.all(
                      color: secondaryTextColor.withOpacity(0.2),
                      width: 1,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                const SizedBox(height: AppTheme.spaceMD),
                CupertinoTextField(
                  controller: _passwordController,
                  placeholder: 'Password',
                  obscureText: _obscurePassword,
                  padding: const EdgeInsets.all(AppTheme.spaceMD),
                  style: TextStyle(color: textColor),
                  placeholderStyle:
                      TextStyle(color: secondaryTextColor.withOpacity(0.7)),
                  decoration: BoxDecoration(
                    color: surfaceColor,
                    border: Border.all(
                      color: secondaryTextColor.withOpacity(0.2),
                      width: 1,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  suffix: CupertinoButton(
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppTheme.spaceMD),
                    child: Icon(
                      _obscurePassword
                          ? CupertinoIcons.eye
                          : CupertinoIcons.eye_slash,
                      color: secondaryTextColor,
                    ),
                    onPressed: () {
                      setState(() {
                        _obscurePassword = !_obscurePassword;
                      });
                    },
                  ),
                ),
                const SizedBox(height: AppTheme.spaceLG),
                Container(
                  height: 50,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFF0277BD), // Primary Blue
                        const Color(0xFF0288D1), // Primary Blue Gradient End
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: CupertinoButton(
                    onPressed: _handleSubmit,
                    padding: EdgeInsets.zero,
                    child: Text(
                      _isSignUp ? 'Create Account' : 'Sign In',
                      style: const TextStyle(
                        color: Colors.white,
                        fontFamily: 'Inter',
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: AppTheme.spaceMD),
                Container(
                  height: 50,
                  decoration: BoxDecoration(
                    color: surfaceColor,
                    border: Border.all(
                      color: secondaryTextColor.withOpacity(0.2),
                      width: 1,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: CupertinoButton(
                    onPressed: _handleGoogleSignIn,
                    padding: EdgeInsets.zero,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SvgPicture.asset(
                          'assets/icon/google_logo.svg',
                          width: 24,
                          height: 24,
                        ),
                        const SizedBox(width: AppTheme.spaceSM),
                        Text(
                          'Continue with Google',
                          style: TextStyle(
                            color: textColor,
                            fontFamily: 'Inter',
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppTheme.spaceLG),
                CupertinoButton(
                  onPressed: () {
                    setState(() {
                      _isSignUp = !_isSignUp;
                    });
                  },
                  child: Text(
                    _isSignUp
                        ? 'Already have an account? Sign in'
                        : 'Need an account? Sign up',
                    style: TextStyle(
                      color: secondaryTextColor,
                      fontFamily: 'Inter',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
