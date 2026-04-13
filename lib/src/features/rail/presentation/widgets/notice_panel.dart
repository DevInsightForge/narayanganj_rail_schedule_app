import 'package:flutter/material.dart';

import 'panel_shell.dart';
import 'rail_board_texts.dart';
import 'rail_primitives.dart';

class NoticePanel extends StatelessWidget {
  const NoticePanel({super.key});

  @override
  Widget build(BuildContext context) {
    return const PanelShell(
      child: RailStateMessage(
        title: RailBoardTexts.noticeTitle,
        message: RailBoardTexts.noticeMessage,
        icon: Icons.info_outline_rounded,
        compact: true,
      ),
    );
  }
}
