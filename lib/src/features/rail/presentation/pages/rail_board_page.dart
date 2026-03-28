import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../community/domain/entities/predicted_stop_time.dart';
import '../../domain/entities/rail_snapshot.dart';
import '../bloc/rail_board_bloc.dart';
import '../widgets/decision_panel.dart';
import '../widgets/footer_panel.dart';
import '../widgets/header_panel.dart';
import '../widgets/notice_panel.dart';
import '../widgets/panel_palette.dart';
import '../widgets/rail_primitives.dart';
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
              BlocListener<RailBoardBloc, RailBoardState>(
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
            child: BlocBuilder<RailBoardBloc, RailBoardState>(
              buildWhen: (previous, current) =>
                  previous.status != current.status ||
                  previous.errorMessage != current.errorMessage,
              builder: (context, state) {
                if (state.isLoading) {
                  return _BoardScaffold(
                    child: const RailStateMessage(
                      title: 'Preparing your commuter board',
                      message:
                          'Loading your saved route, schedule source, and live community status.',
                      icon: Icons.train_rounded,
                    ),
                  );
                }

                if (state.hasFailed) {
                  return _BoardScaffold(
                    child: RailStateMessage(
                      title: 'Rail board unavailable',
                      message:
                          state.errorMessage ??
                          'Please check your connection and try again.',
                      icon: Icons
                          .signal_wifi_statusbar_connected_no_internet_4_rounded,
                      action: FilledButton.icon(
                        onPressed: () => context.read<RailBoardBloc>().add(
                          const RailBoardRetryRequested(),
                        ),
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('Retry'),
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
    final boardService = context.read<RailBoardBloc>().boardService;

    return RepositoryProvider.value(
      value: boardService,
      child: Align(
        alignment: Alignment.topCenter,
        child: SingleChildScrollView(
          padding: tokens.pagePadding,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: tokens.maxContentWidth),
            child: Container(
              padding: tokens.pagePadding,
              decoration: BoxDecoration(
                color: tokens.shellSurface,
                borderRadius: BorderRadius.circular(tokens.heroRadius),
                border: Border.all(color: tokens.border),
                boxShadow: [
                  BoxShadow(
                    color: tokens.shadow,
                    blurRadius: 48,
                    offset: const Offset(0, 24),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  BlocSelector<
                    RailBoardBloc,
                    RailBoardState,
                    RailBoardViewState
                  >(
                    selector: (state) => state.view,
                    builder: (context, view) => HeaderPanel(view: view),
                  ),
                  SizedBox(height: tokens.panelGap),
                  if (tokens.isWide)
                    _WideBoard(tokens: tokens)
                  else
                    _CompactBoard(tokens: tokens),
                  SizedBox(height: tokens.panelGap),
                  BlocSelector<
                    RailBoardBloc,
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
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _WideBoard extends StatelessWidget {
  const _WideBoard({required this.tokens});

  final RailBoardTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 6,
          child: Column(
            children: [
              BlocSelector<
                RailBoardBloc,
                RailBoardState,
                ({
                  RailBoardViewState view,
                  RailBoardReportState report,
                  RailBoardCommunityState community,
                })
              >(
                selector: (state) => (
                  view: state.view,
                  report: state.report,
                  community: state.community,
                ),
                builder: (context, slice) => DecisionPanel(
                  view: slice.view,
                  report: slice.report,
                  community: slice.community,
                ),
              ),
              SizedBox(height: tokens.panelGap),
              BlocSelector<
                RailBoardBloc,
                RailBoardState,
                ({
                  RailBoardSnapshot snapshot,
                  List<PredictedStopTime> predictedStopTimes,
                })
              >(
                selector: (state) => (
                  snapshot: state.view.snapshot,
                  predictedStopTimes: state.community.predictedStopTimes,
                ),
                builder: (context, slice) => TimelinePanel(
                  snapshot: slice.snapshot,
                  predictedStopTimes: slice.predictedStopTimes,
                ),
              ),
            ],
          ),
        ),
        SizedBox(width: tokens.panelGap),
        Expanded(
          flex: 4,
          child: Column(
            children: [
              BlocSelector<RailBoardBloc, RailBoardState, RailBoardViewState>(
                selector: (state) => state.view,
                builder: (context, view) =>
                    UpcomingPanel(snapshot: view.snapshot),
              ),
              SizedBox(height: tokens.panelGap),
              const NoticePanel(),
            ],
          ),
        ),
      ],
    );
  }
}

class _CompactBoard extends StatelessWidget {
  const _CompactBoard({required this.tokens});

  final RailBoardTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        BlocSelector<
          RailBoardBloc,
          RailBoardState,
          ({
            RailBoardViewState view,
            RailBoardReportState report,
            RailBoardCommunityState community,
          })
        >(
          selector: (state) => (
            view: state.view,
            report: state.report,
            community: state.community,
          ),
          builder: (context, slice) => DecisionPanel(
            view: slice.view,
            report: slice.report,
            community: slice.community,
          ),
        ),
        SizedBox(height: tokens.panelGap),
        BlocSelector<
          RailBoardBloc,
          RailBoardState,
          ({
            RailBoardSnapshot snapshot,
            List<PredictedStopTime> predictedStopTimes,
          })
        >(
          selector: (state) => (
            snapshot: state.view.snapshot,
            predictedStopTimes: state.community.predictedStopTimes,
          ),
          builder: (context, slice) => TimelinePanel(
            snapshot: slice.snapshot,
            predictedStopTimes: slice.predictedStopTimes,
          ),
        ),
        SizedBox(height: tokens.panelGap),
        BlocSelector<RailBoardBloc, RailBoardState, RailBoardViewState>(
          selector: (state) => state.view,
          builder: (context, view) => UpcomingPanel(snapshot: view.snapshot),
        ),
        SizedBox(height: tokens.panelGap),
        const NoticePanel(),
      ],
    );
  }
}
