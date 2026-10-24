import 'package:flutter/material.dart';

/// A small red circle used as a notification dot.
class RedDot extends StatelessWidget {
  final double size;

  const RedDot({super.key, this.size = 10});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.red,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 1.5),
      ),
    );
  }
}