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
      hasLength(36),
      reason: '06 §6 + OpenAPI ErrorCodeEnum',
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
