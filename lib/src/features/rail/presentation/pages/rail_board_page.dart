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

class RailBoardPage extends StatefulWidget {
  const RailBoardPage({super.key});

  @override
  State<RailBoardPage> createState() => _RailBoardPageState();
}

class _RailBoardPageState extends State<RailBoardPage> {
  final GlobalKey _decisionSectionKey = GlobalKey();

  void _scrollToReportSection() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      final targetContext = _decisionSectionKey.currentContext;
      if (targetContext == null) {
        return;
      }
      final disableAnimations =
          MediaQuery.maybeOf(targetContext)?.disableAnimations ?? false;
      Scrollable.ensureVisible(
        targetContext,
        duration: disableAnimations
            ? Duration.zero
            : const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
      );
    });
  }

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
          child: BlocListener<RailBoardCubit, RailBoardState>(
            listenWhen: (previous, current) =>
                previous.report.feedbackMessage !=
                    current.report.feedbackMessage ||
                previous.report.focusRequestId != current.report.focusRequestId,
            listener: (context, state) {
              if (state.report.focusedTrainNo != null) {
                _scrollToReportSection();
              }
              final message = state.report.feedbackMessage;
              if (message == null || message.isEmpty) {
                return;
              }
              ScaffoldMessenger.of(context)
                ..hideCurrentSnackBar()
                ..showSnackBar(SnackBar(content: Text(message)));
            },
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

                return _ReadyBoardContent(
                  tokens: tokens,
                  decisionSectionKey: _decisionSectionKey,
                );
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
  const _ReadyBoardContent({
    required this.tokens,
    required this.decisionSectionKey,
  });

  final RailBoardTokens tokens;
  final GlobalKey decisionSectionKey;

  @override
  Widget build(BuildContext context) {
    return Align(
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
              _BoardPanels(
                tokens: tokens,
                decisionSectionKey: decisionSectionKey,
              ),
              SizedBox(height: tokens.panelGap),
              const FooterPanel(),
            ],
          ),
        ),
      ),
    );
  }
}

class _BoardPanels extends StatelessWidget {
  const _BoardPanels({required this.tokens, required this.decisionSectionKey});

  final RailBoardTokens tokens;
  final GlobalKey decisionSectionKey;

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
                _DecisionSelector(
                  key: decisionSectionKey,
                  showCommunity: false,
                ),
                SizedBox(height: tokens.panelGap),
                const _UpcomingSelector(),
                SizedBox(height: tokens.panelGap),
                const NoticePanel(),
              ],
            ),
          ),
          SizedBox(width: tokens.panelGap),
          Expanded(flex: 5, child: _WideRightColumn(tokens: tokens)),
        ],
      );
    }

    return Column(
      children: [
        _DecisionSelector(key: decisionSectionKey, showCommunity: true),
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

class _WideRightColumn extends StatelessWidget {
  const _WideRightColumn({required this.tokens});

  final RailBoardTokens tokens;

  @override
  Widget build(BuildContext context) {
    return BlocSelector<RailBoardCubit, RailBoardState, bool>(
      selector: (state) => state.community.featuresEnabled,
      builder: (context, featuresEnabled) {
        return Column(
          children: [
            if (featuresEnabled) ...[
              const _CommunitySelector(),
              SizedBox(height: tokens.panelGap),
            ],
            const _TimelineSelector(),
          ],
        );
      },
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
  const _DecisionSelector({super.key, this.showCommunity = true});

  final bool showCommunity;

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
        showCommunity: showCommunity,
      ),
    );
  }
}

class _CommunitySelector extends StatelessWidget {
  const _CommunitySelector();

  @override
  Widget build(BuildContext context) {
    return BlocSelector<
      RailBoardCubit,
      RailBoardState,
      ({
        RailBoardReportState report,
        RailBoardCommunityState community,
        int? serviceTrainNo,
        bool showReportAction,
      })
    >(
      selector: (state) => (
        report: state.report,
        community: state.community,
        serviceTrainNo: state.view.snapshot.nextService?.trainNo,
        showReportAction:
            !(state.view.snapshot.nextService?.isOverdue == true &&
                state.report.isActionVisible),
      ),
      builder: (context, slice) => CommunityPanel(
        report: slice.report,
        community: slice.community,
        isStandalone: true,
        serviceTrainNo: slice.serviceTrainNo,
        showReportAction: slice.showReportAction,
        onPressed: () => context.read<RailBoardCubit>().submitArrivalReport(),
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
      ({
        RailBoardSnapshot snapshot,
        List<PredictedStopTime> predictedStopTimes,
        RailServiceSnapshot? previewService,
        bool isCollapsed,
        String boardingStationId,
        String destinationStationId,
      })
    >(
      selector: (state) => (
        snapshot: state.view.snapshot,
        predictedStopTimes: state.community.predictedStopTimes,
        previewService: state.view.isPreviewingUpcoming
            ? state.view.activeService
            : null,
        isCollapsed: state.view.isTimelineCollapsed,
        boardingStationId: state.view.selection.boardingStationId,
        destinationStationId: state.view.selection.destinationStationId,
      ),
      builder: (context, slice) => TimelinePanel(
        snapshot: slice.snapshot,
        predictedStopTimes: slice.predictedStopTimes,
        previewService: slice.previewService,
        isCollapsed: slice.isCollapsed,
        boardingStationId: slice.boardingStationId,
        destinationStationId: slice.destinationStationId,
      ),
    );
  }
}

class _UpcomingSelector extends StatelessWidget {
  const _UpcomingSelector();

  @override
  Widget build(BuildContext context) {
    return BlocSelector<
      RailBoardCubit,
      RailBoardState,
      ({
        RailBoardSnapshot snapshot,
        int? previewTrainNo,
        String boardingStationId,
        String destinationStationId,
      })
    >(
      selector: (state) => (
        snapshot: state.view.snapshot,
        previewTrainNo: state.view.previewTrainNo,
        boardingStationId: state.view.selection.boardingStationId,
        destinationStationId: state.view.selection.destinationStationId,
      ),
      builder: (context, slice) => UpcomingPanel(
        snapshot: slice.snapshot,
        previewTrainNo: slice.previewTrainNo,
        boardingStationId: slice.boardingStationId,
        destinationStationId: slice.destinationStationId,
      ),
    );
  }
}
