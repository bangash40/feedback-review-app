import 'package:flutter/material.dart';

import '../../../core/widgets/star_display.dart';

/// Star display with the average and response count, e.g. "4.5 (2 ratings)".
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
    final noun = count == 1 ? 'rating' : 'ratings';
    final label = hasRatings
        ? '${average.toStringAsFixed(1)} ($count $noun)'
        : 'No ratings yet';

    return Semantics(
      label: hasRatings
          ? 'Average rating ${average.toStringAsFixed(1)} out of 5 from $count '
                '$noun'
          : 'No ratings yet',
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          StarDisplay(value: average, size: starSize, muted: !hasRatings),
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
}
