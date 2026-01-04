import 'package:flutter/material.dart';

class SnackbarHelper {
  static void show(
    BuildContext context,
    String message, {
    bool isError = true,
  }) {
    final theme = Theme.of(context);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Text(message, style: const TextStyle(fontSize: 16)),
        backgroundColor: isError
            ? theme.colorScheme.error
            : theme.colorScheme.primary,
        duration: const Duration(seconds: 2),
      ),
    );
  }
}
