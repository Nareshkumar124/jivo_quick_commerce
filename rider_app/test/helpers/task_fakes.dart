import 'dart:async';

import 'package:flutter/material.dart';
import 'package:rider_app/features/offers/domain/delivery_offer.dart';
import 'package:rider_app/features/task/domain/rider_task.dart';
import 'package:rider_app/features/task/domain/task_repositories.dart';
import 'package:rider_app/features/task/presentation/pickup_scan_screen.dart';

/// A fixed GPS fix, or [LocationUnavailable] when [unavailable].
class FakeLocationReader implements CurrentLocationReader {
  GeoPoint fix = const GeoPoint(28.5706, 77.3261);
  bool unavailable = false;
  int reads = 0;

  /// When set, reads wait for it (a slow GPS fix).
  Completer<void>? hold;

  @override
  Future<GeoPoint> current() async {
    reads++;
    await hold?.future;
    if (unavailable) throw const LocationUnavailable();
    return fix;
  }
}

/// Records rings instead of posting notifications.
class RecordingOfferAlerter implements OfferAlerter {
  final rings = <(int, Duration)>[];
  int stops = 0;

  @override
  Future<void> ring(
    DeliveryOffer offer, {
    required String title,
    required String body,
    required Duration timeout,
  }) async => rings.add((offer.id, timeout));

  @override
  Future<void> stop() async => stops++;
}

/// A stand-in for the camera: buttons that "scan" a value.
QrScannerBuilder fakeScanner(List<String> values) =>
    (context, onScan) => Column(
      children: [
        for (final value in values)
          TextButton(
            key: Key('fake-scan-$value'),
            onPressed: () => onScan(value),
            child: Text('scan $value'),
          ),
      ],
    );
