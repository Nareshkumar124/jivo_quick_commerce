import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jivo_core/jivo_core.dart';

void main() {
  group('compareAppVersions', () {
    test('compares numerically, segment by segment', () {
      expect(compareAppVersions('1.10.0', '1.2.0'), greaterThan(0));
      expect(compareAppVersions('1.2.0', '1.2.1'), lessThan(0));
      expect(compareAppVersions('1.2', '1.2.0'), 0);
      expect(compareAppVersions('2.0.0', '1.99.99'), greaterThan(0));
    });

    test('ignores pre-release/build suffixes and junk segments', () {
      expect(compareAppVersions('1.2.0-dev', '1.2.0'), 0);
      expect(compareAppVersions('1.2.0+7', '1.2.0'), 0);
      expect(compareAppVersions('1.x.0', '1.0.0'), 0);
    });

    test('isVersionBelow tolerates a missing minimum', () {
      expect(isVersionBelow('1.0.0', '1.2.0'), isTrue);
      expect(isVersionBelow('1.2.0', '1.2.0'), isFalse);
      expect(isVersionBelow('1.0.0', null), isFalse);
      expect(isVersionBelow('1.0.0', ''), isFalse);
    });

    // The rider app's old version tests, kept when it moved to jivo_core.
    test('isVersionBelow ignores a build suffix', () {
      expect(isVersionBelow('1.0.0+7', '1.0.1'), isTrue);
      expect(isVersionBelow('1.0.1+7', '1.0.1'), isFalse);
      expect(isVersionBelow('1.0.2+1', '1.0.1'), isFalse);
    });

    test('isVersionBelow pads a short version with zeros', () {
      expect(isVersionBelow('1', '1.0.1'), isTrue);
      expect(isVersionBelow('1.0.1', '1'), isFalse);
      expect(isVersionBelow('1', '1.0.0'), isFalse);
      expect(isVersionBelow('2', '1.9.9'), isFalse);
    });

    test('isVersionBelow trims surrounding spaces', () {
      expect(isVersionBelow(' 1.0.0 ', '1.0.1'), isTrue);
      expect(isVersionBelow('1.0.1', '  1.0.1  '), isFalse);
      expect(isVersionBelow(' 1.0.1+3 ', ' 1.0.1 '), isFalse);
      expect(isVersionBelow('1.0.0', '   '), isFalse); // blank minimum
    });
  });

  group('apiErrorMessageWithDetails', () {
    final l10n = lookupJivoCoreLocalizations(const Locale('en'));

    ApiError parsed(String code, Map<String, Object?> details) =>
        ApiError.tryParseEnvelope({
          'error': {'code': code, 'message': 'x', 'details': details},
        })!;

    test('OTP_INVALID uses attempts_remaining', () {
      final error = parsed('OTP_INVALID', {'attempts_remaining': 3});

      expect(error.attemptsRemaining, 3);
      expect(
        apiErrorMessageWithDetails(l10n, error),
        'That OTP is incorrect. 3 attempts left.',
      );
      expect(
        apiErrorMessageWithDetails(
          l10n,
          parsed('OTP_INVALID', {'attempts_remaining': 1}),
        ),
        'That OTP is incorrect. 1 attempt left.',
      );
    });

    test('rate limits use retry_after_seconds rounded up to minutes', () {
      final error = parsed('OTP_RATE_LIMITED', {'retry_after_seconds': 540});

      expect(error.retryAfterSeconds, 540);
      expect(
        apiErrorMessageWithDetails(l10n, error),
        'Too many attempts. Please try again in 9 minutes.',
      );
      expect(
        apiErrorMessageWithDetails(
          l10n,
          parsed('RATE_LIMITED', {'retry_after_seconds': 30}),
        ),
        'Too many attempts. Please try again in 1 minute.',
      );
    });

    test('falls back to apiErrorMessage without details', () {
      final error = parsed('OTP_INVALID', {});

      expect(
        apiErrorMessageWithDetails(l10n, error),
        apiErrorMessage(l10n, error),
      );
      expect(
        apiErrorMessage(l10n, error),
        l10n.errorOtpInvalid,
        reason: 'unchanged',
      );
    });
  });
}
