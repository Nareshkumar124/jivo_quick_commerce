import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../app/theme.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/task_rules.dart';
import 'task_flow_controller.dart';

/// Builds the camera view that reports each scanned QR value. A provider, so
/// widget tests never start the camera.
typedef QrScannerBuilder = Widget Function(
  BuildContext context,
  void Function(String raw) onScan,
  MobileScannerController? controller,
);

/// The camera controller (torch). Null in tests: no camera, no torch.
final scannerControllerProvider =
    Provider.autoDispose<MobileScannerController?>((ref) {
      final controller = MobileScannerController();
      ref.onDispose(controller.dispose);
      return controller;
    });

final qrScannerBuilderProvider = Provider<QrScannerBuilder>(
  (ref) =>
      (context, onScan, controller) => MobileScanner(
        controller: controller,
        onDetect: (capture) {
          for (final barcode in capture.barcodes) {
            final raw = barcode.rawValue;
            if (raw != null) onScan(raw);
          }
        },
        // Camera denied or missing: the rider types the code instead.
        errorBuilder: (context, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              AppLocalizations.of(context).scanCameraUnavailable,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 18),
            ),
          ),
        ),
      ),
);

/// Scan the QR on the packed bag (04 §2.5, `design/screens/rider/pickup.md`
/// §4): a 240 dp viewfinder, a helper line, a torch toggle that says its
/// state in words, and "Type the code instead" bottom-most. Returns the
/// `order_code` to send (the bag QR payload `JQC1:<order>:<code>` or a bare
/// code) to the pickup step; the server checks it. A label for another
/// order is refused here, so a mixed-up bag never uses an attempt.
class PickupScanScreen extends ConsumerStatefulWidget {
  const PickupScanScreen({super.key});

  @override
  ConsumerState<PickupScanScreen> createState() => _PickupScanScreenState();
}

class _PickupScanScreenState extends ConsumerState<PickupScanScreen> {
  bool _done = false;
  String? _lastRejected;

  static const _viewfinder = 240.0;

  void _onScan(String raw) {
    if (_done || !mounted) return;
    final orderNumber =
        ref.read(taskFlowControllerProvider).task?.orderNumber ?? '';
    final scanned = parseScannedPickup(raw, orderNumber: orderNumber);
    if (scanned is ScannedCode) {
      _done = true;
      context.pop(scanned.orderCode);
      return;
    }
    // Each unusable QR is reported once, not on every camera frame.
    if (_lastRejected == raw) return;
    _lastRejected = raw;
    final l10n = AppLocalizations.of(context);
    final message = switch (scanned) {
      ScannedOtherOrder(:final orderNumber) => l10n.scanOtherOrder(orderNumber),
      _ => l10n.scanNotJivoCode,
    };
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scanner = ref.watch(qrScannerBuilderProvider);
    final controller = ref.watch(scannerControllerProvider);
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(title: Text(l10n.scanTitle)),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                scanner(context, _onScan, controller),
                // Viewfinder over a 50 % scrim; taps pass through.
                IgnorePointer(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        key: const Key('scan-viewfinder'),
                        width: _viewfinder,
                        height: _viewfinder,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.white, width: 3),
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        color: Colors.black54,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        child: Text(
                          l10n.scanHelper,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (controller != null) _TorchButton(controller: controller),
                  FilledButton(
                    key: const Key('scan-type-instead'),
                    onPressed: () => context.pop(),
                    child: Text(l10n.scanTypeInstead),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// "Light" / "Light on": hidden when the phone has no torch.
class _TorchButton extends StatelessWidget {
  const _TorchButton({required this.controller});

  final MobileScannerController controller;

  @override
  Widget build(BuildContext context) =>
      ValueListenableBuilder<MobileScannerState>(
        valueListenable: controller,
        builder: (context, state, _) {
          if (state.torchState == TorchState.unavailable) {
            return const SizedBox.shrink();
          }
          final l10n = AppLocalizations.of(context);
          final on = state.torchState == TorchState.on;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: OutlinedButton.icon(
              key: const Key('scan-torch'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: const BorderSide(
                  color: Colors.white,
                  width: RiderColors.borderWidth,
                ),
              ),
              onPressed: controller.toggleTorch,
              icon: Icon(on ? Icons.flashlight_on : Icons.flashlight_off),
              label: Text(on ? l10n.scanLightOn : l10n.scanLight),
            ),
          );
        },
      );
}
