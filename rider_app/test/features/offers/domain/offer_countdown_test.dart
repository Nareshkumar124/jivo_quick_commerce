import 'package:flutter_test/flutter_test.dart';
import 'package:rider_app/features/offers/domain/delivery_offer.dart';

void main() {
  final server = DateTime.utc(2026, 11, 2, 6, 30);
  final expiresAt = server.add(const Duration(seconds: 30));

  group('OfferCountdown (rule 4: the server\'s expires_at)', () {
    test('clocks in step: 30 s, counting down, then expired', () {
      final c = OfferCountdown(
        expiresAt: expiresAt,
        receivedAt: server,
        serverNow: server,
      );
      expect(c.secondsLeft(server), 30);
      expect(c.secondsLeft(server.add(const Duration(seconds: 10))), 20);
      expect(
        c.secondsLeft(server.add(const Duration(milliseconds: 29100))),
        1,
        reason: 'rounded up until really over',
      );
      expect(c.isExpired(server.add(const Duration(seconds: 29))), isFalse);
      expect(c.isExpired(server.add(const Duration(seconds: 30))), isTrue);
      expect(c.secondsLeft(server.add(const Duration(minutes: 5))), 0);
    });

    test('a late push: only the time the server still allows', () {
      // Received 12 s after the offer was made.
      final received = server.add(const Duration(seconds: 12));
      final c = OfferCountdown(
        expiresAt: expiresAt,
        receivedAt: received,
        serverNow: received,
      );
      expect(c.secondsLeft(received), 18);
    });

    test('phone clock 5 minutes ahead: the server time corrects it', () {
      final phone = server.add(const Duration(minutes: 5));
      final c = OfferCountdown(
        expiresAt: expiresAt,
        receivedAt: phone,
        serverNow: server,
      );
      expect(c.secondsLeft(phone), 30);
      expect(c.isExpired(phone.add(const Duration(seconds: 30))), isTrue);
    });

    test('phone clock behind and no server time: capped at 30 s', () {
      final phone = server.subtract(const Duration(minutes: 5));
      final c = OfferCountdown(expiresAt: expiresAt, receivedAt: phone);
      expect(
        c.secondsLeft(phone),
        30,
        reason: 'expires_at alone would show 5½ minutes',
      );
    });

    test('phone clock ahead and no server time: expires_at as the phone '
        'reads it (fails safe: shorter, never longer)', () {
      final phone = server.add(const Duration(seconds: 20));
      final c = OfferCountdown(expiresAt: expiresAt, receivedAt: phone);
      expect(c.secondsLeft(phone), 10);
    });
  });
}
