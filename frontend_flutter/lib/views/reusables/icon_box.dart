import 'package:flutter/material.dart';

class IconBox extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const IconBox({super.key, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Theme.of(context).colorScheme.outline.withOpacity(0.1),
            width: 1,
          ),
        ),
        child: Icon(
          icon,
          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
          size: 20,
        ),
      ),
    );
  }
}
