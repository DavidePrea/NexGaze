// modes/mode_4_screen.dart
import 'package:flutter/material.dart';

class Mode4Screen extends StatelessWidget {
  const Mode4Screen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Modalità 4')),
      body: const Center(
        child: Text(
          'Contenuto Modalità 4',
          style: TextStyle(fontSize: 24),
        ),
      ),
    );
  }
}
