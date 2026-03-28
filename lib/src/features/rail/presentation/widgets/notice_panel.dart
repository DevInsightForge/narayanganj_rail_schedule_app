import 'package:flutter/material.dart';

import 'panel_shell.dart';
import 'rail_primitives.dart';

class NoticePanel extends StatelessWidget {
  const NoticePanel({super.key});

  @override
  Widget build(BuildContext context) {
    return const PanelShell(
      child: RailStateMessage(
        title: 'Travel note',
        message:
            'Timetable values are approximate and transcribed from source images. Confirm official Bangladesh Railway updates before leaving.',
        icon: Icons.info_outline_rounded,
      ),
    );
  }
}
