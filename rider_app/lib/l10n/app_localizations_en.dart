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
  String get disclosureTitle =>
      'Jivo Rider uses your location in the background';

  @override
  String get disclosureBody =>
      'Jivo Rider collects location data to send you delivery offers near your store, guide you to customers, and show customers where their order is, even when the app is closed or not in use.';

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
  String get disclosureAccept => 'I agree, turn on location';

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

  @override
  String get offerTitle => 'New order';

  @override
  String get offerAlertTitle => 'New order offer';

  @override
  String offerAlertBody(String store, String locality) {
    return '$store to $locality';
  }

  @override
  String get offerPrepaid => 'Prepaid · nothing to collect';

  @override
  String offerCod(String amount) {
    return 'Cash $amount to collect';
  }

  @override
  String offerPayout(String amount) {
    return 'You earn about $amount';
  }

  @override
  String distanceKm(String km) {
    return '$km km';
  }

  @override
  String get offerAccept => 'Accept order';

  @override
  String get offerReject => 'Reject';

  @override
  String get offerRejectTitle => 'Why are you rejecting? (optional)';

  @override
  String get offerRejectTooFar => 'Too far';

  @override
  String get offerRejectVehicle => 'Vehicle problem';

  @override
  String get offerRejectBreak => 'Taking a break';

  @override
  String get offerRejectOther => 'Other reason';

  @override
  String get offerRejectSkip => 'Reject without a reason';

  @override
  String get offerExpiredTitle => 'Offer expired';

  @override
  String get offerExpiredBody =>
      'The time to accept ran out. New orders will come to you.';

  @override
  String get offerTakenTitle => 'Order taken';

  @override
  String get offerTakenBody => 'Another rider accepted this order first.';

  @override
  String get offerWithdrawnTitle => 'Order cancelled';

  @override
  String get offerWithdrawnBody =>
      'This order was cancelled before pickup. Wait for the next one.';

  @override
  String get offerOk => 'OK';

  @override
  String taskOrderNumber(String number) {
    return 'Order $number';
  }

  @override
  String get taskRefresh => 'Refresh';

  @override
  String get taskNavigate => 'Navigate';

  @override
  String get taskNoMapsApp =>
      'No maps app found. Install Mappls or another maps app.';

  @override
  String get taskCallCustomer => 'Call';

  @override
  String get taskStateChanged =>
      'This order changed. The screen now shows its latest step.';

  @override
  String get taskLocationUnavailable =>
      'Couldn\'t get your location. Turn on GPS and try again.';

  @override
  String get taskOutsideGeofence =>
      'You\'re not close enough yet. Move closer and try again.';

  @override
  String taskOutsideGeofenceDistance(int metres) {
    return 'You\'re $metres m away. Move closer and try again.';
  }

  @override
  String get cashLimitExceeded =>
      'Your cash in hand has reached the limit. Deposit cash at the store to get cash orders again.';

  @override
  String get taskGoToStoreTitle => 'Go to the store';

  @override
  String get taskOrderPacking => 'Store is packing: wait here';

  @override
  String get taskOrderReady => 'Ready for pickup';

  @override
  String get taskArrivedStore => 'Arrived at store';

  @override
  String get taskPickupTitle => 'Pick up the order';

  @override
  String get taskItemsTitle => 'Check the items in the bag';

  @override
  String get pickupCodeHelp =>
      'Scan the QR on the bag, or type the 4-character code printed on it.';

  @override
  String get pickupCodeLabel => 'Order code';

  @override
  String get pickupCodeFormat => 'Enter the 4-character code from the bag.';

  @override
  String get pickupCodeWrong =>
      'That code doesn\'t match this order. Check the bag and try again.';

  @override
  String get pickupNotPacked =>
      'The order isn\'t packed yet. Wait until the store marks it ready.';

  @override
  String get taskPickup => 'Confirm pickup';

  @override
  String get pickupScan => 'Scan bag QR';

  @override
  String get scanTitle => 'Scan the bag QR code';

  @override
  String get scanTypeInstead => 'Type the code instead';

  @override
  String get scanNotJivoCode => 'This QR isn\'t a Jivo order code.';

  @override
  String get scanCameraUnavailable =>
      'The camera isn\'t available. Type the code from the bag instead.';

  @override
  String get taskGoToCustomerTitle => 'Deliver to the customer';

  @override
  String taskLandmark(String landmark) {
    return 'Landmark: $landmark';
  }

  @override
  String taskInstructions(String instructions) {
    return 'Note: $instructions';
  }

  @override
  String taskCollectCash(String amount) {
    return 'Collect $amount in cash';
  }

  @override
  String get taskArrivedCustomer => 'Arrived at customer';

  @override
  String get taskCantDeliver => 'Can\'t deliver…';

  @override
  String get arrivedOverride => 'Not at the pin? Arrive anyway';

  @override
  String get arrivedOverrideTitle => 'Why are you outside the pin area?';

  @override
  String get arrivedOverridePinWrong => 'The map pin is in the wrong place';

  @override
  String get arrivedOverrideGate => 'I\'m at the gate or lobby';

  @override
  String get otpStepTitle => 'Enter the delivery code';

  @override
  String get otpStepHelp =>
      'Ask the customer for the 4-digit code in their app or SMS.';

  @override
  String get otpStepLabel => 'Delivery code';

  @override
  String get otpContinue => 'Continue';

  @override
  String get taskDeliver => 'Mark delivered';

  @override
  String otpAttemptsLeft(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count attempts left',
      one: '1 attempt left',
    );
    return '$_temp0';
  }

  @override
  String get deliveryOtpWrong =>
      'Wrong code. Ask the customer to read it again from their app or SMS.';

  @override
  String deliveryOtpWrongLeft(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Wrong code. $count tries left. Ask the customer to read it again from their app or SMS.',
      one: 'Wrong code. 1 try left. Ask the customer to read it again from their app or SMS.',
    );
    return '$_temp0';
  }

  @override
  String get deliveryOtpLocked =>
      'Too many wrong codes. Jivo support has been alerted. Call support to continue.';

  @override
  String get otpLockedTitle => 'Delivery code locked';

  @override
  String get codTitle => 'Collect payment';

  @override
  String get codAmountDueLabel => 'Amount to collect';

  @override
  String get codExactAmount =>
      'Collect exactly this amount. Don\'t accept more or less.';

  @override
  String codCashCollected(String amount) {
    return 'Cash collected $amount';
  }

  @override
  String codConfirmTitle(String amount) {
    return 'Collected $amount?';
  }

  @override
  String get codConfirmBody =>
      'Count the cash before confirming. You can\'t change this after delivery.';

  @override
  String codConfirmYes(String amount) {
    return 'Yes, $amount collected';
  }

  @override
  String get codConfirmNo => 'Not yet';

  @override
  String codCashDone(String amount) {
    return 'Cash collected: $amount';
  }

  @override
  String get codShowUpi => 'Customer pays by UPI: show QR';

  @override
  String get codUpiWaiting => 'Waiting for the payment…';

  @override
  String get codUpiPaid => 'Payment received';

  @override
  String get codUpiCheck => 'Check payment';

  @override
  String get codChangeOtp => 'Change the delivery code';

  @override
  String get codConfirmFirst =>
      'Confirm the cash or wait for the UPI payment first.';

  @override
  String get codAmountMismatch =>
      'The amount doesn\'t match what Jivo expects. Check the amount and try again.';

  @override
  String get taskDeliveredTitle => 'Delivered!';

  @override
  String get taskDeliveredBody => 'Great job. Wait for the next order.';

  @override
  String taskDeliveredEarned(String amount) {
    return 'You earned $amount for this order.';
  }

  @override
  String get taskReturnTitle => 'Return to store';

  @override
  String get taskReturnBody =>
      'Take the items back to the store. The store staff will mark them received.';

  @override
  String get taskCheckStatus => 'Check status';

  @override
  String get taskReturnedTitle => 'Items returned';

  @override
  String get taskReturnedBody =>
      'The store received the items. You\'re ready for new orders.';

  @override
  String get taskCancelledTitle => 'Order cancelled';

  @override
  String get taskCancelledBody =>
      'This order was cancelled before pickup. You don\'t need to collect it.';

  @override
  String get taskUnassignedTitle => 'Order reassigned';

  @override
  String get taskUnassignedBody => 'This order is no longer assigned to you.';

  @override
  String get taskUnknownTitle => 'Can\'t show this order';

  @override
  String get taskUnknownBody =>
      'This app version can\'t show the order\'s status. Try again or update the app.';

  @override
  String get failTitle => 'Can\'t deliver';

  @override
  String get failIntro => 'Why can\'t you deliver this order?';

  @override
  String get failNotReachable => 'Customer not reachable';

  @override
  String get failRefused => 'Customer refused the order';

  @override
  String get failWrongAddress => 'Wrong address';

  @override
  String get failOther => 'Other reason';

  @override
  String failCallsNeeded(int needed, int done) {
    return 'Call the customer at least $needed times ($done done)';
  }

  @override
  String failWaitLeft(String time) {
    return 'Wait at the address: $time left';
  }

  @override
  String get failWaitDone => 'You waited 10 minutes at the address';

  @override
  String get failWaitNotArrived => 'Mark \"Arrived at customer\" first';

  @override
  String get failNoteOptional => 'Note (optional)';

  @override
  String get failNoteRequired => 'Note (required)';

  @override
  String get failAddPhoto => 'Add a photo (optional)';

  @override
  String get failPhotoAdded => 'Photo added';

  @override
  String get failPhotoRemove => 'Remove';

  @override
  String get failPhotoError => 'Couldn\'t use that photo. Try again.';

  @override
  String get failChooseReason => 'Choose a reason.';

  @override
  String get failNotYet =>
      'You can choose this after the calls and the 10-minute wait.';

  @override
  String get failSubmit => 'Return to store';

  @override
  String get logoutBlockedDuringTask =>
      'Finish your current order before logging out.';

  @override
  String get offlineBlockedDuringTask => 'Finish your current order first.';

  @override
  String get devOfferPrepaid => 'Test offer (dev)';

  @override
  String get devOfferCod => 'Test COD offer (dev)';

  @override
  String get devMarkPacked => 'Store: packed (dev)';

  @override
  String get devCancelOrder => 'Cancel order (dev)';

  @override
  String get devReturnReceived => 'Store: return received (dev)';

  @override
  String get devUpiPaid => 'Customer paid (dev)';

  @override
  String get codTakeCashInstead => 'Customer pays cash instead';

  @override
  String get codUpiExpired => 'The QR expired. Show a new one.';

  @override
  String get taskUnconfirmedTitle => 'Couldn\'t confirm the last step';

  @override
  String get taskUnconfirmedBody =>
      'The connection dropped before Jivo answered, and this order is no longer open. It may have gone through. Check the order status, or call support.';

  @override
  String get taskBackToOrders => 'Back to orders';

  @override
  String get codQrUnavailable =>
      'Couldn\'t show the QR code. Check payment again, or collect cash.';

  @override
  String get listLoadMore => 'Load more';

  @override
  String dateRange(String from, String to) {
    return '$from – $to';
  }

  @override
  String get earningsTitle => 'Earnings';

  @override
  String get earningsToday => 'Today';

  @override
  String get earningsThisWeek => 'This week';

  @override
  String get earningsChooseDates => 'Choose dates';

  @override
  String earningsOrders(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count orders',
      one: '1 order',
      zero: 'No orders',
    );
    return '$_temp0';
  }

  @override
  String get earningsPerOrder => 'Per order';

  @override
  String get earningsAdjustments => 'Incentives and penalties';

  @override
  String get earningBase => 'Base pay';

  @override
  String get earningDistance => 'Distance pay';

  @override
  String get earningTip => 'Tips';

  @override
  String get earningIncentive => 'Incentives';

  @override
  String get earningPenalty => 'Penalties';

  @override
  String get payoutsTitle => 'Payouts';

  @override
  String get payoutsEmpty => 'No payouts yet.';

  @override
  String get payoutPaid => 'Paid';

  @override
  String get payoutPending => 'Pending';

  @override
  String payoutReference(String reference) {
    return 'Reference $reference';
  }

  @override
  String payoutPaidOn(String date) {
    return 'Paid on $date';
  }

  @override
  String get cashTitle => 'Cash in hand';

  @override
  String get cashEmpty => 'No cash entries yet.';

  @override
  String get cashInHand => 'Cash in hand';

  @override
  String cashLimit(String amount) {
    return 'Limit $amount';
  }

  @override
  String get cashDepositTitle => 'Deposit cash';

  @override
  String cashDepositBody(String limit) {
    return 'You\'ve reached the cash limit of $limit. Hand the cash to the store manager to get cash orders again. Until then you get prepaid orders only.';
  }

  @override
  String cashCodCollected(String order) {
    return 'Cash collected · Order $order';
  }

  @override
  String get cashCodCollectedNoOrder => 'Cash collected';

  @override
  String get cashDeposit => 'Deposited at the store';

  @override
  String get cashAdjustment => 'Adjustment';

  @override
  String cashBalanceAfter(String amount) {
    return 'Balance $amount';
  }

  @override
  String get historyTitle => 'History';

  @override
  String get historyEmpty => 'No past orders yet.';

  @override
  String historyRoute(String store, String drop) {
    return '$store → $drop';
  }

  @override
  String get historyDelivered => 'Delivered';

  @override
  String get historyReturned => 'Returned';

  @override
  String get historyCancelled => 'Cancelled';

  @override
  String get historyFailed => 'Not delivered';

  @override
  String get historyOther => 'Ended';

  @override
  String get profileTitle => 'Profile';

  @override
  String get profileHomeStore => 'Home store';

  @override
  String get profileVehicle => 'Vehicle';

  @override
  String get profileKycStatus => 'KYC status';

  @override
  String get profileKycApproved => 'Verified';

  @override
  String get profileRating => 'Rating';

  @override
  String profileRatingValue(String rating) {
    return '$rating ★';
  }

  @override
  String get profileNoRating => 'No ratings yet';

  @override
  String get documentsProfileIntro =>
      'Your KYC documents and their review status. Approved documents can\'t be changed. Upload again any document marked Rejected.';

  @override
  String documentsNeedAttention(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count documents need a new upload.',
      one: '1 document needs a new upload.',
    );
    return '$_temp0';
  }

  @override
  String profileDocumentsAttention(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count need a new upload',
      one: '1 needs a new upload',
    );
    return '$_temp0';
  }

  @override
  String get profileDocumentsAllGood => 'All approved';

  @override
  String get profileDocumentsInReview => 'In review';

  @override
  String get profileSupport => 'Support';

  @override
  String get profileSupportBody =>
      'Problems with an order, a payout or the app? Call Jivo rider support.';

  @override
  String get devRejectDocument => 'Ops: reject the driving licence (dev)';

  @override
  String get debugSimulateServerOffline => 'Server has auto-offlined me (fake)';

  @override
  String debugStatsLink(int failures, int heartbeats) {
    return 'Failed in a row $failures · Heartbeats $heartbeats';
  }

  @override
  String get dismiss => 'Dismiss';

  @override
  String homeGreeting(String name) {
    return 'Hi, $name';
  }

  @override
  String get homeYourStore => 'your store';

  @override
  String get shiftOfflineTitle => 'You\'re offline';

  @override
  String get shiftOfflineBody => 'You won\'t get orders.';

  @override
  String get shiftOnlineTitle => 'You\'re online';

  @override
  String get shiftOnlineBody => 'Waiting for orders near your store.';

  @override
  String shiftOnlineBodyStore(String store) {
    return 'Waiting for orders near $store.';
  }

  @override
  String get shiftOnlinePrepaidTitle => 'You\'re online: prepaid orders only';

  @override
  String get shiftOnlinePrepaidBody =>
      'Deposit cash at the store to get cash orders again.';

  @override
  String get shiftAutoOfflineTitle => 'You were set offline';

  @override
  String get shiftAutoOfflineBody =>
      'We didn\'t get your location for 10 minutes. Check GPS and your connection, then go online again.';

  @override
  String get shiftGoOnline => 'Go online';

  @override
  String get shiftGoOffline => 'Go offline';

  @override
  String get shiftGoingOnline => 'Going online…';

  @override
  String get shiftGoingOffline => 'Going offline…';

  @override
  String get shiftFixPermissions => 'Fix permissions';

  @override
  String get shiftSeeStatus => 'See status';

  @override
  String get shiftServiceFailed =>
      'Location tracking couldn\'t start. Try again; if it keeps failing, restart the phone.';

  @override
  String get shiftServerError => 'Couldn\'t go online. Try again.';

  @override
  String get guardBlockedHint => 'Fix the problem shown above first';

  @override
  String get guardNotActiveTitle => 'Your account isn\'t active';

  @override
  String get guardNotActiveBody =>
      'We\'ll let you know when Jivo approves your documents.';

  @override
  String get guardPermissionsTitle => 'Allow location and notifications';

  @override
  String get guardPermissionsBody => 'You need them to get orders.';

  @override
  String get guardGpsTitle => 'Turn on location (GPS)';

  @override
  String get guardGpsBody => 'Jivo Rider can\'t find you with GPS off.';

  @override
  String get guardGpsAction => 'Turn on GPS';

  @override
  String get guardTooFarTitle => 'You\'re too far from your store';

  @override
  String guardTooFarBody(String distance, String store, String radius) {
    return 'You\'re $distance km from $store. Go within $radius km to go online.';
  }

  @override
  String guardTooFarBodyNoDistance(String store) {
    return 'Move closer to $store and try again.';
  }

  @override
  String get guardNavigateToStore => 'Navigate to store';

  @override
  String get guardTaskActiveTitle => 'Finish your current order first';

  @override
  String get guardNetworkTitle => 'No internet';

  @override
  String get guardNetworkBody => 'Check your connection and try again.';

  @override
  String get currentTaskContinue => 'Continue';

  @override
  String get currentTaskContinueOrder => 'Continue order';

  @override
  String currentTaskSemantics(String order, String step) {
    return 'Current order $order, $step. Continue.';
  }

  @override
  String get taskStepGoToStore => 'Go to the store';

  @override
  String get taskStepPickup => 'Pick up the order';

  @override
  String get taskStepGoToCustomer => 'Deliver to the customer';

  @override
  String get taskStepDeliver => 'Enter the delivery code';

  @override
  String get taskStepReturn => 'Return to store';

  @override
  String get taskStepOther => 'Open the order';

  @override
  String get chipCod => 'COD';

  @override
  String chipCodAmount(String amount) {
    return 'COD $amount';
  }

  @override
  String get chipPrepaid => 'Prepaid';

  @override
  String get todayTitle => 'Today';

  @override
  String get todayDelivered => 'Delivered';

  @override
  String get todayEarned => 'Earned';

  @override
  String get todayOnline => 'Online time';

  @override
  String get todayCash => 'Cash in hand';

  @override
  String get todayOpensEarnings => 'opens earnings';

  @override
  String get todayOpensCash => 'opens cash';

  @override
  String get todayNotAvailable => 'not available';

  @override
  String get homeHowToDeposit => 'How to deposit';

  @override
  String get homeHowToDepositBody =>
      'Hand the cash to your store manager. It shows in your cash ledger once they record it.';

  @override
  String get homeSeeCashLedger => 'See cash ledger';

  @override
  String get gateActionLocationPrecise => 'Use precise location';

  @override
  String get gateStepLocationPreciseHint =>
      'Choose \"Precise\". Approximate location can\'t guide deliveries.';

  @override
  String get gateAlwaysNotChosenTitle =>
      '\"Allow all the time\" wasn\'t chosen';

  @override
  String get gateAlwaysNotChosenBody =>
      'Without it Jivo can\'t send you orders or track your delivery when the screen is off, so you can\'t go online. Open settings, tap Permissions › Location and choose \"Allow all the time\".';

  @override
  String get gateOpenAppSettings => 'Open app settings';

  @override
  String get disclosureDeclinedTitle => 'Location is needed to go online';

  @override
  String get disclosureDeclinedBody =>
      'You can still use the app, but you can\'t go online and get orders until you allow location.';

  @override
  String get disclosureNotification =>
      'While you\'re online you\'ll see a \"You\'re online\" notification.';

  @override
  String get offerCodAmountMissing =>
      'Cash on delivery: amount shown after you accept.';

  @override
  String offerTimeLeft(int seconds) {
    return 'Time left to accept: $seconds seconds';
  }

  @override
  String offerSecondsShort(int seconds) {
    return '$seconds s';
  }

  @override
  String get offerExpiring => 'Expiring';

  @override
  String offerDrop(String locality, String distance) {
    return '$locality · $distance';
  }

  @override
  String get codAmountMissing =>
      'Can\'t load the amount to collect. Pull down to refresh, or call support.';

  @override
  String get codRefresh => 'Refresh';

  @override
  String codAmountChangedTitle(String amount) {
    return 'Amount changed: collect $amount';
  }

  @override
  String codAmountChangedBody(String was) {
    return 'Was $was. The store couldn\'t supply some items.';
  }

  @override
  String codAmountPreviously(String amount) {
    return 'previously $amount';
  }

  @override
  String codAmountSemantics(String amount) {
    return 'Amount to collect: $amount';
  }

  @override
  String get devCodAmountChanged => 'Store: an item is unavailable (dev)';

  @override
  String get taskOfflineBanner =>
      'No internet. Your progress is saved on Jivo\'s server; tap the button again when you\'re back online.';

  @override
  String taskTryAgain(String label) {
    return 'Try again: $label';
  }

  @override
  String get taskWorking => 'Working';

  @override
  String get guardDocumentsTitle => 'Some documents need a new upload';

  @override
  String get guardDocumentsBody =>
      'Upload the documents marked in your profile, then go online.';

  @override
  String get guardDocumentsAction => 'See documents';

  @override
  String get pickupTypeCode => 'Type the code';

  @override
  String get pickupEnterAll => 'Enter all 4 characters.';

  @override
  String pickupCheckBag(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Check the bag: $count items',
      one: 'Check the bag: 1 item',
    );
    return '$_temp0';
  }

  @override
  String get scanHelper => 'Point at the QR on the bag label';

  @override
  String get scanLight => 'Light';

  @override
  String get scanLightOn => 'Light on';

  @override
  String get otpLockedHeading => 'Delivery code locked';

  @override
  String get deliveryOtpLockedNoPhone =>
      'Too many wrong codes. Jivo support has been alerted. Wait at the door for a call from support, or choose Can\'t deliver.';

  @override
  String get failConfirmTitle => 'Return the order to the store?';

  @override
  String failConfirmBody(String reason) {
    return 'Reason: $reason. The customer will be told. You can\'t undo this.';
  }

  @override
  String failConfirmNote(String note) {
    return 'Note: $note';
  }

  @override
  String get failConfirmBack => 'Go back';

  @override
  String get failConfirmYes => 'Yes, return to store';

  @override
  String failWaitSemantics(int minutes, int seconds) {
    return 'Wait time left: $minutes minutes $seconds seconds';
  }

  @override
  String get taskReturnNoCash =>
      'Don\'t collect any cash. Nothing is due for this order.';

  @override
  String get riderTooManyTries =>
      'Too many tries. Wait a moment, then try again.';

  @override
  String get shiftEndedByOpsBody =>
      'Jivo operations set you offline. Go online again when you are ready, or call support.';
}
