import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../bloc/rail_board_bloc.dart';
import '../widgets/decision_panel.dart';
import '../widgets/header_panel.dart';
import '../widgets/notice_panel.dart';
import '../widgets/timeline_panel.dart';
import '../widgets/upcoming_panel.dart';

class RailBoardPage extends StatelessWidget {
  const RailBoardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFEBEBEB), Color(0xFFF0F0F0)],
          ),
        ),
        child: SafeArea(
          child: BlocBuilder<RailBoardBloc, RailBoardState>(
            builder: (context, state) {
              if (state.status == RailBoardStatus.loading) {
                return const Center(child: CircularProgressIndicator());
              }

              return LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth >= 1120;

                  return Align(
                    alignment: Alignment.topCenter,
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(12),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1200),
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xD6F7F7F7),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0x1A171717)),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x14171717),
                                blurRadius: 80,
                                offset: Offset(0, 24),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              HeaderPanel(state: state),
                              const SizedBox(height: 12),
                              if (state.snapshot.nextService == null)
                                const NoticePanel()
                              else if (isWide)
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      flex: 7,
                                      child: Column(
                                        children: [
                                          DecisionPanel(
                                            snapshot: state.snapshot,
                                          ),
                                          const SizedBox(height: 12),
                                          UpcomingPanel(
                                            snapshot: state.snapshot,
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      flex: 5,
                                      child: Column(
                                        children: [
                                          TimelinePanel(
                                            snapshot: state.snapshot,
                                          ),
                                          const SizedBox(height: 12),
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
                                    const SizedBox(height: 12),
                                    UpcomingPanel(snapshot: state.snapshot),
                                    const SizedBox(height: 12),
                                    TimelinePanel(snapshot: state.snapshot),
                                    const SizedBox(height: 12),
                                    const NoticePanel(),
                                  ],
                                ),
                            ],
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
