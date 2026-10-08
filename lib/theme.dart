import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AppColors {
  AppColors._();
  static const metallicBlue = Color(0xFF3E5E82);
  static const navy = Color(0xFF0D1B4C);
  static const blue = Color(0xFF2E6FF2);
  static const green = Color(0xFF22A45D);
  static const amber = Color(0xFFE08A00);
  static const red = Color(0xFFE14B4B);
  static const muted = Color(0xFF7C8798);
  static const line = Color(0xFFE5EAF0);
  static const background = Color(0xFFF6F8FB);
  static const softBlue = Color(0xFFEAF1FF);
  static const softGreen = Color(0xFFE8F6EE);
  static const softAmber = Color(0xFFFFF3DD);
  static const softRed = Color(0xFFFDECEC);
}

BoxDecoration appCardDecoration({double radius = 18}) {
  return BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(color: AppColors.line),
    boxShadow: const [
      BoxShadow(color: Color(0x100D1B4C), blurRadius: 18, offset: Offset(0, 6)),
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
  );
}

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
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.navy, AppColors.metallicBlue],
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    if (leading != null) ...[leading!, const SizedBox(width: 8)] else const SizedBox(width: 4),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title, maxLines: 1, overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18, letterSpacing: -0.2)),
                          if (subtitle != null) ...[
                            const SizedBox(height: 2),
                            Text(subtitle!, maxLines: 1, overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: Color(0xFFDCE6F2), fontSize: 12, fontWeight: FontWeight.w500)),
                          ],
                        ],
                      ),
                    ),
                    if (trailing != null) trailing!,
                  ],
                ),
                if (bottom != null) ...[const SizedBox(height: 12), bottom!],
              ],
            ),
          ),
        ),
      ),
    );
  }
}