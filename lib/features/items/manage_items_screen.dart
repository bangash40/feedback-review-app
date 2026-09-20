import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_routes.dart';
import '../../core/utils/snackbars.dart';
import '../../core/widgets/state_views.dart';
import '../../models/item.dart';
import '../../providers/item_providers.dart';
import 'widgets/item_type_chip.dart';
import 'widgets/rating_summary.dart';

/// Admin screen: every item, with create / edit / activate / deactivate.
class ManageItemsScreen extends ConsumerWidget {
  const ManageItemsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(itemsControllerProvider, (_, next) {
      if (next is AsyncError) showErrorSnackBar(context, next.error);
    });
    final items = ref.watch(allItemsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Manage items')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(AppRoutes.adminItemNew),
        icon: const Icon(Icons.add),
        label: const Text('Add item'),
      ),
      body: items.when(
        loading: () => const LoadingView(),
        error: (error, _) => ErrorView(
          error: error,
          onRetry: () => ref.invalidate(allItemsProvider),
        ),
        data: (list) => list.isEmpty
            ? const EmptyView(
                icon: Icons.playlist_add,
                title: 'No items yet',
                message: 'Tap "Add item" to create the first one.',
              )
            : ListView.separated(
                // Leave room so the floating button never covers the last row.
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                itemCount: list.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, index) =>
                    _ManageItemTile(item: list[index]),
              ),
      ),
    );
  }
}

class _ManageItemTile extends ConsumerWidget {
  const _ManageItemTile({required this.item});

  final Item item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final muted = !item.isActive;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push(AppRoutes.adminItemEdit(item.id)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
          child: Row(
            children: [
              Expanded(
                child: Opacity(
                  opacity: muted ? 0.6 : 1,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          ItemTypeChip(type: item.type),
                          if (muted) const Text('Inactive'),
                        ],
                      ),
                      const SizedBox(height: 8),
                      RatingSummary(
                        average: item.averageRating,
                        count: item.ratingCount,
                      ),
                    ],
                  ),
                ),
              ),
              Semantics(
                label: item.isActive
                    ? 'Deactivate ${item.title}'
                    : 'Activate ${item.title}',
                child: Switch(
                  value: item.isActive,
                  onChanged: (value) => ref
                      .read(itemsControllerProvider.notifier)
                      .setActive(item.id, isActive: value),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
