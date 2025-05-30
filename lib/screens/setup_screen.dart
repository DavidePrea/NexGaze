// menu_screen.dart – ripristinato e modificato SOLO logo (h 20), testo, e voce Setup
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Added for SystemNavigator
import '../modes/mode_1_screen.dart';
import '../modes/mode_2_screen.dart';
import '../modes/mode_3_screen.dart';
import '../modes/mode_4_screen.dart';
import '../modes/mode_5_screen.dart';
import '../modes/mode_6_screen.dart';
import '../screens/setup_screen.dart'; // Added import for SetupScreen

class MenuScreen extends StatelessWidget {
  const MenuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // lista originale di _MenuItem con const solo sui primi 4
    final List<_MenuItem> items = [
      _MenuItem('Hiking', 'assets/images/mode1.png', const Mode1Screen()),
      _MenuItem('Running', 'assets/images/mode2.png', const Mode2Screen()),
      _MenuItem('Cycling', 'assets/images/mode3.png', const Mode3Screen()),
      _MenuItem('Skiing',  'assets/images/mode4.png', const Mode4Screen()),
      _MenuItem('Yoga',    'assets/images/mode5.png',       Mode5Screen()),
      _MenuItem('Relax',   'assets/images/mode6.png',       Mode6Screen()),
    ];

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            // Logo in alto a sinistra
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Image.asset('assets/images/nexgaze_logo.png', height: 20),
                  const Spacer(), // Sposta il logo a sinistra e lascia spazio
                ],
              ),
            ),
            // Testo "Select your activity" centrato sotto il logo
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8.0),
              child: Center(
                child: Text(
                  'Select your activity',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),

            // Griglia delle icone
            Expanded(
              child: GridView.count(
                crossAxisCount: 2,
                children: items,
              ),
            ),

            // Footer con Setup + Exit
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
                      style: TextStyle(color: Colors.red, fontSize: 20),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => SystemNavigator.pop(),
                    child: const Text(
                      'Exit  ',
                      style: TextStyle(color: Colors.red, fontSize: 20),
                    ),
                  ),
                ],
              ),
            ),

            // Pulsante "Back" in basso a sinistra
            Padding(
              padding: const EdgeInsets.only(left: 12, bottom: 12),
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: const Text(
                  'Back',
                  style: TextStyle(color: Colors.red, fontSize: 20),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

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
          Image.asset(imagePath, height: 180),
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