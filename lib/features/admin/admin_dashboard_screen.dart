import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_routes.dart';
import '../../core/widgets/state_views.dart';
import '../../models/item.dart';
import '../../providers/auth_providers.dart';
import '../../providers/dashboard_providers.dart';
import '../../providers/item_providers.dart';
import '../../repositories/feedback_repository.dart';
import '../items/widgets/item_type_chip.dart';
import '../items/widgets/rating_summary.dart';
import 'widgets/admin_feedback_tile.dart';
import 'widgets/feedback_filter_bar.dart';
import 'widgets/rating_distribution_chart.dart';
import 'widgets/stats_overview.dart';

/// Admin landing page: live feedback with filters and analytics, plus a
/// per-item breakdown and the entry points to item and user management.
class AdminDashboardScreen extends ConsumerWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider).value;

    return DefaultTabController(
      length: 2,
      // A Builder so the tab controller can be reached from inside the tabs.
      child: Builder(
        builder: (context) {
          final tabs = DefaultTabController.of(context);
          return Scaffold(
            appBar: AppBar(
              title: const Text('Admin dashboard'),
              actions: [
                IconButton(
                  tooltip: 'Manage items',
                  icon: const Icon(Icons.list_alt),
                  onPressed: () => context.push(AppRoutes.adminItems),
                ),
                if (user?.isSuperAdmin ?? false)
                  IconButton(
                    tooltip: 'Manage users',
                    icon: const Icon(Icons.manage_accounts),
                    onPressed: () => context.push(AppRoutes.adminUsers),
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
              bottom: const TabBar(
                tabs: [
                  Tab(text: 'Feedback'),
                  Tab(text: 'Items'),
                ],
              ),
            ),
            body: TabBarView(
              children: [
                _FeedbackTab(
                  greeting:
                      'Welcome, ${user?.name ?? ''} '
                      '(${user?.isSuperAdmin == true ? 'super admin' : 'admin'})',
                ),
                _ItemsTab(onItemChosen: () => tabs.animateTo(0)),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _FeedbackTab extends ConsumerWidget {
  const _FeedbackTab({required this.greeting});

  final String greeting;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final all = ref.watch(allFeedbackProvider);

    if (all.hasError) {
      return ErrorView(
        error: all.error!,
        onRetry: () => ref.invalidate(allFeedbackProvider),
      );
    }
    if (!all.hasValue) return const LoadingView();

    final stats = ref.watch(feedbackStatsProvider).value;
    final shown = ref.watch(filteredFeedbackProvider).value ?? const [];
    final theme = Theme.of(context);
    final capped = all.value!.length >= FeedbackRepository.dashboardLimit;

    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              Text(greeting, style: theme.textTheme.titleMedium),
              const SizedBox(height: 12),
              if (stats != null) ...[
                StatsOverview(stats: stats),
                const SizedBox(height: 12),
                RatingDistributionChart(stats: stats),
              ],
              const SizedBox(height: 20),
              Text('Feedback', style: theme.textTheme.titleLarge),
              const SizedBox(height: 8),
              const FeedbackFilterBar(),
              const SizedBox(height: 8),
              Text(
                'Showing ${shown.length} of ${all.value!.length}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              if (capped)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    'Only the newest ${FeedbackRepository.dashboardLimit} '
                    'entries are loaded.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              const SizedBox(height: 8),
            ]),
          ),
        ),
        if (shown.isEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: all.value!.isEmpty
                  ? const EmptyView(
                      icon: Icons.forum_outlined,
                      title: 'No feedback yet',
                      message:
                          'New feedback appears here as soon as it is sent.',
                    )
                  : const EmptyView(
                      icon: Icons.filter_alt_off_outlined,
                      title: 'No feedback matches these filters',
                      message: 'Try clearing a filter.',
                    ),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            sliver: SliverList.separated(
              itemCount: shown.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final feedback = shown[index];
                return AdminFeedbackTile(
                  feedback: feedback,
                  onTap: () =>
                      context.push(AppRoutes.adminFeedback(feedback.id)),
                );
              },
            ),
          ),
      ],
    );
  }
}

/// Per-item response counts and averages, straight from the item documents
/// (so they cover all feedback, not just what the dashboard has loaded).
class _ItemsTab extends ConsumerWidget {
  const _ItemsTab({required this.onItemChosen});

  final VoidCallback onItemChosen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(allItemsProvider);

    return items.when(
      loading: () => const LoadingView(),
      error: (error, _) => ErrorView(
        error: error,
        onRetry: () => ref.invalidate(allItemsProvider),
      ),
      data: (list) {
        if (list.isEmpty) {
          return const EmptyView(
            icon: Icons.playlist_add,
            title: 'No items yet',
            message: 'Create items from the "Manage items" button above.',
          );
        }
        // Most-reviewed first, then alphabetical.
        final sorted = [...list]
          ..sort((a, b) {
            final byCount = b.ratingCount.compareTo(a.ratingCount);
            return byCount != 0
                ? byCount
                : a.title.toLowerCase().compareTo(b.title.toLowerCase());
          });

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: sorted.length,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (context, index) => _ItemStatsTile(
            item: sorted[index],
            onTap: () {
              // Show only this item's feedback and jump to the Feedback tab.
              final filter = ref.read(feedbackFilterProvider.notifier);
              filter.setType(null);
              filter.setItem(sorted[index].id);
              onItemChosen();
            },
          ),
        );
      },
    );
  }
}

class _ItemStatsTile extends StatelessWidget {
  const _ItemStatsTile({required this.item, required this.onTap});

  final Item item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
                      item.title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ItemTypeChip(type: item.type),
                ],
              ),
              const SizedBox(height: 8),
              RatingSummary(
                average: item.averageRating,
                count: item.ratingCount,
              ),
              if (!item.isActive) ...[
                const SizedBox(height: 4),
                Text(
                  'Inactive',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
