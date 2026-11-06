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

  /// Bottom tab: home.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get tabHome;

  /// Bottom tab and screen title: category tree.
  ///
  /// In en, this message translates to:
  /// **'Categories'**
  String get tabCategories;

  /// Bottom tab: previously bought items.
  ///
  /// In en, this message translates to:
  /// **'Order again'**
  String get tabOrderAgain;

  /// Bottom tab: account.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get tabAccount;

  /// Button on a product tile that adds one unit to the cart.
  ///
  /// In en, this message translates to:
  /// **'ADD'**
  String get addToCart;

  /// Screen-reader label of the ADD button.
  ///
  /// In en, this message translates to:
  /// **'Add {name} to cart'**
  String addToCartSemantics(String name);

  /// Screen-reader label of the stepper's minus button.
  ///
  /// In en, this message translates to:
  /// **'Remove one {name}'**
  String stepperDecrease(String name);

  /// Screen-reader label of the stepper's plus button.
  ///
  /// In en, this message translates to:
  /// **'Add one more {name}'**
  String stepperIncrease(String name);

  /// Screen-reader label of the quantity between minus and plus.
  ///
  /// In en, this message translates to:
  /// **'{count} in cart'**
  String stepperQuantity(int count);

  /// Shown when plus is tapped at the cap min(stock, max per order).
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{You can add only 1 of this item} other{You can add up to {count} of this item}}'**
  String maxQtyReached(int count);

  /// Label on a product that the store can't sell now.
  ///
  /// In en, this message translates to:
  /// **'Out of stock'**
  String get outOfStock;

  /// Low-stock label on a product.
  ///
  /// In en, this message translates to:
  /// **'Only {count} left'**
  String onlyLeft(int count);

  /// Discount badge, percent from the server.
  ///
  /// In en, this message translates to:
  /// **'{percent}% OFF'**
  String discountOff(int percent);

  /// Screen-reader text for the struck-out MRP.
  ///
  /// In en, this message translates to:
  /// **'MRP {price}'**
  String mrpSemantics(String price);

  /// Screen-reader text for the selling price.
  ///
  /// In en, this message translates to:
  /// **'Price {price}'**
  String priceSemantics(String price);

  /// Screen-reader label of the green veg mark.
  ///
  /// In en, this message translates to:
  /// **'Vegetarian'**
  String get vegMark;

  /// Screen-reader label of the brown non-veg mark.
  ///
  /// In en, this message translates to:
  /// **'Non-vegetarian'**
  String get nonVegMark;

  /// Item count on the floating cart bar.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 item} other{{count} items}}'**
  String cartItems(int count);

  /// Floating cart bar action.
  ///
  /// In en, this message translates to:
  /// **'View cart'**
  String get viewCart;

  /// Home header: delivery ETA from the server.
  ///
  /// In en, this message translates to:
  /// **'{minutes, plural, =1{Delivery in 1 min} other{Delivery in {minutes} mins}}'**
  String deliveryIn(int minutes);

  /// Home header and location screen title when no location is chosen.
  ///
  /// In en, this message translates to:
  /// **'Select delivery location'**
  String get selectLocation;

  /// Home header while serviceability loads.
  ///
  /// In en, this message translates to:
  /// **'Checking delivery…'**
  String get checkingDelivery;

  /// Home header when the location is not serviceable.
  ///
  /// In en, this message translates to:
  /// **'Not delivering here'**
  String get notDeliveringHere;

  /// Screen-reader hint of the home header address.
  ///
  /// In en, this message translates to:
  /// **'Change delivery location'**
  String get changeLocationSemantics;

  /// Home search bar placeholder.
  ///
  /// In en, this message translates to:
  /// **'Search for oils, ghee and more'**
  String get searchHint;

  /// Home section title: category grid.
  ///
  /// In en, this message translates to:
  /// **'Shop by category'**
  String get shopByCategory;

  /// Home section title: buy-again rail.
  ///
  /// In en, this message translates to:
  /// **'Previously bought'**
  String get previouslyBought;

  /// Opens the full list of a home section.
  ///
  /// In en, this message translates to:
  /// **'See all'**
  String get seeAll;

  /// Home empty state.
  ///
  /// In en, this message translates to:
  /// **'Nothing to show here yet. Pull down to refresh.'**
  String get homeEmpty;

  /// Home when no location is chosen.
  ///
  /// In en, this message translates to:
  /// **'Choose a delivery location to see what\'s in stock near you.'**
  String get homeNeedsLocation;

  /// Home when the saved location is no longer serviceable.
  ///
  /// In en, this message translates to:
  /// **'We don\'t deliver to this location yet.'**
  String get notServiceableInline;

  /// Button that opens the location picker.
  ///
  /// In en, this message translates to:
  /// **'Change location'**
  String get changeLocation;

  /// Store-closed banner with the opening time (IST).
  ///
  /// In en, this message translates to:
  /// **'Store closed. Opens at {time}. You can browse; checkout opens then.'**
  String storeClosedOpensAt(String time);

  /// Store-closed banner without an opening time.
  ///
  /// In en, this message translates to:
  /// **'Store closed right now. You can still browse.'**
  String get storeClosed;

  /// Screen-reader label of a home banner.
  ///
  /// In en, this message translates to:
  /// **'Offer: {title}'**
  String bannerSemantics(String title);

  /// Left-rail entry that shows the whole category.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get allInCategory;

  /// Categories empty state.
  ///
  /// In en, this message translates to:
  /// **'No categories yet.'**
  String get categoriesEmpty;

  /// Sort sheet title.
  ///
  /// In en, this message translates to:
  /// **'Sort by'**
  String get sortBy;

  /// Sort button on the product list.
  ///
  /// In en, this message translates to:
  /// **'Sort: {option}'**
  String sortButton(String option);

  /// Sort option.
  ///
  /// In en, this message translates to:
  /// **'Relevance'**
  String get sortRelevance;

  /// Sort option.
  ///
  /// In en, this message translates to:
  /// **'Price: low to high'**
  String get sortPriceLowHigh;

  /// Sort option.
  ///
  /// In en, this message translates to:
  /// **'Price: high to low'**
  String get sortPriceHighLow;

  /// Sort option.
  ///
  /// In en, this message translates to:
  /// **'Discount'**
  String get sortDiscount;

  /// Product list empty state.
  ///
  /// In en, this message translates to:
  /// **'No products here yet.'**
  String get productsEmpty;

  /// Footer of a product grid when the next page fails.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load more products.'**
  String get loadMoreFailed;

  /// Collection page empty state.
  ///
  /// In en, this message translates to:
  /// **'No products in this collection yet.'**
  String get collectionEmpty;

  /// Order again tab empty state.
  ///
  /// In en, this message translates to:
  /// **'Items you order will show up here so you can buy them again quickly.'**
  String get orderAgainEmpty;

  /// Product detail when the product does not exist.
  ///
  /// In en, this message translates to:
  /// **'This product isn\'t available.'**
  String get productNotFound;

  /// Product detail: variant chips heading.
  ///
  /// In en, this message translates to:
  /// **'Pack size'**
  String get packSize;

  /// Savings from the server, formatted in rupees.
  ///
  /// In en, this message translates to:
  /// **'You save {amount}'**
  String youSave(String amount);

  /// Product detail section.
  ///
  /// In en, this message translates to:
  /// **'Highlights'**
  String get highlights;

  /// Product detail section.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get description;

  /// Product detail section: label information.
  ///
  /// In en, this message translates to:
  /// **'Product information'**
  String get productInfo;

  /// Product information row.
  ///
  /// In en, this message translates to:
  /// **'Ingredients'**
  String get ingredients;

  /// Product information: nutrition table title.
  ///
  /// In en, this message translates to:
  /// **'Nutrition information'**
  String get nutritionInfo;

  /// Product information row.
  ///
  /// In en, this message translates to:
  /// **'Shelf life'**
  String get shelfLife;

  /// Product information row.
  ///
  /// In en, this message translates to:
  /// **'Storage'**
  String get storageInfo;

  /// Product information row.
  ///
  /// In en, this message translates to:
  /// **'Country of origin'**
  String get countryOfOrigin;

  /// Product information row.
  ///
  /// In en, this message translates to:
  /// **'Manufactured by'**
  String get manufacturedBy;

  /// Product information row.
  ///
  /// In en, this message translates to:
  /// **'Marketed by'**
  String get marketedBy;

  /// Product information row.
  ///
  /// In en, this message translates to:
  /// **'FSSAI licence no.'**
  String get fssaiLicence;

  /// Product detail rail.
  ///
  /// In en, this message translates to:
  /// **'Similar products'**
  String get similarProducts;

  /// Screen-reader label of a product gallery image.
  ///
  /// In en, this message translates to:
  /// **'Image {index} of {count}. Double tap to zoom.'**
  String galleryImage(int index, int count);

  /// Search field placeholder.
  ///
  /// In en, this message translates to:
  /// **'Search products'**
  String get searchFieldHint;

  /// Tooltip of the button that clears the search field.
  ///
  /// In en, this message translates to:
  /// **'Clear search'**
  String get clearSearch;

  /// Search section title.
  ///
  /// In en, this message translates to:
  /// **'Recent searches'**
  String get recentSearches;

  /// Clears the recent searches.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get clearRecentSearches;

  /// Search section title.
  ///
  /// In en, this message translates to:
  /// **'Trending'**
  String get trendingSearches;

  /// Search when the typeahead fails.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load suggestions.'**
  String get suggestionsFailed;

  /// Search results empty state.
  ///
  /// In en, this message translates to:
  /// **'No results for \"{query}\"'**
  String noResults(String query);

  /// Search results empty state: trending suggestions follow.
  ///
  /// In en, this message translates to:
  /// **'Try one of these:'**
  String get noResultsTry;

  /// Location screen heading.
  ///
  /// In en, this message translates to:
  /// **'Where should we deliver?'**
  String get locationPrompt;

  /// Detects the device location to pick the delivery location.
  ///
  /// In en, this message translates to:
  /// **'Use current location'**
  String get detectLocation;

  /// Opens the map pin picker.
  ///
  /// In en, this message translates to:
  /// **'Pick on map'**
  String get pickOnMap;

  /// Title of a delivery location detected by GPS.
  ///
  /// In en, this message translates to:
  /// **'Current location'**
  String get currentLocationTitle;

  /// Title of a delivery location picked on the map.
  ///
  /// In en, this message translates to:
  /// **'Pinned location'**
  String get pinnedLocationTitle;

  /// Dialog when the new location has a different store.
  ///
  /// In en, this message translates to:
  /// **'Change delivery location?'**
  String get storeChangeTitle;

  /// Dialog body: stock and prices are per store.
  ///
  /// In en, this message translates to:
  /// **'A different store delivers to this location, so your cart will be cleared.'**
  String get storeChangeBody;

  /// Confirms the store change.
  ///
  /// In en, this message translates to:
  /// **'Change and clear cart'**
  String get storeChangeConfirm;

  /// Map pin picker title.
  ///
  /// In en, this message translates to:
  /// **'Pick location on map'**
  String get mapPickerTitle;

  /// Map pin picker hint.
  ///
  /// In en, this message translates to:
  /// **'Move the map to place the pin on your door.'**
  String get mapPickerHint;

  /// Map pin picker preview when reverse geocoding found no address.
  ///
  /// In en, this message translates to:
  /// **'Pin at {lat}, {lng}'**
  String pinCoordinates(String lat, String lng);

  /// Map pin picker while the address under the pin loads.
  ///
  /// In en, this message translates to:
  /// **'Finding the address…'**
  String get findingAddress;

  /// Confirms the pinned location.
  ///
  /// In en, this message translates to:
  /// **'Confirm location'**
  String get confirmLocation;

  /// Tooltip: centres the map on the device location.
  ///
  /// In en, this message translates to:
  /// **'Go to my location'**
  String get locateMe;

  /// Fallback when the build has no Maps key.
  ///
  /// In en, this message translates to:
  /// **'Map isn\'t available'**
  String get mapUnavailableTitle;

  /// Fallback when the build has no Maps key.
  ///
  /// In en, this message translates to:
  /// **'Use your current location, or enter the address by hand.'**
  String get mapUnavailableBody;

  /// Opens the address form.
  ///
  /// In en, this message translates to:
  /// **'Enter address manually'**
  String get enterAddressManually;

  /// Not-serviceable screen title.
  ///
  /// In en, this message translates to:
  /// **'We\'re not in your area yet'**
  String get notServiceableTitle;

  /// Not-serviceable screen text.
  ///
  /// In en, this message translates to:
  /// **'Jivo is growing fast. Tap Notify me and we\'ll tell you when we deliver here.'**
  String get notServiceableBody;

  /// Saves interest in an unserviced location.
  ///
  /// In en, this message translates to:
  /// **'Notify me'**
  String get notifyMe;

  /// After Notify me succeeds.
  ///
  /// In en, this message translates to:
  /// **'Thanks! We\'ll let you know when we start delivering here.'**
  String get notifyMeDone;

  /// Goes back to pick another location.
  ///
  /// In en, this message translates to:
  /// **'Try another address'**
  String get tryAnotherAddress;

  /// Tile caption when a product has several pack sizes.
  ///
  /// In en, this message translates to:
  /// **'{variant} · {count} options'**
  String variantOptions(String variant, int count);

  /// Unit price for comparison, e.g. ₹24.90/100 ml.
  ///
  /// In en, this message translates to:
  /// **'{amount}/{per}'**
  String unitPrice(String amount, String per);

  /// Home header when the store is closed (no ETA).
  ///
  /// In en, this message translates to:
  /// **'Store closed'**
  String get storeClosedHeadline;

  /// Store-closed banner when it opens tomorrow (IST).
  ///
  /// In en, this message translates to:
  /// **'Store closed. Opens tomorrow at {time}. You can browse; checkout opens then.'**
  String storeClosedOpensTomorrow(String time);

  /// Product information row.
  ///
  /// In en, this message translates to:
  /// **'Imported by'**
  String get importedBy;

  /// Product information row.
  ///
  /// In en, this message translates to:
  /// **'Consumer care'**
  String get consumerCare;

  /// Shown instead of ADD in builds without a cart yet (staging/prod before Phase 3).
  ///
  /// In en, this message translates to:
  /// **'Cart coming soon'**
  String get cartComingSoonLabel;

  /// Flag on a saved address outside every delivery area.
  ///
  /// In en, this message translates to:
  /// **'Not serviceable'**
  String get addressNotServiceable;

  /// Cart screen title.
  ///
  /// In en, this message translates to:
  /// **'Cart'**
  String get cartTitle;

  /// Empty cart message.
  ///
  /// In en, this message translates to:
  /// **'Your cart is empty. Add a few Jivo favourites to get started.'**
  String get cartEmpty;

  /// Empty cart action: goes to Home.
  ///
  /// In en, this message translates to:
  /// **'Start shopping'**
  String get startShopping;

  /// Heading of the delivery address card.
  ///
  /// In en, this message translates to:
  /// **'Deliver to'**
  String get deliverTo;

  /// Opens the address switcher from the cart or checkout.
  ///
  /// In en, this message translates to:
  /// **'Change'**
  String get changeAddress;

  /// Shown when the delivery location is a pin without a saved address (orders need address_id).
  ///
  /// In en, this message translates to:
  /// **'Save this location as an address, or choose a saved one, to place the order.'**
  String get chooseSavedAddress;

  /// Opens the address switcher to choose a saved address.
  ///
  /// In en, this message translates to:
  /// **'Select address'**
  String get selectAddress;

  /// Tooltip/screen-reader label of a cart line's remove button.
  ///
  /// In en, this message translates to:
  /// **'Remove {name}'**
  String removeItem(String name);

  /// Cart line flag: fewer units in stock than in the cart.
  ///
  /// In en, this message translates to:
  /// **'Only {count} available'**
  String onlyAvailable(int count);

  /// Fix action on a cart line with reduced stock.
  ///
  /// In en, this message translates to:
  /// **'Update to {count}'**
  String updateQuantityTo(int count);

  /// Fix action on an unavailable cart line; removes a coupon.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get removeAction;

  /// Banner above flagged cart lines (stock re-validation).
  ///
  /// In en, this message translates to:
  /// **'Some items changed since you added them. Fix them to continue.'**
  String get cartProblemsBanner;

  /// Upsell nudge; the amount comes from the server.
  ///
  /// In en, this message translates to:
  /// **'Add {amount} more for FREE delivery'**
  String freeDeliveryNudge(String amount);

  /// Opens the coupon sheet.
  ///
  /// In en, this message translates to:
  /// **'Apply coupon'**
  String get applyCoupon;

  /// Applied coupon row title.
  ///
  /// In en, this message translates to:
  /// **'{code} applied'**
  String couponApplied(String code);

  /// Applied coupon saving (server value).
  ///
  /// In en, this message translates to:
  /// **'You save {amount}'**
  String couponSaves(String amount);

  /// Applied coupon that became ineligible.
  ///
  /// In en, this message translates to:
  /// **'{code} no longer applies to this cart'**
  String couponNoLongerApplies(String code);

  /// Coupon sheet title.
  ///
  /// In en, this message translates to:
  /// **'Coupons'**
  String get couponsTitle;

  /// Coupon code field label.
  ///
  /// In en, this message translates to:
  /// **'Coupon code'**
  String get couponCodeLabel;

  /// Applies a coupon code.
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get couponApply;

  /// Screen-reader label of a coupon's Apply button.
  ///
  /// In en, this message translates to:
  /// **'Apply coupon {code}'**
  String couponApplySemantics(String code);

  /// Coupon sheet empty state.
  ///
  /// In en, this message translates to:
  /// **'No coupons available right now.'**
  String get couponsEmpty;

  /// Coupon card saving (server value).
  ///
  /// In en, this message translates to:
  /// **'Save {amount} on this order'**
  String couponSavesOnCart(String amount);

  /// Coupon not eligible: below its minimum (server shortfall).
  ///
  /// In en, this message translates to:
  /// **'Add {amount} more to use this coupon'**
  String couponAddMore(String amount);

  /// Coupon not eligible: below its minimum, no shortfall sent.
  ///
  /// In en, this message translates to:
  /// **'Your cart is below this coupon\'s minimum order'**
  String get couponBelowMinimum;

  /// Coupon not eligible: other reason.
  ///
  /// In en, this message translates to:
  /// **'Not applicable on this cart'**
  String get couponNotApplicable;

  /// Snackbar after a coupon is applied.
  ///
  /// In en, this message translates to:
  /// **'{code} applied. You save {amount}.'**
  String couponAppliedMessage(String code, String amount);

  /// Validation: empty coupon code.
  ///
  /// In en, this message translates to:
  /// **'Enter a coupon code'**
  String get couponCodeRequired;

  /// Rider tip section title.
  ///
  /// In en, this message translates to:
  /// **'Tip your delivery partner'**
  String get tipTitle;

  /// Rider tip section text.
  ///
  /// In en, this message translates to:
  /// **'Say thanks with a tip. It goes to your delivery partner.'**
  String get tipBody;

  /// Custom tip chip.
  ///
  /// In en, this message translates to:
  /// **'Custom'**
  String get tipCustom;

  /// Custom tip dialog title.
  ///
  /// In en, this message translates to:
  /// **'Enter a tip'**
  String get tipCustomTitle;

  /// Custom tip field label.
  ///
  /// In en, this message translates to:
  /// **'Tip in ₹'**
  String get tipCustomLabel;

  /// Custom tip validation.
  ///
  /// In en, this message translates to:
  /// **'Enter a whole amount from ₹1 to ₹{max}'**
  String tipCustomInvalid(int max);

  /// Screen-reader label of a tip chip.
  ///
  /// In en, this message translates to:
  /// **'Tip {amount}'**
  String tipChipSemantics(String amount);

  /// Delivery instructions section title.
  ///
  /// In en, this message translates to:
  /// **'Delivery instructions'**
  String get instructionsTitle;

  /// Delivery instruction chip.
  ///
  /// In en, this message translates to:
  /// **'Don\'t ring the bell'**
  String get instructionDontRingBell;

  /// Delivery instruction chip.
  ///
  /// In en, this message translates to:
  /// **'Leave at the door'**
  String get instructionLeaveAtDoor;

  /// Delivery instruction chip.
  ///
  /// In en, this message translates to:
  /// **'Avoid calling'**
  String get instructionAvoidCalling;

  /// Free-text delivery instruction label.
  ///
  /// In en, this message translates to:
  /// **'Note for the delivery partner'**
  String get instructionsNoteLabel;

  /// Snackbar after the note is saved.
  ///
  /// In en, this message translates to:
  /// **'Instructions saved'**
  String get instructionsSaved;

  /// Bill section title.
  ///
  /// In en, this message translates to:
  /// **'Bill details'**
  String get billTitle;

  /// Bill row: MRP total.
  ///
  /// In en, this message translates to:
  /// **'Item total (MRP)'**
  String get billItemTotal;

  /// Bill row.
  ///
  /// In en, this message translates to:
  /// **'Product discount'**
  String get billProductDiscount;

  /// Bill row without a code.
  ///
  /// In en, this message translates to:
  /// **'Coupon discount'**
  String get billCouponDiscount;

  /// Bill row with the applied coupon code.
  ///
  /// In en, this message translates to:
  /// **'Coupon ({code})'**
  String billCouponDiscountCode(String code);

  /// Bill row.
  ///
  /// In en, this message translates to:
  /// **'Delivery fee'**
  String get billDeliveryFee;

  /// Bill value when the delivery fee is zero.
  ///
  /// In en, this message translates to:
  /// **'FREE'**
  String get billFree;

  /// Bill row.
  ///
  /// In en, this message translates to:
  /// **'Small cart fee'**
  String get billSmallCartFee;

  /// Bill row.
  ///
  /// In en, this message translates to:
  /// **'Handling fee'**
  String get billHandlingFee;

  /// Bill row.
  ///
  /// In en, this message translates to:
  /// **'Delivery partner tip'**
  String get billTip;

  /// Bill grand total row and checkout bar label.
  ///
  /// In en, this message translates to:
  /// **'To pay'**
  String get billToPay;

  /// Total savings banner (server value).
  ///
  /// In en, this message translates to:
  /// **'You save {amount} on this order'**
  String billSavings(String amount);

  /// A discount shown as a deduction, e.g. −₹50 (display only).
  ///
  /// In en, this message translates to:
  /// **'−{amount}'**
  String minusAmount(String amount);

  /// Checkout disabled below the minimum (server values).
  ///
  /// In en, this message translates to:
  /// **'Minimum order is {amount}. Add {shortfall} more to check out.'**
  String minimumOrderShortfall(String amount, String shortfall);

  /// Checkout disabled below the minimum, no shortfall sent.
  ///
  /// In en, this message translates to:
  /// **'Minimum order is {amount}.'**
  String minimumOrderNotMet(String amount);

  /// Checkout disabled while the store is closed.
  ///
  /// In en, this message translates to:
  /// **'The store is closed right now. You can check out when it opens.'**
  String get cartStoreClosed;

  /// Cart screen primary action.
  ///
  /// In en, this message translates to:
  /// **'Proceed to checkout'**
  String get proceedToCheckout;

  /// After re-validation finds stock problems.
  ///
  /// In en, this message translates to:
  /// **'Some items in your cart changed. Please review them.'**
  String get cartReviewChanges;

  /// Checkout / payment method screen title.
  ///
  /// In en, this message translates to:
  /// **'Payment'**
  String get checkoutTitle;

  /// Payment method section title.
  ///
  /// In en, this message translates to:
  /// **'Pay with'**
  String get payWith;

  /// Payment method.
  ///
  /// In en, this message translates to:
  /// **'Pay online'**
  String get payOnline;

  /// Payment method subtitle.
  ///
  /// In en, this message translates to:
  /// **'UPI, cards, net banking and wallets'**
  String get payOnlineSubtitle;

  /// Payment method.
  ///
  /// In en, this message translates to:
  /// **'Cash on delivery'**
  String get payCod;

  /// Payment method subtitle.
  ///
  /// In en, this message translates to:
  /// **'Pay by cash or UPI when your order arrives'**
  String get payCodSubtitle;

  /// Places a COD order.
  ///
  /// In en, this message translates to:
  /// **'Place order'**
  String get placeOrder;

  /// Places an online order and opens payment.
  ///
  /// In en, this message translates to:
  /// **'Pay {amount}'**
  String payAmount(String amount);

  /// Checkout progress.
  ///
  /// In en, this message translates to:
  /// **'Placing your order…'**
  String get checkoutPlacing;

  /// Checkout progress while the payment gateway is open.
  ///
  /// In en, this message translates to:
  /// **'Waiting for your payment…'**
  String get checkoutPaying;

  /// Checkout progress while the server verifies the payment.
  ///
  /// In en, this message translates to:
  /// **'Confirming your payment…'**
  String get checkoutVerifying;

  /// Order success title.
  ///
  /// In en, this message translates to:
  /// **'Order placed!'**
  String get orderPlacedTitle;

  /// Order number line.
  ///
  /// In en, this message translates to:
  /// **'Order {number}'**
  String orderNumber(String number);

  /// Order success payment line.
  ///
  /// In en, this message translates to:
  /// **'Paid {amount} online'**
  String paidOnlineAmount(String amount);

  /// Order success payment line for COD.
  ///
  /// In en, this message translates to:
  /// **'Pay {amount} on delivery'**
  String payOnDeliveryAmount(String amount);

  /// Opens order tracking.
  ///
  /// In en, this message translates to:
  /// **'Track order'**
  String get trackOrder;

  /// Goes back to Home.
  ///
  /// In en, this message translates to:
  /// **'Continue shopping'**
  String get continueShopping;

  /// Shown until the tracking screen exists.
  ///
  /// In en, this message translates to:
  /// **'Order tracking arrives in a later update.'**
  String get trackingComingSoon;

  /// Payment failed screen title.
  ///
  /// In en, this message translates to:
  /// **'Payment failed'**
  String get paymentFailedTitle;

  /// Payment failed screen text.
  ///
  /// In en, this message translates to:
  /// **'The payment for order {number} wasn\'t completed.'**
  String paymentNotCompleted(String number);

  /// Payment failed: the customer cancelled.
  ///
  /// In en, this message translates to:
  /// **'You closed the payment before it finished.'**
  String get paymentCancelled;

  /// Payment retry window end (IST).
  ///
  /// In en, this message translates to:
  /// **'Pay by {time} to keep this order.'**
  String paymentPayBy(String time);

  /// Retries an online payment.
  ///
  /// In en, this message translates to:
  /// **'Retry payment'**
  String get retryPayment;

  /// Cancels the unpaid order and returns to checkout.
  ///
  /// In en, this message translates to:
  /// **'Change payment method'**
  String get changePaymentMethod;

  /// Cancels an unpaid order.
  ///
  /// In en, this message translates to:
  /// **'Cancel order'**
  String get cancelOrder;

  /// Confirm dialog title.
  ///
  /// In en, this message translates to:
  /// **'Cancel this order?'**
  String get cancelOrderConfirm;

  /// Confirm dialog: don't cancel.
  ///
  /// In en, this message translates to:
  /// **'Keep order'**
  String get keepOrder;

  /// Snackbar/title after cancelling.
  ///
  /// In en, this message translates to:
  /// **'Order cancelled'**
  String get orderCancelled;

  /// Order became PAYMENT_FAILED (window expired, 08 T4).
  ///
  /// In en, this message translates to:
  /// **'The time to pay for order {number} has run out, so it wasn\'t placed. Your items are still in your cart.'**
  String paymentWindowOver(String number);

  /// Order is CANCELLED.
  ///
  /// In en, this message translates to:
  /// **'Order {number} was cancelled.'**
  String paymentOrderCancelled(String number);

  /// Goes to the cart.
  ///
  /// In en, this message translates to:
  /// **'Back to cart'**
  String get backToCart;

  /// Dev-only fake payment sheet title.
  ///
  /// In en, this message translates to:
  /// **'Test payment (dev build)'**
  String get fakePaymentTitle;

  /// Dev-only fake payment sheet text.
  ///
  /// In en, this message translates to:
  /// **'No real money moves. Choose how paying {amount} ends.'**
  String fakePaymentBody(String amount);

  /// Dev-only fake payment option.
  ///
  /// In en, this message translates to:
  /// **'Payment succeeds'**
  String get fakePaymentSucceed;

  /// Dev-only fake payment option.
  ///
  /// In en, this message translates to:
  /// **'Succeeds with a bad signature'**
  String get fakePaymentBadSignature;

  /// Dev-only fake payment option.
  ///
  /// In en, this message translates to:
  /// **'Payment fails'**
  String get fakePaymentFail;

  /// Dev-only fake payment option.
  ///
  /// In en, this message translates to:
  /// **'External wallet (result by webhook)'**
  String get fakePaymentWallet;

  /// Dev-only fake payment option.
  ///
  /// In en, this message translates to:
  /// **'Close checkout'**
  String get fakePaymentCancel;

  /// Checkout blocker NOT_SERVICEABLE.
  ///
  /// In en, this message translates to:
  /// **'We don\'t deliver to this address from this store. Choose another address.'**
  String get blockerNotServiceable;

  /// Checkout blocker COUPON_NOT_ELIGIBLE.
  ///
  /// In en, this message translates to:
  /// **'Your coupon no longer applies. Remove it or add items to continue.'**
  String get blockerCouponNotEligible;

  /// Checkout blocker COUPON_EXPIRED.
  ///
  /// In en, this message translates to:
  /// **'Your coupon has expired. Remove it to continue.'**
  String get blockerCouponExpired;

  /// Checkout blocker COUPON_INVALID.
  ///
  /// In en, this message translates to:
  /// **'Your coupon isn\'t valid any more. Remove it to continue.'**
  String get blockerCouponInvalid;

  /// Checkout blocker COUPON_USAGE_EXCEEDED.
  ///
  /// In en, this message translates to:
  /// **'You\'ve already used this coupon. Remove it to continue.'**
  String get blockerCouponUsed;

  /// Coupon not eligible: FIRST_ORDER_ONLY.
  ///
  /// In en, this message translates to:
  /// **'Only for your first order'**
  String get couponFirstOrderOnly;

  /// Coupon not eligible: NO_ELIGIBLE_ITEMS.
  ///
  /// In en, this message translates to:
  /// **'No items in your cart qualify for this coupon'**
  String get couponNoEligibleItems;

  /// Coupon not eligible: STORE.
  ///
  /// In en, this message translates to:
  /// **'Not valid at this store'**
  String get couponWrongStore;

  /// Coupon sheet: the coupon already on the cart.
  ///
  /// In en, this message translates to:
  /// **'Applied'**
  String get couponAppliedBadge;

  /// Coupon expiry date (IST).
  ///
  /// In en, this message translates to:
  /// **'Expires on {date}'**
  String couponExpiresOn(String date);

  /// PRICE_CHANGED with the server's old and new totals.
  ///
  /// In en, this message translates to:
  /// **'Your total changed from {before} to {after}. Please check the updated bill.'**
  String priceChangedDetail(String before, String after);

  /// STOCK_UNAVAILABLE for a line that can't be ordered at all.
  ///
  /// In en, this message translates to:
  /// **'{name} is now out of stock.'**
  String stockOutDetail(String name);

  /// STOCK_UNAVAILABLE with the server's orderable quantity.
  ///
  /// In en, this message translates to:
  /// **'Only {count} of {name} can be ordered now.'**
  String stockOnlyDetail(int count, String name);

  /// Dialog when placing an order while another awaits payment.
  ///
  /// In en, this message translates to:
  /// **'An order is waiting for payment'**
  String get pendingOrderTitle;

  /// Dialog body (409 with pending_order_id).
  ///
  /// In en, this message translates to:
  /// **'Finish or cancel the payment for that order before placing a new one.'**
  String get pendingOrderBody;

  /// Opens the pending order's payment screen.
  ///
  /// In en, this message translates to:
  /// **'Go to that order'**
  String get pendingOrderAction;

  /// Home banner for a PAYMENT_PENDING order (recovery after the app was closed).
  ///
  /// In en, this message translates to:
  /// **'Order {number} is waiting for payment'**
  String pendingPaymentBanner(String number);

  /// Home banner action: opens the order's payment screen.
  ///
  /// In en, this message translates to:
  /// **'Pay now'**
  String get pendingPaymentAction;

  /// Order success ETA (IST).
  ///
  /// In en, this message translates to:
  /// **'Arriving by {time}'**
  String arrivingBy(String time);

  /// Payment screen when the server status read failed.
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t check this order\'s payment status, so payment can\'t be retried yet.'**
  String get paymentStatusUnchecked;

  /// Re-reads the order's status from the server.
  ///
  /// In en, this message translates to:
  /// **'Check again'**
  String get checkAgain;

  /// Payment screen while the server status loads.
  ///
  /// In en, this message translates to:
  /// **'Checking the payment status…'**
  String get checkingPayment;

  /// Account row and screen title: the order list.
  ///
  /// In en, this message translates to:
  /// **'My orders'**
  String get myOrders;

  /// Order list section: orders not finished yet.
  ///
  /// In en, this message translates to:
  /// **'Active orders'**
  String get ordersActive;

  /// Order list section: finished orders.
  ///
  /// In en, this message translates to:
  /// **'Past orders'**
  String get ordersPast;

  /// Order list empty state.
  ///
  /// In en, this message translates to:
  /// **'You haven\'t placed an order yet. Your orders will show up here.'**
  String get ordersEmpty;

  /// Footer of a paged list when the next page failed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load more orders.'**
  String get ordersLoadMoreFailed;

  /// Units in an order.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 item} other{{count} items}}'**
  String orderItemCount(int count);

  /// Order date (IST).
  ///
  /// In en, this message translates to:
  /// **'Placed on {date}'**
  String orderPlacedOn(String date);

  /// 08 §1 label: PAYMENT_PENDING.
  ///
  /// In en, this message translates to:
  /// **'Completing payment…'**
  String get orderStatusPaymentPending;

  /// 08 §1 label: PLACED.
  ///
  /// In en, this message translates to:
  /// **'Order placed'**
  String get orderStatusPlaced;

  /// 08 §1 label: ACCEPTED.
  ///
  /// In en, this message translates to:
  /// **'Order confirmed'**
  String get orderStatusAccepted;

  /// 08 §1 label: PACKING.
  ///
  /// In en, this message translates to:
  /// **'Packing your order'**
  String get orderStatusPacking;

  /// 08 §1 label: PACKED.
  ///
  /// In en, this message translates to:
  /// **'Packed, rider on the way to store'**
  String get orderStatusPacked;

  /// 08 §1 label: OUT_FOR_DELIVERY.
  ///
  /// In en, this message translates to:
  /// **'On the way'**
  String get orderStatusOutForDelivery;

  /// 08 §1 label: DELIVERED.
  ///
  /// In en, this message translates to:
  /// **'Delivered'**
  String get orderStatusDelivered;

  /// 08 §1 label: CANCELLED.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get orderStatusCancelled;

  /// 08 §1 label: PAYMENT_FAILED.
  ///
  /// In en, this message translates to:
  /// **'Payment failed'**
  String get orderStatusPaymentFailed;

  /// 08 §1 label: DELIVERY_FAILED and RETURNED.
  ///
  /// In en, this message translates to:
  /// **'Delivery unsuccessful'**
  String get orderStatusDeliveryFailed;

  /// A status this app version does not know.
  ///
  /// In en, this message translates to:
  /// **'Status unavailable'**
  String get orderStatusUnknown;

  /// Order detail title.
  ///
  /// In en, this message translates to:
  /// **'Order {number}'**
  String orderTitle(String number);

  /// Timeline step (03 §2.10).
  ///
  /// In en, this message translates to:
  /// **'Confirmed'**
  String get orderStageConfirmed;

  /// Timeline step (03 §2.10).
  ///
  /// In en, this message translates to:
  /// **'Packing'**
  String get orderStagePacking;

  /// Timeline step (03 §2.10).
  ///
  /// In en, this message translates to:
  /// **'On the way'**
  String get orderStageOnTheWay;

  /// Timeline step (03 §2.10).
  ///
  /// In en, this message translates to:
  /// **'Placed'**
  String get orderStagePlaced;

  /// Timeline step (03 §2.10).
  ///
  /// In en, this message translates to:
  /// **'Delivered'**
  String get orderStageDelivered;

  /// Order detail: the timeline header.
  ///
  /// In en, this message translates to:
  /// **'Order status'**
  String get orderTimelineTitle;

  /// Screen reader: a timeline step that was reached.
  ///
  /// In en, this message translates to:
  /// **'done'**
  String get orderStepDone;

  /// Screen reader: the current timeline step.
  ///
  /// In en, this message translates to:
  /// **'current'**
  String get orderStepCurrent;

  /// Screen reader: a timeline step not reached yet.
  ///
  /// In en, this message translates to:
  /// **'upcoming'**
  String get orderStepUpcoming;

  /// Order detail: the items header.
  ///
  /// In en, this message translates to:
  /// **'Items'**
  String get orderItemsTitle;

  /// Order line: quantity and unit price.
  ///
  /// In en, this message translates to:
  /// **'{quantity} × {price}'**
  String orderLineQuantity(int quantity, String price);

  /// Order detail: the payment header.
  ///
  /// In en, this message translates to:
  /// **'Payment'**
  String get orderPaymentTitle;

  /// Payment method: ONLINE.
  ///
  /// In en, this message translates to:
  /// **'Paid online'**
  String get paymentMethodOnline;

  /// Payment method: COD.
  ///
  /// In en, this message translates to:
  /// **'Cash on delivery'**
  String get paymentMethodCod;

  /// payment_status PENDING.
  ///
  /// In en, this message translates to:
  /// **'Payment not completed'**
  String get paymentStatusPending;

  /// payment_status PAID.
  ///
  /// In en, this message translates to:
  /// **'Paid'**
  String get paymentStatusPaid;

  /// payment_status FAILED.
  ///
  /// In en, this message translates to:
  /// **'Payment failed'**
  String get paymentStatusFailed;

  /// payment_status REFUND_PENDING.
  ///
  /// In en, this message translates to:
  /// **'Refund initiated'**
  String get paymentStatusRefundPending;

  /// payment_status REFUNDED.
  ///
  /// In en, this message translates to:
  /// **'Refunded'**
  String get paymentStatusRefunded;

  /// payment_status PARTIALLY_REFUNDED.
  ///
  /// In en, this message translates to:
  /// **'Partly refunded'**
  String get paymentStatusPartiallyRefunded;

  /// payment_status COD_PENDING.
  ///
  /// In en, this message translates to:
  /// **'Pay on delivery'**
  String get paymentStatusCodPending;

  /// payment_status COD_COLLECTED.
  ///
  /// In en, this message translates to:
  /// **'Paid on delivery'**
  String get paymentStatusCodCollected;

  /// A cancelled or failed order that was never paid.
  ///
  /// In en, this message translates to:
  /// **'No payment was taken for this order.'**
  String get noPaymentTaken;

  /// A cancelled cash-on-delivery order.
  ///
  /// In en, this message translates to:
  /// **'Nothing to pay for this order.'**
  String get nothingToPay;

  /// A pending refund (08 §6.4).
  ///
  /// In en, this message translates to:
  /// **'Refund of {amount} initiated. It reaches your original payment method in 5–7 working days.'**
  String refundInProgress(String amount);

  /// A processed refund.
  ///
  /// In en, this message translates to:
  /// **'{amount} refunded to your original payment method.'**
  String refundCompleted(String amount);

  /// A refund the gateway refused (ops retries it).
  ///
  /// In en, this message translates to:
  /// **'Your refund of {amount} is delayed. Our team is on it; contact support if you need help.'**
  String refundFailedNote(String amount);

  /// When a refund was processed (IST).
  ///
  /// In en, this message translates to:
  /// **'Refunded on {date}'**
  String refundedOn(String date);

  /// Order detail: the address header.
  ///
  /// In en, this message translates to:
  /// **'Delivery address'**
  String get orderDeliveryTo;

  /// Active order ETA (IST).
  ///
  /// In en, this message translates to:
  /// **'Arriving by {time}'**
  String orderArrivingBy(String time);

  /// Order detail of a PAYMENT_PENDING order.
  ///
  /// In en, this message translates to:
  /// **'This order is waiting for payment.'**
  String get orderAwaitingPayment;

  /// Opens the payment screen of a PAYMENT_PENDING order.
  ///
  /// In en, this message translates to:
  /// **'Complete payment'**
  String get completePayment;

  /// Opens the GST invoice PDF.
  ///
  /// In en, this message translates to:
  /// **'Download invoice'**
  String get downloadInvoice;

  /// No app could open the invoice link.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t open the invoice. Install a PDF viewer or browser and try again.'**
  String get invoiceOpenFailed;

  /// Adds the order's items back to the cart.
  ///
  /// In en, this message translates to:
  /// **'Order again'**
  String get reorder;

  /// Reorder: everything was added.
  ///
  /// In en, this message translates to:
  /// **'Items added to your cart.'**
  String get reorderAllAdded;

  /// Reorder: nothing could be added.
  ///
  /// In en, this message translates to:
  /// **'None of these items can be ordered right now.'**
  String get reorderNothingAdded;

  /// Reorder dialog title when items are unavailable.
  ///
  /// In en, this message translates to:
  /// **'Some items were not added'**
  String get reorderSomeUnavailableTitle;

  /// Reorder: an out-of-stock item.
  ///
  /// In en, this message translates to:
  /// **'{name} is out of stock'**
  String reorderOutOfStock(String name);

  /// Reorder: a discontinued item.
  ///
  /// In en, this message translates to:
  /// **'{name} is no longer sold'**
  String reorderDiscontinued(String name);

  /// Reorder: fewer units than ordered were available.
  ///
  /// In en, this message translates to:
  /// **'Only {count} of {name} added'**
  String reorderReduced(int count, String name);

  /// Order detail past the cancel window (08 §7).
  ///
  /// In en, this message translates to:
  /// **'Need to cancel?'**
  String get cannotCancelTitle;

  /// Order detail past the cancel window (08 §7).
  ///
  /// In en, this message translates to:
  /// **'Your order is already being packed, so it can no longer be cancelled in the app. Contact support for help.'**
  String get cannotCancelBody;

  /// Calls Jivo support.
  ///
  /// In en, this message translates to:
  /// **'Contact support'**
  String get contactSupport;

  /// Cancel sheet title.
  ///
  /// In en, this message translates to:
  /// **'Why are you cancelling?'**
  String get cancelSheetTitle;

  /// Cancel reason ORDERED_BY_MISTAKE.
  ///
  /// In en, this message translates to:
  /// **'Ordered by mistake'**
  String get cancelReasonOrderedByMistake;

  /// Cancel reason CHANGED_MIND.
  ///
  /// In en, this message translates to:
  /// **'Changed my mind'**
  String get cancelReasonChangedMind;

  /// Cancel reason DELIVERY_TOO_SLOW.
  ///
  /// In en, this message translates to:
  /// **'Delivery is taking too long'**
  String get cancelReasonDeliveryTooSlow;

  /// Cancel reason CHANGE_PAYMENT_METHOD.
  ///
  /// In en, this message translates to:
  /// **'Want to change the payment method'**
  String get cancelReasonChangePaymentMethod;

  /// Cancel reason PAYMENT_PROBLEM.
  ///
  /// In en, this message translates to:
  /// **'Problem with the payment'**
  String get cancelReasonPaymentProblem;

  /// Cancel reason OTHER.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get cancelReasonOther;

  /// Cancel sheet refund info, paid online (08 §6.4).
  ///
  /// In en, this message translates to:
  /// **'You will get a full refund of {amount} to your original payment method in 5–7 working days.'**
  String cancelRefundOnline(String amount);

  /// Cancel sheet refund info, COD (08 §6.4).
  ///
  /// In en, this message translates to:
  /// **'Nothing is due for a cash-on-delivery order.'**
  String get cancelRefundCod;

  /// Cancel sheet info, order awaiting payment.
  ///
  /// In en, this message translates to:
  /// **'No payment was taken for this order, so there is nothing to refund.'**
  String get cancelRefundUnpaid;

  /// Cancel sheet confirm button.
  ///
  /// In en, this message translates to:
  /// **'Cancel order'**
  String get cancelConfirmAction;

  /// Cancel sheet hint before a reason is chosen.
  ///
  /// In en, this message translates to:
  /// **'Choose a reason to continue.'**
  String get cancelChooseReason;

  /// The store the order comes from.
  ///
  /// In en, this message translates to:
  /// **'From {store}'**
  String orderStoreName(String store);

  /// The coupon used on the order.
  ///
  /// In en, this message translates to:
  /// **'Coupon {code}'**
  String couponUsed(String code);

  /// Tracking ETA countdown.
  ///
  /// In en, this message translates to:
  /// **'{minutes, plural, =1{Arriving in 1 min} other{Arriving in {minutes} mins}}'**
  String trackingEtaMinutes(int minutes);

  /// Tracking: the ETA has passed.
  ///
  /// In en, this message translates to:
  /// **'Arriving any moment'**
  String get trackingArrivingNow;

  /// Tracking before a rider is assigned.
  ///
  /// In en, this message translates to:
  /// **'Assigning a delivery partner…'**
  String get trackingRiderAssigning;

  /// Tracking: the rider card.
  ///
  /// In en, this message translates to:
  /// **'Your delivery partner'**
  String get trackingRiderLabel;

  /// Tracking: call the rider.
  ///
  /// In en, this message translates to:
  /// **'Call {name}'**
  String trackingCallRider(String name);

  /// Tracking: the delivery OTP.
  ///
  /// In en, this message translates to:
  /// **'Delivery OTP'**
  String get trackingOtpTitle;

  /// Tracking: OTP guidance.
  ///
  /// In en, this message translates to:
  /// **'Share this with your rider at the door, only when you receive your order.'**
  String get trackingOtpHint;

  /// Route sketch: the store end.
  ///
  /// In en, this message translates to:
  /// **'Store'**
  String get trackingMapStore;

  /// Route sketch: the customer end.
  ///
  /// In en, this message translates to:
  /// **'You'**
  String get trackingMapHome;

  /// Route sketch for screen readers.
  ///
  /// In en, this message translates to:
  /// **'The rider is {percent} percent of the way to you.'**
  String trackingMapSemantics(int percent);

  /// Tracking: opens the order detail.
  ///
  /// In en, this message translates to:
  /// **'Order details'**
  String get trackingViewDetails;

  /// Inbox title and account row.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notificationsTitle;

  /// Inbox empty state.
  ///
  /// In en, this message translates to:
  /// **'No notifications yet. Order updates and offers will show up here.'**
  String get notificationsEmpty;

  /// Screen reader: an unread notification.
  ///
  /// In en, this message translates to:
  /// **'Unread'**
  String get notificationUnread;

  /// Order line: units the store marked unavailable (08 T8a).
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 unit was unavailable and is not charged} other{{count} units were unavailable and are not charged}}'**
  String orderLineUnavailable(int count);

  /// Order detail: the cancellation section header.
  ///
  /// In en, this message translates to:
  /// **'Why this order was cancelled'**
  String get orderCancelledTitle;

  /// Screen reader: the delivery OTP read digit by digit.
  ///
  /// In en, this message translates to:
  /// **'Delivery OTP {digits}'**
  String trackingOtpSemantics(String digits);

  /// Rate order screen title.
  ///
  /// In en, this message translates to:
  /// **'Rate your order'**
  String get rateOrderTitle;

  /// Rate order: the order stars question.
  ///
  /// In en, this message translates to:
  /// **'How was your order?'**
  String get rateOrderQuestion;

  /// Rate order: tags for 4-5 stars.
  ///
  /// In en, this message translates to:
  /// **'What went well?'**
  String get rateTagsPositive;

  /// Rate order: tags for 1-3 stars.
  ///
  /// In en, this message translates to:
  /// **'What went wrong?'**
  String get rateTagsNegative;

  /// Rate order: the rider stars.
  ///
  /// In en, this message translates to:
  /// **'Rate your delivery partner'**
  String get rateRiderQuestion;

  /// Rate order: the rider rating can be skipped.
  ///
  /// In en, this message translates to:
  /// **'Optional'**
  String get rateRiderOptional;

  /// Rate order: the comment field.
  ///
  /// In en, this message translates to:
  /// **'Tell us more'**
  String get rateCommentLabel;

  /// Rate order: comment hint.
  ///
  /// In en, this message translates to:
  /// **'Anything we should know? (optional)'**
  String get rateCommentHint;

  /// Rate order: shown until stars are picked.
  ///
  /// In en, this message translates to:
  /// **'Pick a star rating to submit.'**
  String get rateChooseStars;

  /// Rate order: submit button.
  ///
  /// In en, this message translates to:
  /// **'Submit'**
  String get rateSubmit;

  /// A star in the rating picker.
  ///
  /// In en, this message translates to:
  /// **'{stars, plural, =1{1 star} other{{stars} stars}}'**
  String rateStars(int stars);

  /// Rating tag.
  ///
  /// In en, this message translates to:
  /// **'On time'**
  String get rateTagOnTime;

  /// Rating tag.
  ///
  /// In en, this message translates to:
  /// **'Well packed'**
  String get rateTagWellPacked;

  /// Rating tag.
  ///
  /// In en, this message translates to:
  /// **'Fresh products'**
  String get rateTagFresh;

  /// Rating tag.
  ///
  /// In en, this message translates to:
  /// **'Polite delivery partner'**
  String get rateTagPoliteRider;

  /// Rating tag.
  ///
  /// In en, this message translates to:
  /// **'Late delivery'**
  String get rateTagLate;

  /// Rating tag.
  ///
  /// In en, this message translates to:
  /// **'Damaged items'**
  String get rateTagDamaged;

  /// Rating tag.
  ///
  /// In en, this message translates to:
  /// **'Missing items'**
  String get rateTagMissing;

  /// Rating tag.
  ///
  /// In en, this message translates to:
  /// **'Rude delivery partner'**
  String get rateTagRudeRider;

  /// Snackbar after rating.
  ///
  /// In en, this message translates to:
  /// **'Thanks for your feedback!'**
  String get ratingThanks;

  /// Order detail: the customer's rating.
  ///
  /// In en, this message translates to:
  /// **'{stars, plural, =1{You rated this order 1 star} other{You rated this order {stars} stars}}'**
  String ratedOrder(int stars);

  /// Help screen title and account row.
  ///
  /// In en, this message translates to:
  /// **'Help & support'**
  String get helpTitle;

  /// Help: start a ticket.
  ///
  /// In en, this message translates to:
  /// **'Get help with an order'**
  String get helpWithOrder;

  /// Help: start a ticket subtitle.
  ///
  /// In en, this message translates to:
  /// **'Missing, damaged or wrong items, refunds and more'**
  String get helpWithOrderSubtitle;

  /// Order detail: open a ticket for this order.
  ///
  /// In en, this message translates to:
  /// **'Get help with this order'**
  String get helpWithThisOrder;

  /// Help: the customer's tickets.
  ///
  /// In en, this message translates to:
  /// **'My tickets'**
  String get myTickets;

  /// Help: call the support phone.
  ///
  /// In en, this message translates to:
  /// **'Call support'**
  String get callSupport;

  /// Help when no contact option is available.
  ///
  /// In en, this message translates to:
  /// **'Support is coming soon to the app.'**
  String get helpComingSoon;

  /// Help: FAQ section.
  ///
  /// In en, this message translates to:
  /// **'Frequently asked questions'**
  String get faqTitle;

  /// Help: no FAQs.
  ///
  /// In en, this message translates to:
  /// **'No FAQs yet.'**
  String get faqEmpty;

  /// New ticket screen title and button.
  ///
  /// In en, this message translates to:
  /// **'New ticket'**
  String get newTicket;

  /// Tickets empty state.
  ///
  /// In en, this message translates to:
  /// **'You have no support tickets.'**
  String get ticketsEmpty;

  /// Snackbar after a ticket is created.
  ///
  /// In en, this message translates to:
  /// **'Ticket created. We\'ll reply here soon.'**
  String get ticketCreated;

  /// New ticket: the related order.
  ///
  /// In en, this message translates to:
  /// **'Order'**
  String get ticketOrderLabel;

  /// New ticket: pick an order.
  ///
  /// In en, this message translates to:
  /// **'Choose an order (optional)'**
  String get ticketChooseOrder;

  /// New ticket: unlink the order.
  ///
  /// In en, this message translates to:
  /// **'Remove order'**
  String get ticketRemoveOrder;

  /// New ticket: the issue type.
  ///
  /// In en, this message translates to:
  /// **'What\'s the issue?'**
  String get ticketIssueLabel;

  /// New ticket: no issue type picked.
  ///
  /// In en, this message translates to:
  /// **'Choose an issue type.'**
  String get ticketChooseIssue;

  /// New ticket: the message field.
  ///
  /// In en, this message translates to:
  /// **'Describe the issue'**
  String get ticketMessageLabel;

  /// New ticket: message hint.
  ///
  /// In en, this message translates to:
  /// **'Tell us what happened'**
  String get ticketMessageHint;

  /// New ticket: message too short.
  ///
  /// In en, this message translates to:
  /// **'Please write at least {min} characters.'**
  String ticketMessageTooShort(int min);

  /// New ticket: submit.
  ///
  /// In en, this message translates to:
  /// **'Create ticket'**
  String get ticketSubmit;

  /// Ticket detail: closed ticket.
  ///
  /// In en, this message translates to:
  /// **'This ticket is closed. Create a new ticket if you still need help.'**
  String get ticketClosedNote;

  /// Ticket thread: the customer's message.
  ///
  /// In en, this message translates to:
  /// **'You'**
  String get ticketYou;

  /// Ticket thread: a support message.
  ///
  /// In en, this message translates to:
  /// **'Jivo support'**
  String get ticketSupport;

  /// Ticket thread: reply field.
  ///
  /// In en, this message translates to:
  /// **'Write a reply'**
  String get ticketReplyHint;

  /// Ticket thread: send button.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get ticketSend;

  /// Ticket issue type.
  ///
  /// In en, this message translates to:
  /// **'Missing items'**
  String get ticketMissingItems;

  /// Ticket issue type.
  ///
  /// In en, this message translates to:
  /// **'Damaged items'**
  String get ticketDamagedItems;

  /// Ticket issue type.
  ///
  /// In en, this message translates to:
  /// **'Wrong items'**
  String get ticketWrongItems;

  /// Ticket issue type.
  ///
  /// In en, this message translates to:
  /// **'Late delivery'**
  String get ticketLateDelivery;

  /// Ticket issue type.
  ///
  /// In en, this message translates to:
  /// **'Payment or refund'**
  String get ticketPaymentRefund;

  /// Ticket issue type.
  ///
  /// In en, this message translates to:
  /// **'My account'**
  String get ticketAccount;

  /// Ticket issue type.
  ///
  /// In en, this message translates to:
  /// **'Something else'**
  String get ticketOther;

  /// Ticket status.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get ticketStatusOpen;

  /// Ticket status.
  ///
  /// In en, this message translates to:
  /// **'In progress'**
  String get ticketStatusInProgress;

  /// Ticket status.
  ///
  /// In en, this message translates to:
  /// **'Resolved'**
  String get ticketStatusResolved;

  /// Ticket status.
  ///
  /// In en, this message translates to:
  /// **'Closed'**
  String get ticketStatusClosed;

  /// Account: the About page.
  ///
  /// In en, this message translates to:
  /// **'About Jivo'**
  String get aboutJivo;

  /// CMS page without content.
  ///
  /// In en, this message translates to:
  /// **'This page has no content yet.'**
  String get cmsPageEmpty;

  /// CMS page: last update date.
  ///
  /// In en, this message translates to:
  /// **'Last updated {date}'**
  String cmsUpdatedOn(String date);

  /// CMS page missing on the server (404): fall back to the policy URL.
  ///
  /// In en, this message translates to:
  /// **'This page isn\'t available in the app right now. You can read it in your browser.'**
  String get cmsPageUnavailable;

  /// Button: open a page in the browser.
  ///
  /// In en, this message translates to:
  /// **'Open in browser'**
  String get openInBrowser;

  /// Checkout: the payment gateway is down when placing an ONLINE order (503 SERVICE_UNAVAILABLE, M6).
  ///
  /// In en, this message translates to:
  /// **'Payment service is unavailable right now. Try again, or choose Cash on Delivery.'**
  String get onlinePaymentUnavailable;

  /// Tracking/order detail: task PICKED_UP (order OUT_FOR_DELIVERY).
  ///
  /// In en, this message translates to:
  /// **'Order picked up'**
  String get deliveryStagePickedUpTitle;

  /// Tracking/order detail: picked-up explanation.
  ///
  /// In en, this message translates to:
  /// **'Your rider has your order and is on the way.'**
  String get deliveryStagePickedUpBody;

  /// Tracking/order detail: task AT_CUSTOMER.
  ///
  /// In en, this message translates to:
  /// **'Rider is arriving'**
  String get deliveryStageArrivingTitle;

  /// Tracking/order detail: arriving explanation.
  ///
  /// In en, this message translates to:
  /// **'Your rider has reached your location. Keep your delivery OTP ready.'**
  String get deliveryStageArrivingBody;

  /// Tracking/order detail: order DELIVERY_FAILED.
  ///
  /// In en, this message translates to:
  /// **'Delivery failed'**
  String get deliveryStageFailedTitle;

  /// Tracking/order detail: delivery-failed explanation.
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t deliver your order. The items are going back to the store.'**
  String get deliveryStageFailedBody;

  /// Tracking/order detail: order RETURNED.
  ///
  /// In en, this message translates to:
  /// **'Order returned'**
  String get deliveryStageReturnedTitle;

  /// Tracking/order detail: returned explanation.
  ///
  /// In en, this message translates to:
  /// **'Your items are back at the store.'**
  String get deliveryStageReturnedBody;

  /// Failed/returned delivery: payment_status REFUND_PENDING.
  ///
  /// In en, this message translates to:
  /// **'Your refund has started. It goes back to your original payment method.'**
  String get refundNoteStarted;

  /// Failed/returned delivery: payment_status REFUNDED or PARTIALLY_REFUNDED; amount is the server's amount_refunded.
  ///
  /// In en, this message translates to:
  /// **'{amount} refunded to your original payment method.'**
  String refundNoteDone(String amount);

  /// Cash on delivery: the server's bill grand total to hand to the rider.
  ///
  /// In en, this message translates to:
  /// **'Pay {amount} to the rider'**
  String codPayRiderTitle(String amount);

  /// Cash on delivery: how to pay.
  ///
  /// In en, this message translates to:
  /// **'Cash on delivery. Pay by cash or UPI when your order arrives.'**
  String get codPayRiderHint;
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
