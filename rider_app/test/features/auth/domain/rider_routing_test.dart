import 'package:flutter_test/flutter_test.dart';
import 'package:jivo_api/jivo_api.dart' show Me, RiderStatusEnum;
import 'package:jivo_core/jivo_core.dart';
import 'package:rider_app/app/route_guard.dart';
import 'package:rider_app/app/routes.dart';
import 'package:rider_app/features/auth/domain/rider_account.dart';
import 'package:rider_app/features/auth/domain/rider_destination.dart';

AccountLoaded loaded(RiderStatusEnum status) => AccountLoaded(
  user: Me.fromJson({
    'id': 57,
    'phone': '+919811122233',
    'name': 'Ravi Kumar',
    'email': null,
    'marketing_opt_in': false,
    'is_profile_complete': true,
    'rider_status': status.value,
    'created_at': '2026-10-28T04:00:00Z',
  }),
  riderStatus: status,
);

String? redirect(
  String location, {
  AppControlEvent? appControl,
  bool configLoaded = true,
  bool softUpdatePending = false,
  SessionStatus sessionStatus = SessionStatus.signedOut,
  RiderAccountState account = const AccountUnknown(),
  bool hasOtpChallenge = false,
  bool showDevTools = true,
  bool hasRiderTask = false,
  bool hasOffer = false,
  bool recordsEnabled = true,
}) => riderRedirect(
  location: location,
  appControl: appControl,
  configLoaded: configLoaded,
  softUpdatePending: softUpdatePending,
  sessionStatus: sessionStatus,
  account: account,
  hasOtpChallenge: hasOtpChallenge,
  showDevTools: showDevTools,
  hasRiderTask: hasRiderTask,
  hasOffer: hasOffer,
  recordsEnabled: recordsEnabled,
);

void main() {
  group('destinationFor (routing by rider_status)', () {
    test('every status has a destination; only ACTIVE reaches home', () {
      expect(destinationFor(RiderStatusEnum.NONE), RiderDestination.register);
      expect(
        destinationFor(RiderStatusEnum.PENDING_KYC),
        RiderDestination.status,
      );
      expect(destinationFor(RiderStatusEnum.REJECTED), RiderDestination.status);
      expect(
        destinationFor(RiderStatusEnum.SUSPENDED),
        RiderDestination.status,
      );
      expect(destinationFor(RiderStatusEnum.ACTIVE), RiderDestination.home);
      expect(
        destinationFor(RiderStatusEnum.unknownDefaultOpenApi),
        RiderDestination.status,
        reason: 'a status this version does not know must never open home',
      );
    });
  });

  group('riderRedirect', () {
    test('signed in: lands on the screen for rider_status', () {
      final cases = {
        RiderStatusEnum.NONE: Routes.register,
        RiderStatusEnum.PENDING_KYC: Routes.riderStatus,
        RiderStatusEnum.REJECTED: Routes.riderStatus,
        RiderStatusEnum.SUSPENDED: Routes.riderStatus,
        RiderStatusEnum.ACTIVE: Routes.home,
        RiderStatusEnum.unknownDefaultOpenApi: Routes.riderStatus,
      };
      for (final MapEntry(key: status, value: route) in cases.entries) {
        expect(
          redirect(
            Routes.splash,
            sessionStatus: SessionStatus.signedIn,
            account: loaded(status),
          ),
          route,
          reason: '$status',
        );
        expect(
          redirect(
            route,
            sessionStatus: SessionStatus.signedIn,
            account: loaded(status),
          ),
          isNull,
          reason: '$status stays',
        );
      }
    });

    test('a non-active rider cannot open home or login', () {
      final pending = loaded(RiderStatusEnum.PENDING_KYC);
      for (final location in [Routes.home, Routes.login, Routes.register]) {
        expect(
          redirect(
            location,
            sessionStatus: SessionStatus.signedIn,
            account: pending,
          ),
          Routes.riderStatus,
        );
      }
    });

    test('application steps: open to PENDING_KYC and REJECTED only', () {
      final steps = [
        Routes.documents,
        Routes.documentCapture('PAN'),
        Routes.bankDetails,
      ];
      for (final status in [
        RiderStatusEnum.PENDING_KYC,
        RiderStatusEnum.REJECTED,
      ]) {
        for (final route in steps) {
          expect(
            redirect(
              route,
              sessionStatus: SessionStatus.signedIn,
              account: loaded(status),
            ),
            isNull,
            reason: '$status may open $route',
          );
        }
      }
      for (final (status, target) in [
        (RiderStatusEnum.SUSPENDED, Routes.riderStatus),
        (RiderStatusEnum.unknownDefaultOpenApi, Routes.riderStatus),
        (RiderStatusEnum.NONE, Routes.register),
        (RiderStatusEnum.ACTIVE, Routes.home),
      ]) {
        for (final route in steps) {
          expect(
            redirect(
              route,
              sessionStatus: SessionStatus.signedIn,
              account: loaded(status),
            ),
            target,
            reason: '$status may not open $route',
          );
        }
      }
      expect(
        Routes.documentCapture('AADHAAR_FRONT'),
        '/rider-status/documents/aadhaar_front',
      );
      // A look-alike path is not a sub-route.
      expect(
        redirect(
          '/rider-statusx',
          sessionStatus: SessionStatus.signedIn,
          account: loaded(RiderStatusEnum.PENDING_KYC),
        ),
        Routes.riderStatus,
      );
    });

    test('ACTIVE with a task: only the task screens; then an offer; then '
        'home', () {
      final active = loaded(RiderStatusEnum.ACTIVE);
      String? at(String location, {bool task = false, bool offer = false}) =>
          redirect(
            location,
            sessionStatus: SessionStatus.signedIn,
            account: active,
            hasRiderTask: task,
            hasOffer: offer,
          );

      for (final location in [Routes.home, Routes.offer, Routes.login]) {
        expect(at(location, task: true), Routes.task, reason: location);
      }
      for (final location in [Routes.task, Routes.taskScan, Routes.taskFail]) {
        expect(at(location, task: true), isNull, reason: location);
        expect(
          at(location, task: true, offer: true),
          isNull,
          reason: 'a task outranks an offer',
        );
        expect(at(location), Routes.home, reason: 'no task: $location');
      }
      expect(at(Routes.home, offer: true), Routes.offer);
      expect(at(Routes.offer, offer: true), isNull);
      expect(at(Routes.offer), Routes.home);
    });

    test('records (earnings, cash, history, payouts, profile): ACTIVE '
        'riders between orders only', () {
      final records = [
        Routes.earnings,
        Routes.payouts,
        Routes.cash,
        Routes.history,
        Routes.profile,
        Routes.profileDocuments,
      ];
      for (final route in records) {
        expect(
          redirect(
            route,
            sessionStatus: SessionStatus.signedIn,
            account: loaded(RiderStatusEnum.ACTIVE),
          ),
          isNull,
          reason: route,
        );
        expect(
          redirect(
            route,
            sessionStatus: SessionStatus.signedIn,
            account: loaded(RiderStatusEnum.ACTIVE),
            hasRiderTask: true,
          ),
          Routes.task,
          reason: 'during a task: $route',
        );
        expect(
          redirect(
            route,
            sessionStatus: SessionStatus.signedIn,
            account: loaded(RiderStatusEnum.ACTIVE),
            hasOffer: true,
          ),
          Routes.offer,
          reason: 'with an open offer: $route',
        );
        expect(
          redirect(
            route,
            sessionStatus: SessionStatus.signedIn,
            account: loaded(RiderStatusEnum.PENDING_KYC),
          ),
          Routes.riderStatus,
          reason: 'not active: $route',
        );
      }
      expect(Routes.isAccountRoute('/earningsx'), isFalse);
    });

    test('records where those routes are not built (staging, prod): '
        'a stray link goes home', () {
      for (final route in [
        Routes.earnings,
        Routes.cash,
        Routes.history,
        Routes.payouts,
        Routes.profileDocuments,
      ]) {
        expect(
          redirect(
            route,
            sessionStatus: SessionStatus.signedIn,
            account: loaded(RiderStatusEnum.ACTIVE),
            recordsEnabled: false,
          ),
          Routes.home,
          reason: route,
        );
      }
    });

    test('task and offer flags never open work screens for other '
        'statuses', () {
      for (final status in [
        RiderStatusEnum.PENDING_KYC,
        RiderStatusEnum.NONE,
        RiderStatusEnum.SUSPENDED,
      ]) {
        expect(
          redirect(
            Routes.task,
            sessionStatus: SessionStatus.signedIn,
            account: loaded(status),
            hasRiderTask: true,
            hasOffer: true,
          ),
          isNot(Routes.task),
          reason: '$status',
        );
      }
    });

    test('signed in but rider_status not loaded (or /me failed): splash', () {
      expect(
        redirect(Routes.home, sessionStatus: SessionStatus.signedIn),
        Routes.splash,
      );
      expect(
        redirect(
          Routes.home,
          sessionStatus: SessionStatus.signedIn,
          account: const AccountLoadFailed(
            ApiError(code: ApiErrorCode.network),
          ),
        ),
        Routes.splash,
      );
    });

    test('config not loaded or session unknown: splash', () {
      expect(redirect(Routes.login, configLoaded: false), Routes.splash);
      expect(
        redirect(Routes.login, sessionStatus: SessionStatus.unknown),
        Routes.splash,
      );
      expect(
        redirect(Routes.splash, configLoaded: false),
        isNull,
        reason: 'already there',
      );
    });

    test('signed out: login; the OTP step only while an OTP is pending', () {
      expect(redirect(Routes.home), Routes.login);
      expect(redirect(Routes.splash), Routes.login);
      expect(redirect(Routes.otp), Routes.login);
      expect(redirect(Routes.otp, hasOtpChallenge: true), isNull);
    });

    test('force update outranks everything, then maintenance', () {
      const update = AppUpdateRequired(minSupportedVersion: '2.0.0');
      const maintenance = MaintenanceMode(message: 'Back at 6');
      expect(redirect(Routes.login, appControl: update), Routes.update);
      expect(
        redirect(
          Routes.home,
          appControl: update,
          sessionStatus: SessionStatus.signedIn,
          account: loaded(RiderStatusEnum.ACTIVE),
        ),
        Routes.update,
      );
      expect(
        redirect(Routes.splash, appControl: update, configLoaded: false),
        Routes.update,
      );
      expect(
        redirect(Routes.login, appControl: maintenance),
        Routes.maintenance,
      );
    });

    test('optional update prompt comes before login/home until dismissed', () {
      expect(redirect(Routes.splash, softUpdatePending: true), Routes.update);
      expect(redirect(Routes.update, softUpdatePending: false), Routes.login);
    });

    test('dev routes are never redirected in the dev flavor only', () {
      for (final route in [
        Routes.locationDebug,
        Routes.offerPreview,
        Routes.permissions,
        Routes.disclosure,
      ]) {
        expect(redirect(route, configLoaded: false), isNull, reason: route);
        expect(
          redirect(route, showDevTools: false),
          Routes.login,
          reason: '$route outside dev',
        );
      }
    });
  });
}
