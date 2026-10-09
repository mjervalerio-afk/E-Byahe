import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Shared E-Byahe visual system: luminous blue chrome, soft ice-blue
/// backgrounds, frosted white cards, and clear seat-status colors.
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
  static const background = Color(0xFFF5FAFF);

  static const softBlue = Color(0xFFE7F3FF);
  static const softGreen = Color(0xFFE4F9F0);
  static const softAmber = Color(0xFFFFF4D9);
  static const softRed = Color(0xFFFFE8EB);

  /// Multi-stop blue gradient used by the top app bars.
  static const headerGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF174B83),
      Color(0xFF2C75B9),
      Color(0xFF70C4FF),
      Color(0xFF3989CC),
      Color(0xFF1B548E),
    ],
    stops: [0, 0.30, 0.49, 0.70, 1],
  );

  /// Matching blue chrome for the persistent bottom navigation.
  static const bottomGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF194F87),
      Color(0xFF347FC2),
      Color(0xFF70C4FF),
      Color(0xFF3B8BCB),
      Color(0xFF1C568F),
    ],
    stops: [0, 0.32, 0.50, 0.72, 1],
  );

  /// Subtle white-to-ice-blue glass used on cards and floating surfaces.
  static const glassGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFCFFFFFF),
      Color(0xF1F5FBFF),
      Color(0xFCFFFFFF),
    ],
    stops: [0, 0.64, 1],
  );
}

/// Raised frosted-white surface with a thin blue edge and soft, restrained glow.
BoxDecoration appCardDecoration({double radius = 20}) {
  return BoxDecoration(
    gradient: AppColors.glassGradient,
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(color: AppColors.line, width: 1.15),
    boxShadow: const [
      BoxShadow(
        color: Color(0x1C265F9E),
        blurRadius: 22,
        offset: Offset(0, 6),
      ),
      BoxShadow(
        color: Color(0xBFFFFFFF),
        blurRadius: 1,
        offset: Offset(0, 1),
      ),
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
      backgroundColor: Colors.white.withValues(alpha: 0.96),
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

/// Reusable luminous header shared by the map, shuttle list, detail, and info.
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
              blurRadius: 20,
              offset: Offset(0, 5),
            ),
          ],
          border: Border(
            bottom: BorderSide(color: Color(0xAA9ADFFF), width: 1.3),
          ),
        ),
        child: Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: const Alignment(0.18, -1.15),
                      radius: 1.25,
                      colors: [
                        const Color(0x777ED5FF),
                        const Color(0x18C7ECFF),
                        Colors.transparent,
                      ],
                      stops: const [0, 0.46, 1],
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              right: -58,
              bottom: -76,
              child: IgnorePointer(
                child: Container(
                  width: 220,
                  height: 150,
                  decoration: const BoxDecoration(
                    gradient: RadialGradient(
                      colors: [Color(0x4476CFFF), Colors.transparent],
                    ),
                  ),
                ),
              ),
            ),
            SafeArea(
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
                                  fontSize: 20,
                                  letterSpacing: -0.3,
                                  shadows: [
                                    Shadow(
                                      color: Color(0x33204470),
                                      offset: Offset(0, 1),
                                      blurRadius: 3,
                                    ),
                                  ],
                                ),
                              ),
                              if (subtitle != null) ...[
                                const SizedBox(height: 3),
                                Text(
                                  subtitle!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Color(0xFFE5F3FF),
                                    fontSize: 13,
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
          ],
        ),
      ),
    );
  }
}
