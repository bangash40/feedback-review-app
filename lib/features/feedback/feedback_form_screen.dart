import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_routes.dart';
import '../../core/utils/snackbars.dart';
import '../../core/utils/validators.dart';
import '../../core/widgets/state_views.dart';
import '../../models/feedback_model.dart';
import '../../models/item.dart';
import '../../providers/feedback_providers.dart';
import '../../providers/item_providers.dart';
import '../items/widgets/item_type_chip.dart';
import 'widgets/star_rating_input.dart';

/// Give feedback on an item, or edit the review the user already left.
class FeedbackFormScreen extends ConsumerWidget {
  const FeedbackFormScreen({super.key, required this.itemId});

  final String itemId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final item = ref.watch(itemProvider(itemId));
    final mine = ref.watch(myFeedbackForItemProvider(itemId));
    final existing = mine.value;

    Widget body;
    if (item.hasError) {
      body = ErrorView(
        error: item.error!,
        onRetry: () => ref.invalidate(itemProvider(itemId)),
      );
    } else if (mine.hasError) {
      body = ErrorView(
        error: mine.error!,
        onRetry: () => ref.invalidate(myFeedbackProvider),
      );
    } else if (!item.hasValue || !mine.hasValue) {
      body = const LoadingView();
    } else if (item.value == null) {
      body = const EmptyView(
        icon: Icons.search_off,
        title: 'Item not found',
        message: 'It may have been removed.',
      );
    } else if (existing == null && !item.value!.isActive) {
      body = const EmptyView(
        icon: Icons.block,
        title: 'Not accepting feedback',
        message: 'This item has been closed for new feedback.',
      );
    } else {
      body = _FeedbackForm(item: item.value!, existing: existing);
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(existing == null ? 'Give feedback' : 'Edit feedback'),
      ),
      body: body,
    );
  }
}

class _FeedbackForm extends ConsumerStatefulWidget {
  const _FeedbackForm({required this.item, required this.existing});

  final Item item;
  final FeedbackModel? existing;

  @override
  ConsumerState<_FeedbackForm> createState() => _FeedbackFormState();
}

class _FeedbackFormState extends ConsumerState<_FeedbackForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _reviewController;
  late final TextEditingController _suggestionController;
  late int _rating;
  bool _showRatingError = false;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _rating = existing?.rating ?? 0;
    _reviewController = TextEditingController(text: existing?.review ?? '');
    _suggestionController = TextEditingController(
      text: existing?.suggestion ?? '',
    );
  }

  @override
  void dispose() {
    _reviewController.dispose();
    _suggestionController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final textsValid = _formKey.currentState!.validate();
    final ratingValid = Validators.rating(_rating) == null;
    setState(() => _showRatingError = !ratingValid);
    if (!textsValid || !ratingValid) return;

    final messenger = ScaffoldMessenger.of(context);
    final saved = await ref
        .read(feedbackControllerProvider.notifier)
        .submit(
          itemId: widget.item.id,
          rating: _rating,
          review: _reviewController.text,
          suggestion: _suggestionController.text,
        );
    if (!saved || !mounted) return;

    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            _isEditing ? 'Feedback updated' : 'Thanks for your feedback!',
          ),
        ),
      );
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppRoutes.home);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(feedbackControllerProvider, (_, next) {
      if (next is AsyncError) showErrorSnackBar(context, next.error);
    });
    final isSaving = ref.watch(feedbackControllerProvider).isLoading;
    final theme = Theme.of(context);

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
                  Row(
                    children: [
                      ItemTypeChip(type: widget.item.type),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          widget.item.title,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  StarRatingInput(
                    value: _rating,
                    errorText: _showRatingError
                        ? Validators.rating(_rating)
                        : null,
                    onChanged: (value) => setState(() {
                      _rating = value;
                      _showRatingError = false;
                    }),
                  ),
                  const SizedBox(height: 24),
                  TextFormField(
                    controller: _reviewController,
                    textCapitalization: TextCapitalization.sentences,
                    minLines: 3,
                    maxLines: 6,
                    maxLength: Validators.maxFeedbackTextLength,
                    validator: Validators.feedbackText,
                    decoration: const InputDecoration(
                      labelText: 'Review (optional)',
                      hintText: 'What did you think?',
                      alignLabelWithHint: true,
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _suggestionController,
                    textCapitalization: TextCapitalization.sentences,
                    minLines: 2,
                    maxLines: 5,
                    maxLength: Validators.maxFeedbackTextLength,
                    validator: Validators.feedbackText,
                    decoration: const InputDecoration(
                      labelText: 'Suggestion (optional)',
                      hintText: 'How could this be better?',
                      alignLabelWithHint: true,
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: isSaving ? null : _submit,
                    child: isSaving
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(_isEditing ? 'Save changes' : 'Submit feedback'),
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
