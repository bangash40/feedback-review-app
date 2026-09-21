import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/widgets/star_display.dart';
import '../../../models/feedback_model.dart';
import '../../items/widgets/item_type_chip.dart';

/// One feedback entry in the admin dashboard list.
class AdminFeedbackTile extends StatelessWidget {
  const AdminFeedbackTile({
    super.key,
    required this.feedback,
    required this.onTap,
  });

  final FeedbackModel feedback;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      feedback.userName,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Text(
                    DateFormat.yMMMd().format(feedback.createdAt),
                    style: theme.textTheme.bodySmall?.copyWith(color: muted),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  ItemTypeChip(type: feedback.itemType),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      feedback.itemTitle,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(color: muted),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Semantics(
                label: 'Rating: ${feedback.rating} out of 5',
                excludeSemantics: true,
                child: StarDisplay(value: feedback.rating.toDouble()),
              ),
              if (feedback.review.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  feedback.review,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              if (feedback.suggestion.isNotEmpty) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.lightbulb_outline, size: 16, color: muted),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        'Includes a suggestion',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: muted,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
