import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/widgets/state_views.dart';
import '../../providers/item_providers.dart';
import 'widgets/item_type_chip.dart';
import 'widgets/rating_summary.dart';

/// Details and average rating for one item.
class ItemDetailScreen extends ConsumerWidget {
  const ItemDetailScreen({super.key, required this.itemId});

  final String itemId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final item = ref.watch(itemProvider(itemId));
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Item details')),
      body: item.when(
        loading: () => const LoadingView(),
        error: (error, _) => ErrorView(
          error: error,
          onRetry: () => ref.invalidate(itemProvider(itemId)),
        ),
        data: (item) {
          if (item == null) {
            return const EmptyView(
              icon: Icons.search_off,
              title: 'Item not found',
              message: 'It may have been removed.',
            );
          }
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Row(
                children: [
                  Icon(
                    iconForItemType(item.type),
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  ItemTypeChip(type: item.type),
                  if (!item.isActive) ...[
                    const SizedBox(width: 8),
                    Chip(
                      label: const Text('Inactive'),
                      visualDensity: VisualDensity.compact,
                      backgroundColor: theme.colorScheme.errorContainer,
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 16),
              Text(
                item.title,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              RatingSummary(
                average: item.averageRating,
                count: item.ratingCount,
                starSize: 24,
              ),
              const SizedBox(height: 20),
              Text('About', style: theme.textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(
                item.description.isEmpty
                    ? 'No description provided.'
                    : item.description,
                style: theme.textTheme.bodyLarge,
              ),
            ],
          );
        },
      ),
    );
  }
}
