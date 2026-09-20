import 'package:flutter/material.dart';

import 'app_exception.dart';

/// Shows [error] as a snackbar, unless [context] belongs to a screen that is
/// covered by another one (stacked screens sharing a controller would
/// otherwise each show the same error).
void showErrorSnackBar(BuildContext context, Object error) {
  if (!(ModalRoute.of(context)?.isCurrent ?? true)) return;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(AppException.from(error).message)));
}
