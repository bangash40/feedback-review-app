import 'package:flutter/material.dart';

import '../../../providers/dashboard_providers.dart';

/// Two headline numbers: how many reviews, and their average rating.
class StatsOverview extends StatelessWidget {
  const StatsOverview({super.key, required this.stats});

  final FeedbackStats stats;

  @override
  Widget build(BuildContext context) {
    final hasRatings = stats.total > 0;
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            icon: Icons.forum_outlined,
            label: 'Total feedback',
            value: '${stats.total}',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            icon: Icons.star_rounded,
            iconColor: Colors.amber.shade700,
            label: 'Average rating',
            value: hasRatings ? stats.average.toStringAsFixed(1) : '–',
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    this.iconColor,
  });

  final IconData icon;
  final Color? iconColor;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      label: '$label: $value',
      excludeSemantics: true,
      child: Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: iconColor ?? theme.colorScheme.primary),
              const SizedBox(height: 8),
              Text(
                value,
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                label,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
