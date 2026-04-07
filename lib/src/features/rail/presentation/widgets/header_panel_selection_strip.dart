import 'package:flutter/material.dart';

import '../../domain/entities/rail_snapshot.dart';
import 'panel_palette.dart';

class HeaderSelectionStrip extends StatelessWidget {
  const HeaderSelectionStrip({
    super.key,
    required this.label,
    required this.options,
    required this.value,
    required this.scrollable,
    required this.onPressed,
  });

  final String label;
  final List<RailSelectableOption> options;
  final String value;
  final bool scrollable;
  final ValueChanged<String> onPressed;

  @override
  Widget build(BuildContext context) {
    final tokens = RailBoardTokens.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelMedium),
        SizedBox(height: tokens.compactGap),
        if (scrollable)
          _ScrollableSelectionRow(
            options: options,
            value: value,
            onPressed: onPressed,
          )
        else
          Wrap(
            spacing: tokens.compactGap,
            runSpacing: tokens.compactGap,
            children: options
                .map(
                  (option) => _SelectionChip(
                    label: option.label,
                    selected: option.value == value,
                    disabled: option.disabled,
                    onPressed: option.disabled
                        ? null
                        : () => onPressed(option.value),
                  ),
                )
                .toList(growable: false),
          ),
      ],
    );
  }
}

class _ScrollableSelectionRow extends StatefulWidget {
  const _ScrollableSelectionRow({
    required this.options,
    required this.value,
    required this.onPressed,
  });

  final List<RailSelectableOption> options;
  final String value;
  final ValueChanged<String> onPressed;

  @override
  State<_ScrollableSelectionRow> createState() =>
      _ScrollableSelectionRowState();
}

class _ScrollableSelectionRowState extends State<_ScrollableSelectionRow> {
  final ScrollController _controller = ScrollController();
  bool _showLeading = false;
  bool _showTrailing = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_syncIndicators);
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncIndicators());
  }

  @override
  void didUpdateWidget(covariant _ScrollableSelectionRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncIndicators());
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_syncIndicators)
      ..dispose();
    super.dispose();
  }

  void _syncIndicators() {
    if (!_controller.hasClients) {
      return;
    }
    final position = _controller.position;
    final showLeading = position.pixels > 2;
    final showTrailing = position.pixels < position.maxScrollExtent - 2;
    if (showLeading == _showLeading && showTrailing == _showTrailing) {
      return;
    }
    setState(() {
      _showLeading = showLeading;
      _showTrailing = showTrailing;
    });
  }

  @override
  Widget build(BuildContext context) {
    final tokens = RailBoardTokens.of(context);
    return Stack(
      children: [
        SingleChildScrollView(
          controller: _controller,
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (var i = 0; i < widget.options.length; i++) ...[
                _SelectionChip(
                  label: widget.options[i].label,
                  selected: widget.options[i].value == widget.value,
                  disabled: widget.options[i].disabled,
                  onPressed: widget.options[i].disabled
                      ? null
                      : () => widget.onPressed(widget.options[i].value),
                ),
                if (i < widget.options.length - 1)
                  SizedBox(width: tokens.compactGap),
              ],
            ],
          ),
        ),
        if (_showLeading)
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            child: IgnorePointer(
              child: _ScrollIndicator(
                alignment: Alignment.centerLeft,
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                icon: Icons.chevron_left_rounded,
              ),
            ),
          ),
        if (_showTrailing)
          Positioned(
            right: 0,
            top: 0,
            bottom: 0,
            child: IgnorePointer(
              child: _ScrollIndicator(
                alignment: Alignment.centerRight,
                begin: Alignment.centerRight,
                end: Alignment.centerLeft,
                icon: Icons.chevron_right_rounded,
              ),
            ),
          ),
      ],
    );
  }
}

class _ScrollIndicator extends StatelessWidget {
  const _ScrollIndicator({
    required this.alignment,
    required this.begin,
    required this.end,
    required this.icon,
  });

  final Alignment alignment;
  final Alignment begin;
  final Alignment end;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final tokens = RailBoardTokens.of(context);
    return Container(
      width: 28,
      alignment: alignment,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: begin,
          end: end,
          colors: [
            tokens.accentSurface,
            tokens.accentSurface.withValues(alpha: 0.2),
          ],
        ),
      ),
      child: Icon(icon, size: 16, color: tokens.textMuted),
    );
  }
}

class _SelectionChip extends StatelessWidget {
  const _SelectionChip({
    required this.label,
    required this.selected,
    required this.disabled,
    this.onPressed,
  });

  final String label;
  final bool selected;
  final bool disabled;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final tokens = RailBoardTokens.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Opacity(
      opacity: disabled ? 0.45 : 1,
      child: FilledButton.tonal(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          foregroundColor: selected
              ? (isDark ? const Color(0xFF171717) : Colors.white)
              : null,
          backgroundColor: selected ? tokens.accent : tokens.primarySurface,
          side: BorderSide(color: selected ? tokens.accent : tokens.border),
          textStyle: Theme.of(context).textTheme.labelMedium,
          minimumSize: const Size(0, 34),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: const VisualDensity(horizontal: -1, vertical: -1),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(tokens.chipRadius),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        ),
        child: Text(label),
      ),
    );
  }
}
