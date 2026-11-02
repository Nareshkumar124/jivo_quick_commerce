import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[Locale('en')];

  /// App name (D-06).
  ///
  /// In en, this message translates to:
  /// **'Jivo Rider'**
  String get appTitle;

  /// Shows the build flavor on the placeholder home screen.
  ///
  /// In en, this message translates to:
  /// **'Build: {flavor}'**
  String homeBuildLabel(String flavor);

  /// No description provided for @homePlaceholderBody.
  ///
  /// In en, this message translates to:
  /// **'Login, shifts and order offers arrive in later phases.'**
  String get homePlaceholderBody;

  /// No description provided for @homeDevToolsButton.
  ///
  /// In en, this message translates to:
  /// **'Developer tools'**
  String get homeDevToolsButton;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get retry;

  /// No description provided for @done.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get done;

  /// No description provided for @permissionsTitle.
  ///
  /// In en, this message translates to:
  /// **'Before you go online'**
  String get permissionsTitle;

  /// No description provided for @permissionsIntro.
  ///
  /// In en, this message translates to:
  /// **'Jivo Rider needs these to send you orders and track your deliveries.'**
  String get permissionsIntro;

  /// No description provided for @permissionsLoadError.
  ///
  /// In en, this message translates to:
  /// **'Could not check permissions.'**
  String get permissionsLoadError;

  /// No description provided for @permissionsAllSet.
  ///
  /// In en, this message translates to:
  /// **'All set. You can go online.'**
  String get permissionsAllSet;

  /// No description provided for @gateStepDisclosure.
  ///
  /// In en, this message translates to:
  /// **'How we use your location'**
  String get gateStepDisclosure;

  /// No description provided for @gateStepDisclosureHint.
  ///
  /// In en, this message translates to:
  /// **'Read this before we ask for location.'**
  String get gateStepDisclosureHint;

  /// No description provided for @gateStepLocationWhenInUse.
  ///
  /// In en, this message translates to:
  /// **'Location access'**
  String get gateStepLocationWhenInUse;

  /// No description provided for @gateStepLocationWhenInUseHint.
  ///
  /// In en, this message translates to:
  /// **'Tap Allow on the next screen.'**
  String get gateStepLocationWhenInUseHint;

  /// No description provided for @gateStepLocationAlways.
  ///
  /// In en, this message translates to:
  /// **'Location: Allow all the time'**
  String get gateStepLocationAlways;

  /// No description provided for @gateStepLocationAlwaysHint.
  ///
  /// In en, this message translates to:
  /// **'On the next screen, choose \"Allow all the time\".'**
  String get gateStepLocationAlwaysHint;

  /// No description provided for @gateStepNotifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get gateStepNotifications;

  /// No description provided for @gateStepNotificationsHint.
  ///
  /// In en, this message translates to:
  /// **'So you hear new orders and see that you are online.'**
  String get gateStepNotificationsHint;

  /// No description provided for @gateStepBattery.
  ///
  /// In en, this message translates to:
  /// **'No battery restrictions'**
  String get gateStepBattery;

  /// No description provided for @gateStepBatteryHint.
  ///
  /// In en, this message translates to:
  /// **'So your phone does not stop the app while you ride.'**
  String get gateStepBatteryHint;

  /// No description provided for @gateStepGps.
  ///
  /// In en, this message translates to:
  /// **'GPS on'**
  String get gateStepGps;

  /// No description provided for @gateStepGpsHint.
  ///
  /// In en, this message translates to:
  /// **'Switch on location in your phone settings.'**
  String get gateStepGpsHint;

  /// No description provided for @gateStatusDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get gateStatusDone;

  /// No description provided for @gateStatusNeeded.
  ///
  /// In en, this message translates to:
  /// **'Needed'**
  String get gateStatusNeeded;

  /// No description provided for @gateStatusBlocked.
  ///
  /// In en, this message translates to:
  /// **'Blocked: open settings'**
  String get gateStatusBlocked;

  /// No description provided for @gateActionDisclosure.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get gateActionDisclosure;

  /// No description provided for @gateActionLocationWhenInUse.
  ///
  /// In en, this message translates to:
  /// **'Allow location'**
  String get gateActionLocationWhenInUse;

  /// No description provided for @gateActionLocationAlways.
  ///
  /// In en, this message translates to:
  /// **'Allow all the time'**
  String get gateActionLocationAlways;

  /// No description provided for @gateActionNotifications.
  ///
  /// In en, this message translates to:
  /// **'Allow notifications'**
  String get gateActionNotifications;

  /// No description provided for @gateActionBattery.
  ///
  /// In en, this message translates to:
  /// **'Remove battery restriction'**
  String get gateActionBattery;

  /// No description provided for @gateActionGps.
  ///
  /// In en, this message translates to:
  /// **'Turn on GPS'**
  String get gateActionGps;

  /// No description provided for @gateActionOpenSettings.
  ///
  /// In en, this message translates to:
  /// **'Open settings'**
  String get gateActionOpenSettings;

  /// No description provided for @fullScreenIntentTitle.
  ///
  /// In en, this message translates to:
  /// **'Full-screen order alerts'**
  String get fullScreenIntentTitle;

  /// No description provided for @fullScreenIntentBody.
  ///
  /// In en, this message translates to:
  /// **'Allow full-screen alerts so new orders show even when your phone is locked.'**
  String get fullScreenIntentBody;

  /// No description provided for @fullScreenIntentAction.
  ///
  /// In en, this message translates to:
  /// **'Allow full-screen alerts'**
  String get fullScreenIntentAction;

  /// No description provided for @oemTitle.
  ///
  /// In en, this message translates to:
  /// **'Keep Jivo Rider running'**
  String get oemTitle;

  /// No description provided for @oemXiaomi.
  ///
  /// In en, this message translates to:
  /// **'Xiaomi, Redmi, POCO: open App settings, turn Autostart on, and set Battery saver to No restrictions.'**
  String get oemXiaomi;

  /// No description provided for @oemOppo.
  ///
  /// In en, this message translates to:
  /// **'OPPO: open App settings > Battery, then allow background activity and auto launch.'**
  String get oemOppo;

  /// No description provided for @oemVivo.
  ///
  /// In en, this message translates to:
  /// **'vivo, iQOO: open App settings > Battery, allow high background power use, and turn Autostart on.'**
  String get oemVivo;

  /// No description provided for @oemRealme.
  ///
  /// In en, this message translates to:
  /// **'realme: open App settings > Battery, then allow background activity and auto launch.'**
  String get oemRealme;

  /// No description provided for @oemOneplus.
  ///
  /// In en, this message translates to:
  /// **'OnePlus: open App settings > Battery, choose Unrestricted, and allow auto launch.'**
  String get oemOneplus;

  /// No description provided for @oemAction.
  ///
  /// In en, this message translates to:
  /// **'Open app settings'**
  String get oemAction;

  /// No description provided for @disclosureTitle.
  ///
  /// In en, this message translates to:
  /// **'Your location while you\'re online'**
  String get disclosureTitle;

  /// No description provided for @disclosureBody.
  ///
  /// In en, this message translates to:
  /// **'Jivo Rider collects location data to send you delivery offers near your store, show customers where their order is, and calculate your distance pay, even when the app is closed or not in use.'**
  String get disclosureBody;

  /// No description provided for @disclosureOnlineOnly.
  ///
  /// In en, this message translates to:
  /// **'Location is collected only while you are online. It stops as soon as you go offline.'**
  String get disclosureOnlineOnly;

  /// No description provided for @disclosureSharing.
  ///
  /// In en, this message translates to:
  /// **'Your live location is shared with Jivo operations and with the customer whose order you are delivering.'**
  String get disclosureSharing;

  /// No description provided for @disclosureNextSteps.
  ///
  /// In en, this message translates to:
  /// **'Next, allow location and then choose \"Allow all the time\".'**
  String get disclosureNextSteps;

  /// No description provided for @disclosureAccept.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get disclosureAccept;

  /// No description provided for @disclosureDecline.
  ///
  /// In en, this message translates to:
  /// **'Not now'**
  String get disclosureDecline;

  /// No description provided for @onlineNotificationTitle.
  ///
  /// In en, this message translates to:
  /// **'You\'re online'**
  String get onlineNotificationTitle;

  /// No description provided for @onlineNotificationText.
  ///
  /// In en, this message translates to:
  /// **'Jivo Rider is using your location for deliveries.'**
  String get onlineNotificationText;

  /// No description provided for @onlineChannelName.
  ///
  /// In en, this message translates to:
  /// **'Online status'**
  String get onlineChannelName;

  /// No description provided for @onlineChannelDescription.
  ///
  /// In en, this message translates to:
  /// **'Shown while you are online and your location is shared.'**
  String get onlineChannelDescription;

  /// No description provided for @offerChannelName.
  ///
  /// In en, this message translates to:
  /// **'New order offers'**
  String get offerChannelName;

  /// No description provided for @offerChannelDescription.
  ///
  /// In en, this message translates to:
  /// **'Rings and opens full screen when a new order is offered to you.'**
  String get offerChannelDescription;

  /// No description provided for @testOfferTitle.
  ///
  /// In en, this message translates to:
  /// **'New order offer (test)'**
  String get testOfferTitle;

  /// No description provided for @testOfferBody.
  ///
  /// In en, this message translates to:
  /// **'Test store to Sector 21 · 2.4 km · Prepaid'**
  String get testOfferBody;

  /// No description provided for @offerPreviewTitle.
  ///
  /// In en, this message translates to:
  /// **'Test offer'**
  String get offerPreviewTitle;

  /// No description provided for @offerPreviewBody.
  ///
  /// In en, this message translates to:
  /// **'This screen was opened by the offer alert. The real offer screen comes in Phase 5.'**
  String get offerPreviewBody;

  /// No description provided for @offerPreviewDismiss.
  ///
  /// In en, this message translates to:
  /// **'Dismiss'**
  String get offerPreviewDismiss;

  /// No description provided for @debugTitle.
  ///
  /// In en, this message translates to:
  /// **'Location spike (dev)'**
  String get debugTitle;

  /// No description provided for @debugStatusOnline.
  ///
  /// In en, this message translates to:
  /// **'Online: location service running'**
  String get debugStatusOnline;

  /// No description provided for @debugStatusOffline.
  ///
  /// In en, this message translates to:
  /// **'Offline: no location tracking'**
  String get debugStatusOffline;

  /// No description provided for @debugGoOnline.
  ///
  /// In en, this message translates to:
  /// **'Go online'**
  String get debugGoOnline;

  /// No description provided for @debugGoOffline.
  ///
  /// In en, this message translates to:
  /// **'Go offline'**
  String get debugGoOffline;

  /// No description provided for @debugPermissionsButton.
  ///
  /// In en, this message translates to:
  /// **'Permissions gate'**
  String get debugPermissionsButton;

  /// No description provided for @debugPermissionsMissing.
  ///
  /// In en, this message translates to:
  /// **'Some permissions are missing. Fix them before going online.'**
  String get debugPermissionsMissing;

  /// No description provided for @debugStartFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not start the location service: {error}'**
  String debugStartFailed(String error);

  /// No description provided for @debugModeIdle.
  ///
  /// In en, this message translates to:
  /// **'Idle'**
  String get debugModeIdle;

  /// No description provided for @debugModeOnTask.
  ///
  /// In en, this message translates to:
  /// **'On task'**
  String get debugModeOnTask;

  /// No description provided for @debugSimulateOffline.
  ///
  /// In en, this message translates to:
  /// **'Simulate no network (fake uploader)'**
  String get debugSimulateOffline;

  /// No description provided for @debugFlushNow.
  ///
  /// In en, this message translates to:
  /// **'Upload now'**
  String get debugFlushNow;

  /// No description provided for @debugStatsIntervals.
  ///
  /// In en, this message translates to:
  /// **'Fix every {sample} s, upload every {upload} s'**
  String debugStatsIntervals(int sample, int upload);

  /// No description provided for @debugStatsCounts.
  ///
  /// In en, this message translates to:
  /// **'Buffered {buffered} · Uploaded {uploaded} · Dropped {dropped} · Rejected {rejected}'**
  String debugStatsCounts(
    int buffered,
    int uploaded,
    int dropped,
    int rejected,
  );

  /// No description provided for @debugStatsLastFix.
  ///
  /// In en, this message translates to:
  /// **'Last fix: {lat}, {lng} (±{accuracy} m) at {time}'**
  String debugStatsLastFix(
    String lat,
    String lng,
    String accuracy,
    String time,
  );

  /// No description provided for @debugStatsNoFix.
  ///
  /// In en, this message translates to:
  /// **'No fix yet'**
  String get debugStatsNoFix;

  /// No description provided for @debugStatsLastUpload.
  ///
  /// In en, this message translates to:
  /// **'Last upload: {status} at {time}'**
  String debugStatsLastUpload(String status, String time);

  /// No description provided for @debugStatsLastError.
  ///
  /// In en, this message translates to:
  /// **'Last error: {error}'**
  String debugStatsLastError(String error);

  /// No description provided for @debugOfferSection.
  ///
  /// In en, this message translates to:
  /// **'Offer alert'**
  String get debugOfferSection;

  /// No description provided for @debugOfferNow.
  ///
  /// In en, this message translates to:
  /// **'Show test offer now'**
  String get debugOfferNow;

  /// No description provided for @debugOfferDelayed.
  ///
  /// In en, this message translates to:
  /// **'Show test offer in 10 s'**
  String get debugOfferDelayed;

  /// No description provided for @debugOfferScheduled.
  ///
  /// In en, this message translates to:
  /// **'Test offer in 10 s. Lock the phone now.'**
  String get debugOfferScheduled;

  /// No description provided for @splashLoading.
  ///
  /// In en, this message translates to:
  /// **'Getting things ready…'**
  String get splashLoading;

  /// No description provided for @splashErrorTitle.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t connect'**
  String get splashErrorTitle;

  /// No description provided for @updateRequiredTitle.
  ///
  /// In en, this message translates to:
  /// **'Update required'**
  String get updateRequiredTitle;

  /// No description provided for @updateRequiredBody.
  ///
  /// In en, this message translates to:
  /// **'This version of Jivo Rider is no longer supported. Update the app to keep receiving orders.'**
  String get updateRequiredBody;

  /// No description provided for @updateAvailableTitle.
  ///
  /// In en, this message translates to:
  /// **'Update available'**
  String get updateAvailableTitle;

  /// No description provided for @updateAvailableBody.
  ///
  /// In en, this message translates to:
  /// **'A newer version of Jivo Rider is available, with fixes and improvements.'**
  String get updateAvailableBody;

  /// No description provided for @updateNow.
  ///
  /// In en, this message translates to:
  /// **'Update now'**
  String get updateNow;

  /// No description provided for @updateLater.
  ///
  /// In en, this message translates to:
  /// **'Later'**
  String get updateLater;

  /// No description provided for @updateStoreOpenFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t open the Play Store. Update Jivo Rider from the Play Store app.'**
  String get updateStoreOpenFailed;

  /// No description provided for @maintenanceTitle.
  ///
  /// In en, this message translates to:
  /// **'We\'ll be back soon'**
  String get maintenanceTitle;

  /// No description provided for @maintenanceDefaultMessage.
  ///
  /// In en, this message translates to:
  /// **'Jivo Rider is under maintenance. Please try again in a little while.'**
  String get maintenanceDefaultMessage;

  /// No description provided for @loginTitle.
  ///
  /// In en, this message translates to:
  /// **'Log in to Jivo Rider'**
  String get loginTitle;

  /// No description provided for @loginSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Enter your mobile number. We\'ll send you a one-time code by SMS.'**
  String get loginSubtitle;

  /// No description provided for @loginPhoneLabel.
  ///
  /// In en, this message translates to:
  /// **'Mobile number'**
  String get loginPhoneLabel;

  /// No description provided for @loginPhoneHint.
  ///
  /// In en, this message translates to:
  /// **'98765 43210'**
  String get loginPhoneHint;

  /// No description provided for @loginPhoneEmpty.
  ///
  /// In en, this message translates to:
  /// **'Enter your mobile number.'**
  String get loginPhoneEmpty;

  /// No description provided for @loginPhoneIncomplete.
  ///
  /// In en, this message translates to:
  /// **'Enter all 10 digits.'**
  String get loginPhoneIncomplete;

  /// No description provided for @loginPhoneInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid Indian mobile number starting with 6, 7, 8 or 9.'**
  String get loginPhoneInvalid;

  /// Consent shown above the Get OTP button. {terms} and {privacy} become links; their text is loginTermsLink and loginPrivacyLink.
  ///
  /// In en, this message translates to:
  /// **'By continuing, you agree to the {terms} and the {privacy}.'**
  String loginConsent(String terms, String privacy);

  /// No description provided for @loginTermsLink.
  ///
  /// In en, this message translates to:
  /// **'Terms of Use'**
  String get loginTermsLink;

  /// No description provided for @loginPrivacyLink.
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get loginPrivacyLink;

  /// No description provided for @loginGetOtp.
  ///
  /// In en, this message translates to:
  /// **'Get OTP'**
  String get loginGetOtp;

  /// No description provided for @loginSessionExpired.
  ///
  /// In en, this message translates to:
  /// **'Your session has ended. Please log in again.'**
  String get loginSessionExpired;

  /// No description provided for @otpTitle.
  ///
  /// In en, this message translates to:
  /// **'Enter the code'**
  String get otpTitle;

  /// No description provided for @otpSentTo.
  ///
  /// In en, this message translates to:
  /// **'We sent a {length}-digit code to {phone}.'**
  String otpSentTo(int length, String phone);

  /// No description provided for @otpChangeNumber.
  ///
  /// In en, this message translates to:
  /// **'Change number'**
  String get otpChangeNumber;

  /// No description provided for @otpFieldLabel.
  ///
  /// In en, this message translates to:
  /// **'One-time code'**
  String get otpFieldLabel;

  /// No description provided for @otpVerify.
  ///
  /// In en, this message translates to:
  /// **'Verify'**
  String get otpVerify;

  /// No description provided for @otpResend.
  ///
  /// In en, this message translates to:
  /// **'Resend code'**
  String get otpResend;

  /// No description provided for @otpResendIn.
  ///
  /// In en, this message translates to:
  /// **'Resend code in {seconds} s'**
  String otpResendIn(int seconds);

  /// No description provided for @otpGetNewCode.
  ///
  /// In en, this message translates to:
  /// **'Get a new code'**
  String get otpGetNewCode;

  /// No description provided for @otpWrongCode.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Wrong code. 1 attempt left.} other{Wrong code. {count} attempts left.}}'**
  String otpWrongCode(int count);

  /// No description provided for @otpExpired.
  ///
  /// In en, this message translates to:
  /// **'This code has expired. Get a new code.'**
  String get otpExpired;

  /// No description provided for @authRateLimited.
  ///
  /// In en, this message translates to:
  /// **'{minutes, plural, =1{Too many attempts. Try again in 1 minute.} other{Too many attempts. Try again in {minutes} minutes.}}'**
  String authRateLimited(int minutes);

  /// No description provided for @logout.
  ///
  /// In en, this message translates to:
  /// **'Log out'**
  String get logout;

  /// No description provided for @logoutBlockedOnline.
  ///
  /// In en, this message translates to:
  /// **'Go offline before logging out.'**
  String get logoutBlockedOnline;

  /// No description provided for @registerTitle.
  ///
  /// In en, this message translates to:
  /// **'Become a Jivo rider'**
  String get registerTitle;

  /// No description provided for @registerBody.
  ///
  /// In en, this message translates to:
  /// **'Rider registration and document upload open in an upcoming update. You\'ll be able to sign up right here.'**
  String get registerBody;

  /// No description provided for @statusPendingTitle.
  ///
  /// In en, this message translates to:
  /// **'Documents under review'**
  String get statusPendingTitle;

  /// No description provided for @statusPendingBody.
  ///
  /// In en, this message translates to:
  /// **'Jivo is checking your documents. You\'ll be able to go online once they are approved.'**
  String get statusPendingBody;

  /// No description provided for @statusRejectedTitle.
  ///
  /// In en, this message translates to:
  /// **'Documents not approved'**
  String get statusRejectedTitle;

  /// No description provided for @statusRejectedBody.
  ///
  /// In en, this message translates to:
  /// **'Some of your documents need to be uploaded again. Contact support for details.'**
  String get statusRejectedBody;

  /// No description provided for @statusSuspendedTitle.
  ///
  /// In en, this message translates to:
  /// **'Account suspended'**
  String get statusSuspendedTitle;

  /// No description provided for @statusSuspendedBody.
  ///
  /// In en, this message translates to:
  /// **'Your rider account is suspended. Contact Jivo support to continue.'**
  String get statusSuspendedBody;

  /// No description provided for @statusUnknownTitle.
  ///
  /// In en, this message translates to:
  /// **'Account status unavailable'**
  String get statusUnknownTitle;

  /// No description provided for @statusUnknownBody.
  ///
  /// In en, this message translates to:
  /// **'This version of the app can\'t show your account status. Update the app or contact support.'**
  String get statusUnknownBody;

  /// No description provided for @callSupport.
  ///
  /// In en, this message translates to:
  /// **'Call support'**
  String get callSupport;

  /// Progress through registration, documents and bank details.
  ///
  /// In en, this message translates to:
  /// **'Step {step} of {total}'**
  String onboardingStepOf(int step, int total);

  /// Server VALIDATION_ERROR on an onboarding form.
  ///
  /// In en, this message translates to:
  /// **'Some details were not accepted. Check them and try again.'**
  String get onboardingCheckDetails;

  /// No description provided for @onboardingLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading your application…'**
  String get onboardingLoading;

  /// No description provided for @onboardingLoadError.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load your application'**
  String get onboardingLoadError;

  /// No description provided for @fieldRequired.
  ///
  /// In en, this message translates to:
  /// **'This is required.'**
  String get fieldRequired;

  /// No description provided for @fieldNameInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a name with letters only, at least 2 characters.'**
  String get fieldNameInvalid;

  /// No description provided for @fieldDobInFuture.
  ///
  /// In en, this message translates to:
  /// **'Date of birth can\'t be in the future.'**
  String get fieldDobInFuture;

  /// No description provided for @fieldDobUnderage.
  ///
  /// In en, this message translates to:
  /// **'You must be at least {age} years old to ride with Jivo.'**
  String fieldDobUnderage(int age);

  /// No description provided for @fieldPhoneSameAsRider.
  ///
  /// In en, this message translates to:
  /// **'Enter someone else\'s number, not your own.'**
  String get fieldPhoneSameAsRider;

  /// No description provided for @fieldVehicleNumberInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter the vehicle number as on the number plate, like DL 3C AB 1234.'**
  String get fieldVehicleNumberInvalid;

  /// No description provided for @fieldAccountNumberInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid account number (9 to 18 digits).'**
  String get fieldAccountNumberInvalid;

  /// No description provided for @fieldAccountNumbersMismatch.
  ///
  /// In en, this message translates to:
  /// **'The account numbers don\'t match.'**
  String get fieldAccountNumbersMismatch;

  /// No description provided for @fieldIfscInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter the 11-character IFSC, like HDFC0001234.'**
  String get fieldIfscInvalid;

  /// No description provided for @fieldUpiInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid UPI ID, like name@okbank.'**
  String get fieldUpiInvalid;

  /// No description provided for @fieldAadhaarInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter your 12-digit Aadhaar number exactly as printed.'**
  String get fieldAadhaarInvalid;

  /// No description provided for @fieldPanInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter your PAN exactly as printed, like ABCDE1234F.'**
  String get fieldPanInvalid;

  /// No description provided for @fieldDrivingLicenceInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter your licence number exactly as printed on the card.'**
  String get fieldDrivingLicenceInvalid;

  /// No description provided for @registerIntro.
  ///
  /// In en, this message translates to:
  /// **'Tell us about yourself and your vehicle. Next, you\'ll upload your documents.'**
  String get registerIntro;

  /// No description provided for @registerSectionAboutYou.
  ///
  /// In en, this message translates to:
  /// **'About you'**
  String get registerSectionAboutYou;

  /// No description provided for @registerFullName.
  ///
  /// In en, this message translates to:
  /// **'Full name (as on Aadhaar)'**
  String get registerFullName;

  /// No description provided for @registerDob.
  ///
  /// In en, this message translates to:
  /// **'Date of birth'**
  String get registerDob;

  /// No description provided for @registerDobHint.
  ///
  /// In en, this message translates to:
  /// **'Choose the date'**
  String get registerDobHint;

  /// No description provided for @registerDobPickerHelp.
  ///
  /// In en, this message translates to:
  /// **'Select your date of birth'**
  String get registerDobPickerHelp;

  /// No description provided for @registerSectionEmergency.
  ///
  /// In en, this message translates to:
  /// **'Emergency contact'**
  String get registerSectionEmergency;

  /// No description provided for @registerEmergencyHelp.
  ///
  /// In en, this message translates to:
  /// **'Someone Jivo can call if something happens to you on a delivery.'**
  String get registerEmergencyHelp;

  /// No description provided for @registerEmergencyName.
  ///
  /// In en, this message translates to:
  /// **'Contact name'**
  String get registerEmergencyName;

  /// No description provided for @registerEmergencyPhone.
  ///
  /// In en, this message translates to:
  /// **'Contact mobile number'**
  String get registerEmergencyPhone;

  /// No description provided for @registerSectionStore.
  ///
  /// In en, this message translates to:
  /// **'Preferred store'**
  String get registerSectionStore;

  /// No description provided for @registerStoreLabel.
  ///
  /// In en, this message translates to:
  /// **'Store you want to deliver for'**
  String get registerStoreLabel;

  /// No description provided for @registerStoreHelp.
  ///
  /// In en, this message translates to:
  /// **'Jivo confirms your store when your account is approved.'**
  String get registerStoreHelp;

  /// A dark store in the store dropdown.
  ///
  /// In en, this message translates to:
  /// **'{name}, {city}'**
  String registerStoreOption(String name, String city);

  /// No description provided for @registerStoresLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading stores…'**
  String get registerStoresLoading;

  /// No description provided for @registerStoresError.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load the stores.'**
  String get registerStoresError;

  /// No description provided for @registerSectionVehicle.
  ///
  /// In en, this message translates to:
  /// **'Your vehicle'**
  String get registerSectionVehicle;

  /// No description provided for @registerVehicleNumber.
  ///
  /// In en, this message translates to:
  /// **'Vehicle number'**
  String get registerVehicleNumber;

  /// No description provided for @registerVehicleNumberHint.
  ///
  /// In en, this message translates to:
  /// **'DL 3C AB 1234'**
  String get registerVehicleNumberHint;

  /// No description provided for @registerSubmit.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get registerSubmit;

  /// No description provided for @vehicleBicycle.
  ///
  /// In en, this message translates to:
  /// **'Bicycle'**
  String get vehicleBicycle;

  /// No description provided for @vehicleEBike.
  ///
  /// In en, this message translates to:
  /// **'E-bike'**
  String get vehicleEBike;

  /// No description provided for @vehicleMotorbike.
  ///
  /// In en, this message translates to:
  /// **'Motorbike'**
  String get vehicleMotorbike;

  /// No description provided for @vehicleScooter.
  ///
  /// In en, this message translates to:
  /// **'Scooter'**
  String get vehicleScooter;

  /// No description provided for @statusFinishTitle.
  ///
  /// In en, this message translates to:
  /// **'Finish your application'**
  String get statusFinishTitle;

  /// No description provided for @statusFinishBody.
  ///
  /// In en, this message translates to:
  /// **'Complete these steps so Jivo can review your application.'**
  String get statusFinishBody;

  /// No description provided for @statusStepDetails.
  ///
  /// In en, this message translates to:
  /// **'Personal and vehicle details'**
  String get statusStepDetails;

  /// No description provided for @statusStepDocuments.
  ///
  /// In en, this message translates to:
  /// **'Documents'**
  String get statusStepDocuments;

  /// No description provided for @statusStepBank.
  ///
  /// In en, this message translates to:
  /// **'Bank details'**
  String get statusStepBank;

  /// No description provided for @statusStepDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get statusStepDone;

  /// No description provided for @statusStepNeeded.
  ///
  /// In en, this message translates to:
  /// **'Needed'**
  String get statusStepNeeded;

  /// No description provided for @statusStepDocumentsProgress.
  ///
  /// In en, this message translates to:
  /// **'{done} of {total} uploaded'**
  String statusStepDocumentsProgress(int done, int total);

  /// No description provided for @statusStepDocumentsFix.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 document needs a new photo} other{{count} documents need new photos}}'**
  String statusStepDocumentsFix(int count);

  /// No description provided for @statusActionUploadDocuments.
  ///
  /// In en, this message translates to:
  /// **'Upload documents'**
  String get statusActionUploadDocuments;

  /// No description provided for @statusActionAddBank.
  ///
  /// In en, this message translates to:
  /// **'Add bank details'**
  String get statusActionAddBank;

  /// No description provided for @statusActionCheck.
  ///
  /// In en, this message translates to:
  /// **'Check status'**
  String get statusActionCheck;

  /// No description provided for @statusActionViewDocuments.
  ///
  /// In en, this message translates to:
  /// **'View documents'**
  String get statusActionViewDocuments;

  /// No description provided for @statusRejectedFixBody.
  ///
  /// In en, this message translates to:
  /// **'Fix the items below. Jivo reviews your application again after you send them.'**
  String get statusRejectedFixBody;

  /// No description provided for @statusRejectedReasonLabel.
  ///
  /// In en, this message translates to:
  /// **'Reason from Jivo'**
  String get statusRejectedReasonLabel;

  /// No description provided for @statusActionFixDocuments.
  ///
  /// In en, this message translates to:
  /// **'Upload documents again'**
  String get statusActionFixDocuments;

  /// No description provided for @statusActionFixBank.
  ///
  /// In en, this message translates to:
  /// **'Update bank details'**
  String get statusActionFixBank;

  /// No description provided for @statusApprovedTitle.
  ///
  /// In en, this message translates to:
  /// **'You\'re approved!'**
  String get statusApprovedTitle;

  /// No description provided for @statusApprovedBody.
  ///
  /// In en, this message translates to:
  /// **'Your home store is {store}. You can now go online and start delivering.'**
  String statusApprovedBody(String store);

  /// No description provided for @statusActionStart.
  ///
  /// In en, this message translates to:
  /// **'Start delivering'**
  String get statusActionStart;

  /// Dev flavor only: plays the ops review against the fake backend.
  ///
  /// In en, this message translates to:
  /// **'Simulate review (dev)'**
  String get statusDevReview;

  /// No description provided for @statusDevApprove.
  ///
  /// In en, this message translates to:
  /// **'Approve (fake)'**
  String get statusDevApprove;

  /// No description provided for @statusDevReject.
  ///
  /// In en, this message translates to:
  /// **'Reject the PAN (fake)'**
  String get statusDevReject;

  /// No description provided for @documentsTitle.
  ///
  /// In en, this message translates to:
  /// **'Documents'**
  String get documentsTitle;

  /// No description provided for @documentsIntro.
  ///
  /// In en, this message translates to:
  /// **'Take clear photos in good light. Each photo must show the whole document.'**
  String get documentsIntro;

  /// No description provided for @documentsProgress.
  ///
  /// In en, this message translates to:
  /// **'{done} of {total} done. Upload every document to continue.'**
  String documentsProgress(int done, int total);

  /// No description provided for @documentsContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get documentsContinue;

  /// No description provided for @docPhoto.
  ///
  /// In en, this message translates to:
  /// **'Your photo (selfie)'**
  String get docPhoto;

  /// No description provided for @docAadhaarFront.
  ///
  /// In en, this message translates to:
  /// **'Aadhaar card: front'**
  String get docAadhaarFront;

  /// No description provided for @docAadhaarBack.
  ///
  /// In en, this message translates to:
  /// **'Aadhaar card: back'**
  String get docAadhaarBack;

  /// No description provided for @docPan.
  ///
  /// In en, this message translates to:
  /// **'PAN card'**
  String get docPan;

  /// No description provided for @docDrivingLicence.
  ///
  /// In en, this message translates to:
  /// **'Driving licence'**
  String get docDrivingLicence;

  /// No description provided for @docVehicleRc.
  ///
  /// In en, this message translates to:
  /// **'Vehicle RC'**
  String get docVehicleRc;

  /// No description provided for @docStatusNeeded.
  ///
  /// In en, this message translates to:
  /// **'Needed'**
  String get docStatusNeeded;

  /// No description provided for @docStatusPending.
  ///
  /// In en, this message translates to:
  /// **'In review'**
  String get docStatusPending;

  /// No description provided for @docStatusApproved.
  ///
  /// In en, this message translates to:
  /// **'Approved'**
  String get docStatusApproved;

  /// No description provided for @docStatusRejected.
  ///
  /// In en, this message translates to:
  /// **'Not accepted: upload again'**
  String get docStatusRejected;

  /// No description provided for @docActionUpload.
  ///
  /// In en, this message translates to:
  /// **'Upload'**
  String get docActionUpload;

  /// No description provided for @docActionReplace.
  ///
  /// In en, this message translates to:
  /// **'Replace'**
  String get docActionReplace;

  /// No description provided for @docActionReupload.
  ///
  /// In en, this message translates to:
  /// **'Upload again'**
  String get docActionReupload;

  /// Snackbar after a document upload.
  ///
  /// In en, this message translates to:
  /// **'{document} uploaded'**
  String docUploaded(String document);

  /// No description provided for @captureHintPhoto.
  ///
  /// In en, this message translates to:
  /// **'Take a clear photo of your face in good light. Remove your helmet, cap and sunglasses.'**
  String get captureHintPhoto;

  /// No description provided for @captureHintCard.
  ///
  /// In en, this message translates to:
  /// **'Put the card on a flat, dark surface. All four corners and the text must be clear, with no glare.'**
  String get captureHintCard;

  /// No description provided for @captureTakePhoto.
  ///
  /// In en, this message translates to:
  /// **'Take photo'**
  String get captureTakePhoto;

  /// No description provided for @captureChooseGallery.
  ///
  /// In en, this message translates to:
  /// **'Choose from gallery'**
  String get captureChooseGallery;

  /// No description provided for @captureProcessing.
  ///
  /// In en, this message translates to:
  /// **'Preparing the photo…'**
  String get captureProcessing;

  /// No description provided for @captureReady.
  ///
  /// In en, this message translates to:
  /// **'Photo ready'**
  String get captureReady;

  /// No description provided for @captureCheck.
  ///
  /// In en, this message translates to:
  /// **'Check that the photo is sharp and nothing is cut off.'**
  String get captureCheck;

  /// No description provided for @captureUpload.
  ///
  /// In en, this message translates to:
  /// **'Upload'**
  String get captureUpload;

  /// No description provided for @captureRetake.
  ///
  /// In en, this message translates to:
  /// **'Retake'**
  String get captureRetake;

  /// No description provided for @captureProblemPicker.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t open the camera or gallery. Allow Jivo Rider to use the camera in your phone settings, then try again.'**
  String get captureProblemPicker;

  /// No description provided for @captureProblemUnreadable.
  ///
  /// In en, this message translates to:
  /// **'That file can\'t be used. Take a new photo.'**
  String get captureProblemUnreadable;

  /// No description provided for @captureProblemTooLarge.
  ///
  /// In en, this message translates to:
  /// **'That photo is too large. Take a new photo.'**
  String get captureProblemTooLarge;

  /// No description provided for @numberAadhaar.
  ///
  /// In en, this message translates to:
  /// **'Aadhaar number'**
  String get numberAadhaar;

  /// No description provided for @numberPan.
  ///
  /// In en, this message translates to:
  /// **'PAN'**
  String get numberPan;

  /// No description provided for @numberDrivingLicence.
  ///
  /// In en, this message translates to:
  /// **'Driving licence number'**
  String get numberDrivingLicence;

  /// No description provided for @numberVehicleRc.
  ///
  /// In en, this message translates to:
  /// **'Vehicle number (as on the RC)'**
  String get numberVehicleRc;

  /// Helper under a document or account number once typed; only the masked form is shown.
  ///
  /// In en, this message translates to:
  /// **'Entered: {masked}'**
  String numberMaskedHelper(String masked);

  /// No description provided for @bankTitle.
  ///
  /// In en, this message translates to:
  /// **'Bank details'**
  String get bankTitle;

  /// No description provided for @bankIntro.
  ///
  /// In en, this message translates to:
  /// **'Jivo pays your earnings into this account.'**
  String get bankIntro;

  /// No description provided for @bankSaved.
  ///
  /// In en, this message translates to:
  /// **'Saved account {account} · {ifsc}'**
  String bankSaved(String account, String ifsc);

  /// No description provided for @bankSavedShort.
  ///
  /// In en, this message translates to:
  /// **'Account {account}'**
  String bankSavedShort(String account);

  /// No description provided for @bankReplaceHint.
  ///
  /// In en, this message translates to:
  /// **'To change it, enter the new details below.'**
  String get bankReplaceHint;

  /// No description provided for @bankHolderName.
  ///
  /// In en, this message translates to:
  /// **'Account holder name'**
  String get bankHolderName;

  /// No description provided for @bankAccountNumber.
  ///
  /// In en, this message translates to:
  /// **'Account number'**
  String get bankAccountNumber;

  /// No description provided for @bankConfirmAccountNumber.
  ///
  /// In en, this message translates to:
  /// **'Re-enter account number'**
  String get bankConfirmAccountNumber;

  /// No description provided for @bankIfsc.
  ///
  /// In en, this message translates to:
  /// **'IFSC'**
  String get bankIfsc;

  /// No description provided for @bankIfscHint.
  ///
  /// In en, this message translates to:
  /// **'HDFC0001234'**
  String get bankIfscHint;

  /// No description provided for @bankUpi.
  ///
  /// In en, this message translates to:
  /// **'UPI ID (optional)'**
  String get bankUpi;

  /// No description provided for @bankUpiHint.
  ///
  /// In en, this message translates to:
  /// **'name@okbank'**
  String get bankUpiHint;

  /// No description provided for @bankSave.
  ///
  /// In en, this message translates to:
  /// **'Save bank details'**
  String get bankSave;

  /// No description provided for @bankSavedToast.
  ///
  /// In en, this message translates to:
  /// **'Bank details saved'**
  String get bankSavedToast;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
