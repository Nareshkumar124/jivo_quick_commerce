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

/// Requests in a row that failed for lack of a connection (no network or a
/// timeout); 0 again after any answer from the server (CA-02). Wi-Fi
/// without internet, or data with no signal, still reports a network
/// interface, so the device's state alone can't tell.
class NetworkHealth extends Notifier<int> {
  @override
  int build() => 0;

  void failed() => state = state + 1;

  void answered() {
    if (state != 0) state = 0;
  }
}

final networkHealthProvider = NotifierProvider<NetworkHealth, int>(
  NetworkHealth.new,
);

/// How many failures in a row count as "no internet" (CA-02).
const kNetworkErrorsForOffline = 2;

/// The offline banner shows: the device is offline, or the last
/// [kNetworkErrorsForOffline] requests failed for lack of a connection.
final connectionLostProvider = Provider<bool>(
  (ref) =>
      (ref.watch(isOfflineProvider).value ?? false) ||
      ref.watch(networkHealthProvider) >= kNetworkErrorsForOffline,
);

/// Counts the times the connection came back (lost, then not lost). Screens
/// in an error state retry once on each (`03 §2.1` "Retry on reconnect").
class Reconnects extends Notifier<int> {
  @override
  int build() {
    // The device is back online: forget the failures from while it was
    // off, so the next requests decide.
    ref.listen(isOfflineProvider, (previous, next) {
      if ((previous?.value ?? false) && next.value == false) {
        ref.read(networkHealthProvider.notifier).answered();
      }
    });
    ref.listen(connectionLostProvider, (previous, next) {
      if ((previous ?? false) && !next) state = state + 1;
    });
    return 0;
  }
}

final reconnectProvider = NotifierProvider<Reconnects, int>(Reconnects.new);
