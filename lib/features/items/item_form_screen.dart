import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/utils/snackbars.dart';
import '../../core/utils/validators.dart';
import '../../core/widgets/state_views.dart';
import '../../models/item.dart';
import '../../providers/item_providers.dart';

/// Admin form to create an item, or edit one when [itemId] is given.
class ItemFormScreen extends ConsumerWidget {
  const ItemFormScreen({super.key, this.itemId});

  final String? itemId;

  bool get _isEditing => itemId != null;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final title = Text(_isEditing ? 'Edit item' : 'New item');

    if (!_isEditing) {
      return Scaffold(
        appBar: AppBar(title: title),
        body: const _ItemForm(),
      );
    }

    final existing = ref.watch(itemProvider(itemId!));
    return Scaffold(
      appBar: AppBar(title: title),
      body: existing.when(
        loading: () => const LoadingView(),
        error: (error, _) => ErrorView(
          error: error,
          onRetry: () => ref.invalidate(itemProvider(itemId!)),
        ),
        data: (item) => item == null
            ? const EmptyView(icon: Icons.search_off, title: 'Item not found')
            : _ItemForm(initial: item),
      ),
    );
  }
}

class _ItemForm extends ConsumerStatefulWidget {
  const _ItemForm({this.initial});

  final Item? initial;

  @override
  ConsumerState<_ItemForm> createState() => _ItemFormState();
}

class _ItemFormState extends ConsumerState<_ItemForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late ItemType _type;
  late bool _isActive;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _titleController = TextEditingController(text: initial?.title ?? '');
    _descriptionController = TextEditingController(
      text: initial?.description ?? '',
    );
    _type = initial?.type ?? ItemType.task;
    _isActive = initial?.isActive ?? true;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final controller = ref.read(itemsControllerProvider.notifier);
    final initial = widget.initial;

    final saved = initial == null
        ? await controller.create(
            title: _titleController.text,
            description: _descriptionController.text,
            type: _type,
            isActive: _isActive,
          )
        : await controller.saveChanges(
            initial.copyWith(
              title: _titleController.text,
              description: _descriptionController.text,
              type: _type,
              isActive: _isActive,
            ),
          );

    if (saved && mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(itemsControllerProvider, (_, next) {
      if (next is AsyncError) showErrorSnackBar(context, next.error);
    });
    final isSaving = ref.watch(itemsControllerProvider).isLoading;

    return SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    controller: _titleController,
                    textCapitalization: TextCapitalization.sentences,
                    textInputAction: TextInputAction.next,
                    validator: Validators.itemTitle,
                    decoration: const InputDecoration(
                      labelText: 'Title',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _descriptionController,
                    textCapitalization: TextCapitalization.sentences,
                    minLines: 3,
                    maxLines: 6,
                    validator: Validators.itemDescription,
                    decoration: const InputDecoration(
                      labelText: 'Description',
                      alignLabelWithHint: true,
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text('Type', style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 8),
                  SegmentedButton<ItemType>(
                    segments: [
                      for (final type in ItemType.values)
                        ButtonSegment(value: type, label: Text(type.label)),
                    ],
                    selected: {_type},
                    onSelectionChanged: (selection) =>
                        setState(() => _type = selection.first),
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Active'),
                    subtitle: const Text(
                      'Inactive items are hidden from users',
                    ),
                    value: _isActive,
                    onChanged: (value) => setState(() => _isActive = value),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: isSaving ? null : _save,
                    child: isSaving
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(widget.initial == null ? 'Create item' : 'Save'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
