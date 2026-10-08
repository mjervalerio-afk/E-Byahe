import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// One place for the app's colors, so every screen looks like the same app.
class AppColors {
  AppColors._();

  static const metallicBlue = Color(0xFF3E5E82);
  static const navy = Color(0xFF0D1B4C);
  static const blue = Color(0xFF2E6FF2);
  static const green = Color(0xFF22A45D);
  static const amber = Color(0xFFE08A00);
  static const red = Color(0xFFE14B4B);
  static const muted = Color(0xFF8A93A6);
  static const line = Color(0xFFE8ECF1);
  static const background = Color(0xFFF5F7FA);

  static const softBlue = Color(0xFFEAF1FF);
  static const softGreen = Color(0xFFE8F6EE);
  static const softAmber = Color(0xFFFFF3DD);
  static const softRed = Color(0xFFFDECEC);
}

/// White rounded card with a hairline border and a soft shadow.
BoxDecoration appCardDecoration({double radius = 16}) {
  return BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(color: AppColors.line),
    boxShadow: const [
      BoxShadow(color: Color(0x120D1B4C), blurRadius: 12, offset: Offset(0, 4)),
    ],
  );
}

ThemeData buildAppTheme() {
  return ThemeData(
    useMaterial3: true,
    colorSchemeSeed: AppColors.blue,
    scaffoldBackgroundColor: AppColors.background,
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
  );
}

/// The metallic-blue bar at the top of every screen. It paints behind the
/// phone's status bar too, so there is no pale strip above it.
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
      value: SystemUiOverlayStyle.light.copyWith(statusBarColor: Colors.transparent),
      child: Container(
        color: AppColors.metallicBlue,
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 16, 14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    if (leading != null) ...[
                      leading!,
                      const SizedBox(width: 8),
                    ] else
                      const SizedBox(width: 4),
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
                              fontWeight: FontWeight.w700,
                              fontSize: 18,
                            ),
                          ),
                          if (subtitle != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              subtitle!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: Colors.white70, fontSize: 12),
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
