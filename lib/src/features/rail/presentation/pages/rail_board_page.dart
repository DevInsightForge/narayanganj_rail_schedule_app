import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

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
    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFEBEBEB), Color(0xFFF0F0F0)],
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x14171717),
              blurRadius: 120,
              offset: Offset(0, 40),
            ),
          ],
        ),
        child: SafeArea(
          child: BlocBuilder<RailBoardBloc, RailBoardState>(
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

              return LayoutBuilder(
                builder: (context, constraints) {
                  final isTablet = constraints.maxWidth >= _tabletBreakpoint;
                  final shellPadding = isTablet ? 18.0 : 8.0;
                  final boardService = context
                      .read<RailBoardBloc>()
                      .boardService;

                  return RepositoryProvider.value(
                    value: boardService,
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: SingleChildScrollView(
                        physics: const ClampingScrollPhysics(),
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth: isTablet ? 920 : 560,
                          ),
                          child: Container(
                            padding: EdgeInsets.all(shellPadding),
                            decoration: BoxDecoration(
                              color: const Color(0xD6F7F7F7),
                              border: Border.all(
                                color: const Color(0x1A171717),
                              ),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x14171717),
                                  blurRadius: 64,
                                  offset: Offset(0, 20),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                HeaderPanel(state: state),
                                SizedBox(height: isTablet ? 16 : 14),
                                if (state.snapshot.nextService == null)
                                  const NoticePanel()
                                else if (isTablet)
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        flex: 6,
                                        child: Column(
                                          children: [
                                            DecisionPanel(
                                              snapshot: state.snapshot,
                                            ),
                                            const SizedBox(height: 14),
                                            UpcomingPanel(
                                              snapshot: state.snapshot,
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        flex: 4,
                                        child: Column(
                                          children: [
                                            TimelinePanel(
                                              snapshot: state.snapshot,
                                            ),
                                            const SizedBox(height: 14),
                                            const NoticePanel(),
                                          ],
                                        ),
                                      ),
                                    ],
                                  )
                                else
                                  Column(
                                    children: [
                                      DecisionPanel(snapshot: state.snapshot),
                                      const SizedBox(height: 14),
                                      TimelinePanel(snapshot: state.snapshot),
                                      const SizedBox(height: 14),
                                      UpcomingPanel(snapshot: state.snapshot),
                                      const SizedBox(height: 14),
                                      const NoticePanel(),
                                    ],
                                  ),
                                const SizedBox(height: 14),
                                FooterPanel(
                                  dataSourceLabel:
                                      state.snapshot.dataSourceLabel,
                                  lastUpdatedAt: state.snapshot.lastUpdatedAt,
                                  scheduleVersion:
                                      state.snapshot.scheduleVersion,
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
            },
          ),
        ),
      ),
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
