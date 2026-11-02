import 'package:customer_app/app/redirect.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jivo_core/jivo_core.dart';

String? redirect(
  String location, {
  AppControlEvent? control,
  SessionStatus session = SessionStatus.signedIn,
  bool ready = true,
  bool onboardingSeen = true,
  bool? profileComplete = true,
  bool hasOtpChallenge = false,
}) => resolveRedirect(
  location: location,
  control: control,
  session: session,
  ready: ready,
  onboardingSeen: onboardingSeen,
  profileComplete: profileComplete,
  hasOtpChallenge: hasOtpChallenge,
);

void main() {
  test('a force update blocks everything, even maintenance and splash', () {
    const update = AppUpdateRequired(minSupportedVersion: '2.0.0');
    expect(redirect(Routes.home, control: update), Routes.updateRequired);
    expect(
      redirect(Routes.splash, control: update, ready: false),
      Routes.updateRequired,
    );
    expect(redirect(Routes.updateRequired, control: update), isNull);
  });

  test('maintenance blocks; when it clears the user leaves the screen', () {
    const maintenance = MaintenanceMode(message: 'x');
    expect(redirect(Routes.account, control: maintenance), Routes.maintenance);
    expect(redirect(Routes.maintenance, control: maintenance), isNull);
    expect(redirect(Routes.maintenance), Routes.home);
    expect(
      redirect(Routes.maintenance, session: SessionStatus.signedOut),
      Routes.login,
    );
  });

  test('the splash holds until start-up is done and the session is known', () {
    expect(redirect(Routes.home, ready: false), Routes.splash);
    expect(redirect(Routes.splash, ready: false), isNull);
    expect(
      redirect(Routes.login, session: SessionStatus.unknown),
      Routes.splash,
    );
  });

  test('signed out: onboarding on first launch, then login', () {
    expect(
      redirect(
        Routes.splash,
        session: SessionStatus.signedOut,
        onboardingSeen: false,
      ),
      Routes.onboarding,
    );
    expect(
      redirect(
        Routes.onboarding,
        session: SessionStatus.signedOut,
        onboardingSeen: false,
      ),
      isNull,
    );
    expect(
      redirect(Routes.onboarding, session: SessionStatus.signedOut),
      Routes.login,
    );
    expect(
      redirect(Routes.account, session: SessionStatus.signedOut),
      Routes.login,
    );
    expect(redirect(Routes.login, session: SessionStatus.signedOut), isNull);
  });

  test('the OTP screen needs a pending challenge', () {
    expect(
      redirect(
        Routes.otp,
        session: SessionStatus.signedOut,
        hasOtpChallenge: true,
      ),
      isNull,
    );
    expect(
      redirect(Routes.otp, session: SessionStatus.signedOut),
      Routes.login,
    );
  });

  test(
    'signed in: complete-profile until done, then away from entry screens',
    () {
      expect(
        redirect(Routes.otp, profileComplete: false),
        Routes.completeProfile,
      );
      expect(
        redirect(Routes.home, profileComplete: false),
        Routes.completeProfile,
      );
      expect(redirect(Routes.completeProfile, profileComplete: false), isNull);
      for (final entry in [
        Routes.splash,
        Routes.login,
        Routes.otp,
        Routes.onboarding,
        Routes.completeProfile,
      ]) {
        expect(redirect(entry), Routes.home, reason: entry);
      }
      expect(redirect(Routes.addresses), isNull);
      expect(
        redirect(Routes.home, profileComplete: null),
        isNull,
        reason: 'unknown does not block',
      );
    },
  );
}
