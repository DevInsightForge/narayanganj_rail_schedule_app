import 'package:flutter/material.dart';

import 'panel_shell.dart';

class NoticePanel extends StatelessWidget {
  const NoticePanel({super.key});

  @override
  Widget build(BuildContext context) {
    return PanelShell(
      backgroundColor: const Color(0xB8F0F0F0),
      borderColor: const Color(0x2E171717),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: const BoxDecoration(
              color: Color(0x14171717),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text('i', style: Theme.of(context).textTheme.titleMedium),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Travel note',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  'Timetable values are approximate and transcribed from source images. Confirm official Bangladesh Railway updates before leaving.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFF5E5E5E),
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
