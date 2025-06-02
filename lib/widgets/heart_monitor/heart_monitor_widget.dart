// lib/widgets/heart_monitor/heart_monitor_widget.dart

import 'package:flutter/material.dart';
import 'heart_monitor_controller.dart';
import '../../screens/setup_screen.dart'; // Importa GlobalSettings

class HeartMonitorWidget extends StatelessWidget {
  final HeartMonitorController controller;

  const HeartMonitorWidget({super.key, required this.controller});

  // Funzione per mappare il nome del colore a un oggetto Color
  Color _getOverlayColor() {
    switch (GlobalSettings.overlayColor.toLowerCase()) {
      case 'white':
        return Colors.white;
      case 'yellow':
        return Colors.yellow;
      case 'red':
        return Colors.red;
      case 'green':
        return Colors.green;
      case 'blue':
        return Colors.blue;
      default:
        return Colors.white;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Colonna per i testi allineati in alto
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'BPM',
                  style: TextStyle(fontSize: 14, color: _getOverlayColor()),
                ),
                Text(
                  '${controller.bpm}',
                  style: TextStyle(fontSize: 24, color: _getOverlayColor()),
                ),
              ],
            ),
            const SizedBox(width: 8),
            // Icona del cuore a destra
            Icon(
              Icons.favorite,
              color: controller.pulse ? Colors.red : Colors.grey[800],
              size: 24, // Dimensione invariata come da codice originale
            ),
          ],
        );
      },
    );
  }
}