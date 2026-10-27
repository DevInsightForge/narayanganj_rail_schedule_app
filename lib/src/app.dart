import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/services.dart';

import 'bootstrap/app_composition.dart';
import 'core/theme/app_theme.dart';
import 'features/rail/application/services/widget_sync_service.dart';
import 'features/rail/presentation/bloc/rail_board_cubit.dart';
import 'features/rail/presentation/pages/rail_board_page.dart';

class NarayanganjRailScheduleApp extends StatelessWidget {
  const NarayanganjRailScheduleApp({super.key, required this.composition});

  final AppComposition composition;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<RailBoardCubit>(
      create: (_) => composition.createRailBoardCubit(),
      child: _WidgetLifecycleCoordinator(
        widgetSyncService: composition.widgetSyncService,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          themeMode: ThemeMode.system,
          builder: (context, child) {
            final isDark = Theme.of(context).brightness == Brightness.dark;
            SystemChrome.setSystemUIOverlayStyle(
              SystemUiOverlayStyle(
                statusBarColor: Colors.transparent,
                statusBarIconBrightness: isDark
                    ? Brightness.light
                    : Brightness.dark,
                statusBarBrightness: isDark
                    ? Brightness.dark
                    : Brightness.light,
                systemStatusBarContrastEnforced: false,
                systemNavigationBarColor: Colors.transparent,
                systemNavigationBarDividerColor: Colors.transparent,
                systemNavigationBarIconBrightness: isDark
                    ? Brightness.light
                    : Brightness.dark,
                systemNavigationBarContrastEnforced: false,
              ),
            );
            final mediaQuery = MediaQuery.of(context);
            final clampedScaler = mediaQuery.textScaler.clamp(
              minScaleFactor: 0.85,
              maxScaleFactor: 1.35,
            );
            return MediaQuery(
              data: mediaQuery.copyWith(textScaler: clampedScaler),
              child: child ?? const SizedBox.shrink(),
            );
          },
          home: const RailBoardPage(),
        ),
      ),
    );
  }
}

class _WidgetLifecycleCoordinator extends StatefulWidget {
  const _WidgetLifecycleCoordinator({
    required this.widgetSyncService,
    required this.child,
  });

  final WidgetSyncService widgetSyncService;
  final Widget child;

  @override
  State<_WidgetLifecycleCoordinator> createState() =>
      _WidgetLifecycleCoordinatorState();
}

class _WidgetLifecycleCoordinatorState
    extends State<_WidgetLifecycleCoordinator>
    with WidgetsBindingObserver {
  StreamSubscription<Uri?>? _uriSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final cubit = context.read<RailBoardCubit>();
    _uriSubscription = widget.widgetSyncService.launchUriStream.listen(
      cubit.handleWidgetLaunchUri,
    );
    unawaited(
      widget.widgetSyncService.getInitialLaunchUri().then(
        cubit.handleWidgetLaunchUri,
      ),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final cubit = context.read<RailBoardCubit>();
    if (state == AppLifecycleState.resumed) {
      unawaited(cubit.tick());
      unawaited(cubit.syncWidgets(force: true));
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      unawaited(cubit.syncWidgets(force: true));
    }
  }

  @override
  void dispose() {
    unawaited(_uriSubscription?.cancel());
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
