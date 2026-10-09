import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Shared E-Byahe visual system: luminous metallic blues, clean white surfaces,
/// soft shadows, and consistent status colors across every screen.
class AppColors {
  AppColors._();

  static const metallicBlue = Color(0xFF2467A9);
  static const navy = Color(0xFF123766);
  static const blue = Color(0xFF168BFA);
  static const sky = Color(0xFF79D4FF);
  static const green = Color(0xFF12B981);
  static const amber = Color(0xFFFFB52E);
  static const red = Color(0xFFF04458);
  static const muted = Color(0xFF7897BE);
  static const line = Color(0xFFDCEAF8);
  static const background = Color(0xFFF3F8FE);

  static const softBlue = Color(0xFFE7F3FF);
  static const softGreen = Color(0xFFE4F9F0);
  static const softAmber = Color(0xFFFFF4D9);
  static const softRed = Color(0xFFFFE8EB);

  static const headerGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF15508D), Color(0xFF3988D1), Color(0xFF1E5B9B)],
    stops: [0, 0.52, 1],
  );

  static const bottomGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF174D88), Color(0xFF3988D1), Color(0xFF1B5A9B)],
  );
}

/// Rounded, bright surface with a subtle blue outline and gentle elevation.
BoxDecoration appCardDecoration({double radius = 20}) {
  return BoxDecoration(
    color: const Color(0xF7FFFFFF),
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(color: AppColors.line, width: 1.15),
    boxShadow: const [
      BoxShadow(color: Color(0x15265F9E), blurRadius: 18, offset: Offset(0, 6)),
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

/// Shared metallic-blue gradient header used across the app. Safe-area padding
/// lets the blue finish extend behind the phone status bar.
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
            BoxShadow(color: Color(0x33245F9C), blurRadius: 16, offset: Offset(0, 5)),
          ],
          border: Border(bottom: BorderSide(color: Color(0x887DD8FF), width: 1.2)),
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
