import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';

import '../../presentation/bloc/rail_board_state.dart';
import '../models/rail_widget_payload.dart';

abstract class WidgetSyncService {
  Future<void> syncBoardState(RailBoardState state, {bool force = false});

  Future<Uri?> getInitialLaunchUri();

  Stream<Uri?> get launchUriStream;

  void dispose();
}

abstract class HomeWidgetPlatformGateway {
  Future<bool?> savePayloadJson(String key, String json);

  Future<bool?> updateProvider(String qualifiedAndroidName);

  Future<Uri?> initiallyLaunchedFromHomeWidget();

  Stream<Uri?> get widgetClicked;
}

class DefaultHomeWidgetPlatformGateway implements HomeWidgetPlatformGateway {
  const DefaultHomeWidgetPlatformGateway();

  @override
  Future<bool?> savePayloadJson(String key, String json) {
    return HomeWidget.saveWidgetData<String>(key, json);
  }

  @override
  Future<bool?> updateProvider(String qualifiedAndroidName) {
    return HomeWidget.updateWidget(qualifiedAndroidName: qualifiedAndroidName);
  }

  @override
  Future<Uri?> initiallyLaunchedFromHomeWidget() {
    return HomeWidget.initiallyLaunchedFromHomeWidget();
  }

  @override
  Stream<Uri?> get widgetClicked => HomeWidget.widgetClicked;
}

class NoOpWidgetSyncService implements WidgetSyncService {
  const NoOpWidgetSyncService();

  @override
  Future<void> syncBoardState(
    RailBoardState state, {
    bool force = false,
  }) async {}

  @override
  Future<Uri?> getInitialLaunchUri() async => null;

  @override
  Stream<Uri?> get launchUriStream => const Stream<Uri?>.empty();

  @override
  void dispose() {}
}

class AndroidWidgetSyncService implements WidgetSyncService {
  AndroidWidgetSyncService({
    HomeWidgetPlatformGateway? gateway,
    DateTime Function()? nowProvider,
    bool? isSupportedPlatform,
  }) : _gateway = gateway ?? const DefaultHomeWidgetPlatformGateway(),
       _nowProvider = nowProvider ?? DateTime.now,
       _isSupportedPlatform =
           isSupportedPlatform ??
           (!kIsWeb && defaultTargetPlatform == TargetPlatform.android);

  static const String compactProviderClass =
      'com.devinsightforge.narayanganjcommuter.RailCompactWidgetProvider';
  static const String expandedProviderClass =
      'com.devinsightforge.narayanganjcommuter.RailExpandedWidgetProvider';

  final HomeWidgetPlatformGateway _gateway;
  final DateTime Function() _nowProvider;
  final bool _isSupportedPlatform;

  RailWidgetPayload? _lastSyncedPayload;
  RailBoardState? _pendingState;
  bool _pendingForce = false;
  bool _isWriting = false;
  bool _isDisposed = false;

  RailWidgetPayload? get lastSyncedPayload => _lastSyncedPayload;

  @override
  Future<void> syncBoardState(
    RailBoardState state, {
    bool force = false,
  }) async {
    if (_isDisposed || !_isSupportedPlatform) {
      return;
    }
    if (state.status != RailBoardStatus.ready) {
      return;
    }

    _pendingState = state;
    _pendingForce = _pendingForce || force;

    if (_isWriting) {
      return;
    }

    _isWriting = true;
    try {
      while (!_isDisposed && _pendingState != null) {
        final nextState = _pendingState!;
        final nextForce = _pendingForce;
        _pendingState = null;
        _pendingForce = false;

        final payload = RailWidgetPayload.fromBoardState(
          nextState,
          now: _nowProvider(),
        );
        if (payload == null) {
          continue;
        }
        if (!nextForce &&
            _lastSyncedPayload != null &&
            payload.hasSameContent(_lastSyncedPayload!)) {
          continue;
        }

        try {
          final saved = await _gateway.savePayloadJson(
            RailWidgetPayload.storageKey,
            payload.toJsonString(),
          );
          if (saved != false) {
            await _gateway.updateProvider(compactProviderClass);
            await _gateway.updateProvider(expandedProviderClass);
            _lastSyncedPayload = payload;
          }
        } catch (_) {}
      }
    } finally {
      _isWriting = false;
    }
  }

  @override
  Future<Uri?> getInitialLaunchUri() async {
    if (_isDisposed || !_isSupportedPlatform) {
      return null;
    }
    try {
      return await _gateway.initiallyLaunchedFromHomeWidget();
    } catch (_) {
      return null;
    }
  }

  @override
  Stream<Uri?> get launchUriStream {
    if (_isDisposed || !_isSupportedPlatform) {
      return const Stream<Uri?>.empty();
    }
    return _gateway.widgetClicked;
  }

  @override
  void dispose() {
    _isDisposed = true;
    _pendingState = null;
  }
}
