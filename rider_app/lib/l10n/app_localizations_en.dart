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

  @override
  String onboardingStepOf(int step, int total) {
    return 'Step $step of $total';
  }

  @override
  String get onboardingCheckDetails =>
      'Some details were not accepted. Check them and try again.';

  @override
  String get onboardingLoading => 'Loading your application…';

  @override
  String get onboardingLoadError => 'Couldn\'t load your application';

  @override
  String get fieldRequired => 'This is required.';

  @override
  String get fieldNameInvalid =>
      'Enter a name with letters only, at least 2 characters.';

  @override
  String get fieldDobInFuture => 'Date of birth can\'t be in the future.';

  @override
  String fieldDobUnderage(int age) {
    return 'You must be at least $age years old to ride with Jivo.';
  }

  @override
  String get fieldPhoneSameAsRider =>
      'Enter someone else\'s number, not your own.';

  @override
  String get fieldVehicleNumberInvalid =>
      'Enter the vehicle number as on the number plate, like DL 3C AB 1234.';

  @override
  String get fieldAccountNumberInvalid =>
      'Enter a valid account number (9 to 18 digits).';

  @override
  String get fieldAccountNumbersMismatch => 'The account numbers don\'t match.';

  @override
  String get fieldIfscInvalid =>
      'Enter the 11-character IFSC, like HDFC0001234.';

  @override
  String get fieldUpiInvalid => 'Enter a valid UPI ID, like name@okbank.';

  @override
  String get fieldAadhaarInvalid =>
      'Enter your 12-digit Aadhaar number exactly as printed.';

  @override
  String get fieldPanInvalid =>
      'Enter your PAN exactly as printed, like ABCDE1234F.';

  @override
  String get fieldDrivingLicenceInvalid =>
      'Enter your licence number exactly as printed on the card.';

  @override
  String get registerIntro =>
      'Tell us about yourself and your vehicle. Next, you\'ll upload your documents.';

  @override
  String get registerSectionAboutYou => 'About you';

  @override
  String get registerFullName => 'Full name (as on Aadhaar)';

  @override
  String get registerDob => 'Date of birth';

  @override
  String get registerDobHint => 'Choose the date';

  @override
  String get registerDobPickerHelp => 'Select your date of birth';

  @override
  String get registerSectionEmergency => 'Emergency contact';

  @override
  String get registerEmergencyHelp =>
      'Someone Jivo can call if something happens to you on a delivery.';

  @override
  String get registerEmergencyName => 'Contact name';

  @override
  String get registerEmergencyPhone => 'Contact mobile number';

  @override
  String get registerSectionStore => 'Preferred store';

  @override
  String get registerStoreLabel => 'Store you want to deliver for';

  @override
  String get registerStoreHelp =>
      'Jivo confirms your store when your account is approved.';

  @override
  String registerStoreOption(String name, String city) {
    return '$name, $city';
  }

  @override
  String get registerStoresLoading => 'Loading stores…';

  @override
  String get registerStoresError => 'Couldn\'t load the stores.';

  @override
  String get registerSectionVehicle => 'Your vehicle';

  @override
  String get registerVehicleNumber => 'Vehicle number';

  @override
  String get registerVehicleNumberHint => 'DL 3C AB 1234';

  @override
  String get registerSubmit => 'Continue';

  @override
  String get vehicleBicycle => 'Bicycle';

  @override
  String get vehicleEBike => 'E-bike';

  @override
  String get vehicleMotorbike => 'Motorbike';

  @override
  String get vehicleScooter => 'Scooter';

  @override
  String get statusFinishTitle => 'Finish your application';

  @override
  String get statusFinishBody =>
      'Complete these steps so Jivo can review your application.';

  @override
  String get statusStepDetails => 'Personal and vehicle details';

  @override
  String get statusStepDocuments => 'Documents';

  @override
  String get statusStepBank => 'Bank details';

  @override
  String get statusStepDone => 'Done';

  @override
  String get statusStepNeeded => 'Needed';

  @override
  String statusStepDocumentsProgress(int done, int total) {
    return '$done of $total uploaded';
  }

  @override
  String statusStepDocumentsFix(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count documents need new photos',
      one: '1 document needs a new photo',
    );
    return '$_temp0';
  }

  @override
  String get statusActionUploadDocuments => 'Upload documents';

  @override
  String get statusActionAddBank => 'Add bank details';

  @override
  String get statusActionCheck => 'Check status';

  @override
  String get statusActionViewDocuments => 'View documents';

  @override
  String get statusRejectedFixBody =>
      'Fix the items below. Jivo reviews your application again after you send them.';

  @override
  String get statusRejectedReasonLabel => 'Reason from Jivo';

  @override
  String get statusActionFixDocuments => 'Upload documents again';

  @override
  String get statusActionFixBank => 'Update bank details';

  @override
  String get statusApprovedTitle => 'You\'re approved!';

  @override
  String statusApprovedBody(String store) {
    return 'Your home store is $store. You can now go online and start delivering.';
  }

  @override
  String get statusActionStart => 'Start delivering';

  @override
  String get statusDevReview => 'Simulate review (dev)';

  @override
  String get statusDevApprove => 'Approve (fake)';

  @override
  String get statusDevReject => 'Reject the PAN (fake)';

  @override
  String get documentsTitle => 'Documents';

  @override
  String get documentsIntro =>
      'Take clear photos in good light. Each photo must show the whole document.';

  @override
  String documentsProgress(int done, int total) {
    return '$done of $total done. Upload every document to continue.';
  }

  @override
  String get documentsContinue => 'Continue';

  @override
  String get docPhoto => 'Your photo (selfie)';

  @override
  String get docAadhaarFront => 'Aadhaar card: front';

  @override
  String get docAadhaarBack => 'Aadhaar card: back';

  @override
  String get docPan => 'PAN card';

  @override
  String get docDrivingLicence => 'Driving licence';

  @override
  String get docVehicleRc => 'Vehicle RC';

  @override
  String get docStatusNeeded => 'Needed';

  @override
  String get docStatusPending => 'In review';

  @override
  String get docStatusApproved => 'Approved';

  @override
  String get docStatusRejected => 'Not accepted: upload again';

  @override
  String get docActionUpload => 'Upload';

  @override
  String get docActionReplace => 'Replace';

  @override
  String get docActionReupload => 'Upload again';

  @override
  String docUploaded(String document) {
    return '$document uploaded';
  }

  @override
  String get captureHintPhoto =>
      'Take a clear photo of your face in good light. Remove your helmet, cap and sunglasses.';

  @override
  String get captureHintCard =>
      'Put the card on a flat, dark surface. All four corners and the text must be clear, with no glare.';

  @override
  String get captureTakePhoto => 'Take photo';

  @override
  String get captureChooseGallery => 'Choose from gallery';

  @override
  String get captureProcessing => 'Preparing the photo…';

  @override
  String get captureReady => 'Photo ready';

  @override
  String get captureCheck =>
      'Check that the photo is sharp and nothing is cut off.';

  @override
  String get captureUpload => 'Upload';

  @override
  String get captureRetake => 'Retake';

  @override
  String get captureProblemPicker =>
      'Couldn\'t open the camera or gallery. Allow Jivo Rider to use the camera in your phone settings, then try again.';

  @override
  String get captureProblemUnreadable =>
      'That file can\'t be used. Take a new photo.';

  @override
  String get captureProblemTooLarge =>
      'That photo is too large. Take a new photo.';

  @override
  String get numberAadhaar => 'Aadhaar number';

  @override
  String get numberPan => 'PAN';

  @override
  String get numberDrivingLicence => 'Driving licence number';

  @override
  String get numberVehicleRc => 'Vehicle number (as on the RC)';

  @override
  String numberMaskedHelper(String masked) {
    return 'Entered: $masked';
  }

  @override
  String get bankTitle => 'Bank details';

  @override
  String get bankIntro => 'Jivo pays your earnings into this account.';

  @override
  String bankSaved(String account, String ifsc) {
    return 'Saved account $account · $ifsc';
  }

  @override
  String bankSavedShort(String account) {
    return 'Account $account';
  }

  @override
  String get bankReplaceHint => 'To change it, enter the new details below.';

  @override
  String get bankHolderName => 'Account holder name';

  @override
  String get bankAccountNumber => 'Account number';

  @override
  String get bankConfirmAccountNumber => 'Re-enter account number';

  @override
  String get bankIfsc => 'IFSC';

  @override
  String get bankIfscHint => 'HDFC0001234';

  @override
  String get bankUpi => 'UPI ID (optional)';

  @override
  String get bankUpiHint => 'name@okbank';

  @override
  String get bankSave => 'Save bank details';

  @override
  String get bankSavedToast => 'Bank details saved';
}
