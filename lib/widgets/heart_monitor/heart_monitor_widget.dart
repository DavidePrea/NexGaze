// lib/widgets/heart_monitor/heart_monitor_widget.dart

import 'package:flutter/material.dart';
import 'heart_monitor_controller.dart';

class HeartMonitorWidget extends StatelessWidget {
  final HeartMonitorController controller;

  const HeartMonitorWidget({super.key, required this.controller});

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
                  style: const TextStyle(fontSize: 14, color: Colors.white),
                ),
                Text(
                  '${controller.bpm}',
                  style: const TextStyle(fontSize: 24, color: Colors.white),
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