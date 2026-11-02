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
