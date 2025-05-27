// modes/mode_3_screen.dart
import 'package:flutter/material.dart';

class Mode3Screen extends StatelessWidget {
  const Mode3Screen({super.key});


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Modalità 3')),
      body: const Center(
        child: Text(
          'Contenuto Modalità 3',
          style: TextStyle(fontSize: 24),
        ),
      ),
    );
  }
}
