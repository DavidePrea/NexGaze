import 'package:flutter/material.dart';
import 'brain_bit_controller.dart';

// Widget to display BrainBit data such as attention and meditation levels
class BrainBitWidget extends StatelessWidget {
  final BrainBitController controller; // Controller for BrainBit data

  const BrainBitWidget({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller, // Listens for updates from the controller
      builder: (context, _) {
        return Column(
          mainAxisSize: MainAxisSize.min, // Minimize column size
          children: [
            Text(
              'Attention: ${controller.attention}', // Display attention level
              style: const TextStyle(color: Colors.white, fontSize: 18),
            ),
            Text(
              'Meditation: ${controller.meditation}', // Display meditation level
              style: const TextStyle(color: Colors.white, fontSize: 18),
            ),
          ],
        );
      },
    );
  }
}