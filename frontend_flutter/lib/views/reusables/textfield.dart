import 'package:flutter/material.dart';

class ModernTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final TextInputType? keyboardType;
  final bool isObscured;
  final String? Function(String?)? validator;

  const ModernTextField({
    super.key,
    required this.controller,
    required this.label,
    required this.icon,
    this.keyboardType,
    this.isObscured = false,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.1),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.shadow.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        obscureText: isObscured,
        validator: validator,
        style: TextStyle(
          color: theme.colorScheme.onSurface,
          fontSize: 16,
          letterSpacing: -0.2,
        ),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            fontSize: 14,
            letterSpacing: -0.2,
          ),
          prefixIcon: Container(
            margin: const EdgeInsets.only(left: 16, right: 12),
            child: Icon(
              icon,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              size: 20,
            ),
          ),
          prefixIconConstraints: const BoxConstraints(
            minWidth: 48,
            minHeight: 20,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(
              color: theme.colorScheme.primary.withValues(alpha: 0.5),
              width: 2,
            ),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(
              color: theme.colorScheme.error.withValues(alpha: 0.5),
              width: 2,
            ),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: BorderSide(color: theme.colorScheme.error, width: 2),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 20,
          ),
          filled: true,
          fillColor: Colors.transparent,
        ),
      ),
    );
  }
}
