import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

/// Watches whether the phone has a network connection (Wi-Fi, mobile data,
/// ethernet...) and tells the app when it changes. Anything can listen to
/// [isOnline]; the "Live" badge in the headers does.
///
/// Note: this reports whether the device is *connected* to a network. A
/// Wi-Fi network that has no internet behind it can still read as online.
class ConnectionStatus {
  ConnectionStatus._();
  static final ConnectionStatus instance = ConnectionStatus._();

  final ValueNotifier<bool> isOnline = ValueNotifier<bool>(true);
  StreamSubscription<List<ConnectivityResult>>? _subscription;
  bool _started = false;

  /// Safe to call many times; only the first call does anything.
  void start() {
    if (_started) return;
    _started = true;

    final connectivity = Connectivity();
    connectivity.checkConnectivity().then(_update);
    _subscription = connectivity.onConnectivityChanged.listen(_update);
  }

  void _update(List<ConnectivityResult> results) {
    isOnline.value = results.any((r) => r != ConnectivityResult.none);
  }

  void dispose() {
    _subscription?.cancel();
  }
}
