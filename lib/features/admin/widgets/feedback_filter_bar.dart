import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/item.dart';
import '../../../providers/dashboard_providers.dart';
import '../../../providers/item_providers.dart';

/// Type chips, rating chips, an item picker and the sort menu for the
/// dashboard's feedback list.
class FeedbackFilterBar extends ConsumerWidget {
  const FeedbackFilterBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(feedbackFilterProvider);
    final controller = ref.read(feedbackFilterProvider.notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ChipRow(
          label: 'Type',
          children: [
            ChoiceChip(
              label: const Text('All'),
              selected: filter.itemType == null,
              onSelected: (_) => controller.setType(null),
            ),
            for (final type in ItemType.values)
              ChoiceChip(
                label: Text(type.label),
                selected: filter.itemType == type,
                onSelected: (_) => controller.setType(type),
              ),
          ],
        ),
        const SizedBox(height: 8),
        _ChipRow(
          label: 'Rating',
          children: [
            ChoiceChip(
              label: const Text('All'),
              selected: filter.rating == null,
              onSelected: (_) => controller.setRating(null),
            ),
            for (var stars = 5; stars >= 1; stars--)
              ChoiceChip(
                // The tooltip-style semantic label reads better than "5★".
                label: Text('$stars★'),
                tooltip: stars == 1 ? '1 star' : '$stars stars',
                selected: filter.rating == stars,
                onSelected: (_) => controller.setRating(stars),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _ItemPicker(filter: filter)),
            const SizedBox(width: 8),
            _SortMenu(filter: filter),
          ],
        ),
        if (filter.isActive)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: controller.clear,
              icon: const Icon(Icons.filter_alt_off_outlined),
              label: const Text('Clear filters'),
            ),
          ),
      ],
    );
  }
}

class _ChipRow extends StatelessWidget {
  const _ChipRow({required this.label, required this.children});

  final String label;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        SizedBox(
          // Scales with the system font so the label never overlaps the chips.
          width: MediaQuery.textScalerOf(context).scale(52),
          child: Text(
            label,
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final child in children) ...[
                  child,
                  const SizedBox(width: 8),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Dropdown of items (narrowed to the chosen type).
class _ItemPicker extends ConsumerWidget {
  const _ItemPicker({required this.filter});

  final FeedbackFilter filter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items =
        (ref.watch(allItemsProvider).value ?? const <Item>[])
            .where(
              (item) => filter.itemType == null || item.type == filter.itemType,
            )
            .toList()
          ..sort(
            (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
          );

    // Guard against a filter that points at an item no longer in the list.
    final selected = items.any((item) => item.id == filter.itemId)
        ? filter.itemId
        : null;

    return InputDecorator(
      decoration: const InputDecoration(
        labelText: 'Item',
        border: OutlineInputBorder(),
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String?>(
          value: selected,
          isExpanded: true,
          items: [
            const DropdownMenuItem<String?>(
              value: null,
              child: Text('All items'),
            ),
            for (final item in items)
              DropdownMenuItem<String?>(
                value: item.id,
                child: Text(item.title, overflow: TextOverflow.ellipsis),
              ),
          ],
          onChanged: (id) =>
              ref.read(feedbackFilterProvider.notifier).setItem(id),
        ),
      ),
    );
  }
}

class _SortMenu extends ConsumerWidget {
  const _SortMenu({required this.filter});

  final FeedbackFilter filter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PopupMenuButton<FeedbackSort>(
      tooltip: 'Sort: ${filter.sort.label}',
      icon: const Icon(Icons.sort),
      onSelected: ref.read(feedbackFilterProvider.notifier).setSort,
      itemBuilder: (context) => [
        for (final sort in FeedbackSort.values)
          CheckedPopupMenuItem(
            value: sort,
            checked: sort == filter.sort,
            child: Text(sort.label),
          ),
      ],
    );
  }
}
