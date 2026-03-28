import 'package:flutter/material.dart';

import 'panel_palette.dart';

class PanelShell extends StatelessWidget {
  const PanelShell({
    super.key,
    required this.child,
    this.surface = RailPanelSurface.primary,
    this.padding,
  });

  final Widget child;
  final RailPanelSurface surface;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final tokens = RailBoardTokens.of(context);
    return Container(
      width: double.infinity,
      padding: padding ?? tokens.panelPadding,
      decoration: BoxDecoration(
        color: tokens.surfaceFor(surface),
        borderRadius: BorderRadius.circular(tokens.panelRadius),
        border: Border.all(color: tokens.border),
        boxShadow: [
          BoxShadow(
            color: tokens.shadow,
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: child,
    );
  }
}
