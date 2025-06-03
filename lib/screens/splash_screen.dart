// screens/splash_screen.dart
import 'package:flutter/material.dart';
import 'dart:async';
import 'menu_screen.dart';

// Splash screen displayed on app startup
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    // Navigate to MenuScreen after 3 seconds
    Timer(const Duration(seconds: 3), () {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const MenuScreen()),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black, // Black background
      body: Center(
        child: Image.asset(
          'assets/images/nexgaze.png',
          width: 200,
          height: 200, // Display logo
        ),
      ),
    );
  }
}