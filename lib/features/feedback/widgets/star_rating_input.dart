import 'package:flutter/material.dart';

/// Tappable 1-5 star input. [value] 0 means nothing chosen yet.
class StarRatingInput extends StatelessWidget {
  const StarRatingInput({
    super.key,
    required this.value,
    required this.onChanged,
    this.errorText,
  });

  final int value;
  final ValueChanged<int> onChanged;

  /// Shown under the stars, e.g. "Please select a rating".
  final String? errorText;

  static const _labels = [
    'Tap a star to rate',
    'Poor',
    'Fair',
    'Good',
    'Very good',
    'Excellent',
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      container: true,
      label: 'Rating',
      value: value == 0 ? 'Not rated' : '$value out of 5',
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 1; i <= 5; i++)
                IconButton(
                  tooltip: i == 1 ? '1 star' : '$i stars',
                  iconSize: 40,
                  onPressed: () => onChanged(i),
                  icon: Icon(
                    i <= value ? Icons.star : Icons.star_border,
                    color: i <= value
                        ? Colors.amber.shade700
                        : theme.colorScheme.outline,
                  ),
                ),
            ],
          ),
          Text(
            _labels[value],
            style: theme.textTheme.titleSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          if (errorText != null) ...[
            const SizedBox(height: 4),
            Text(
              errorText!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
