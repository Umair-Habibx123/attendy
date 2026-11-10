// lib/data/connectivity_service.dart (same approach as News App and FireStream)

import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

/// Tracks *real* internet reachability — not just whether a network interface
/// exists.
///
/// `connectivity_plus` only tells us if the device is attached to Wi-Fi/mobile,
/// which is often true while there is no actual internet (captive portals,
/// "connected, no internet", DNS down). To know if requests will really
/// succeed we probe a lightweight endpoint that returns an empty `204 No
/// Content` response:
///
///   https://www.gstatic.com/generate_204
///
/// This is the same trick Android itself uses for its connectivity check. The
/// body is empty so the probe is fast and cheap, and a 204 is an unambiguous
/// "you reached the internet" signal.
class ConnectivityService with ChangeNotifier {
  static const String _probeUrl = 'https://www.gstatic.com/generate_204';
  static const Duration _probeTimeout = Duration(seconds: 5);
  static const Duration _probeInterval = Duration(seconds: 15);

  bool _hasInternet = true;
  bool _isChecking = true;

  StreamSubscription? _subscription;
  Timer? _pollTimer;
  final http.Client _client = http.Client();

  bool get hasInternet => _hasInternet;
  bool get isChecking => _isChecking;

  ConnectivityService() {
    _init();
  }

  Future<void> _init() async {
    await _verifyConnection();
    // Re-probe whenever the OS reports a network change…
    _subscription =
        Connectivity().onConnectivityChanged.listen((results) {
      if (results.contains(ConnectivityResult.none)) {
        _setStatus(false);
      } else {
        _verifyConnection(silent: true);
      }
    });
    // …and on a steady interval to catch captive portals / silent drops.
    _pollTimer = Timer.periodic(
        _probeInterval, (_) => _verifyConnection(silent: true));
  }

  /// Performs the actual reachability probe and updates [hasInternet].
  ///
  /// When [silent] is true (background polls / OS change events) we only notify
  /// listeners if the online status actually flips, avoiding needless rebuilds
  /// of the whole app every interval. User-initiated checks (initial load,
  /// Retry button) surface the [isChecking] spinner.
  Future<void> _verifyConnection({bool silent = false}) async {
    if (!silent) {
      _isChecking = true;
      notifyListeners();
    }

    bool reachable;
    try {
      // Skip the network call entirely if there's no interface at all.
      final conn = await Connectivity().checkConnectivity();
      if (conn.contains(ConnectivityResult.none)) {
        reachable = false;
      } else {
        final response =
            await _client.get(Uri.parse(_probeUrl)).timeout(_probeTimeout);
        // gstatic returns 204; accept any 2xx as "online".
        reachable = response.statusCode >= 200 && response.statusCode < 300;
      }
    } catch (_) {
      reachable = false;
    }

    _isChecking = false;
    _setStatus(reachable, forceNotify: !silent);
  }

  void _setStatus(bool value, {bool forceNotify = false}) {
    if (value != _hasInternet || forceNotify) {
      _hasInternet = value;
      notifyListeners();
    }
  }

  /// Triggered by the "Retry" button on the no-internet screen.
  Future<void> retryConnection() => _verifyConnection();

  @override
  void dispose() {
    _subscription?.cancel();
    _pollTimer?.cancel();
    _client.close();
    super.dispose();
  }
}
