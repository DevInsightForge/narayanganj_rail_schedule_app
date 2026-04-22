import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../community/domain/entities/predicted_stop_time.dart';
import '../../domain/entities/rail_snapshot.dart';
import '../bloc/rail_board_cubit.dart';
import '../widgets/decision_panel.dart';
import '../widgets/footer_panel.dart';
import '../widgets/header_panel.dart';
import '../widgets/notice_panel.dart';
import '../widgets/panel_palette.dart';
import '../widgets/rail_primitives.dart';
import '../widgets/rail_board_texts.dart';
import '../widgets/timeline_panel.dart';
import '../widgets/upcoming_panel.dart';

class RailBoardPage extends StatelessWidget {
  const RailBoardPage({super.key});

  @override
  Widget build(BuildContext context) {
    final tokens = RailBoardTokens.of(context);

    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [tokens.boardStart, tokens.boardEnd],
          ),
        ),
        child: SafeArea(
          child: MultiBlocListener(
            listeners: [
              BlocListener<RailBoardCubit, RailBoardState>(
                listenWhen: (previous, current) =>
                    previous.report.feedbackMessage !=
                    current.report.feedbackMessage,
                listener: (context, state) {
                  final message = state.report.feedbackMessage;
                  if (message == null || message.isEmpty) {
                    return;
                  }
                  ScaffoldMessenger.of(context)
                    ..hideCurrentSnackBar()
                    ..showSnackBar(SnackBar(content: Text(message)));
                },
              ),
            ],
            child: BlocBuilder<RailBoardCubit, RailBoardState>(
              buildWhen: (previous, current) =>
                  previous.status != current.status ||
                  previous.errorMessage != current.errorMessage,
              builder: (context, state) {
                if (state.isLoading) {
                  return _BoardScaffold(
                    child: const RailStateMessage(
                      title: RailBoardTexts.loadingBoardTitle,
                      message: RailBoardTexts.loadingBoardMessage,
                      icon: Icons.train_rounded,
                    ),
                  );
                }

                if (state.hasFailed) {
                  return _BoardScaffold(
                    child: RailStateMessage(
                      title: RailBoardTexts.boardUnavailableTitle,
                      message:
                          state.errorMessage ??
                          RailBoardTexts.boardUnavailableMessage,
                      icon: Icons
                          .signal_wifi_statusbar_connected_no_internet_4_rounded,
                      action: FilledButton.icon(
                        onPressed: () => context.read<RailBoardCubit>().retry(),
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text(RailBoardTexts.retryAction),
                      ),
                    ),
                  );
                }

                return _ReadyBoardContent(tokens: tokens);
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _BoardScaffold extends StatelessWidget {
  const _BoardScaffold({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final tokens = RailBoardTokens.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: tokens.pagePadding,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: tokens.maxContentWidth),
          child: child,
        ),
      ),
    );
  }
}

class _ReadyBoardContent extends StatelessWidget {
  const _ReadyBoardContent({required this.tokens});

  final RailBoardTokens tokens;

  @override
  Widget build(BuildContext context) {
    final boardService = context.read<RailBoardCubit>().boardService;

    return RepositoryProvider.value(
      value: boardService,
      child: Align(
        alignment: Alignment.topCenter,
        child: SingleChildScrollView(
          padding: tokens.pagePadding,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: tokens.maxContentWidth),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _HeaderSelector(),
                SizedBox(height: tokens.panelGap),
                _BoardPanels(tokens: tokens),
                SizedBox(height: tokens.panelGap),
                const _FooterSelector(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BoardPanels extends StatelessWidget {
  const _BoardPanels({required this.tokens});

  final RailBoardTokens tokens;

  @override
  Widget build(BuildContext context) {
    if (tokens.isWide) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 6,
            child: Column(
              children: [
                const _DecisionSelector(),
                SizedBox(height: tokens.panelGap),
                const _TimelineSelector(),
              ],
            ),
          ),
          SizedBox(width: tokens.panelGap),
          Expanded(
            flex: 4,
            child: Column(
              children: [
                const _UpcomingSelector(),
                SizedBox(height: tokens.panelGap),
                const NoticePanel(),
              ],
            ),
          ),
        ],
      );
    }

    return Column(
      children: [
        const _DecisionSelector(),
        SizedBox(height: tokens.panelGap),
        const _TimelineSelector(),
        SizedBox(height: tokens.panelGap),
        const _UpcomingSelector(),
        SizedBox(height: tokens.panelGap),
        const NoticePanel(),
      ],
    );
  }
}

class _HeaderSelector extends StatelessWidget {
  const _HeaderSelector();

  @override
  Widget build(BuildContext context) {
    return BlocSelector<RailBoardCubit, RailBoardState, RailBoardViewState>(
      selector: (state) => state.view,
      builder: (context, view) => HeaderPanel(view: view),
    );
  }
}

class _DecisionSelector extends StatelessWidget {
  const _DecisionSelector();

  @override
  Widget build(BuildContext context) {
    return BlocSelector<
      RailBoardCubit,
      RailBoardState,
      ({
        RailBoardViewState view,
        RailBoardReportState report,
        RailBoardCommunityState community,
      })
    >(
      selector: (state) =>
          (view: state.view, report: state.report, community: state.community),
      builder: (context, slice) => DecisionPanel(
        view: slice.view,
        report: slice.report,
        community: slice.community,
      ),
    );
  }
}

class _TimelineSelector extends StatelessWidget {
  const _TimelineSelector();

  @override
  Widget build(BuildContext context) {
    return BlocSelector<
      RailBoardCubit,
      RailBoardState,
      ({RailBoardSnapshot snapshot, List<PredictedStopTime> predictedStopTimes})
    >(
      selector: (state) => (
        snapshot: state.view.snapshot,
        predictedStopTimes: state.community.predictedStopTimes,
      ),
      builder: (context, slice) => TimelinePanel(
        snapshot: slice.snapshot,
        predictedStopTimes: slice.predictedStopTimes,
      ),
    );
  }
}

class _UpcomingSelector extends StatelessWidget {
  const _UpcomingSelector();

  @override
  Widget build(BuildContext context) {
    return BlocSelector<RailBoardCubit, RailBoardState, RailBoardViewState>(
      selector: (state) => state.view,
      builder: (context, view) => UpcomingPanel(snapshot: view.snapshot),
    );
  }
}

class _FooterSelector extends StatelessWidget {
  const _FooterSelector();

  @override
  Widget build(BuildContext context) {
    return BlocSelector<
      RailBoardCubit,
      RailBoardState,
      ({
        String dataSourceLabel,
        DateTime? lastUpdatedAt,
        String scheduleVersion,
      })
    >(
      selector: (state) => (
        dataSourceLabel: state.view.snapshot.dataSourceLabel,
        lastUpdatedAt: state.view.snapshot.lastUpdatedAt,
        scheduleVersion: state.view.snapshot.scheduleVersion,
      ),
      builder: (context, slice) => FooterPanel(
        dataSourceLabel: slice.dataSourceLabel,
        lastUpdatedAt: slice.lastUpdatedAt,
        scheduleVersion: slice.scheduleVersion,
      ),
    );
  }
}
