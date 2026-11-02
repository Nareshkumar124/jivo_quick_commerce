// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Jivo';

  @override
  String get retry => 'Retry';

  @override
  String get cancel => 'Cancel';

  @override
  String get continueLabel => 'Continue';

  @override
  String get save => 'Save';

  @override
  String get close => 'Close';

  @override
  String get ok => 'OK';

  @override
  String get splashChecking => 'Getting things ready…';

  @override
  String get splashFailedTitle => 'Can\'t reach Jivo';

  @override
  String get offlineBanner => 'No internet connection';

  @override
  String get onboardingTitle1 => 'Wellness, delivered fast';

  @override
  String get onboardingBody1 =>
      'Jivo oils, foods and essentials at your door in minutes.';

  @override
  String get onboardingTitle2 => 'Straight from Jivo';

  @override
  String get onboardingBody2 => 'Genuine products, fresh stock, fair prices.';

  @override
  String get onboardingTitle3 => 'Track every order';

  @override
  String get onboardingBody3 =>
      'Follow your rider live until your order arrives.';

  @override
  String get onboardingSkip => 'Skip';

  @override
  String get onboardingNext => 'Next';

  @override
  String get onboardingStart => 'Get started';

  @override
  String get updateRequiredTitle => 'Update required';

  @override
  String get updateRequiredBody =>
      'This version of Jivo is no longer supported. Please update the app to continue.';

  @override
  String get updateNow => 'Update now';

  @override
  String get updateAvailable => 'A new version of Jivo is available.';

  @override
  String get later => 'Later';

  @override
  String get maintenanceTitle => 'We\'ll be back soon';

  @override
  String get maintenanceDefaultBody =>
      'Jivo is down for maintenance. Please try again in a little while.';

  @override
  String get tryAgain => 'Try again';

  @override
  String get linkOpenFailed => 'Couldn\'t open the link.';

  @override
  String get loginTitle => 'Log in or sign up';

  @override
  String get loginSubtitle => 'Enter your mobile number to get an OTP.';

  @override
  String get phoneLabel => 'Mobile number';

  @override
  String get phonePrefix => '+91';

  @override
  String get phoneInvalid => 'Enter a valid 10-digit mobile number.';

  @override
  String get getOtp => 'Get OTP';

  @override
  String get consentPrefix => 'By continuing, you agree to our';

  @override
  String get termsOfService => 'Terms of Service';

  @override
  String get privacyPolicy => 'Privacy Policy';

  @override
  String get refundPolicy => 'Refund Policy';

  @override
  String get sessionExpired => 'Your session has expired. Please log in again.';

  @override
  String get otpTitle => 'Verify your number';

  @override
  String otpSentTo(int length, String phone) {
    return 'Enter the $length-digit OTP sent to $phone';
  }

  @override
  String get otpLabel => 'OTP';

  @override
  String otpIncomplete(int length) {
    return 'Enter the $length-digit OTP.';
  }

  @override
  String get verify => 'Verify';

  @override
  String resendIn(int seconds) {
    return 'Resend OTP in ${seconds}s';
  }

  @override
  String get resendOtp => 'Resend OTP';

  @override
  String get otpResent => 'A new OTP has been sent.';

  @override
  String get changeNumber => 'Change number';

  @override
  String get accountDeactivated =>
      'This account is deactivated. Please contact support.';

  @override
  String get deletionCancelledNotice =>
      'Welcome back! Your account deletion request has been cancelled.';

  @override
  String get completeProfileTitle => 'Tell us about you';

  @override
  String get completeProfileSubtitle => 'We\'ll use your name for deliveries.';

  @override
  String get nameLabel => 'Full name';

  @override
  String get nameRequired => 'Please enter your name.';

  @override
  String get emailLabel => 'Email (optional)';

  @override
  String get emailInvalid => 'Enter a valid email address.';

  @override
  String get emailCantBeUsed => 'This email can\'t be used.';

  @override
  String homeGreeting(String name) {
    return 'Hi, $name!';
  }

  @override
  String get homeComingSoon =>
      'Shopping arrives in the next update. Meanwhile, set up your account and addresses.';

  @override
  String get accountTitle => 'Account';

  @override
  String get editProfile => 'Edit profile';

  @override
  String get addresses => 'Saved addresses';

  @override
  String get legal => 'Legal';

  @override
  String appVersion(String version) {
    return 'App version $version';
  }

  @override
  String get logout => 'Log out';

  @override
  String get logoutConfirm => 'Log out of Jivo on this device?';

  @override
  String get deleteAccount => 'Delete account';

  @override
  String get phoneNotEditable => 'Your mobile number can\'t be changed.';

  @override
  String get profileSaved => 'Profile updated.';

  @override
  String get addressesEmpty => 'No saved addresses yet.';

  @override
  String get addAddress => 'Add address';

  @override
  String get editAddress => 'Edit address';

  @override
  String get newAddress => 'New address';

  @override
  String get defaultAddress => 'Default';

  @override
  String get setAsDefault => 'Set as default';

  @override
  String get delete => 'Delete';

  @override
  String get edit => 'Edit';

  @override
  String get deleteAddressConfirm => 'Delete this address?';

  @override
  String get labelHome => 'Home';

  @override
  String get labelWork => 'Work';

  @override
  String get labelOther => 'Other';

  @override
  String get customLabel => 'Name this address (e.g. Mom\'s place)';

  @override
  String get houseLabel => 'House / flat / floor';

  @override
  String get buildingStreetLabel => 'Building / street';

  @override
  String get landmarkLabel => 'Landmark (optional)';

  @override
  String get areaLabel => 'Area (optional)';

  @override
  String get cityLabel => 'City';

  @override
  String get stateLabel => 'State';

  @override
  String get pincodeLabel => 'PIN code';

  @override
  String get pincodeInvalid => 'Enter a valid 6-digit PIN code.';

  @override
  String get receiverNameLabel => 'Receiver\'s name';

  @override
  String get receiverPhoneLabel => 'Receiver\'s mobile number';

  @override
  String get fieldRequired => 'This field is required.';

  @override
  String get locationTitle => 'Delivery location';

  @override
  String get useCurrentLocation => 'Use my current location';

  @override
  String get locationCaptured => 'Location captured';

  @override
  String get locationNeeded =>
      'We need your location to deliver to this address. Stand at the address and tap \"Use my current location\".';

  @override
  String get locationDenied =>
      'Location permission is off. Allow location access so we can find your address.';

  @override
  String get locationDeniedForever =>
      'Location access is blocked for Jivo. Turn it on in Settings.';

  @override
  String get locationServicesOff =>
      'Your phone\'s location is turned off. Turn it on and try again.';

  @override
  String get locationFailed =>
      'We couldn\'t get your location. Please try again.';

  @override
  String get openSettings => 'Open settings';

  @override
  String get addressSaved => 'Address saved.';

  @override
  String get deleteAccountTitle => 'Delete account';

  @override
  String get deleteAccountExplainer =>
      'Deleting your account signs you out on all devices. You have 30 days to change your mind: log in again within 30 days to restore it. After that, your personal data is permanently anonymised. Order and invoice records are kept without your personal details, as required by law.';

  @override
  String get deleteReasonLabel => 'Why are you leaving? (optional)';

  @override
  String get sendOtpToConfirm => 'Send OTP to confirm';

  @override
  String deleteOtpSentTo(String phone) {
    return 'Enter the OTP sent to $phone to confirm.';
  }

  @override
  String get deleteMyAccount => 'Delete my account';

  @override
  String get accountDeletedTitle => 'Account deleted';

  @override
  String accountDeletedBody(String date) {
    return 'Your account is scheduled for deletion. Log in again before $date to restore it.';
  }

  @override
  String get staffCannotDelete =>
      'This account can\'t be deleted from the app. Please contact support.';
}
