import 'package:flutter/material.dart';

/// Read-only row of five stars for a [value] from 0 to 5. Fractions show as a
/// half star from .25 to .75.
class StarDisplay extends StatelessWidget {
  const StarDisplay({
    super.key,
    required this.value,
    this.size = 18,
    this.muted = false,
  });

  final double value;
  final double size;

  /// Grey stars, for "no ratings yet".
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final color = muted
        ? Theme.of(context).disabledColor
        : Colors.amber.shade700;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 1; i <= 5; i++)
          Icon(_iconFor(i), size: size, color: color),
      ],
    );
  }

  /// Full star, half star or outline for star number [i].
  IconData _iconFor(int i) {
    if (muted) return Icons.star_border;
    final remainder = value - (i - 1);
    if (remainder >= 0.75) return Icons.star;
    if (remainder >= 0.25) return Icons.star_half;
    return Icons.star_border;
  }
}
