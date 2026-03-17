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
              if (state.status == RailBoardStatus.loading) {
                return const Center(child: CircularProgressIndicator());
              }

              return LayoutBuilder(
                builder: (context, constraints) {
                  final isTablet = constraints.maxWidth >= 760;
                  final shellPadding = isTablet ? 18.0 : 8.0;

                  return Align(
                    alignment: Alignment.topCenter,
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: isTablet ? 920 : 560,
                        ),
                        child: Container(
                          padding: EdgeInsets.all(shellPadding),
                          decoration: BoxDecoration(
                            color: const Color(0xD6F7F7F7),
                            // borderRadius: BorderRadius.circular(28),
                            border: Border.all(color: const Color(0x1A171717)),
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
                                  crossAxisAlignment: CrossAxisAlignment.start,
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
