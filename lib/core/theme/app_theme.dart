import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';

/// CookCut's theme configuration implementing the style guide
class AppTheme {
  // Private constructor to prevent instantiation
  AppTheme._();

  /// Primary Colors - Light Mode
  static const primaryBlue = Color(0xFF0277BD);
  static const primaryBlueGradientEnd = Color(0xFF0288D1);

  /// Primary Colors - Dark Mode
  static const primaryBlueDark = Color(0xFF039BE5);
  static const primaryBlueGradientEndDark = Color(0xFF03A9F4);

  /// Surface Colors - Light
  static const backgroundLight = Color(0xFFFAFAFA);
  static const surfaceLight = Color(0xFFF5F5F5);
  static const surfaceVariantLight = Color(0xFFEEEEEE);
  static const splashBackground = Color(0xFFD2E7F9);

  /// Surface Colors - Dark
  static const backgroundDark = Color(0xFF001A2F);
  static const surfaceDark = Color(0xFF002542);
  static const surfaceVariantDark = Color(0xFF003356);
  static const splashBackgroundDark = Color(0xFF001F3D);

  /// Text Colors - Light
  static const textPrimaryLight = Color(0xFF263238);
  static const textSecondaryLight = Color(0xFF37474F);

  /// Text Colors - Dark
  static const textPrimaryDark = Color(0xFFE4F2FD);
  static const textSecondaryDark = Color(0xFFBAE2F6);

  /// Semantic Colors
  static const error = Color(0xFFF44336);
  static const warning = Color(0xFFFFA000);
  static const info = Color(0xFF2196F3);
  static const success = Color(0xFF4CAF50);

  /// Animation Durations
  static const animDurationShort = Duration(milliseconds: 200);
  static const animDurationMedium = Duration(milliseconds: 300);
  static const animDurationLong = Duration(milliseconds: 500);

  /// Spacing
  static const spaceXS = 4.0;
  static const spaceSM = 8.0;
  static const spaceMD = 16.0;
  static const spaceLG = 24.0;
  static const spaceXL = 32.0;
  static const space2XL = 48.0;

  /// Border Radius
  static const borderRadiusSM = 8.0;
  static const borderRadiusMD = 12.0;
  static const borderRadiusLG = 16.0;

  /// Component Heights
  static const buttonHeight = 50.0;
  static const inputHeight = 50.0;

  /// Get the light theme
  static ThemeData get lightTheme {
    return ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryBlue,
        background: backgroundLight,
        surface: surfaceLight,
        surfaceVariant: surfaceVariantLight,
        error: error,
        onBackground: textPrimaryLight,
        onSurface: textSecondaryLight,
      ),
      useMaterial3: true,
      fontFamily: 'Inter',
      textTheme: const TextTheme(
        displayLarge: TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.w700,
          fontFamily: 'Poppins',
        ),
        displayMedium: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w600,
          fontFamily: 'Poppins',
        ),
        displaySmall: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w600,
          fontFamily: 'Poppins',
        ),
        headlineLarge: TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.w600,
          fontFamily: 'Poppins',
        ),
        headlineMedium: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w600,
          fontFamily: 'Poppins',
        ),
        headlineSmall: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w600,
          fontFamily: 'Poppins',
        ),
        bodyLarge: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w400,
          height: 1.5,
          letterSpacing: 0.15,
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          height: 1.5,
          letterSpacing: 0.25,
        ),
        labelLarge: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.1,
        ),
      ),
      appBarTheme: const AppBarTheme(
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        titleTextStyle: TextStyle(
          fontFamily: 'Poppins',
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size.fromHeight(buttonHeight),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(borderRadiusMD),
          ),
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: spaceLG),
        ),
      ),
      cardTheme: CardTheme(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(borderRadiusMD),
        ),
        clipBehavior: Clip.antiAlias,
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(borderRadiusMD),
          borderSide: const BorderSide(width: 1),
        ),
        contentPadding: const EdgeInsets.all(spaceMD),
      ),
    );
  }

  /// Get the dark theme
  static ThemeData get darkTheme {
    return lightTheme.copyWith(
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryBlueDark,
        brightness: Brightness.dark,
        background: backgroundDark,
        surface: surfaceDark,
        surfaceVariant: surfaceVariantDark,
        error: error,
        onBackground: textPrimaryDark,
        onSurface: textSecondaryDark,
      ),
    );
  }

  /// Get Cupertino light theme
  static CupertinoThemeData get cupertinoLightTheme {
    return const CupertinoThemeData(
      primaryColor: primaryBlue,
      brightness: Brightness.light,
      textTheme: CupertinoTextThemeData(
        primaryColor: primaryBlue,
        textStyle: TextStyle(
          fontFamily: 'Inter',
          color: textPrimaryLight,
        ),
        navTitleTextStyle: TextStyle(
          fontFamily: 'Poppins',
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: textPrimaryLight,
        ),
      ),
    );
  }

  /// Get Cupertino dark theme
  static CupertinoThemeData get cupertinoDarkTheme {
    return const CupertinoThemeData(
      primaryColor: primaryBlueDark,
      brightness: Brightness.dark,
      textTheme: CupertinoTextThemeData(
        primaryColor: primaryBlueDark,
        textStyle: TextStyle(
          fontFamily: 'Inter',
          color: textPrimaryDark,
        ),
        navTitleTextStyle: TextStyle(
          fontFamily: 'Poppins',
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: textPrimaryDark,
        ),
      ),
    );
  }

  /// Helper method to determine if a page should use Cupertino styling
  static bool shouldUseCupertinoStyle(String routeName) {
    const cupertinoRoutes = {
      '/login',
      '/signup',
      '/projects',
      '/splash',
    };
    return cupertinoRoutes.contains(routeName);
  }
}
