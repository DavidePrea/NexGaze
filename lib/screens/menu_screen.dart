import 'package:flutter/material.dart';
import '../modes/mode_1_screen.dart';
import '../modes/mode_2_screen.dart';
import '../modes/mode_3_screen.dart';
import '../modes/mode_4_screen.dart';
import '../modes/mode_5_screen.dart';
import '../modes/mode_6_screen.dart';
import 'dart:io'; // necessario per exit()

class MenuScreen extends StatelessWidget {
  const MenuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final List<_MenuItem> items = [
      _MenuItem('Hiking', 'assets/images/mode1.png', const Mode1Screen()),
      _MenuItem('Running', 'assets/images/mode2.png', const Mode2Screen()),
      _MenuItem('Cycling', 'assets/images/mode3.png', const Mode3Screen()),
      _MenuItem('Skiing', 'assets/images/mode4.png', const Mode4Screen()),
      _MenuItem('Yoga', 'assets/images/mode5.png', Mode5Screen()),
      _MenuItem('Relax', 'assets/images/mode6.png', Mode6Screen()),
    ];

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text(
          'Select your activity',
          style: TextStyle(color: Colors.white),
        ),
        centerTitle: true,
      ),
      backgroundColor: Colors.black, // 🔲 Sfondo nero per sicurezza
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            Expanded(
              child: GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                children: items.map((item) {
                  return GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => item.screen),
                      );
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.all(8),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Image.asset(item.imagePath, fit: BoxFit.contain),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            item.title,
                            style: const TextStyle(
                              fontSize: 16,
                              color: Colors.white, // ✅ testo visibile
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            Align(
              alignment: Alignment.bottomRight,
              child: GestureDetector(
                onTap: () {
                  exit(0); // ✅ Chiude l'app
                },
                child: const Padding(
                  padding: EdgeInsets.only(top: 8, bottom: 12, right: 12),
                  child: Text(
                    'Exit',
                    style: TextStyle(
                      color: Colors.redAccent,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MenuItem {
  final String title;
  final String imagePath;
  final Widget screen;

  _MenuItem(this.title, this.imagePath, this.screen);
}