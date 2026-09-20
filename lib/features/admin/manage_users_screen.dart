import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/snackbars.dart';
import '../../core/widgets/state_views.dart';
import '../../models/app_user.dart';
import '../../providers/auth_providers.dart';
import '../../providers/user_providers.dart';

/// Super admin screen: find users and promote or demote them.
class ManageUsersScreen extends ConsumerStatefulWidget {
  const ManageUsersScreen({super.key});

  @override
  ConsumerState<ManageUsersScreen> createState() => _ManageUsersScreenState();
}

class _ManageUsersScreenState extends ConsumerState<ManageUsersScreen> {
  static const _debounce = Duration(milliseconds: 350);

  final _searchController = TextEditingController();
  Timer? _debounceTimer;

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  /// Waits for a pause in typing so each keystroke is not a Firestore query.
  void _onQueryChanged(String value) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(_debounce, () {
      ref.read(userSearchProvider.notifier).search(query: value);
    });
  }

  Future<void> _changeRole(AppUser target, UserRole role) async {
    final makeAdmin = role == UserRole.admin;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(makeAdmin ? 'Make admin?' : 'Remove admin?'),
        content: Text(
          makeAdmin
              ? '${target.name} will be able to manage items and see all '
                    'feedback.'
              : '${target.name} will become a regular user and lose access '
                    'to the admin screens.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(makeAdmin ? 'Make admin' : 'Remove admin'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final changed = await ref
        .read(roleControllerProvider.notifier)
        .setRole(target, role);
    if (changed && mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              makeAdmin
                  ? '${target.name} is now an admin'
                  : '${target.name} is now a regular user',
            ),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(roleControllerProvider, (_, next) {
      if (next is AsyncError) showErrorSnackBar(context, next.error);
    });
    final search = ref.watch(userSearchProvider);
    final myUid = ref.watch(signedInUidProvider);
    final adminsOnly = search.value?.adminsOnly ?? false;

    return Scaffold(
      appBar: AppBar(title: const Text('Manage users')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: TextField(
              controller: _searchController,
              onChanged: _onQueryChanged,
              textInputAction: TextInputAction.search,
              autocorrect: false,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                labelText: 'Search by email',
                prefixIcon: const Icon(Icons.search),
                border: const OutlineInputBorder(),
                suffixIcon: _searchController.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Clear search',
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          _debounceTimer?.cancel();
                          ref
                              .read(userSearchProvider.notifier)
                              .search(query: '');
                          setState(() {});
                        },
                      ),
              ),
            ),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: FilterChip(
                label: const Text('Admins only'),
                selected: adminsOnly,
                onSelected: (value) => ref
                    .read(userSearchProvider.notifier)
                    .search(adminsOnly: value),
              ),
            ),
          ),
          if (search.isLoading) const LinearProgressIndicator(),
          Expanded(
            child: search.when(
              skipLoadingOnRefresh: false,
              loading: () => const SizedBox.shrink(),
              error: (error, _) => ErrorView(
                error: error,
                onRetry: () => ref.read(userSearchProvider.notifier).refresh(),
              ),
              data: (state) => _UserList(
                state: state,
                myUid: myUid,
                onChangeRole: _changeRole,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _UserList extends ConsumerWidget {
  const _UserList({
    required this.state,
    required this.myUid,
    required this.onChangeRole,
  });

  final UserSearchState state;
  final String? myUid;
  final Future<void> Function(AppUser target, UserRole role) onChangeRole;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (state.users.isEmpty) {
      return EmptyView(
        icon: Icons.person_search,
        title: 'No users found',
        message: state.query.isEmpty && !state.adminsOnly
            ? 'Users appear here once they sign up.'
            : 'Try a different search.',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 24),
      // One extra row at the end for the "Load more" button.
      itemCount: state.users.length + (state.hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == state.users.length) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Center(
              child: state.isLoadingMore
                  ? const CircularProgressIndicator()
                  : OutlinedButton(
                      onPressed: () =>
                          ref.read(userSearchProvider.notifier).loadMore(),
                      child: Text(
                        state.loadMoreFailed
                            ? "Couldn't load more. Retry"
                            : 'Load more',
                      ),
                    ),
            ),
          );
        }
        final user = state.users[index];
        return _UserTile(
          user: user,
          isMe: user.uid == myUid,
          onChangeRole: onChangeRole,
        );
      },
    );
  }
}

class _UserTile extends StatelessWidget {
  const _UserTile({
    required this.user,
    required this.isMe,
    required this.onChangeRole,
  });

  final AppUser user;
  final bool isMe;
  final Future<void> Function(AppUser target, UserRole role) onChangeRole;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final initial = user.name.isEmpty ? '?' : user.name[0].toUpperCase();

    // Nobody can change their own role or the super admin's.
    final locked = isMe || user.isSuperAdmin;

    return ListTile(
      leading: CircleAvatar(child: Text(initial)),
      title: Text(isMe ? '${user.name} (you)' : user.name),
      subtitle: Text(user.email),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Chip(
            label: Text(user.role.label),
            visualDensity: VisualDensity.compact,
            backgroundColor: user.isAdmin
                ? theme.colorScheme.primaryContainer
                : null,
          ),
          if (!locked)
            PopupMenuButton<UserRole>(
              tooltip: 'Change role for ${user.name}',
              onSelected: (role) => onChangeRole(user, role),
              itemBuilder: (context) => [
                if (user.isAdmin)
                  const PopupMenuItem(
                    value: UserRole.user,
                    child: Text('Make regular user'),
                  )
                else
                  const PopupMenuItem(
                    value: UserRole.admin,
                    child: Text('Make admin'),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}
