import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/services.dart';

import '../../../community/domain/entities/predicted_stop_time.dart';
import '../../domain/entities/rail_snapshot.dart';
import '../bloc/rail_board_bloc.dart';
import '../widgets/decision_panel.dart';
import '../widgets/footer_panel.dart';
import '../widgets/header_panel.dart';
import '../widgets/notice_panel.dart';
import '../widgets/timeline_panel.dart';
import '../widgets/upcoming_panel.dart';

class RailBoardPage extends StatelessWidget {
  const RailBoardPage({super.key});

  static const _tabletBreakpoint = 760.0;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = colorScheme.brightness == Brightness.dark;
    final overlayStyle = SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarDividerColor: Colors.transparent,
      systemNavigationBarIconBrightness: isDark
          ? Brightness.light
          : Brightness.dark,
      systemStatusBarContrastEnforced: false,
      systemNavigationBarContrastEnforced: false,
    );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: overlayStyle,
      child: Scaffold(
        body: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [colorScheme.surface, colorScheme.surfaceContainerLow],
            ),
            boxShadow: [
              BoxShadow(
                color: colorScheme.shadow.withValues(alpha: 0.08),
                blurRadius: 120,
                offset: const Offset(0, 40),
              ),
            ],
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
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (state.hasFailed) {
                    return _FailureView(
                      message: state.errorMessage,
                      onRetry: () => context.read<RailBoardBloc>().add(
                        const RailBoardRetryRequested(),
                      ),
                    );
                  }

                  return _ReadyBoardContent(
                    tabletBreakpoint: _tabletBreakpoint,
                    colorScheme: colorScheme,
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ReadyBoardContent extends StatelessWidget {
  const _ReadyBoardContent({
    required this.tabletBreakpoint,
    required this.colorScheme,
  });

  final double tabletBreakpoint;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    final boardService = context.read<RailBoardBloc>().boardService;
    return LayoutBuilder(
      builder: (context, constraints) {
        final isTablet = constraints.maxWidth >= tabletBreakpoint;
        final shellPadding = isTablet ? 18.0 : 8.0;
        return RepositoryProvider.value(
          value: boardService,
          child: Align(
            alignment: Alignment.topCenter,
            child: SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: isTablet ? 920 : 560),
                child: Container(
                  padding: EdgeInsets.all(shellPadding),
                  decoration: BoxDecoration(
                    color: colorScheme.surface.withValues(
                      alpha: colorScheme.brightness == Brightness.dark
                          ? 0.9
                          : 0.86,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: colorScheme.shadow.withValues(alpha: 0.08),
                        blurRadius: 64,
                        offset: const Offset(0, 20),
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
                      SizedBox(height: isTablet ? 16 : 14),
                      BlocSelector<
                        RailBoardBloc,
                        RailBoardState,
                        RailBoardViewState
                      >(
                        selector: (state) => state.view,
                        builder: (context, view) {
                          if (view.snapshot.nextService == null) {
                            return const NoticePanel();
                          }
                          if (isTablet) {
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
                                        builder: (context, slice) =>
                                            DecisionPanel(
                                              view: slice.view,
                                              report: slice.report,
                                              community: slice.community,
                                            ),
                                      ),
                                      const SizedBox(height: 14),
                                      UpcomingPanel(snapshot: view.snapshot),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  flex: 4,
                                  child: Column(
                                    children: [
                                      BlocSelector<
                                        RailBoardBloc,
                                        RailBoardState,
                                        ({
                                          RailBoardSnapshot snapshot,
                                          List<PredictedStopTime>
                                          predictedStopTimes,
                                        })
                                      >(
                                        selector: (state) => (
                                          snapshot: state.view.snapshot,
                                          predictedStopTimes: state
                                              .community
                                              .predictedStopTimes,
                                        ),
                                        builder: (context, slice) =>
                                            TimelinePanel(
                                              snapshot: slice.snapshot,
                                              predictedStopTimes:
                                                  slice.predictedStopTimes,
                                            ),
                                      ),
                                      const SizedBox(height: 14),
                                      const NoticePanel(),
                                    ],
                                  ),
                                ),
                              ],
                            );
                          }
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
                              const SizedBox(height: 14),
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
                                  predictedStopTimes:
                                      state.community.predictedStopTimes,
                                ),
                                builder: (context, slice) => TimelinePanel(
                                  snapshot: slice.snapshot,
                                  predictedStopTimes: slice.predictedStopTimes,
                                ),
                              ),
                              const SizedBox(height: 14),
                              UpcomingPanel(snapshot: view.snapshot),
                              const SizedBox(height: 14),
                              const NoticePanel(),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 14),
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
      },
    );
  }
}

class _FailureView extends StatelessWidget {
  const _FailureView({required this.onRetry, this.message});

  final VoidCallback onRetry;
  final String? message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'We could not load your rail board.',
                    style: Theme.of(context).textTheme.titleMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    message ?? 'Please check your connection and retry.',
                    style: Theme.of(context).textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
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
