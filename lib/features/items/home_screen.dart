import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_routes.dart';
import '../../core/widgets/state_views.dart';
import '../../models/item.dart';
import '../../providers/auth_providers.dart';
import '../../providers/item_providers.dart';
import 'widgets/item_card.dart';

/// User landing page: browse active items, filtered by type.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider).value;
    final filter = ref.watch(itemTypeFilterProvider);
    final items = ref.watch(itemsProvider(filter));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Home'),
        actions: [
          IconButton(
            tooltip: 'My feedback',
            icon: const Icon(Icons.rate_review_outlined),
            onPressed: () => context.push(AppRoutes.myFeedback),
          ),
          IconButton(
            tooltip: 'Profile',
            icon: const Icon(Icons.person_outline),
            onPressed: () => context.push(AppRoutes.profile),
          ),
          IconButton(
            tooltip: 'Log out',
            icon: const Icon(Icons.logout),
            onPressed: () =>
                ref.read(authControllerProvider.notifier).signOut(),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Text(
              'Welcome, ${user?.name ?? ''}',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(
              'Pick something to give feedback on',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          _TypeFilterBar(
            selected: filter,
            onSelected: ref.read(itemTypeFilterProvider.notifier).select,
          ),
          Expanded(
            child: items.when(
              loading: () => const LoadingView(),
              error: (error, _) => ErrorView(
                error: error,
                onRetry: () => ref.invalidate(itemsProvider(filter)),
              ),
              data: (list) => list.isEmpty
                  ? EmptyView(
                      icon: Icons.inbox_outlined,
                      title: filter == null
                          ? 'Nothing to review yet'
                          : 'No ${filter.label.toLowerCase()}s to review',
                      message: 'New items will show up here.',
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                      itemCount: list.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final item = list[index];
                        return ItemCard(
                          item: item,
                          onTap: () =>
                              context.push(AppRoutes.itemDetail(item.id)),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

/// "All / Task / Course / Service" chips.
class _TypeFilterBar extends StatelessWidget {
  const _TypeFilterBar({required this.selected, required this.onSelected});

  final ItemType? selected;
  final ValueChanged<ItemType?> onSelected;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          ChoiceChip(
            label: const Text('All'),
            selected: selected == null,
            onSelected: (_) => onSelected(null),
          ),
          for (final type in ItemType.values) ...[
            const SizedBox(width: 8),
            ChoiceChip(
              label: Text(type.label),
              selected: selected == type,
              onSelected: (_) => onSelected(type),
            ),
          ],
        ],
      ),
    );
  }
}
