import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../bloc/rail_board_cubit.dart';
import 'header_panel_hero.dart';
import 'header_panel_selection_strip.dart';
import 'panel_palette.dart';
import 'panel_shell.dart';
import 'rail_board_texts.dart';

class HeaderPanel extends StatelessWidget {
  const HeaderPanel({super.key, required this.view});

  final RailBoardViewState view;

  @override
  Widget build(BuildContext context) {
    final tokens = RailBoardTokens.of(context);

    return PanelShell(
      surface: RailPanelSurface.accent,
      padding: tokens.panelPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          HeaderPanelHero(view: view),
          SizedBox(height: tokens.sectionGap),
          HeaderSelectionStrip(
            label: RailBoardTexts.routeDirectionLabel,
            options: view.directionOptions,
            value: view.selection.direction,
            scrollable: false,
            onPressed: (value) =>
                context.read<RailBoardCubit>().changeDirection(value),
          ),
          SizedBox(height: tokens.itemGap),
          HeaderSelectionStrip(
            label: RailBoardTexts.boardFromLabel,
            options: view.boardingStations,
            value: view.selection.boardingStationId,
            scrollable: true,
            onPressed: (value) =>
                context.read<RailBoardCubit>().changeBoarding(value),
          ),
          SizedBox(height: tokens.itemGap),
          HeaderSelectionStrip(
            label: RailBoardTexts.goToLabel,
            options: view.destinationStations,
            value: view.selection.destinationStationId,
            scrollable: true,
            onPressed: (value) =>
                context.read<RailBoardCubit>().changeDestination(value),
          ),
        ],
      ),
    );
  }
}
