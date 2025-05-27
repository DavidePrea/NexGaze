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
            Text(
              'BPM: ',
              style: const TextStyle(fontSize: 18, color: Colors.white),
            ),
            Text(
              '${controller.bpm}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.favorite,
              color: controller.pulse ? Colors.red : Colors.grey[800],
              size: 24, // 50% of previous size (was 48)
            ),
          ],
        );
      },
    );
  }
}
