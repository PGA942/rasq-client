import 'package:flutter/material.dart';

/// Loading indicator. Wireframe rule: **no skeleton loading anywhere** —
/// show a loading circle and render content the moment it is available.
class RasqLoading extends StatelessWidget {
  const RasqLoading({super.key, this.size = 28, this.padding = const EdgeInsets.all(24)});
  final double size;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: padding,
          child: SizedBox(width: size, height: size, child: const CircularProgressIndicator.adaptive(strokeWidth: 2.5)),
        ),
      );
}
