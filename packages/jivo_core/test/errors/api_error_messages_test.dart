import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jivo_core/jivo_core.dart';

void main() {
  final l10n = lookupJivoCoreLocalizations(const Locale('en'));

  String messageFor(ApiErrorCode code) =>
      apiErrorMessage(l10n, ApiError(code: code));

  // App bugs the user can't act on: they get the generic message.
  const protocolCodes = {
    ApiErrorCode.methodNotAllowed,
    ApiErrorCode.notAcceptable,
    ApiErrorCode.unsupportedMediaType,
  };

  test('every other backend code has its own, distinct message', () {
    final backendCodes = ApiErrorCode.values.where((c) => c.wireValue != null);
    expect(
      backendCodes,
      hasLength(47),
      reason: '06 §6 + OpenAPI ErrorCodeEnum (+ REFERRAL_*, 2026-11-13; + email login codes, 2026-11-28)',
    );

    final specific = backendCodes.where((c) => !protocolCodes.contains(c));
    final messages = <String>{};
    for (final code in specific) {
      final message = messageFor(code);
      expect(message, isNotEmpty, reason: code.name);
      expect(message, isNot(l10n.errorGeneric), reason: code.name);
      messages.add(message);
    }
    expect(
      messages,
      hasLength(specific.length),
      reason: 'messages must be distinct',
    );
  });

  test('protocol errors fall back to the generic message', () {
    for (final code in protocolCodes) {
      expect(messageFor(code), l10n.errorGeneric, reason: code.name);
    }
  });

  test('client-side failures have specific messages', () {
    expect(messageFor(ApiErrorCode.network), l10n.errorNetwork);
    expect(messageFor(ApiErrorCode.timeout), l10n.errorTimeout);
    expect(messageFor(ApiErrorCode.serverError), l10n.errorServer);
    expect(messageFor(ApiErrorCode.cancelled), l10n.errorCancelled);
  });

  test('MIN_QTY_REQUIRED names the minimum from details when sent', () {
    final error = ApiError.tryParseEnvelope({
      'error': {
        'code': 'MIN_QTY_REQUIRED',
        'message': 'You need to order at least 5 of Jivo Water.',
        'details': {'variant_id': 1501, 'min_qty_per_order': 5},
      },
    })!;

    expect(error.code, ApiErrorCode.minQtyRequired);
    expect(error.minQtyPerOrder, 5);
    expect(
      apiErrorMessageWithDetails(l10n, error),
      'You need to order at least 5 of this item.',
    );
    // Without details: the generic minimum message, never the server's.
    expect(
      apiErrorMessageWithDetails(
        l10n,
        const ApiError(code: ApiErrorCode.minQtyRequired),
      ),
      l10n.errorMinQtyRequired,
    );
  });

  test('MIN_UNITS_NOT_MET carries the units from details', () {
    final error = ApiError.tryParseEnvelope({
      'error': {
        'code': 'MIN_UNITS_NOT_MET',
        'message': 'Add 2 more cartons.',
        'details': {'min_order_units': 5, 'units_to_min_order': 2},
      },
    })!;

    expect(error.code, ApiErrorCode.minUnitsNotMet);
    expect(error.minOrderUnits, 5);
    expect(error.unitsToMinOrder, 2);
    expect(apiErrorMessage(l10n, error), l10n.errorMinUnitsNotMet);
  });

  test('REFERRAL_* codes map to their own messages', () {
    ApiError parse(String code, [Map<String, Object?> details = const {}]) =>
        ApiError.tryParseEnvelope({
          'error': {'code': code, 'message': 'server text', 'details': details},
        }, statusCode: 422)!;

    expect(
      apiErrorMessageWithDetails(
        l10n,
        parse('REFERRAL_CODE_INVALID', {'code': 'ZZZZ99'}),
      ),
      "This referral code isn't valid. Check it and try again.",
    );
    expect(
      apiErrorMessageWithDetails(l10n, parse('REFERRAL_SELF')),
      "That's your own code. Enter a friend's code instead.",
    );
    expect(
      apiErrorMessageWithDetails(l10n, parse('REFERRAL_ALREADY_APPLIED')),
      "You've already used a referral code. It can't be changed.",
    );
    final hasOrders = parse('REFERRAL_NOT_ELIGIBLE', {'reason': 'HAS_ORDERS'});
    expect(hasOrders.reason, 'HAS_ORDERS');
    expect(
      apiErrorMessageWithDetails(l10n, hasOrders),
      'Referral codes are only for new customers, before their first order.',
    );
    final paused = parse('REFERRAL_NOT_ELIGIBLE', {'reason': 'PROGRAM_OFF'});
    expect(paused.code, ApiErrorCode.referralNotEligible);
    expect(
      apiErrorMessageWithDetails(l10n, paused),
      'Refer & earn is paused right now. Please try again later.',
    );
    // Without details the reason is unknown: the general message.
    expect(apiErrorMessage(l10n, paused), l10n.errorReferralNotEligible);
    expect(parse('REFERRAL_SELF').reason, isNull);
  });

  test('unknown codes fall back to the generic message', () {
    final error = ApiError.tryParseEnvelope({
      'error': {'code': 'NOT_IN_THE_DOCS', 'message': 'Internal detail'},
    })!;

    expect(apiErrorMessage(l10n, error), l10n.errorGeneric);
  });

  test('server messages and exception text are never shown', () {
    final error = ApiError.tryParseEnvelope({
      'error': {'code': 'OTP_INVALID', 'message': 'otp mismatch for user 42'},
    })!;

    expect(apiErrorMessage(l10n, error), l10n.errorOtpInvalid);
    expect(
      apiErrorMessage(l10n, ApiError.from(StateError('secret stack'))),
      l10n.errorGeneric,
    );
  });

  testWidgets('describeError resolves through the localizations delegate', (
    tester,
  ) async {
    late String message;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: JivoCoreLocalizations.localizationsDelegates,
        supportedLocales: JivoCoreLocalizations.supportedLocales,
        home: Builder(
          builder: (context) {
            message = describeError(
              context,
              const ApiError(code: ApiErrorCode.notServiceable),
            );
            return const SizedBox();
          },
        ),
      ),
    );

    expect(message, "We don't deliver to this location yet.");
  });
}
