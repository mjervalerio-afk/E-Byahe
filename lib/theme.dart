import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// E-Byahe's shared luminous-blue visual language, inspired by the supplied
/// reference screens: glassy blue gradients, airy white surfaces, and soft blue
/// borders/shadows. Keep status colors consistent throughout the app.
class AppColors {
  AppColors._();

  static const metallicBlue = Color(0xFF2671B8);
  static const navy = Color(0xFF123766);
  static const blue = Color(0xFF168BFA);
  static const sky = Color(0xFF8AD9FF);
  static const green = Color(0xFF12B981);
  static const amber = Color(0xFFFFB52E);
  static const red = Color(0xFFF04458);
  static const muted = Color(0xFF7897BE);
  static const line = Color(0xFFD7E7F8);
  static const background = Color(0xFFF1F7FE);

  static const softBlue = Color(0xFFE7F3FF);
  static const softGreen = Color(0xFFE4F9F0);
  static const softAmber = Color(0xFFFFF4D9);
  static const softRed = Color(0xFFFFE8EB);

  static const headerGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF174F8D),
      Color(0xFF327FC2),
      Color(0xFF6DBBFA),
      Color(0xFF1F5B9A),
    ],
    stops: [0, 0.36, 0.62, 1],
  );

  static const bottomGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF1B518B),
      Color(0xFF347FC2),
      Color(0xFF65B9F8),
      Color(0xFF1B5A99),
    ],
    stops: [0, 0.42, 0.66, 1],
  );

  static const glassGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xF7FFFFFF), Color(0xEAF2FBFF)],
  );
}

/// Raised frosted-white surface with a thin blue edge and restrained shadows.
BoxDecoration appCardDecoration({double radius = 20}) {
  return BoxDecoration(
    gradient: AppColors.glassGradient,
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(color: AppColors.line, width: 1.15),
    boxShadow: const [
      BoxShadow(color: Color(0x18265F9E), blurRadius: 20, offset: Offset(0, 6)),
      BoxShadow(color: Color(0xBFFFFFFF), blurRadius: 1, offset: Offset(0, 1)),
    ],
  );
}

ThemeData buildAppTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.blue,
    brightness: Brightness.light,
    primary: AppColors.blue,
    secondary: AppColors.sky,
    surface: Colors.white,
    error: AppColors.red,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.background,
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.metallicBlue,
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: false,
    ),
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: AppColors.line),
      ),
      margin: EdgeInsets.zero,
    ),
    chipTheme: ChipThemeData(
      backgroundColor: Colors.white.withValues(alpha: 0.94),
      selectedColor: AppColors.metallicBlue,
      disabledColor: AppColors.background,
      side: const BorderSide(color: AppColors.line),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      labelStyle: const TextStyle(
        color: AppColors.navy,
        fontWeight: FontWeight.w600,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 8),
    ),
    dividerColor: AppColors.line,
    textTheme: ThemeData.light().textTheme.apply(
      bodyColor: AppColors.navy,
      displayColor: AppColors.navy,
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppColors.navy,
      contentTextStyle: const TextStyle(color: Colors.white),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
  );
}

/// Common header used across all major screens.
class AppHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final Widget? bottom;

  const AppHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.bottom,
  });

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: AppColors.background,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: Container(
        decoration: const BoxDecoration(
          gradient: AppColors.headerGradient,
          boxShadow: [
            BoxShadow(
              color: Color(0x33245F9C),
              blurRadius: 18,
              offset: Offset(0, 5),
            ),
          ],
          border: Border(
            bottom: BorderSide(color: Color(0x997DD8FF), width: 1.2),
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 15),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    if (leading != null) ...[
                      leading!,
                      const SizedBox(width: 10),
                    ] else
                      const SizedBox(width: 2),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 19,
                              letterSpacing: -0.25,
                            ),
                          ),
                          if (subtitle != null) ...[
                            const SizedBox(height: 3),
                            Text(
                              subtitle!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Color(0xFFE3F2FF),
                                fontSize: 12.5,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (trailing != null) trailing!,
                  ],
                ),
                if (bottom != null) ...[
                  const SizedBox(height: 14),
                  bottom!,
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
