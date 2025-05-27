// modes/mode_2_screen.dart
import 'package:flutter/material.dart';

class Mode2Screen extends StatelessWidget {
  const Mode2Screen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Modalità 2')),
      body: const Center(
        child: Text(
          'Contenuto Modalità 2',
          style: TextStyle(fontSize: 24),
        ),
      ),
    );
  }
}
