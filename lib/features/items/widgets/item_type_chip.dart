import 'package:flutter/material.dart';

import '../../../models/item.dart';

/// Small pill showing an item's type (Task / Course / Service).
class ItemTypeChip extends StatelessWidget {
  const ItemTypeChip({super.key, required this.type});

  final ItemType type;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        type.label,
        style: theme.textTheme.labelMedium?.copyWith(
          color: theme.colorScheme.onSecondaryContainer,
        ),
      ),
    );
  }
}

/// Icon that represents an item type.
IconData iconForItemType(ItemType type) => switch (type) {
  ItemType.task => Icons.task_alt,
  ItemType.course => Icons.school_outlined,
  ItemType.service => Icons.support_agent,
};
