import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../location/domain/tracker_stats.dart';
import '../../location/presentation/location_debug_controller.dart';
import '../../realtime/data/rider_socket_client.dart';
import '../../realtime/presentation/rider_socket_providers.dart';
import 'shift_controller.dart';

/// How long the rider socket may be down before home says "no internet"
/// (a reconnect after a short drop is normal).
const kSocketDownGrace = Duration(seconds: 10);

/// The grace ([kSocketDownGrace]); shortened in tests.
final socketDownGraceProvider = Provider<Duration>((ref) => kSocketDownGrace);

final riderConnectionLostProvider =
    NotifierProvider<RiderConnectionController, bool>(
      RiderConnectionController.new,
    );

/// Whether an online rider has lost the connection (UX audit RA-10): the
/// rider socket has not been up for [kSocketDownGrace] (API builds), or the
/// last location upload failed for lack of network. Cleared as soon as
/// either works again. Display only: the app never changes the shift
/// itself; the server still decides auto-offline.
class RiderConnectionController extends Notifier<bool> {
  Timer? _grace;
  bool _socketDown = false;
  bool _uploadsFailing = false;

  @override
  bool build() {
    final online = ref.watch(
      shiftControllerProvider.select((shift) => shift.isOnline),
    );
    ref.onDispose(() {
      _grace?.cancel();
      _grace = null;
    });
    _socketDown = false;
    _uploadsFailing = false;
    if (!online) return false;

    if (ref.watch(riderSocketEnabledProvider)) {
      ref.listen(riderSocketControllerProvider, (_, status) {
        _onSocket(status);
      });
      // Not up yet when the shift starts: the grace covers the connect.
      if (ref.read(riderSocketControllerProvider) !=
          RiderSocketStatus.connected) {
        _armGrace();
      }
    }
    final stats = ref
        .watch(locationServiceClientProvider)
        .stats
        .listen(_onStats);
    ref.onDispose(stats.cancel);
    return false;
  }

  void _armGrace() {
    _grace?.cancel();
    _grace = Timer(ref.read(socketDownGraceProvider), () {
      _grace = null;
      if (!ref.mounted) return;
      _socketDown = true;
      _update();
    });
  }

  void _onSocket(RiderSocketStatus status) {
    if (status == RiderSocketStatus.connected) {
      _grace?.cancel();
      _grace = null;
      _socketDown = false;
      _update();
    } else if (_grace == null && !_socketDown) {
      _armGrace();
    }
  }

  void _onStats(TrackerStats stats) {
    if (!ref.mounted) return;
    _uploadsFailing = switch (stats.lastUploadStatus) {
      UploadStatus.retryLater => _isNetwork(stats.lastError),
      UploadStatus.accepted || UploadStatus.rejected => false,
      UploadStatus.none => _uploadsFailing,
    };
    _update();
  }

  /// `UploadRetryLater` carries the `ApiErrorCode` name: no network or a
  /// timeout means the phone is not reaching the server.
  static bool _isNetwork(String? reason) =>
      reason == 'network' || reason == 'timeout';

  void _update() {
    final lost = _socketDown || _uploadsFailing;
    if (state != lost) state = lost;
  }
}
