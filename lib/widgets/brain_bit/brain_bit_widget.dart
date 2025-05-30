import 'package:flutter/material.dart';
import 'brain_bit_controller.dart';

class BrainBitWidget extends StatelessWidget {
  final BrainBitController controller;

  const BrainBitWidget({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Attention: ${controller.attention}',
              style: const TextStyle(color: Colors.white, fontSize: 18),
            ),
            Text(
              'Meditation: ${controller.meditation}',
              style: const TextStyle(color: Colors.white, fontSize: 18),
            ),
          ],
        );
      },
    );
  }
}