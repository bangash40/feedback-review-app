import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_routes.dart';
import '../../providers/auth_providers.dart';

/// Placeholder landing page for admins; the real dashboard replaces the body
/// later, but the entry to item management already lives here.
class AdminDashboardScreen extends ConsumerWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider).value;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin dashboard'),
        actions: [
          IconButton(
            tooltip: 'Log out',
            icon: const Icon(Icons.logout),
            onPressed: () =>
                ref.read(authControllerProvider.notifier).signOut(),
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Welcome, ${user?.name ?? ''} (${user?.isSuperAdmin == true ? 'super admin' : 'admin'})',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => context.push(AppRoutes.adminItems),
              icon: const Icon(Icons.list_alt),
              label: const Text('Manage items'),
            ),
            if (user?.isSuperAdmin ?? false) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => context.push(AppRoutes.adminUsers),
                icon: const Icon(Icons.manage_accounts),
                label: const Text('Manage users'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
