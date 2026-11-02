import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Emits whether the device has a network connection. Overridden in tests.
final connectivityStreamProvider = Provider<Stream<bool>>((ref) {
  final connectivity = Connectivity();
  bool online(List<ConnectivityResult> results) =>
      results.any((r) => r != ConnectivityResult.none);
  return Stream<bool>.multi((controller) async {
    try {
      controller.add(online(await connectivity.checkConnectivity()));
    } catch (_) {
      controller.add(true); // unknown: don't claim to be offline
    }
    final sub = connectivity.onConnectivityChanged
        .map(online)
        .listen(controller.add, onError: (_) {});
    controller.onCancel = sub.cancel;
  });
});

/// True while the device is offline (`03 §2.1`). Unknown counts as online.
final isOfflineProvider = StreamProvider<bool>(
  (ref) => ref.watch(connectivityStreamProvider).map((online) => !online),
);
