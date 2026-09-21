import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/constants/app_routes.dart';
import '../../core/widgets/star_display.dart';
import '../../core/widgets/state_views.dart';
import '../../models/feedback_model.dart';
import '../../providers/dashboard_providers.dart';
import '../items/widgets/item_type_chip.dart';

/// Admin view of one feedback entry: the full review and suggestion.
class FeedbackDetailScreen extends ConsumerWidget {
  const FeedbackDetailScreen({super.key, required this.feedbackId});

  final String feedbackId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feedback = ref.watch(feedbackByIdProvider(feedbackId));

    return Scaffold(
      appBar: AppBar(title: const Text('Feedback details')),
      body: feedback.when(
        loading: () => const LoadingView(),
        error: (error, _) => ErrorView(
          error: error,
          onRetry: () => ref.invalidate(feedbackByIdProvider(feedbackId)),
        ),
        data: (entry) => entry == null
            ? const EmptyView(
                icon: Icons.search_off,
                title: 'Feedback not found',
                message: 'It may have been deleted by its author.',
              )
            : _Details(feedback: entry),
      ),
    );
  }
}

class _Details extends StatelessWidget {
  const _Details({required this.feedback});

  final FeedbackModel feedback;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final format = DateFormat.yMMMd().add_jm();
    final edited = feedback.updatedAt.isAfter(
      feedback.createdAt.add(const Duration(minutes: 1)),
    );

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Row(
          children: [
            ItemTypeChip(type: feedback.itemType),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                feedback.itemTitle,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Semantics(
          label: 'Rating: ${feedback.rating} out of 5',
          excludeSemantics: true,
          // A Wrap, not a Row, so a large system font size cannot overflow.
          child: Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 4,
            children: [
              StarDisplay(value: feedback.rating.toDouble(), size: 32),
              Text(
                '${feedback.rating} out of 5',
                style: theme.textTheme.titleMedium,
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        _Section(
          title: 'Review',
          text: feedback.review,
          emptyText: 'No review written.',
        ),
        const SizedBox(height: 16),
        _Section(
          title: 'Suggestion',
          text: feedback.suggestion,
          emptyText: 'No suggestion given.',
        ),
        const SizedBox(height: 24),
        Text('From', style: theme.textTheme.labelLarge?.copyWith(color: muted)),
        Text(feedback.userName, style: theme.textTheme.bodyLarge),
        const SizedBox(height: 12),
        Text(
          'Submitted',
          style: theme.textTheme.labelLarge?.copyWith(color: muted),
        ),
        Text(
          format.format(feedback.createdAt),
          style: theme.textTheme.bodyLarge,
        ),
        if (edited) ...[
          const SizedBox(height: 12),
          Text(
            'Last edited',
            style: theme.textTheme.labelLarge?.copyWith(color: muted),
          ),
          Text(
            format.format(feedback.updatedAt),
            style: theme.textTheme.bodyLarge,
          ),
        ],
        const SizedBox(height: 24),
        OutlinedButton.icon(
          onPressed: () => context.push(AppRoutes.itemDetail(feedback.itemId)),
          icon: const Icon(Icons.open_in_new),
          label: const Text('View item'),
        ),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.text,
    required this.emptyText,
  });

  final String title;
  final String text;
  final String emptyText;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasText = text.isNotEmpty;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            SelectableText(
              hasText ? text : emptyText,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: hasText ? null : theme.colorScheme.onSurfaceVariant,
                fontStyle: hasText ? null : FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
