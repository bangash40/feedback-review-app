import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/constants/app_routes.dart';
import '../../core/utils/snackbars.dart';
import '../../core/widgets/star_display.dart';
import '../../core/widgets/state_views.dart';
import '../../models/feedback_model.dart';
import '../../providers/feedback_providers.dart';
import '../items/widgets/item_type_chip.dart';

/// The signed-in user's own feedback, with edit and delete.
class MyFeedbackScreen extends ConsumerWidget {
  const MyFeedbackScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(feedbackControllerProvider, (_, next) {
      if (next is AsyncError) showErrorSnackBar(context, next.error);
    });
    final feedback = ref.watch(myFeedbackProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('My feedback')),
      body: feedback.when(
        loading: () => const LoadingView(),
        error: (error, _) => ErrorView(
          error: error,
          onRetry: () => ref.invalidate(myFeedbackProvider),
        ),
        data: (list) => list.isEmpty
            ? EmptyView(
                icon: Icons.rate_review_outlined,
                title: "You haven't left any feedback yet",
                message: 'Pick an item on the home screen to get started.',
              )
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: list.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, index) =>
                    _FeedbackTile(feedback: list[index]),
              ),
      ),
    );
  }
}

class _FeedbackTile extends ConsumerWidget {
  const _FeedbackTile({required this.feedback});

  final FeedbackModel feedback;

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete feedback?'),
        content: Text(
          'Your review of "${feedback.itemTitle}" will be removed and no longer '
          'counts towards its rating.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    final deleted = await ref
        .read(feedbackControllerProvider.notifier)
        .delete(feedback);
    if (deleted) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('Feedback deleted')));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final edited = feedback.updatedAt.isAfter(
      feedback.createdAt.add(const Duration(minutes: 1)),
    );
    final date = DateFormat.yMMMd().format(feedback.updatedAt);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push(AppRoutes.feedbackForm(feedback.itemId)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 4, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            feedback.itemTitle,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ItemTypeChip(type: feedback.itemType),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Semantics(
                      label: 'Your rating: ${feedback.rating} out of 5',
                      excludeSemantics: true,
                      child: StarDisplay(value: feedback.rating.toDouble()),
                    ),
                    if (feedback.review.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        feedback.review,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 8),
                    Text(
                      edited ? 'Updated $date' : date,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<_Action>(
                tooltip: 'More actions for ${feedback.itemTitle}',
                onSelected: (action) {
                  switch (action) {
                    case _Action.edit:
                      context.push(AppRoutes.feedbackForm(feedback.itemId));
                    case _Action.delete:
                      _delete(context, ref);
                  }
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(value: _Action.edit, child: Text('Edit')),
                  PopupMenuItem(value: _Action.delete, child: Text('Delete')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum _Action { edit, delete }
