// menu_screen.dart – Modified with logo (height 20), text, and Setup option
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // For SystemNavigator
import '../modes/hiking_mode.dart';
import '../modes/running_mode.dart';
import '../modes/cycling_mode.dart';
import '../modes/skiing_mode.dart';
import '../modes/yoga_mode.dart';
import '../modes/relax_mode.dart';
import '../screens/setup_screen.dart'; // Import for SetupScreen

// Main menu screen for selecting activity modes
class MenuScreen extends StatelessWidget {
  const MenuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // List of menu items with navigation targets
    final List<_MenuItem> items = [
      _MenuItem('Hiking', 'assets/images/mode1.png', const Mode1Screen()),
      _MenuItem('Running', 'assets/images/mode2.png', const Mode2Screen()),
      _MenuItem('Cycling', 'assets/images/mode3.png', const Mode3Screen()),
      _MenuItem('Skiing', 'assets/images/mode4.png', const Mode4Screen()),
      _MenuItem('Yoga', 'assets/images/mode5.png', Mode5Screen()),
      _MenuItem('Relax', 'assets/images/mode6.png', Mode6Screen()),
    ];

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            // Header with logo and title
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Image.asset('assets/images/nexgaze_logo.png', height: 20),
                  const Text(
                    'Select your activity',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),

            // Grid of activity options
            Expanded(
              child: GridView.count(
                crossAxisCount: 2,
                children: items,
              ),
            ),

            // Footer with Setup and Exit options
            Padding(
              padding: const EdgeInsets.only(left: 12, bottom: 10, right: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  GestureDetector(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const SetupScreen()),
                    ),
                    child: const Text(
                      '  Setup',
                      style: TextStyle(color: Colors.red, fontSize: 16),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => SystemNavigator.pop(), // Exit the app
                    child: const Text(
                      'Exit  ',
                      style: TextStyle(color: Colors.red, fontSize: 16),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Widget for individual menu items
class _MenuItem extends StatelessWidget {
  final String label;
  final String imagePath;
  final Widget screen;
  const _MenuItem(this.label, this.imagePath, this.screen, {super.key});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => screen),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.asset(imagePath, height: 160),
          const SizedBox(height: 10),
          Text(
            label,
            style: const TextStyle(color: Colors.white, fontSize: 16),
          ),
        ],
      ),
    );
  }
}