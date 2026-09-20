import 'package:flutter/material.dart';

/// Read-only star display with the average and response count.
class RatingSummary extends StatelessWidget {
  const RatingSummary({
    super.key,
    required this.average,
    required this.count,
    this.starSize = 18,
  });

  final double average;
  final int count;
  final double starSize;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasRatings = count > 0;
    final label = hasRatings
        ? '${average.toStringAsFixed(1)} ($count ${count == 1 ? 'rating' : 'ratings'})'
        : 'No ratings yet';

    return Semantics(
      label: hasRatings
          ? 'Average rating ${average.toStringAsFixed(1)} out of 5 from $count '
                '${count == 1 ? 'rating' : 'ratings'}'
          : 'No ratings yet',
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 1; i <= 5; i++)
            Icon(
              _iconFor(i),
              size: starSize,
              color: hasRatings ? Colors.amber.shade700 : theme.disabledColor,
            ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Full star, half star (from .25 to .75) or outline for star number [i].
  IconData _iconFor(int i) {
    if (!(count > 0)) return Icons.star_border;
    final remainder = average - (i - 1);
    if (remainder >= 0.75) return Icons.star;
    if (remainder >= 0.25) return Icons.star_half;
    return Icons.star_border;
  }
}
