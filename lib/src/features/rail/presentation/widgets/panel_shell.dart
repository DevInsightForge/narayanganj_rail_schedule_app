import 'package:flutter/material.dart';

class PanelShell extends StatelessWidget {
  const PanelShell({
    super.key,
    required this.child,
    required this.backgroundColor,
    required this.borderColor,
    this.padding = const EdgeInsets.all(12),
  });

  final Widget child;
  final Color backgroundColor;
  final Color borderColor;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withValues(alpha: 0.08),
            blurRadius: 36,
            offset: Offset(0, 14),
          ),
        ],
      ),
      child: child,
    );
  }
}
