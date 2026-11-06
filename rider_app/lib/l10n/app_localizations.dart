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
  /// **'Jivo Rider uses your location in the background'**
  String get disclosureTitle;

  /// No description provided for @disclosureBody.
  ///
  /// In en, this message translates to:
  /// **'Jivo Rider collects location data to send you delivery offers near your store, guide you to customers, and show customers where their order is, even when the app is closed or not in use.'**
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
  /// **'I agree, turn on location'**
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

  /// No description provided for @offerTitle.
  ///
  /// In en, this message translates to:
  /// **'New order'**
  String get offerTitle;

  /// Offer notification title (rings, full screen).
  ///
  /// In en, this message translates to:
  /// **'New order offer'**
  String get offerAlertTitle;

  /// Offer notification body.
  ///
  /// In en, this message translates to:
  /// **'{store} to {locality}'**
  String offerAlertBody(String store, String locality);

  /// No description provided for @offerPrepaid.
  ///
  /// In en, this message translates to:
  /// **'Prepaid · nothing to collect'**
  String get offerPrepaid;

  /// No description provided for @offerCod.
  ///
  /// In en, this message translates to:
  /// **'Cash {amount} to collect'**
  String offerCod(String amount);

  /// No description provided for @offerPayout.
  ///
  /// In en, this message translates to:
  /// **'You earn about {amount}'**
  String offerPayout(String amount);

  /// Distance from the store to the customer, as sent by the server.
  ///
  /// In en, this message translates to:
  /// **'{km} km'**
  String distanceKm(String km);

  /// No description provided for @offerAccept.
  ///
  /// In en, this message translates to:
  /// **'Accept order'**
  String get offerAccept;

  /// No description provided for @offerReject.
  ///
  /// In en, this message translates to:
  /// **'Reject'**
  String get offerReject;

  /// No description provided for @offerRejectTitle.
  ///
  /// In en, this message translates to:
  /// **'Why are you rejecting? (optional)'**
  String get offerRejectTitle;

  /// No description provided for @offerRejectTooFar.
  ///
  /// In en, this message translates to:
  /// **'Too far'**
  String get offerRejectTooFar;

  /// No description provided for @offerRejectVehicle.
  ///
  /// In en, this message translates to:
  /// **'Vehicle problem'**
  String get offerRejectVehicle;

  /// No description provided for @offerRejectBreak.
  ///
  /// In en, this message translates to:
  /// **'Taking a break'**
  String get offerRejectBreak;

  /// No description provided for @offerRejectOther.
  ///
  /// In en, this message translates to:
  /// **'Other reason'**
  String get offerRejectOther;

  /// No description provided for @offerRejectSkip.
  ///
  /// In en, this message translates to:
  /// **'Reject without a reason'**
  String get offerRejectSkip;

  /// No description provided for @offerExpiredTitle.
  ///
  /// In en, this message translates to:
  /// **'Offer expired'**
  String get offerExpiredTitle;

  /// No description provided for @offerExpiredBody.
  ///
  /// In en, this message translates to:
  /// **'The time to accept ran out. New orders will come to you.'**
  String get offerExpiredBody;

  /// No description provided for @offerTakenTitle.
  ///
  /// In en, this message translates to:
  /// **'Order taken'**
  String get offerTakenTitle;

  /// No description provided for @offerTakenBody.
  ///
  /// In en, this message translates to:
  /// **'Another rider accepted this order first.'**
  String get offerTakenBody;

  /// No description provided for @offerWithdrawnTitle.
  ///
  /// In en, this message translates to:
  /// **'Order cancelled'**
  String get offerWithdrawnTitle;

  /// No description provided for @offerWithdrawnBody.
  ///
  /// In en, this message translates to:
  /// **'This order was cancelled before pickup. Wait for the next one.'**
  String get offerWithdrawnBody;

  /// No description provided for @offerOk.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get offerOk;

  /// No description provided for @taskOrderNumber.
  ///
  /// In en, this message translates to:
  /// **'Order {number}'**
  String taskOrderNumber(String number);

  /// No description provided for @taskRefresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get taskRefresh;

  /// No description provided for @taskNavigate.
  ///
  /// In en, this message translates to:
  /// **'Navigate'**
  String get taskNavigate;

  /// No description provided for @taskNoMapsApp.
  ///
  /// In en, this message translates to:
  /// **'No maps app found. Install Mappls or another maps app.'**
  String get taskNoMapsApp;

  /// No description provided for @taskCallCustomer.
  ///
  /// In en, this message translates to:
  /// **'Call'**
  String get taskCallCustomer;

  /// No description provided for @taskStateChanged.
  ///
  /// In en, this message translates to:
  /// **'This order changed. The screen now shows its latest step.'**
  String get taskStateChanged;

  /// No description provided for @taskLocationUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t get your location. Turn on GPS and try again.'**
  String get taskLocationUnavailable;

  /// No description provided for @taskOutsideGeofence.
  ///
  /// In en, this message translates to:
  /// **'You\'re not close enough yet. Move closer and try again.'**
  String get taskOutsideGeofence;

  /// No description provided for @taskOutsideGeofenceDistance.
  ///
  /// In en, this message translates to:
  /// **'You\'re {metres} m away. Move closer and try again.'**
  String taskOutsideGeofenceDistance(int metres);

  /// No description provided for @cashLimitExceeded.
  ///
  /// In en, this message translates to:
  /// **'Your cash in hand has reached the limit. Deposit cash at the store to get cash orders again.'**
  String get cashLimitExceeded;

  /// No description provided for @taskGoToStoreTitle.
  ///
  /// In en, this message translates to:
  /// **'Go to the store'**
  String get taskGoToStoreTitle;

  /// No description provided for @taskOrderPacking.
  ///
  /// In en, this message translates to:
  /// **'Store is packing: wait here'**
  String get taskOrderPacking;

  /// No description provided for @taskOrderReady.
  ///
  /// In en, this message translates to:
  /// **'Ready for pickup'**
  String get taskOrderReady;

  /// No description provided for @taskArrivedStore.
  ///
  /// In en, this message translates to:
  /// **'Arrived at store'**
  String get taskArrivedStore;

  /// No description provided for @taskPickupTitle.
  ///
  /// In en, this message translates to:
  /// **'Pick up the order'**
  String get taskPickupTitle;

  /// No description provided for @taskItemsTitle.
  ///
  /// In en, this message translates to:
  /// **'Check the items in the bag'**
  String get taskItemsTitle;

  /// No description provided for @pickupCodeHelp.
  ///
  /// In en, this message translates to:
  /// **'Scan the QR on the bag, or type the 4-character code printed on it.'**
  String get pickupCodeHelp;

  /// No description provided for @pickupCodeLabel.
  ///
  /// In en, this message translates to:
  /// **'Order code'**
  String get pickupCodeLabel;

  /// No description provided for @pickupCodeFormat.
  ///
  /// In en, this message translates to:
  /// **'Enter the 4-character code from the bag.'**
  String get pickupCodeFormat;

  /// No description provided for @pickupCodeWrong.
  ///
  /// In en, this message translates to:
  /// **'That code doesn\'t match this order. Check the bag and try again.'**
  String get pickupCodeWrong;

  /// No description provided for @pickupNotPacked.
  ///
  /// In en, this message translates to:
  /// **'The order isn\'t packed yet. Wait until the store marks it ready.'**
  String get pickupNotPacked;

  /// No description provided for @taskPickup.
  ///
  /// In en, this message translates to:
  /// **'Confirm pickup'**
  String get taskPickup;

  /// No description provided for @pickupScan.
  ///
  /// In en, this message translates to:
  /// **'Scan bag QR'**
  String get pickupScan;

  /// No description provided for @scanTitle.
  ///
  /// In en, this message translates to:
  /// **'Scan the bag QR code'**
  String get scanTitle;

  /// No description provided for @scanTypeInstead.
  ///
  /// In en, this message translates to:
  /// **'Type the code instead'**
  String get scanTypeInstead;

  /// No description provided for @scanNotJivoCode.
  ///
  /// In en, this message translates to:
  /// **'This QR isn\'t a Jivo order code.'**
  String get scanNotJivoCode;

  /// No description provided for @scanCameraUnavailable.
  ///
  /// In en, this message translates to:
  /// **'The camera isn\'t available. Type the code from the bag instead.'**
  String get scanCameraUnavailable;

  /// No description provided for @taskGoToCustomerTitle.
  ///
  /// In en, this message translates to:
  /// **'Deliver to the customer'**
  String get taskGoToCustomerTitle;

  /// No description provided for @taskLandmark.
  ///
  /// In en, this message translates to:
  /// **'Landmark: {landmark}'**
  String taskLandmark(String landmark);

  /// No description provided for @taskInstructions.
  ///
  /// In en, this message translates to:
  /// **'Note: {instructions}'**
  String taskInstructions(String instructions);

  /// No description provided for @taskCollectCash.
  ///
  /// In en, this message translates to:
  /// **'Collect {amount} in cash'**
  String taskCollectCash(String amount);

  /// No description provided for @taskArrivedCustomer.
  ///
  /// In en, this message translates to:
  /// **'Arrived at customer'**
  String get taskArrivedCustomer;

  /// No description provided for @taskCantDeliver.
  ///
  /// In en, this message translates to:
  /// **'Can\'t deliver…'**
  String get taskCantDeliver;

  /// No description provided for @arrivedOverride.
  ///
  /// In en, this message translates to:
  /// **'Not at the pin? Arrive anyway'**
  String get arrivedOverride;

  /// No description provided for @arrivedOverrideTitle.
  ///
  /// In en, this message translates to:
  /// **'Why are you outside the pin area?'**
  String get arrivedOverrideTitle;

  /// No description provided for @arrivedOverridePinWrong.
  ///
  /// In en, this message translates to:
  /// **'The map pin is in the wrong place'**
  String get arrivedOverridePinWrong;

  /// No description provided for @arrivedOverrideGate.
  ///
  /// In en, this message translates to:
  /// **'I\'m at the gate or lobby'**
  String get arrivedOverrideGate;

  /// No description provided for @otpStepTitle.
  ///
  /// In en, this message translates to:
  /// **'Enter the delivery code'**
  String get otpStepTitle;

  /// No description provided for @otpStepHelp.
  ///
  /// In en, this message translates to:
  /// **'Ask the customer for the 4-digit code in their app or SMS.'**
  String get otpStepHelp;

  /// No description provided for @otpStepLabel.
  ///
  /// In en, this message translates to:
  /// **'Delivery code'**
  String get otpStepLabel;

  /// No description provided for @otpContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get otpContinue;

  /// No description provided for @taskDeliver.
  ///
  /// In en, this message translates to:
  /// **'Mark delivered'**
  String get taskDeliver;

  /// No description provided for @otpAttemptsLeft.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 attempt left} other{{count} attempts left}}'**
  String otpAttemptsLeft(int count);

  /// No description provided for @deliveryOtpWrong.
  ///
  /// In en, this message translates to:
  /// **'Wrong code. Ask the customer to read it again from their app or SMS.'**
  String get deliveryOtpWrong;

  /// No description provided for @deliveryOtpWrongLeft.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Wrong code. 1 try left. Ask the customer to read it again from their app or SMS.} other{Wrong code. {count} tries left. Ask the customer to read it again from their app or SMS.}}'**
  String deliveryOtpWrongLeft(int count);

  /// No description provided for @deliveryOtpLocked.
  ///
  /// In en, this message translates to:
  /// **'Too many wrong codes. Jivo support has been alerted. Call support to continue.'**
  String get deliveryOtpLocked;

  /// No description provided for @otpLockedTitle.
  ///
  /// In en, this message translates to:
  /// **'Delivery code locked'**
  String get otpLockedTitle;

  /// No description provided for @codTitle.
  ///
  /// In en, this message translates to:
  /// **'Collect payment'**
  String get codTitle;

  /// No description provided for @codAmountDueLabel.
  ///
  /// In en, this message translates to:
  /// **'Amount to collect'**
  String get codAmountDueLabel;

  /// No description provided for @codExactAmount.
  ///
  /// In en, this message translates to:
  /// **'Collect exactly this amount. Don\'t accept more or less.'**
  String get codExactAmount;

  /// No description provided for @codCashCollected.
  ///
  /// In en, this message translates to:
  /// **'Cash collected {amount}'**
  String codCashCollected(String amount);

  /// No description provided for @codConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Collected {amount}?'**
  String codConfirmTitle(String amount);

  /// No description provided for @codConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'Count the cash before confirming. You can\'t change this after delivery.'**
  String get codConfirmBody;

  /// No description provided for @codConfirmYes.
  ///
  /// In en, this message translates to:
  /// **'Yes, {amount} collected'**
  String codConfirmYes(String amount);

  /// No description provided for @codConfirmNo.
  ///
  /// In en, this message translates to:
  /// **'Not yet'**
  String get codConfirmNo;

  /// No description provided for @codCashDone.
  ///
  /// In en, this message translates to:
  /// **'Cash collected: {amount}'**
  String codCashDone(String amount);

  /// No description provided for @codShowUpi.
  ///
  /// In en, this message translates to:
  /// **'Customer pays by UPI: show QR'**
  String get codShowUpi;

  /// No description provided for @codUpiWaiting.
  ///
  /// In en, this message translates to:
  /// **'Waiting for the payment…'**
  String get codUpiWaiting;

  /// No description provided for @codUpiPaid.
  ///
  /// In en, this message translates to:
  /// **'Payment received'**
  String get codUpiPaid;

  /// No description provided for @codUpiCheck.
  ///
  /// In en, this message translates to:
  /// **'Check payment'**
  String get codUpiCheck;

  /// No description provided for @codChangeOtp.
  ///
  /// In en, this message translates to:
  /// **'Change the delivery code'**
  String get codChangeOtp;

  /// No description provided for @codConfirmFirst.
  ///
  /// In en, this message translates to:
  /// **'Confirm the cash or wait for the UPI payment first.'**
  String get codConfirmFirst;

  /// No description provided for @codAmountMismatch.
  ///
  /// In en, this message translates to:
  /// **'The amount doesn\'t match what Jivo expects. Check the amount and try again.'**
  String get codAmountMismatch;

  /// No description provided for @taskDeliveredTitle.
  ///
  /// In en, this message translates to:
  /// **'Delivered!'**
  String get taskDeliveredTitle;

  /// No description provided for @taskDeliveredBody.
  ///
  /// In en, this message translates to:
  /// **'Great job. Wait for the next order.'**
  String get taskDeliveredBody;

  /// No description provided for @taskDeliveredEarned.
  ///
  /// In en, this message translates to:
  /// **'You earned {amount} for this order.'**
  String taskDeliveredEarned(String amount);

  /// No description provided for @taskReturnTitle.
  ///
  /// In en, this message translates to:
  /// **'Return to store'**
  String get taskReturnTitle;

  /// No description provided for @taskReturnBody.
  ///
  /// In en, this message translates to:
  /// **'Take the items back to the store. The store staff will mark them received.'**
  String get taskReturnBody;

  /// No description provided for @taskCheckStatus.
  ///
  /// In en, this message translates to:
  /// **'Check status'**
  String get taskCheckStatus;

  /// No description provided for @taskReturnedTitle.
  ///
  /// In en, this message translates to:
  /// **'Items returned'**
  String get taskReturnedTitle;

  /// No description provided for @taskReturnedBody.
  ///
  /// In en, this message translates to:
  /// **'The store received the items. You\'re ready for new orders.'**
  String get taskReturnedBody;

  /// No description provided for @taskCancelledTitle.
  ///
  /// In en, this message translates to:
  /// **'Order cancelled'**
  String get taskCancelledTitle;

  /// No description provided for @taskCancelledBody.
  ///
  /// In en, this message translates to:
  /// **'This order was cancelled before pickup. You don\'t need to collect it.'**
  String get taskCancelledBody;

  /// No description provided for @taskUnassignedTitle.
  ///
  /// In en, this message translates to:
  /// **'Order reassigned'**
  String get taskUnassignedTitle;

  /// No description provided for @taskUnassignedBody.
  ///
  /// In en, this message translates to:
  /// **'This order is no longer assigned to you.'**
  String get taskUnassignedBody;

  /// No description provided for @taskUnknownTitle.
  ///
  /// In en, this message translates to:
  /// **'Can\'t show this order'**
  String get taskUnknownTitle;

  /// No description provided for @taskUnknownBody.
  ///
  /// In en, this message translates to:
  /// **'This app version can\'t show the order\'s status. Try again or update the app.'**
  String get taskUnknownBody;

  /// No description provided for @failTitle.
  ///
  /// In en, this message translates to:
  /// **'Can\'t deliver'**
  String get failTitle;

  /// No description provided for @failIntro.
  ///
  /// In en, this message translates to:
  /// **'Why can\'t you deliver this order?'**
  String get failIntro;

  /// No description provided for @failNotReachable.
  ///
  /// In en, this message translates to:
  /// **'Customer not reachable'**
  String get failNotReachable;

  /// No description provided for @failRefused.
  ///
  /// In en, this message translates to:
  /// **'Customer refused the order'**
  String get failRefused;

  /// No description provided for @failWrongAddress.
  ///
  /// In en, this message translates to:
  /// **'Wrong address'**
  String get failWrongAddress;

  /// No description provided for @failOther.
  ///
  /// In en, this message translates to:
  /// **'Other reason'**
  String get failOther;

  /// No description provided for @failCallsNeeded.
  ///
  /// In en, this message translates to:
  /// **'Call the customer at least {needed} times ({done} done)'**
  String failCallsNeeded(int needed, int done);

  /// No description provided for @failWaitLeft.
  ///
  /// In en, this message translates to:
  /// **'Wait at the address: {time} left'**
  String failWaitLeft(String time);

  /// No description provided for @failWaitDone.
  ///
  /// In en, this message translates to:
  /// **'You waited 10 minutes at the address'**
  String get failWaitDone;

  /// No description provided for @failWaitNotArrived.
  ///
  /// In en, this message translates to:
  /// **'Mark \"Arrived at customer\" first'**
  String get failWaitNotArrived;

  /// No description provided for @failNoteOptional.
  ///
  /// In en, this message translates to:
  /// **'Note (optional)'**
  String get failNoteOptional;

  /// No description provided for @failNoteRequired.
  ///
  /// In en, this message translates to:
  /// **'Note (required)'**
  String get failNoteRequired;

  /// No description provided for @failAddPhoto.
  ///
  /// In en, this message translates to:
  /// **'Add a photo (optional)'**
  String get failAddPhoto;

  /// No description provided for @failPhotoAdded.
  ///
  /// In en, this message translates to:
  /// **'Photo added'**
  String get failPhotoAdded;

  /// No description provided for @failPhotoRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get failPhotoRemove;

  /// No description provided for @failPhotoError.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t use that photo. Try again.'**
  String get failPhotoError;

  /// No description provided for @failChooseReason.
  ///
  /// In en, this message translates to:
  /// **'Choose a reason.'**
  String get failChooseReason;

  /// No description provided for @failNotYet.
  ///
  /// In en, this message translates to:
  /// **'You can choose this after the calls and the 10-minute wait.'**
  String get failNotYet;

  /// No description provided for @failSubmit.
  ///
  /// In en, this message translates to:
  /// **'Return to store'**
  String get failSubmit;

  /// No description provided for @logoutBlockedDuringTask.
  ///
  /// In en, this message translates to:
  /// **'Finish your current order before logging out.'**
  String get logoutBlockedDuringTask;

  /// No description provided for @offlineBlockedDuringTask.
  ///
  /// In en, this message translates to:
  /// **'Finish your current order first.'**
  String get offlineBlockedDuringTask;

  /// No description provided for @devOfferPrepaid.
  ///
  /// In en, this message translates to:
  /// **'Test offer (dev)'**
  String get devOfferPrepaid;

  /// No description provided for @devOfferCod.
  ///
  /// In en, this message translates to:
  /// **'Test COD offer (dev)'**
  String get devOfferCod;

  /// No description provided for @devMarkPacked.
  ///
  /// In en, this message translates to:
  /// **'Store: packed (dev)'**
  String get devMarkPacked;

  /// No description provided for @devCancelOrder.
  ///
  /// In en, this message translates to:
  /// **'Cancel order (dev)'**
  String get devCancelOrder;

  /// No description provided for @devReturnReceived.
  ///
  /// In en, this message translates to:
  /// **'Store: return received (dev)'**
  String get devReturnReceived;

  /// No description provided for @devUpiPaid.
  ///
  /// In en, this message translates to:
  /// **'Customer paid (dev)'**
  String get devUpiPaid;

  /// No description provided for @codTakeCashInstead.
  ///
  /// In en, this message translates to:
  /// **'Customer pays cash instead'**
  String get codTakeCashInstead;

  /// No description provided for @codUpiExpired.
  ///
  /// In en, this message translates to:
  /// **'The QR expired. Show a new one.'**
  String get codUpiExpired;

  /// No description provided for @taskUnconfirmedTitle.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t confirm the last step'**
  String get taskUnconfirmedTitle;

  /// No description provided for @taskUnconfirmedBody.
  ///
  /// In en, this message translates to:
  /// **'The connection dropped before Jivo answered, and this order is no longer open. It may have gone through. Check the order status, or call support.'**
  String get taskUnconfirmedBody;

  /// No description provided for @taskBackToOrders.
  ///
  /// In en, this message translates to:
  /// **'Back to orders'**
  String get taskBackToOrders;

  /// No description provided for @codQrUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t show the QR code. Check payment again, or collect cash.'**
  String get codQrUnavailable;

  /// No description provided for @listLoadMore.
  ///
  /// In en, this message translates to:
  /// **'Load more'**
  String get listLoadMore;

  /// A range of dates.
  ///
  /// In en, this message translates to:
  /// **'{from} – {to}'**
  String dateRange(String from, String to);

  /// No description provided for @earningsTitle.
  ///
  /// In en, this message translates to:
  /// **'Earnings'**
  String get earningsTitle;

  /// No description provided for @earningsToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get earningsToday;

  /// No description provided for @earningsThisWeek.
  ///
  /// In en, this message translates to:
  /// **'This week'**
  String get earningsThisWeek;

  /// No description provided for @earningsChooseDates.
  ///
  /// In en, this message translates to:
  /// **'Choose dates'**
  String get earningsChooseDates;

  /// No description provided for @earningsOrders.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No orders} =1{1 order} other{{count} orders}}'**
  String earningsOrders(int count);

  /// No description provided for @earningsPerOrder.
  ///
  /// In en, this message translates to:
  /// **'Per order'**
  String get earningsPerOrder;

  /// No description provided for @earningsAdjustments.
  ///
  /// In en, this message translates to:
  /// **'Incentives and penalties'**
  String get earningsAdjustments;

  /// No description provided for @earningBase.
  ///
  /// In en, this message translates to:
  /// **'Base pay'**
  String get earningBase;

  /// No description provided for @earningDistance.
  ///
  /// In en, this message translates to:
  /// **'Distance pay'**
  String get earningDistance;

  /// No description provided for @earningTip.
  ///
  /// In en, this message translates to:
  /// **'Tips'**
  String get earningTip;

  /// No description provided for @earningIncentive.
  ///
  /// In en, this message translates to:
  /// **'Incentives'**
  String get earningIncentive;

  /// No description provided for @earningPenalty.
  ///
  /// In en, this message translates to:
  /// **'Penalties'**
  String get earningPenalty;

  /// No description provided for @payoutsTitle.
  ///
  /// In en, this message translates to:
  /// **'Payouts'**
  String get payoutsTitle;

  /// No description provided for @payoutsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No payouts yet.'**
  String get payoutsEmpty;

  /// No description provided for @payoutPaid.
  ///
  /// In en, this message translates to:
  /// **'Paid'**
  String get payoutPaid;

  /// No description provided for @payoutPending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get payoutPending;

  /// No description provided for @payoutReference.
  ///
  /// In en, this message translates to:
  /// **'Reference {reference}'**
  String payoutReference(String reference);

  /// No description provided for @payoutPaidOn.
  ///
  /// In en, this message translates to:
  /// **'Paid on {date}'**
  String payoutPaidOn(String date);

  /// No description provided for @cashTitle.
  ///
  /// In en, this message translates to:
  /// **'Cash in hand'**
  String get cashTitle;

  /// No description provided for @cashEmpty.
  ///
  /// In en, this message translates to:
  /// **'No cash entries yet.'**
  String get cashEmpty;

  /// No description provided for @cashInHand.
  ///
  /// In en, this message translates to:
  /// **'Cash in hand'**
  String get cashInHand;

  /// No description provided for @cashLimit.
  ///
  /// In en, this message translates to:
  /// **'Limit {amount}'**
  String cashLimit(String amount);

  /// No description provided for @cashDepositTitle.
  ///
  /// In en, this message translates to:
  /// **'Deposit cash'**
  String get cashDepositTitle;

  /// No description provided for @cashDepositBody.
  ///
  /// In en, this message translates to:
  /// **'You\'ve reached the cash limit of {limit}. Hand the cash to the store manager to get cash orders again. Until then you get prepaid orders only.'**
  String cashDepositBody(String limit);

  /// No description provided for @cashCodCollected.
  ///
  /// In en, this message translates to:
  /// **'Cash collected · Order {order}'**
  String cashCodCollected(String order);

  /// No description provided for @cashCodCollectedNoOrder.
  ///
  /// In en, this message translates to:
  /// **'Cash collected'**
  String get cashCodCollectedNoOrder;

  /// No description provided for @cashDeposit.
  ///
  /// In en, this message translates to:
  /// **'Deposited at the store'**
  String get cashDeposit;

  /// No description provided for @cashAdjustment.
  ///
  /// In en, this message translates to:
  /// **'Adjustment'**
  String get cashAdjustment;

  /// No description provided for @cashBalanceAfter.
  ///
  /// In en, this message translates to:
  /// **'Balance {amount}'**
  String cashBalanceAfter(String amount);

  /// No description provided for @historyTitle.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get historyTitle;

  /// No description provided for @historyEmpty.
  ///
  /// In en, this message translates to:
  /// **'No past orders yet.'**
  String get historyEmpty;

  /// No description provided for @historyRoute.
  ///
  /// In en, this message translates to:
  /// **'{store} → {drop}'**
  String historyRoute(String store, String drop);

  /// No description provided for @historyDelivered.
  ///
  /// In en, this message translates to:
  /// **'Delivered'**
  String get historyDelivered;

  /// No description provided for @historyReturned.
  ///
  /// In en, this message translates to:
  /// **'Returned'**
  String get historyReturned;

  /// No description provided for @historyCancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get historyCancelled;

  /// No description provided for @historyFailed.
  ///
  /// In en, this message translates to:
  /// **'Not delivered'**
  String get historyFailed;

  /// No description provided for @historyOther.
  ///
  /// In en, this message translates to:
  /// **'Ended'**
  String get historyOther;

  /// No description provided for @profileTitle.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profileTitle;

  /// No description provided for @profileHomeStore.
  ///
  /// In en, this message translates to:
  /// **'Home store'**
  String get profileHomeStore;

  /// No description provided for @profileVehicle.
  ///
  /// In en, this message translates to:
  /// **'Vehicle'**
  String get profileVehicle;

  /// No description provided for @profileKycStatus.
  ///
  /// In en, this message translates to:
  /// **'KYC status'**
  String get profileKycStatus;

  /// No description provided for @profileKycApproved.
  ///
  /// In en, this message translates to:
  /// **'Verified'**
  String get profileKycApproved;

  /// No description provided for @profileRating.
  ///
  /// In en, this message translates to:
  /// **'Rating'**
  String get profileRating;

  /// No description provided for @profileRatingValue.
  ///
  /// In en, this message translates to:
  /// **'{rating} ★'**
  String profileRatingValue(String rating);

  /// No description provided for @profileNoRating.
  ///
  /// In en, this message translates to:
  /// **'No ratings yet'**
  String get profileNoRating;

  /// No description provided for @documentsProfileIntro.
  ///
  /// In en, this message translates to:
  /// **'Your KYC documents and their review status. Approved documents can\'t be changed. Upload again any document marked Rejected.'**
  String get documentsProfileIntro;

  /// No description provided for @documentsNeedAttention.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 document needs a new upload.} other{{count} documents need a new upload.}}'**
  String documentsNeedAttention(int count);

  /// No description provided for @profileDocumentsAttention.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 needs a new upload} other{{count} need a new upload}}'**
  String profileDocumentsAttention(int count);

  /// No description provided for @profileDocumentsAllGood.
  ///
  /// In en, this message translates to:
  /// **'All approved'**
  String get profileDocumentsAllGood;

  /// No description provided for @profileDocumentsInReview.
  ///
  /// In en, this message translates to:
  /// **'In review'**
  String get profileDocumentsInReview;

  /// No description provided for @profileSupport.
  ///
  /// In en, this message translates to:
  /// **'Support'**
  String get profileSupport;

  /// No description provided for @profileSupportBody.
  ///
  /// In en, this message translates to:
  /// **'Problems with an order, a payout or the app? Call Jivo rider support.'**
  String get profileSupportBody;

  /// No description provided for @devRejectDocument.
  ///
  /// In en, this message translates to:
  /// **'Ops: reject the driving licence (dev)'**
  String get devRejectDocument;

  /// No description provided for @debugSimulateServerOffline.
  ///
  /// In en, this message translates to:
  /// **'Server has auto-offlined me (fake)'**
  String get debugSimulateServerOffline;

  /// No description provided for @debugStatsLink.
  ///
  /// In en, this message translates to:
  /// **'Failed in a row {failures} · Heartbeats {heartbeats}'**
  String debugStatsLink(int failures, int heartbeats);

  /// No description provided for @dismiss.
  ///
  /// In en, this message translates to:
  /// **'Dismiss'**
  String get dismiss;

  /// No description provided for @homeGreeting.
  ///
  /// In en, this message translates to:
  /// **'Hi, {name}'**
  String homeGreeting(String name);

  /// No description provided for @homeYourStore.
  ///
  /// In en, this message translates to:
  /// **'your store'**
  String get homeYourStore;

  /// No description provided for @shiftOfflineTitle.
  ///
  /// In en, this message translates to:
  /// **'You\'re offline'**
  String get shiftOfflineTitle;

  /// No description provided for @shiftOfflineBody.
  ///
  /// In en, this message translates to:
  /// **'You won\'t get orders.'**
  String get shiftOfflineBody;

  /// No description provided for @shiftOnlineTitle.
  ///
  /// In en, this message translates to:
  /// **'You\'re online'**
  String get shiftOnlineTitle;

  /// No description provided for @shiftOnlineBody.
  ///
  /// In en, this message translates to:
  /// **'Waiting for orders near your store.'**
  String get shiftOnlineBody;

  /// No description provided for @shiftOnlineBodyStore.
  ///
  /// In en, this message translates to:
  /// **'Waiting for orders near {store}.'**
  String shiftOnlineBodyStore(String store);

  /// No description provided for @shiftOnlinePrepaidTitle.
  ///
  /// In en, this message translates to:
  /// **'You\'re online: prepaid orders only'**
  String get shiftOnlinePrepaidTitle;

  /// No description provided for @shiftOnlinePrepaidBody.
  ///
  /// In en, this message translates to:
  /// **'Deposit cash at the store to get cash orders again.'**
  String get shiftOnlinePrepaidBody;

  /// No description provided for @shiftAutoOfflineTitle.
  ///
  /// In en, this message translates to:
  /// **'You were set offline'**
  String get shiftAutoOfflineTitle;

  /// No description provided for @shiftAutoOfflineBody.
  ///
  /// In en, this message translates to:
  /// **'We didn\'t get your location for 10 minutes. Check GPS and your connection, then go online again.'**
  String get shiftAutoOfflineBody;

  /// No description provided for @shiftGoOnline.
  ///
  /// In en, this message translates to:
  /// **'Go online'**
  String get shiftGoOnline;

  /// No description provided for @shiftGoOffline.
  ///
  /// In en, this message translates to:
  /// **'Go offline'**
  String get shiftGoOffline;

  /// No description provided for @shiftGoingOnline.
  ///
  /// In en, this message translates to:
  /// **'Going online…'**
  String get shiftGoingOnline;

  /// No description provided for @shiftGoingOffline.
  ///
  /// In en, this message translates to:
  /// **'Going offline…'**
  String get shiftGoingOffline;

  /// No description provided for @shiftFixPermissions.
  ///
  /// In en, this message translates to:
  /// **'Fix permissions'**
  String get shiftFixPermissions;

  /// No description provided for @shiftSeeStatus.
  ///
  /// In en, this message translates to:
  /// **'See status'**
  String get shiftSeeStatus;

  /// No description provided for @shiftServiceFailed.
  ///
  /// In en, this message translates to:
  /// **'Location tracking couldn\'t start. Try again; if it keeps failing, restart the phone.'**
  String get shiftServiceFailed;

  /// No description provided for @shiftServerError.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t go online. Try again.'**
  String get shiftServerError;

  /// No description provided for @guardBlockedHint.
  ///
  /// In en, this message translates to:
  /// **'Fix the problem shown above first'**
  String get guardBlockedHint;

  /// No description provided for @guardNotActiveTitle.
  ///
  /// In en, this message translates to:
  /// **'Your account isn\'t active'**
  String get guardNotActiveTitle;

  /// No description provided for @guardNotActiveBody.
  ///
  /// In en, this message translates to:
  /// **'We\'ll let you know when Jivo approves your documents.'**
  String get guardNotActiveBody;

  /// No description provided for @guardPermissionsTitle.
  ///
  /// In en, this message translates to:
  /// **'Allow location and notifications'**
  String get guardPermissionsTitle;

  /// No description provided for @guardPermissionsBody.
  ///
  /// In en, this message translates to:
  /// **'You need them to get orders.'**
  String get guardPermissionsBody;

  /// No description provided for @guardGpsTitle.
  ///
  /// In en, this message translates to:
  /// **'Turn on location (GPS)'**
  String get guardGpsTitle;

  /// No description provided for @guardGpsBody.
  ///
  /// In en, this message translates to:
  /// **'Jivo Rider can\'t find you with GPS off.'**
  String get guardGpsBody;

  /// No description provided for @guardGpsAction.
  ///
  /// In en, this message translates to:
  /// **'Turn on GPS'**
  String get guardGpsAction;

  /// No description provided for @guardTooFarTitle.
  ///
  /// In en, this message translates to:
  /// **'You\'re too far from your store'**
  String get guardTooFarTitle;

  /// No description provided for @guardTooFarBody.
  ///
  /// In en, this message translates to:
  /// **'You\'re {distance} km from {store}. Go within {radius} km to go online.'**
  String guardTooFarBody(String distance, String store, String radius);

  /// No description provided for @guardTooFarBodyNoDistance.
  ///
  /// In en, this message translates to:
  /// **'Move closer to {store} and try again.'**
  String guardTooFarBodyNoDistance(String store);

  /// No description provided for @guardNavigateToStore.
  ///
  /// In en, this message translates to:
  /// **'Navigate to store'**
  String get guardNavigateToStore;

  /// No description provided for @guardTaskActiveTitle.
  ///
  /// In en, this message translates to:
  /// **'Finish your current order first'**
  String get guardTaskActiveTitle;

  /// No description provided for @guardNetworkTitle.
  ///
  /// In en, this message translates to:
  /// **'No internet'**
  String get guardNetworkTitle;

  /// No description provided for @guardNetworkBody.
  ///
  /// In en, this message translates to:
  /// **'Check your connection and try again.'**
  String get guardNetworkBody;

  /// No description provided for @currentTaskContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get currentTaskContinue;

  /// No description provided for @currentTaskContinueOrder.
  ///
  /// In en, this message translates to:
  /// **'Continue order'**
  String get currentTaskContinueOrder;

  /// No description provided for @currentTaskSemantics.
  ///
  /// In en, this message translates to:
  /// **'Current order {order}, {step}. Continue.'**
  String currentTaskSemantics(String order, String step);

  /// No description provided for @taskStepGoToStore.
  ///
  /// In en, this message translates to:
  /// **'Go to the store'**
  String get taskStepGoToStore;

  /// No description provided for @taskStepPickup.
  ///
  /// In en, this message translates to:
  /// **'Pick up the order'**
  String get taskStepPickup;

  /// No description provided for @taskStepGoToCustomer.
  ///
  /// In en, this message translates to:
  /// **'Deliver to the customer'**
  String get taskStepGoToCustomer;

  /// No description provided for @taskStepDeliver.
  ///
  /// In en, this message translates to:
  /// **'Enter the delivery code'**
  String get taskStepDeliver;

  /// No description provided for @taskStepReturn.
  ///
  /// In en, this message translates to:
  /// **'Return to store'**
  String get taskStepReturn;

  /// No description provided for @taskStepOther.
  ///
  /// In en, this message translates to:
  /// **'Open the order'**
  String get taskStepOther;

  /// No description provided for @chipCod.
  ///
  /// In en, this message translates to:
  /// **'COD'**
  String get chipCod;

  /// No description provided for @chipCodAmount.
  ///
  /// In en, this message translates to:
  /// **'COD {amount}'**
  String chipCodAmount(String amount);

  /// No description provided for @chipPrepaid.
  ///
  /// In en, this message translates to:
  /// **'Prepaid'**
  String get chipPrepaid;

  /// No description provided for @todayTitle.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get todayTitle;

  /// No description provided for @todayDelivered.
  ///
  /// In en, this message translates to:
  /// **'Delivered'**
  String get todayDelivered;

  /// No description provided for @todayEarned.
  ///
  /// In en, this message translates to:
  /// **'Earned'**
  String get todayEarned;

  /// No description provided for @todayOnline.
  ///
  /// In en, this message translates to:
  /// **'Online time'**
  String get todayOnline;

  /// No description provided for @todayCash.
  ///
  /// In en, this message translates to:
  /// **'Cash in hand'**
  String get todayCash;

  /// No description provided for @todayOpensEarnings.
  ///
  /// In en, this message translates to:
  /// **'opens earnings'**
  String get todayOpensEarnings;

  /// No description provided for @todayOpensCash.
  ///
  /// In en, this message translates to:
  /// **'opens cash'**
  String get todayOpensCash;

  /// No description provided for @todayNotAvailable.
  ///
  /// In en, this message translates to:
  /// **'not available'**
  String get todayNotAvailable;

  /// No description provided for @homeHowToDeposit.
  ///
  /// In en, this message translates to:
  /// **'How to deposit'**
  String get homeHowToDeposit;

  /// No description provided for @homeHowToDepositBody.
  ///
  /// In en, this message translates to:
  /// **'Hand the cash to your store manager. It shows in your cash ledger once they record it.'**
  String get homeHowToDepositBody;

  /// No description provided for @homeSeeCashLedger.
  ///
  /// In en, this message translates to:
  /// **'See cash ledger'**
  String get homeSeeCashLedger;

  /// No description provided for @gateActionLocationPrecise.
  ///
  /// In en, this message translates to:
  /// **'Use precise location'**
  String get gateActionLocationPrecise;

  /// No description provided for @gateStepLocationPreciseHint.
  ///
  /// In en, this message translates to:
  /// **'Choose \"Precise\". Approximate location can\'t guide deliveries.'**
  String get gateStepLocationPreciseHint;

  /// No description provided for @gateAlwaysNotChosenTitle.
  ///
  /// In en, this message translates to:
  /// **'\"Allow all the time\" wasn\'t chosen'**
  String get gateAlwaysNotChosenTitle;

  /// No description provided for @gateAlwaysNotChosenBody.
  ///
  /// In en, this message translates to:
  /// **'Without it Jivo can\'t send you orders or track your delivery when the screen is off, so you can\'t go online. Open settings, tap Permissions › Location and choose \"Allow all the time\".'**
  String get gateAlwaysNotChosenBody;

  /// No description provided for @gateOpenAppSettings.
  ///
  /// In en, this message translates to:
  /// **'Open app settings'**
  String get gateOpenAppSettings;

  /// No description provided for @disclosureDeclinedTitle.
  ///
  /// In en, this message translates to:
  /// **'Location is needed to go online'**
  String get disclosureDeclinedTitle;

  /// No description provided for @disclosureDeclinedBody.
  ///
  /// In en, this message translates to:
  /// **'You can still use the app, but you can\'t go online and get orders until you allow location.'**
  String get disclosureDeclinedBody;

  /// No description provided for @disclosureNotification.
  ///
  /// In en, this message translates to:
  /// **'While you\'re online you\'ll see a \"You\'re online\" notification.'**
  String get disclosureNotification;

  /// No description provided for @offerCodAmountMissing.
  ///
  /// In en, this message translates to:
  /// **'Cash on delivery: amount shown after you accept.'**
  String get offerCodAmountMissing;

  /// No description provided for @offerTimeLeft.
  ///
  /// In en, this message translates to:
  /// **'Time left to accept: {seconds} seconds'**
  String offerTimeLeft(int seconds);

  /// No description provided for @offerSecondsShort.
  ///
  /// In en, this message translates to:
  /// **'{seconds} s'**
  String offerSecondsShort(int seconds);

  /// No description provided for @offerExpiring.
  ///
  /// In en, this message translates to:
  /// **'Expiring'**
  String get offerExpiring;

  /// No description provided for @offerDrop.
  ///
  /// In en, this message translates to:
  /// **'{locality} · {distance}'**
  String offerDrop(String locality, String distance);

  /// No description provided for @codAmountMissing.
  ///
  /// In en, this message translates to:
  /// **'Can\'t load the amount to collect. Pull down to refresh, or call support.'**
  String get codAmountMissing;

  /// No description provided for @codRefresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get codRefresh;

  /// No description provided for @codAmountChangedTitle.
  ///
  /// In en, this message translates to:
  /// **'Amount changed: collect {amount}'**
  String codAmountChangedTitle(String amount);

  /// No description provided for @codAmountChangedBody.
  ///
  /// In en, this message translates to:
  /// **'Was {was}. The store couldn\'t supply some items.'**
  String codAmountChangedBody(String was);

  /// No description provided for @codAmountPreviously.
  ///
  /// In en, this message translates to:
  /// **'previously {amount}'**
  String codAmountPreviously(String amount);

  /// No description provided for @codAmountSemantics.
  ///
  /// In en, this message translates to:
  /// **'Amount to collect: {amount}'**
  String codAmountSemantics(String amount);

  /// No description provided for @devCodAmountChanged.
  ///
  /// In en, this message translates to:
  /// **'Store: an item is unavailable (dev)'**
  String get devCodAmountChanged;

  /// No description provided for @taskOfflineBanner.
  ///
  /// In en, this message translates to:
  /// **'No internet. Your progress is saved on Jivo\'s server; tap the button again when you\'re back online.'**
  String get taskOfflineBanner;

  /// No description provided for @taskTryAgain.
  ///
  /// In en, this message translates to:
  /// **'Try again: {label}'**
  String taskTryAgain(String label);

  /// No description provided for @taskWorking.
  ///
  /// In en, this message translates to:
  /// **'Working'**
  String get taskWorking;

  /// No description provided for @guardDocumentsTitle.
  ///
  /// In en, this message translates to:
  /// **'Some documents need a new upload'**
  String get guardDocumentsTitle;

  /// No description provided for @guardDocumentsBody.
  ///
  /// In en, this message translates to:
  /// **'Upload the documents marked in your profile, then go online.'**
  String get guardDocumentsBody;

  /// No description provided for @guardDocumentsAction.
  ///
  /// In en, this message translates to:
  /// **'See documents'**
  String get guardDocumentsAction;

  /// No description provided for @pickupTypeCode.
  ///
  /// In en, this message translates to:
  /// **'Type the code'**
  String get pickupTypeCode;

  /// No description provided for @pickupEnterAll.
  ///
  /// In en, this message translates to:
  /// **'Enter all 4 characters.'**
  String get pickupEnterAll;

  /// No description provided for @pickupCheckBag.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Check the bag: 1 item} other{Check the bag: {count} items}}'**
  String pickupCheckBag(int count);

  /// No description provided for @scanHelper.
  ///
  /// In en, this message translates to:
  /// **'Point at the QR on the bag label'**
  String get scanHelper;

  /// No description provided for @scanLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get scanLight;

  /// No description provided for @scanLightOn.
  ///
  /// In en, this message translates to:
  /// **'Light on'**
  String get scanLightOn;

  /// No description provided for @otpLockedHeading.
  ///
  /// In en, this message translates to:
  /// **'Delivery code locked'**
  String get otpLockedHeading;

  /// No description provided for @deliveryOtpLockedNoPhone.
  ///
  /// In en, this message translates to:
  /// **'Too many wrong codes. Jivo support has been alerted. Wait at the door for a call from support, or choose Can\'t deliver.'**
  String get deliveryOtpLockedNoPhone;

  /// No description provided for @failConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Return the order to the store?'**
  String get failConfirmTitle;

  /// No description provided for @failConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'Reason: {reason}. The customer will be told. You can\'t undo this.'**
  String failConfirmBody(String reason);

  /// No description provided for @failConfirmNote.
  ///
  /// In en, this message translates to:
  /// **'Note: {note}'**
  String failConfirmNote(String note);

  /// No description provided for @failConfirmBack.
  ///
  /// In en, this message translates to:
  /// **'Go back'**
  String get failConfirmBack;

  /// No description provided for @failConfirmYes.
  ///
  /// In en, this message translates to:
  /// **'Yes, return to store'**
  String get failConfirmYes;

  /// No description provided for @failWaitSemantics.
  ///
  /// In en, this message translates to:
  /// **'Wait time left: {minutes} minutes {seconds} seconds'**
  String failWaitSemantics(int minutes, int seconds);

  /// No description provided for @taskReturnNoCash.
  ///
  /// In en, this message translates to:
  /// **'Don\'t collect any cash. Nothing is due for this order.'**
  String get taskReturnNoCash;

  /// No description provided for @riderTooManyTries.
  ///
  /// In en, this message translates to:
  /// **'Too many tries. Wait a moment, then try again.'**
  String get riderTooManyTries;

  /// No description provided for @shiftEndedByOpsBody.
  ///
  /// In en, this message translates to:
  /// **'Jivo operations set you offline. Go online again when you are ready, or call support.'**
  String get shiftEndedByOpsBody;

  /// No description provided for @pickupCodeWrongLeft.
  ///
  /// In en, this message translates to:
  /// **'That code doesn\'t match this order. {count, plural, =1{1 try left.} other{{count} tries left.}}'**
  String pickupCodeWrongLeft(int count);

  /// No description provided for @pickupCodeLocked.
  ///
  /// In en, this message translates to:
  /// **'Too many wrong codes. Ask the store staff or call support to hand over this order.'**
  String get pickupCodeLocked;

  /// No description provided for @pickupLockedTitle.
  ///
  /// In en, this message translates to:
  /// **'Code entry locked'**
  String get pickupLockedTitle;

  /// No description provided for @pickupCallStore.
  ///
  /// In en, this message translates to:
  /// **'Call store'**
  String get pickupCallStore;

  /// No description provided for @riderOfflineError.
  ///
  /// In en, this message translates to:
  /// **'You are offline. Go online again to continue.'**
  String get riderOfflineError;

  /// No description provided for @failWaitNotElapsed.
  ///
  /// In en, this message translates to:
  /// **'Wait 10 minutes at the drop location before choosing this.'**
  String get failWaitNotElapsed;

  /// No description provided for @failNeedsCalls.
  ///
  /// In en, this message translates to:
  /// **'Call the customer at least 2 times first.'**
  String get failNeedsCalls;

  /// No description provided for @codAmountChangedCollect.
  ///
  /// In en, this message translates to:
  /// **'The amount changed. Collect exactly {amount}.'**
  String codAmountChangedCollect(String amount);

  /// No description provided for @codUpiNotConfirmed.
  ///
  /// In en, this message translates to:
  /// **'The UPI payment isn\'t confirmed yet. Wait for it, or collect cash.'**
  String get codUpiNotConfirmed;

  /// No description provided for @scanOtherOrder.
  ///
  /// In en, this message translates to:
  /// **'This bag is for order {orderNumber}, not this one.'**
  String scanOtherOrder(String orderNumber);

  /// No description provided for @taskReturnWaiting.
  ///
  /// In en, this message translates to:
  /// **'Checking with the store every few seconds…'**
  String get taskReturnWaiting;

  /// No description provided for @offerItemCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 item} other{{count} items}}'**
  String offerItemCount(int count);

  /// No description provided for @cashDepositSkippedBody.
  ///
  /// In en, this message translates to:
  /// **'A cash order was not sent to you because it would take your cash over the limit of {limit}. Hand the cash to the store manager to get cash orders again. Until then you get prepaid orders only.'**
  String cashDepositSkippedBody(String limit);

  /// No description provided for @cashDepositWhere.
  ///
  /// In en, this message translates to:
  /// **'Deposit cash with the store manager at {store}. It shows here once they record it.'**
  String cashDepositWhere(String store);

  /// No description provided for @earningsOrdersTruncated.
  ///
  /// In en, this message translates to:
  /// **'Showing the latest 200 orders. The totals above include all orders in these dates.'**
  String get earningsOrdersTruncated;

  /// No description provided for @historyDetailTitle.
  ///
  /// In en, this message translates to:
  /// **'Order details'**
  String get historyDetailTitle;

  /// No description provided for @historyAssignedAt.
  ///
  /// In en, this message translates to:
  /// **'Accepted'**
  String get historyAssignedAt;

  /// No description provided for @historyPickedUpAt.
  ///
  /// In en, this message translates to:
  /// **'Picked up'**
  String get historyPickedUpAt;

  /// No description provided for @historyDeliveredAt.
  ///
  /// In en, this message translates to:
  /// **'Delivered'**
  String get historyDeliveredAt;

  /// No description provided for @historyFailedAt.
  ///
  /// In en, this message translates to:
  /// **'Delivery failed'**
  String get historyFailedAt;

  /// No description provided for @historyReturnedAt.
  ///
  /// In en, this message translates to:
  /// **'Returned to store'**
  String get historyReturnedAt;

  /// No description provided for @historyCancelledAt.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get historyCancelledAt;

  /// No description provided for @historyItems.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 item} other{{count} items}}'**
  String historyItems(int count);

  /// No description provided for @historyPaymentCod.
  ///
  /// In en, this message translates to:
  /// **'Cash on delivery'**
  String get historyPaymentCod;

  /// No description provided for @historyPaymentPrepaid.
  ///
  /// In en, this message translates to:
  /// **'Prepaid'**
  String get historyPaymentPrepaid;

  /// No description provided for @historyCodCollected.
  ///
  /// In en, this message translates to:
  /// **'Collected {amount}'**
  String historyCodCollected(String amount);

  /// No description provided for @historyEarned.
  ///
  /// In en, this message translates to:
  /// **'You earned'**
  String get historyEarned;

  /// No description provided for @taskChipDontRingBell.
  ///
  /// In en, this message translates to:
  /// **'Don\'t ring the bell'**
  String get taskChipDontRingBell;

  /// No description provided for @taskChipLeaveAtDoor.
  ///
  /// In en, this message translates to:
  /// **'Leave at the door'**
  String get taskChipLeaveAtDoor;

  /// No description provided for @taskChipAvoidCalling.
  ///
  /// In en, this message translates to:
  /// **'Avoid calling'**
  String get taskChipAvoidCalling;
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
