import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/snackbars.dart';
import '../../core/utils/validators.dart';
import '../../core/widgets/state_views.dart';
import '../../models/app_user.dart';
import '../../providers/auth_providers.dart';

/// View and edit the signed-in user's display name; see their role.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: user.when(
        loading: () => const LoadingView(),
        error: (error, _) => ErrorView(
          error: error,
          onRetry: () => ref.invalidate(currentUserProvider),
        ),
        data: (user) => user == null
            ? const EmptyView(
                icon: Icons.person_off_outlined,
                title: 'Profile not found',
                message: 'Try logging out and back in.',
              )
            : _ProfileForm(user: user),
      ),
    );
  }
}

class _ProfileForm extends ConsumerStatefulWidget {
  const _ProfileForm({required this.user});

  final AppUser user;

  @override
  ConsumerState<_ProfileForm> createState() => _ProfileFormState();
}

class _ProfileFormState extends ConsumerState<_ProfileForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.user.name);
  }

  @override
  void didUpdateWidget(_ProfileForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A save from elsewhere (or another device) should be reflected here too,
    // but not while the user is mid-edit with unsaved changes of their own.
    final saving = ref.read(profileControllerProvider).isLoading;
    if (!saving && _nameController.text == oldWidget.user.name) {
      _nameController.text = widget.user.name;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  bool get _hasChanges => _nameController.text.trim() != widget.user.name;

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final messenger = ScaffoldMessenger.of(context);
    final saved = await ref
        .read(profileControllerProvider.notifier)
        .updateName(_nameController.text);
    if (saved && mounted) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('Profile updated')));
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(profileControllerProvider, (_, next) {
      if (next is AsyncError) showErrorSnackBar(context, next.error);
    });
    final isSaving = ref.watch(profileControllerProvider).isLoading;
    final theme = Theme.of(context);

    return SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: CircleAvatar(
                    radius: 36,
                    child: Text(
                      widget.user.name.isEmpty
                          ? '?'
                          : widget.user.name[0].toUpperCase(),
                      style: theme.textTheme.headlineMedium,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Form(
                  key: _formKey,
                  onChanged: () => setState(() {}),
                  child: TextFormField(
                    controller: _nameController,
                    textCapitalization: TextCapitalization.words,
                    validator: Validators.name,
                    decoration: const InputDecoration(
                      labelText: 'Display name',
                      prefixIcon: Icon(Icons.person_outline),
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.email_outlined),
                  title: const Text('Email'),
                  subtitle: Text(widget.user.email),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.shield_outlined),
                  title: const Text('Role'),
                  subtitle: Text(widget.user.role.label),
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: (isSaving || !_hasChanges) ? null : _save,
                  child: isSaving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Save changes'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
