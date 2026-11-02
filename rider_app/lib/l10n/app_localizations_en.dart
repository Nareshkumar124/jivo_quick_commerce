// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Jivo Rider';

  @override
  String homeBuildLabel(String flavor) {
    return 'Build: $flavor';
  }

  @override
  String get homePlaceholderBody =>
      'Login, shifts and order offers arrive in later phases.';

  @override
  String get homeDevToolsButton => 'Developer tools';

  @override
  String get retry => 'Try again';

  @override
  String get done => 'Done';

  @override
  String get permissionsTitle => 'Before you go online';

  @override
  String get permissionsIntro =>
      'Jivo Rider needs these to send you orders and track your deliveries.';

  @override
  String get permissionsLoadError => 'Could not check permissions.';

  @override
  String get permissionsAllSet => 'All set. You can go online.';

  @override
  String get gateStepDisclosure => 'How we use your location';

  @override
  String get gateStepDisclosureHint => 'Read this before we ask for location.';

  @override
  String get gateStepLocationWhenInUse => 'Location access';

  @override
  String get gateStepLocationWhenInUseHint => 'Tap Allow on the next screen.';

  @override
  String get gateStepLocationAlways => 'Location: Allow all the time';

  @override
  String get gateStepLocationAlwaysHint =>
      'On the next screen, choose \"Allow all the time\".';

  @override
  String get gateStepNotifications => 'Notifications';

  @override
  String get gateStepNotificationsHint =>
      'So you hear new orders and see that you are online.';

  @override
  String get gateStepBattery => 'No battery restrictions';

  @override
  String get gateStepBatteryHint =>
      'So your phone does not stop the app while you ride.';

  @override
  String get gateStepGps => 'GPS on';

  @override
  String get gateStepGpsHint => 'Switch on location in your phone settings.';

  @override
  String get gateStatusDone => 'Done';

  @override
  String get gateStatusNeeded => 'Needed';

  @override
  String get gateStatusBlocked => 'Blocked: open settings';

  @override
  String get gateActionDisclosure => 'Continue';

  @override
  String get gateActionLocationWhenInUse => 'Allow location';

  @override
  String get gateActionLocationAlways => 'Allow all the time';

  @override
  String get gateActionNotifications => 'Allow notifications';

  @override
  String get gateActionBattery => 'Remove battery restriction';

  @override
  String get gateActionGps => 'Turn on GPS';

  @override
  String get gateActionOpenSettings => 'Open settings';

  @override
  String get fullScreenIntentTitle => 'Full-screen order alerts';

  @override
  String get fullScreenIntentBody =>
      'Allow full-screen alerts so new orders show even when your phone is locked.';

  @override
  String get fullScreenIntentAction => 'Allow full-screen alerts';

  @override
  String get oemTitle => 'Keep Jivo Rider running';

  @override
  String get oemXiaomi =>
      'Xiaomi, Redmi, POCO: open App settings, turn Autostart on, and set Battery saver to No restrictions.';

  @override
  String get oemOppo =>
      'OPPO: open App settings > Battery, then allow background activity and auto launch.';

  @override
  String get oemVivo =>
      'vivo, iQOO: open App settings > Battery, allow high background power use, and turn Autostart on.';

  @override
  String get oemRealme =>
      'realme: open App settings > Battery, then allow background activity and auto launch.';

  @override
  String get oemOneplus =>
      'OnePlus: open App settings > Battery, choose Unrestricted, and allow auto launch.';

  @override
  String get oemAction => 'Open app settings';

  @override
  String get disclosureTitle => 'Your location while you\'re online';

  @override
  String get disclosureBody =>
      'Jivo Rider collects location data to send you delivery offers near your store, show customers where their order is, and calculate your distance pay, even when the app is closed or not in use.';

  @override
  String get disclosureOnlineOnly =>
      'Location is collected only while you are online. It stops as soon as you go offline.';

  @override
  String get disclosureSharing =>
      'Your live location is shared with Jivo operations and with the customer whose order you are delivering.';

  @override
  String get disclosureNextSteps =>
      'Next, allow location and then choose \"Allow all the time\".';

  @override
  String get disclosureAccept => 'Continue';

  @override
  String get disclosureDecline => 'Not now';

  @override
  String get onlineNotificationTitle => 'You\'re online';

  @override
  String get onlineNotificationText =>
      'Jivo Rider is using your location for deliveries.';

  @override
  String get onlineChannelName => 'Online status';

  @override
  String get onlineChannelDescription =>
      'Shown while you are online and your location is shared.';

  @override
  String get offerChannelName => 'New order offers';

  @override
  String get offerChannelDescription =>
      'Rings and opens full screen when a new order is offered to you.';

  @override
  String get testOfferTitle => 'New order offer (test)';

  @override
  String get testOfferBody => 'Test store to Sector 21 · 2.4 km · Prepaid';

  @override
  String get offerPreviewTitle => 'Test offer';

  @override
  String get offerPreviewBody =>
      'This screen was opened by the offer alert. The real offer screen comes in Phase 5.';

  @override
  String get offerPreviewDismiss => 'Dismiss';

  @override
  String get debugTitle => 'Location spike (dev)';

  @override
  String get debugStatusOnline => 'Online: location service running';

  @override
  String get debugStatusOffline => 'Offline: no location tracking';

  @override
  String get debugGoOnline => 'Go online';

  @override
  String get debugGoOffline => 'Go offline';

  @override
  String get debugPermissionsButton => 'Permissions gate';

  @override
  String get debugPermissionsMissing =>
      'Some permissions are missing. Fix them before going online.';

  @override
  String debugStartFailed(String error) {
    return 'Could not start the location service: $error';
  }

  @override
  String get debugModeIdle => 'Idle';

  @override
  String get debugModeOnTask => 'On task';

  @override
  String get debugSimulateOffline => 'Simulate no network (fake uploader)';

  @override
  String get debugFlushNow => 'Upload now';

  @override
  String debugStatsIntervals(int sample, int upload) {
    return 'Fix every $sample s, upload every $upload s';
  }

  @override
  String debugStatsCounts(
    int buffered,
    int uploaded,
    int dropped,
    int rejected,
  ) {
    return 'Buffered $buffered · Uploaded $uploaded · Dropped $dropped · Rejected $rejected';
  }

  @override
  String debugStatsLastFix(
    String lat,
    String lng,
    String accuracy,
    String time,
  ) {
    return 'Last fix: $lat, $lng (±$accuracy m) at $time';
  }

  @override
  String get debugStatsNoFix => 'No fix yet';

  @override
  String debugStatsLastUpload(String status, String time) {
    return 'Last upload: $status at $time';
  }

  @override
  String debugStatsLastError(String error) {
    return 'Last error: $error';
  }

  @override
  String get debugOfferSection => 'Offer alert';

  @override
  String get debugOfferNow => 'Show test offer now';

  @override
  String get debugOfferDelayed => 'Show test offer in 10 s';

  @override
  String get debugOfferScheduled => 'Test offer in 10 s. Lock the phone now.';

  @override
  String get splashLoading => 'Getting things ready…';

  @override
  String get splashErrorTitle => 'Couldn\'t connect';

  @override
  String get updateRequiredTitle => 'Update required';

  @override
  String get updateRequiredBody =>
      'This version of Jivo Rider is no longer supported. Update the app to keep receiving orders.';

  @override
  String get updateAvailableTitle => 'Update available';

  @override
  String get updateAvailableBody =>
      'A newer version of Jivo Rider is available, with fixes and improvements.';

  @override
  String get updateNow => 'Update now';

  @override
  String get updateLater => 'Later';

  @override
  String get updateStoreOpenFailed =>
      'Couldn\'t open the Play Store. Update Jivo Rider from the Play Store app.';

  @override
  String get maintenanceTitle => 'We\'ll be back soon';

  @override
  String get maintenanceDefaultMessage =>
      'Jivo Rider is under maintenance. Please try again in a little while.';

  @override
  String get loginTitle => 'Log in to Jivo Rider';

  @override
  String get loginSubtitle =>
      'Enter your mobile number. We\'ll send you a one-time code by SMS.';

  @override
  String get loginPhoneLabel => 'Mobile number';

  @override
  String get loginPhoneHint => '98765 43210';

  @override
  String get loginPhoneEmpty => 'Enter your mobile number.';

  @override
  String get loginPhoneIncomplete => 'Enter all 10 digits.';

  @override
  String get loginPhoneInvalid =>
      'Enter a valid Indian mobile number starting with 6, 7, 8 or 9.';

  @override
  String loginConsent(String terms, String privacy) {
    return 'By continuing, you agree to the $terms and the $privacy.';
  }

  @override
  String get loginTermsLink => 'Terms of Use';

  @override
  String get loginPrivacyLink => 'Privacy Policy';

  @override
  String get loginGetOtp => 'Get OTP';

  @override
  String get loginSessionExpired =>
      'Your session has ended. Please log in again.';

  @override
  String get otpTitle => 'Enter the code';

  @override
  String otpSentTo(int length, String phone) {
    return 'We sent a $length-digit code to $phone.';
  }

  @override
  String get otpChangeNumber => 'Change number';

  @override
  String get otpFieldLabel => 'One-time code';

  @override
  String get otpVerify => 'Verify';

  @override
  String get otpResend => 'Resend code';

  @override
  String otpResendIn(int seconds) {
    return 'Resend code in $seconds s';
  }

  @override
  String get otpGetNewCode => 'Get a new code';

  @override
  String otpWrongCode(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Wrong code. $count attempts left.',
      one: 'Wrong code. 1 attempt left.',
    );
    return '$_temp0';
  }

  @override
  String get otpExpired => 'This code has expired. Get a new code.';

  @override
  String authRateLimited(int minutes) {
    String _temp0 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: 'Too many attempts. Try again in $minutes minutes.',
      one: 'Too many attempts. Try again in 1 minute.',
    );
    return '$_temp0';
  }

  @override
  String get logout => 'Log out';

  @override
  String get logoutBlockedOnline => 'Go offline before logging out.';

  @override
  String get registerTitle => 'Become a Jivo rider';

  @override
  String get registerBody =>
      'Rider registration and document upload open in an upcoming update. You\'ll be able to sign up right here.';

  @override
  String get statusPendingTitle => 'Documents under review';

  @override
  String get statusPendingBody =>
      'Jivo is checking your documents. You\'ll be able to go online once they are approved.';

  @override
  String get statusRejectedTitle => 'Documents not approved';

  @override
  String get statusRejectedBody =>
      'Some of your documents need to be uploaded again. Contact support for details.';

  @override
  String get statusSuspendedTitle => 'Account suspended';

  @override
  String get statusSuspendedBody =>
      'Your rider account is suspended. Contact Jivo support to continue.';

  @override
  String get statusUnknownTitle => 'Account status unavailable';

  @override
  String get statusUnknownBody =>
      'This version of the app can\'t show your account status. Update the app or contact support.';

  @override
  String get callSupport => 'Call support';
}
