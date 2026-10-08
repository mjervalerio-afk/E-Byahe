import 'package:flutter/material.dart';
import 'screens/splash_screen.dart';
import 'theme.dart';

void main() {
  runApp(const EByaheApp());
}

class EByaheApp extends StatelessWidget {
  const EByaheApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'E-Byahe Shuttle',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: const SplashScreen(),
    );
  }
}