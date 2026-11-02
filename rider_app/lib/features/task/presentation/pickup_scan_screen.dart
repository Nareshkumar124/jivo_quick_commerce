import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../l10n/app_localizations.dart';
import '../domain/task_rules.dart';

/// Builds the camera view that reports each scanned QR value. A provider, so
/// widget tests never start the camera.
typedef QrScannerBuilder = Widget Function(
  BuildContext context,
  void Function(String raw) onScan,
);

final qrScannerBuilderProvider = Provider<QrScannerBuilder>(
  (ref) =>
      (context, onScan) => MobileScanner(
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

/// Scan the QR on the packed bag (04 §2.5). Returns the 4-character code to
/// the pickup step, which sends it; the server checks it. Typing the code is
/// always possible instead.
class PickupScanScreen extends ConsumerStatefulWidget {
  const PickupScanScreen({super.key});

  @override
  ConsumerState<PickupScanScreen> createState() => _PickupScanScreenState();
}

class _PickupScanScreenState extends ConsumerState<PickupScanScreen> {
  bool _done = false;
  String? _lastRejected;

  void _onScan(String raw) {
    if (_done || !mounted) return;
    final code = pickupCodeFromQr(raw);
    if (code == null) {
      // Each unusable QR is reported once, not on every camera frame.
      if (_lastRejected == raw) return;
      _lastRejected = raw;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).scanNotJivoCode)),
      );
      return;
    }
    _done = true;
    context.pop(code);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scanner = ref.watch(qrScannerBuilderProvider);
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(title: Text(l10n.scanTitle)),
      body: Column(
        children: [
          Expanded(child: scanner(context, _onScan)),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  key: const Key('scan-type-instead'),
                  onPressed: () => context.pop(),
                  child: Text(l10n.scanTypeInstead),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
