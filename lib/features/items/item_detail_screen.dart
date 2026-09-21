import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_routes.dart';
import '../../core/widgets/star_display.dart';
import '../../core/widgets/state_views.dart';
import '../../models/feedback_model.dart';
import '../../models/item.dart';
import '../../providers/feedback_providers.dart';
import '../../providers/item_providers.dart';
import 'widgets/item_type_chip.dart';
import 'widgets/rating_summary.dart';

/// Details and average rating for one item, and the entry to give feedback.
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
              const SizedBox(height: 24),
              _FeedbackSection(item: item),
            ],
          );
        },
      ),
    );
  }
}

/// The user's own review (if any) and the button to give or edit it.
class _FeedbackSection extends ConsumerWidget {
  const _FeedbackSection({required this.item});

  final Item item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mine = ref.watch(myFeedbackForItemProvider(item.id));

    return mine.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Column(
        children: [
          const Text("Couldn't load your feedback."),
          TextButton(
            onPressed: () => ref.invalidate(myFeedbackProvider),
            child: const Text('Retry'),
          ),
        ],
      ),
      data: (existing) {
        if (existing == null && !item.isActive) {
          return const Text('This item is no longer accepting feedback.');
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (existing != null) ...[
              _MyFeedbackCard(feedback: existing),
              const SizedBox(height: 12),
            ],
            FilledButton.icon(
              onPressed: () => context.push(AppRoutes.feedbackForm(item.id)),
              icon: Icon(existing == null ? Icons.rate_review : Icons.edit),
              label: Text(
                existing == null ? 'Give feedback' : 'Edit your feedback',
              ),
            ),
          ],
        );
      },
    );
  }
}

class _MyFeedbackCard extends StatelessWidget {
  const _MyFeedbackCard({required this.feedback});

  final FeedbackModel feedback;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Your feedback', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Semantics(
              label: 'Your rating: ${feedback.rating} out of 5',
              excludeSemantics: true,
              child: StarDisplay(value: feedback.rating.toDouble(), size: 22),
            ),
            if (feedback.review.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(feedback.review),
            ],
            if (feedback.suggestion.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Suggestion',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              Text(feedback.suggestion),
            ],
          ],
        ),
      ),
    );
  }
}
