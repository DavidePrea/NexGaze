// lib/widgets/heart_monitor/heart_monitor_widget.dart

import 'package:flutter/material.dart';
import 'heart_monitor_controller.dart';
import '../../screens/setup_screen.dart'; // Import for GlobalSettings

// Widget to display heart rate data with a pulsing heart icon
class HeartMonitorWidget extends StatelessWidget {
  final HeartMonitorController controller; // Controller for heart rate data

  const HeartMonitorWidget({super.key, required this.controller});

  // Maps overlay color name to a Color object based on GlobalSettings
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
        return Colors.white; // Default color if none matched
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller, // Listens for updates from the controller
      builder: (context, _) {
        return Row(
          mainAxisSize: MainAxisSize.min, // Minimize row size
          crossAxisAlignment: CrossAxisAlignment.center, // Center elements vertically
          children: [
            // Column for BPM text aligned to the start
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'BPM', // Label for beats per minute
                  style: TextStyle(fontSize: 14, color: _getOverlayColor()),
                ),
                Text(
                  '${controller.bpm}', // Display current heart rate
                  style: TextStyle(fontSize: 24, color: _getOverlayColor()),
                ),
              ],
            ),
            const SizedBox(width: 8), // Spacing between text and icon
            // Heart icon indicating pulse status
            Icon(
              Icons.favorite,
              color: controller.pulse ? Colors.red : Colors.grey[800], // Red when pulsing, grey otherwise
              size: 24, // Icon size as per original code
            ),
          ],
        );
      },
    );
  }
}