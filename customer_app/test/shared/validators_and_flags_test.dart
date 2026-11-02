import 'package:customer_app/shared/storage/app_flags.dart';
import 'package:customer_app/shared/validation/validators.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jivo_core/jivo_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('Indian mobile numbers follow ^\\+91[6-9]\\d{9}\$', () {
    expect(Validators.isMobile('9876543210'), isTrue);
    expect(Validators.isMobile('5876543210'), isFalse);
    expect(Validators.isMobile('987654321'), isFalse);
    expect(Validators.toE164('9876543210'), '+919876543210');
    expect(Validators.isE164Mobile('+919876543210'), isTrue);
    expect(Validators.localDigits('+919876543210'), '9876543210');
  });

  test('PIN codes and emails', () {
    expect(Validators.isPincode('110001'), isTrue);
    expect(Validators.isPincode('010001'), isFalse);
    expect(Validators.isPincode('11001'), isFalse);
    expect(Validators.isEmail('asha@example.com'), isTrue);
    expect(Validators.isEmail('asha@'), isFalse);
  });

  test(
    'the first run after (re)install clears tokens left in the Keychain',
    () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final store = InMemoryTokenStore(
        const AuthTokens(access: 'old', refresh: 'old'),
      );

      await clearStaleSessionOnFreshInstall(prefs, store);
      expect(await store.read(), isNull);

      await store.write(const AuthTokens(access: 'new', refresh: 'new'));
      await clearStaleSessionOnFreshInstall(prefs, store);
      expect(
        await store.read(),
        isNotNull,
        reason: 'later runs keep the session',
      );
    },
  );

  test('onboarding is remembered', () async {
    SharedPreferences.setMockInitialValues({});
    final flags = AppFlags(await SharedPreferences.getInstance());

    expect(flags.onboardingSeen, isFalse);
    await flags.markOnboardingSeen();
    expect(flags.onboardingSeen, isTrue);
  });
}
