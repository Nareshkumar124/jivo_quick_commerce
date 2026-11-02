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

  /// Shown when the cart bar is tapped before the cart screen exists.
  ///
  /// In en, this message translates to:
  /// **'Cart and checkout arrive in the next update.'**
  String get cartComingSoon;

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
