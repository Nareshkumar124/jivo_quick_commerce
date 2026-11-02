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
/// import 'generated/app_localizations.dart';
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

  /// App name.
  ///
  /// In en, this message translates to:
  /// **'Jivo'**
  String get appTitle;

  /// Button that repeats a failed request.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// Dismisses a dialog.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// Primary button to go on.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get continueLabel;

  /// Saves a form.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// Closes a screen or dialog.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// Acknowledges a dialog.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get ok;

  /// Splash status while the app config loads.
  ///
  /// In en, this message translates to:
  /// **'Getting things ready…'**
  String get splashChecking;

  /// Splash heading when start-up fails.
  ///
  /// In en, this message translates to:
  /// **'Can\'t reach Jivo'**
  String get splashFailedTitle;

  /// Global banner shown while the device is offline.
  ///
  /// In en, this message translates to:
  /// **'No internet connection'**
  String get offlineBanner;

  /// Onboarding slide 1 title.
  ///
  /// In en, this message translates to:
  /// **'Wellness, delivered fast'**
  String get onboardingTitle1;

  /// Onboarding slide 1 text.
  ///
  /// In en, this message translates to:
  /// **'Jivo oils, foods and essentials at your door in minutes.'**
  String get onboardingBody1;

  /// Onboarding slide 2 title.
  ///
  /// In en, this message translates to:
  /// **'Straight from Jivo'**
  String get onboardingTitle2;

  /// Onboarding slide 2 text.
  ///
  /// In en, this message translates to:
  /// **'Genuine products, fresh stock, fair prices.'**
  String get onboardingBody2;

  /// Onboarding slide 3 title.
  ///
  /// In en, this message translates to:
  /// **'Track every order'**
  String get onboardingTitle3;

  /// Onboarding slide 3 text.
  ///
  /// In en, this message translates to:
  /// **'Follow your rider live until your order arrives.'**
  String get onboardingBody3;

  /// Skips the onboarding slides.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get onboardingSkip;

  /// Goes to the next onboarding slide.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get onboardingNext;

  /// Ends onboarding on the last slide.
  ///
  /// In en, this message translates to:
  /// **'Get started'**
  String get onboardingStart;

  /// Force-update screen title.
  ///
  /// In en, this message translates to:
  /// **'Update required'**
  String get updateRequiredTitle;

  /// Force-update screen text.
  ///
  /// In en, this message translates to:
  /// **'This version of Jivo is no longer supported. Please update the app to continue.'**
  String get updateRequiredBody;

  /// Opens the store listing.
  ///
  /// In en, this message translates to:
  /// **'Update now'**
  String get updateNow;

  /// Dismissible prompt for an optional update.
  ///
  /// In en, this message translates to:
  /// **'A new version of Jivo is available.'**
  String get updateAvailable;

  /// Dismisses the optional update prompt.
  ///
  /// In en, this message translates to:
  /// **'Later'**
  String get later;

  /// Maintenance screen title.
  ///
  /// In en, this message translates to:
  /// **'We\'ll be back soon'**
  String get maintenanceTitle;

  /// Maintenance text when the server sends none.
  ///
  /// In en, this message translates to:
  /// **'Jivo is down for maintenance. Please try again in a little while.'**
  String get maintenanceDefaultBody;

  /// Re-checks whether maintenance is over.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get tryAgain;

  /// Shown when a store or policy link can't be opened.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t open the link.'**
  String get linkOpenFailed;

  /// Login screen heading.
  ///
  /// In en, this message translates to:
  /// **'Log in or sign up'**
  String get loginTitle;

  /// Login screen helper text.
  ///
  /// In en, this message translates to:
  /// **'Enter your mobile number to get an OTP.'**
  String get loginSubtitle;

  /// Phone number field label.
  ///
  /// In en, this message translates to:
  /// **'Mobile number'**
  String get phoneLabel;

  /// Country code shown before the phone field.
  ///
  /// In en, this message translates to:
  /// **'+91'**
  String get phonePrefix;

  /// Phone validation error.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid 10-digit mobile number.'**
  String get phoneInvalid;

  /// Requests an OTP.
  ///
  /// In en, this message translates to:
  /// **'Get OTP'**
  String get getOtp;

  /// Consent text before the policy links.
  ///
  /// In en, this message translates to:
  /// **'By continuing, you agree to our'**
  String get consentPrefix;

  /// Link to the terms.
  ///
  /// In en, this message translates to:
  /// **'Terms of Service'**
  String get termsOfService;

  /// Link to the privacy policy.
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get privacyPolicy;

  /// Link to the refund policy.
  ///
  /// In en, this message translates to:
  /// **'Refund Policy'**
  String get refundPolicy;

  /// Shown on login after the session ended.
  ///
  /// In en, this message translates to:
  /// **'Your session has expired. Please log in again.'**
  String get sessionExpired;

  /// OTP screen heading.
  ///
  /// In en, this message translates to:
  /// **'Verify your number'**
  String get otpTitle;

  /// OTP screen helper text.
  ///
  /// In en, this message translates to:
  /// **'Enter the {length}-digit OTP sent to {phone}'**
  String otpSentTo(int length, String phone);

  /// OTP field label.
  ///
  /// In en, this message translates to:
  /// **'OTP'**
  String get otpLabel;

  /// OTP validation error.
  ///
  /// In en, this message translates to:
  /// **'Enter the {length}-digit OTP.'**
  String otpIncomplete(int length);

  /// Verifies the OTP.
  ///
  /// In en, this message translates to:
  /// **'Verify'**
  String get verify;

  /// Countdown until the OTP can be resent.
  ///
  /// In en, this message translates to:
  /// **'Resend OTP in {seconds}s'**
  String resendIn(int seconds);

  /// Requests a new OTP.
  ///
  /// In en, this message translates to:
  /// **'Resend OTP'**
  String get resendOtp;

  /// Confirmation after a resend.
  ///
  /// In en, this message translates to:
  /// **'A new OTP has been sent.'**
  String get otpResent;

  /// Goes back to the phone screen.
  ///
  /// In en, this message translates to:
  /// **'Change number'**
  String get changeNumber;

  /// PERMISSION_DENIED on login.
  ///
  /// In en, this message translates to:
  /// **'This account is deactivated. Please contact support.'**
  String get accountDeactivated;

  /// Shown after logging in during the deletion grace period.
  ///
  /// In en, this message translates to:
  /// **'Welcome back! Your account deletion request has been cancelled.'**
  String get deletionCancelledNotice;

  /// Complete-profile heading.
  ///
  /// In en, this message translates to:
  /// **'Tell us about you'**
  String get completeProfileTitle;

  /// Complete-profile helper text.
  ///
  /// In en, this message translates to:
  /// **'We\'ll use your name for deliveries.'**
  String get completeProfileSubtitle;

  /// Name field label.
  ///
  /// In en, this message translates to:
  /// **'Full name'**
  String get nameLabel;

  /// Name validation error.
  ///
  /// In en, this message translates to:
  /// **'Please enter your name.'**
  String get nameRequired;

  /// Email field label.
  ///
  /// In en, this message translates to:
  /// **'Email (optional)'**
  String get emailLabel;

  /// Email validation error.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid email address.'**
  String get emailInvalid;

  /// Email rejected by the server.
  ///
  /// In en, this message translates to:
  /// **'This email can\'t be used.'**
  String get emailCantBeUsed;

  /// Home placeholder greeting.
  ///
  /// In en, this message translates to:
  /// **'Hi, {name}!'**
  String homeGreeting(String name);

  /// Phase 1 home placeholder text.
  ///
  /// In en, this message translates to:
  /// **'Shopping arrives in the next update. Meanwhile, set up your account and addresses.'**
  String get homeComingSoon;

  /// Account screen title.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get accountTitle;

  /// Opens the edit-profile screen.
  ///
  /// In en, this message translates to:
  /// **'Edit profile'**
  String get editProfile;

  /// Opens the address list.
  ///
  /// In en, this message translates to:
  /// **'Saved addresses'**
  String get addresses;

  /// Section with policy links.
  ///
  /// In en, this message translates to:
  /// **'Legal'**
  String get legal;

  /// App version in the account screen.
  ///
  /// In en, this message translates to:
  /// **'App version {version}'**
  String appVersion(String version);

  /// Logs out.
  ///
  /// In en, this message translates to:
  /// **'Log out'**
  String get logout;

  /// Logout confirmation question.
  ///
  /// In en, this message translates to:
  /// **'Log out of Jivo on this device?'**
  String get logoutConfirm;

  /// Opens the delete-account flow.
  ///
  /// In en, this message translates to:
  /// **'Delete account'**
  String get deleteAccount;

  /// Helper under the read-only phone field.
  ///
  /// In en, this message translates to:
  /// **'Your mobile number can\'t be changed.'**
  String get phoneNotEditable;

  /// Confirmation after saving the profile.
  ///
  /// In en, this message translates to:
  /// **'Profile updated.'**
  String get profileSaved;

  /// Empty state of the address list.
  ///
  /// In en, this message translates to:
  /// **'No saved addresses yet.'**
  String get addressesEmpty;

  /// Opens the address form.
  ///
  /// In en, this message translates to:
  /// **'Add address'**
  String get addAddress;

  /// Address form title when editing.
  ///
  /// In en, this message translates to:
  /// **'Edit address'**
  String get editAddress;

  /// Address form title when adding.
  ///
  /// In en, this message translates to:
  /// **'New address'**
  String get newAddress;

  /// Badge on the default address.
  ///
  /// In en, this message translates to:
  /// **'Default'**
  String get defaultAddress;

  /// Makes an address the default.
  ///
  /// In en, this message translates to:
  /// **'Set as default'**
  String get setAsDefault;

  /// Deletes an item.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// Edits an item.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get edit;

  /// Address deletion confirmation.
  ///
  /// In en, this message translates to:
  /// **'Delete this address?'**
  String get deleteAddressConfirm;

  /// Address label.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get labelHome;

  /// Address label.
  ///
  /// In en, this message translates to:
  /// **'Work'**
  String get labelWork;

  /// Address label.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get labelOther;

  /// Custom label field.
  ///
  /// In en, this message translates to:
  /// **'Name this address (e.g. Mom\'s place)'**
  String get customLabel;

  /// Address field.
  ///
  /// In en, this message translates to:
  /// **'House / flat / floor'**
  String get houseLabel;

  /// Address field.
  ///
  /// In en, this message translates to:
  /// **'Building / street'**
  String get buildingStreetLabel;

  /// Address field.
  ///
  /// In en, this message translates to:
  /// **'Landmark (optional)'**
  String get landmarkLabel;

  /// Address field.
  ///
  /// In en, this message translates to:
  /// **'Area (optional)'**
  String get areaLabel;

  /// Address field.
  ///
  /// In en, this message translates to:
  /// **'City'**
  String get cityLabel;

  /// Address field.
  ///
  /// In en, this message translates to:
  /// **'State'**
  String get stateLabel;

  /// Address field.
  ///
  /// In en, this message translates to:
  /// **'PIN code'**
  String get pincodeLabel;

  /// PIN code validation error.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid 6-digit PIN code.'**
  String get pincodeInvalid;

  /// Address field; defaults to the user.
  ///
  /// In en, this message translates to:
  /// **'Receiver\'s name'**
  String get receiverNameLabel;

  /// Address field; defaults to the user.
  ///
  /// In en, this message translates to:
  /// **'Receiver\'s mobile number'**
  String get receiverPhoneLabel;

  /// Generic required-field error.
  ///
  /// In en, this message translates to:
  /// **'This field is required.'**
  String get fieldRequired;

  /// Section heading in the address form.
  ///
  /// In en, this message translates to:
  /// **'Delivery location'**
  String get locationTitle;

  /// Captures the device location.
  ///
  /// In en, this message translates to:
  /// **'Use my current location'**
  String get useCurrentLocation;

  /// Shown once the device location is set.
  ///
  /// In en, this message translates to:
  /// **'Location captured'**
  String get locationCaptured;

  /// Shown until the location is captured.
  ///
  /// In en, this message translates to:
  /// **'We need your location to deliver to this address. Stand at the address and tap \"Use my current location\".'**
  String get locationNeeded;

  /// Location permission denied.
  ///
  /// In en, this message translates to:
  /// **'Location permission is off. Allow location access so we can find your address.'**
  String get locationDenied;

  /// Location permission permanently denied.
  ///
  /// In en, this message translates to:
  /// **'Location access is blocked for Jivo. Turn it on in Settings.'**
  String get locationDeniedForever;

  /// Location services disabled.
  ///
  /// In en, this message translates to:
  /// **'Your phone\'s location is turned off. Turn it on and try again.'**
  String get locationServicesOff;

  /// Location lookup failed or timed out.
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t get your location. Please try again.'**
  String get locationFailed;

  /// Opens the system settings.
  ///
  /// In en, this message translates to:
  /// **'Open settings'**
  String get openSettings;

  /// Confirmation after saving an address.
  ///
  /// In en, this message translates to:
  /// **'Address saved.'**
  String get addressSaved;

  /// Delete-account screen title.
  ///
  /// In en, this message translates to:
  /// **'Delete account'**
  String get deleteAccountTitle;

  /// Explains the 30-day grace period.
  ///
  /// In en, this message translates to:
  /// **'Deleting your account signs you out on all devices. You have 30 days to change your mind: log in again within 30 days to restore it. After that, your personal data is permanently anonymised. Order and invoice records are kept without your personal details, as required by law.'**
  String get deleteAccountExplainer;

  /// Optional deletion reason.
  ///
  /// In en, this message translates to:
  /// **'Why are you leaving? (optional)'**
  String get deleteReasonLabel;

  /// Requests the delete-account OTP.
  ///
  /// In en, this message translates to:
  /// **'Send OTP to confirm'**
  String get sendOtpToConfirm;

  /// Delete-account OTP helper text.
  ///
  /// In en, this message translates to:
  /// **'Enter the OTP sent to {phone} to confirm.'**
  String deleteOtpSentTo(String phone);

  /// Confirms deletion.
  ///
  /// In en, this message translates to:
  /// **'Delete my account'**
  String get deleteMyAccount;

  /// Dialog after deletion.
  ///
  /// In en, this message translates to:
  /// **'Account deleted'**
  String get accountDeletedTitle;

  /// Dialog after deletion with the anonymisation date.
  ///
  /// In en, this message translates to:
  /// **'Your account is scheduled for deletion. Log in again before {date} to restore it.'**
  String accountDeletedBody(String date);

  /// PERMISSION_DENIED on account deletion (staff accounts).
  ///
  /// In en, this message translates to:
  /// **'This account can\'t be deleted from the app. Please contact support.'**
  String get staffCannotDelete;
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
