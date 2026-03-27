import 'package:flutter/material.dart';

import 'panel_palette.dart';
import 'panel_shell.dart';

class NoticePanel extends StatelessWidget {
  const NoticePanel({super.key});

  @override
  Widget build(BuildContext context) {
    final palette = RailPanelPalette.of(Theme.of(context).colorScheme);
    return PanelShell(
      backgroundColor: palette.panelBackground,
      borderColor: palette.panelBorder,
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: palette.noticeIconBackground,
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: Icon(
              Icons.info_outline_rounded,
              size: 18,
              color: palette.noticeIconTint,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Travel note',
                  style: Theme.of(
                    context,
                  ).textTheme.titleMedium?.copyWith(fontSize: 15),
                ),
                const SizedBox(height: 4),
                Text(
                  'Timetable values are approximate and transcribed from source images. Confirm official Bangladesh Railway updates before leaving.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: palette.panelMutedText,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
