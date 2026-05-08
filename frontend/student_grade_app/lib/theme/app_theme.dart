import 'package:flutter/material.dart';

class AppTheme {
  // Brand colours — deep navy + teal accent
  static const Color primary      = Color(0xFF0D47A1);   // deep blue
  static const Color primaryLight = Color(0xFF1565C0);
  static const Color accent       = Color(0xFF00ACC1);   // teal
  static const Color surface      = Color(0xFFFFFFFF);
  static const Color background   = Color(0xFFF0F4F8);

  static const Color success      = Color(0xFF2E7D32);
  static const Color successLight = Color(0xFFE8F5E9);
  static const Color successBorder= Color(0xFFA5D6A7);

  static const Color danger       = Color(0xFFC62828);
  static const Color dangerLight  = Color(0xFFFFEBEE);
  static const Color dangerBorder = Color(0xFFEF9A9A);

  static const Color warning      = Color(0xFFE65100);
  static const Color textPrimary  = Color(0xFF1A237E);
  static const Color textSecondary= Color(0xFF546E7A);
  static const Color textHint     = Color(0xFF90A4AE);
  static const Color cardBorder   = Color(0xFFE3EAF2);

  // Radius
  static final BorderRadius radiusSm  = BorderRadius.circular(8);
  static final BorderRadius radiusMd  = BorderRadius.circular(12);
  static final BorderRadius radiusLg  = BorderRadius.circular(20);
  static final BorderRadius radiusFull= BorderRadius.circular(100);

  // Shadows
  static const List<BoxShadow> cardShadow = [
    BoxShadow(color: Color(0x0D0D47A1), blurRadius: 16, offset: Offset(0, 4)),
  ];
  static const List<BoxShadow> elevatedShadow = [
    BoxShadow(color: Color(0x330D47A1), blurRadius: 24, offset: Offset(0, 8)),
  ];

  // Typography
  static const TextStyle headlineLarge = TextStyle(
    fontSize: 28, fontWeight: FontWeight.w800,
    color: textPrimary, letterSpacing: -0.5,
  );
  static const TextStyle headlineMedium = TextStyle(
    fontSize: 22, fontWeight: FontWeight.w700, color: textPrimary,
  );
  static const TextStyle titleMedium = TextStyle(
    fontSize: 15, fontWeight: FontWeight.w600, color: textPrimary,
  );
  static const TextStyle bodyMedium = TextStyle(
    fontSize: 14, fontWeight: FontWeight.w400, color: textSecondary,
  );
  static const TextStyle labelSmall = TextStyle(
    fontSize: 11, fontWeight: FontWeight.w500, color: textHint,
  );

  static Color gradeColor(double grade) {
    if (grade >= 90) return success;
    if (grade >= 80) return primary;
    if (grade >= 70) return warning;
    return danger;
  }

  static Color gradeColorLight(double grade) {
    if (grade >= 90) return successLight;
    if (grade >= 80) return const Color(0xFFE8EAF6);
    if (grade >= 70) return const Color(0xFFFFF3E0);
    return dangerLight;
  }

  static ThemeData get lightTheme => ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: primary,
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: background,
        appBarTheme: const AppBarTheme(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          centerTitle: true,
          elevation: 0,
          titleTextStyle: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Colors.white,
            letterSpacing: 0.3,
          ),
        ),
        cardTheme: CardThemeData(
          color: surface,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: radiusLg,
            side: const BorderSide(color: cardBorder),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFFF5F8FF),
          border: OutlineInputBorder(
            borderRadius: radiusMd,
            borderSide: const BorderSide(color: cardBorder),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: radiusMd,
            borderSide: const BorderSide(color: cardBorder),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: radiusMd,
            borderSide: const BorderSide(color: primary, width: 2),
          ),
          labelStyle: const TextStyle(color: textSecondary),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: primary,
            foregroundColor: Colors.white,
            elevation: 0,
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
            shape: RoundedRectangleBorder(borderRadius: radiusMd),
            textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          ),
        ),
      );
}
