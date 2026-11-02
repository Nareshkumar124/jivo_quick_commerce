import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'jivo_core_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of JivoCoreLocalizations
/// returned by `JivoCoreLocalizations.of(context)`.
///
/// Applications need to include `JivoCoreLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/jivo_core_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: JivoCoreLocalizations.localizationsDelegates,
///   supportedLocales: JivoCoreLocalizations.supportedLocales,
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
/// be consistent with the languages listed in the JivoCoreLocalizations.supportedLocales
/// property.
abstract class JivoCoreLocalizations {
  JivoCoreLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static JivoCoreLocalizations of(BuildContext context) {
    return Localizations.of<JivoCoreLocalizations>(
      context,
      JivoCoreLocalizations,
    )!;
  }

  static const LocalizationsDelegate<JivoCoreLocalizations> delegate =
      _JivoCoreLocalizationsDelegate();

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

  /// Fallback for unknown or unexpected API errors.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Please try again.'**
  String get errorGeneric;

  /// The request could not reach the server.
  ///
  /// In en, this message translates to:
  /// **'No internet connection. Check your connection and try again.'**
  String get errorNetwork;

  /// The request timed out.
  ///
  /// In en, this message translates to:
  /// **'This is taking longer than usual. Please try again.'**
  String get errorTimeout;

  /// The app cancelled the request.
  ///
  /// In en, this message translates to:
  /// **'The request was cancelled.'**
  String get errorCancelled;

  /// A 5xx response without an error envelope.
  ///
  /// In en, this message translates to:
  /// **'Our servers are having trouble. Please try again in a moment.'**
  String get errorServer;

  /// VALIDATION_ERROR
  ///
  /// In en, this message translates to:
  /// **'Some details look incorrect. Please check and try again.'**
  String get errorValidation;

  /// OTP_INVALID
  ///
  /// In en, this message translates to:
  /// **'That OTP is incorrect. Please check and try again.'**
  String get errorOtpInvalid;

  /// OTP_EXPIRED
  ///
  /// In en, this message translates to:
  /// **'That OTP has expired. Please request a new one.'**
  String get errorOtpExpired;

  /// OTP_RATE_LIMITED
  ///
  /// In en, this message translates to:
  /// **'Too many attempts. Please wait a few minutes and try again.'**
  String get errorOtpRateLimited;

  /// AUTH_REQUIRED
  ///
  /// In en, this message translates to:
  /// **'Please log in to continue.'**
  String get errorAuthRequired;

  /// TOKEN_INVALID
  ///
  /// In en, this message translates to:
  /// **'Your session has expired. Please log in again.'**
  String get errorTokenInvalid;

  /// PERMISSION_DENIED
  ///
  /// In en, this message translates to:
  /// **'You don\'t have access to this.'**
  String get errorPermissionDenied;

  /// NOT_FOUND
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t find what you were looking for.'**
  String get errorNotFound;

  /// APP_UPDATE_REQUIRED (HTTP 426)
  ///
  /// In en, this message translates to:
  /// **'A new version of the app is available. Please update to continue.'**
  String get errorAppUpdateRequired;

  /// NOT_SERVICEABLE
  ///
  /// In en, this message translates to:
  /// **'We don\'t deliver to this location yet.'**
  String get errorNotServiceable;

  /// STORE_CLOSED
  ///
  /// In en, this message translates to:
  /// **'The store is closed right now. Please try again later.'**
  String get errorStoreClosed;

  /// STOCK_UNAVAILABLE
  ///
  /// In en, this message translates to:
  /// **'Some items are out of stock or have limited quantity.'**
  String get errorStockUnavailable;

  /// MAX_QTY_EXCEEDED
  ///
  /// In en, this message translates to:
  /// **'You\'ve reached the maximum quantity for this item.'**
  String get errorMaxQtyExceeded;

  /// MIN_ORDER_NOT_MET
  ///
  /// In en, this message translates to:
  /// **'Your cart is below the minimum order value.'**
  String get errorMinOrderNotMet;

  /// COUPON_INVALID
  ///
  /// In en, this message translates to:
  /// **'This coupon code isn\'t valid.'**
  String get errorCouponInvalid;

  /// COUPON_EXPIRED
  ///
  /// In en, this message translates to:
  /// **'This coupon has expired.'**
  String get errorCouponExpired;

  /// COUPON_NOT_ELIGIBLE
  ///
  /// In en, this message translates to:
  /// **'This coupon doesn\'t apply to your cart.'**
  String get errorCouponNotEligible;

  /// COUPON_USAGE_EXCEEDED
  ///
  /// In en, this message translates to:
  /// **'You\'ve already used this coupon the maximum number of times.'**
  String get errorCouponUsageExceeded;

  /// COD_NOT_AVAILABLE
  ///
  /// In en, this message translates to:
  /// **'Cash on delivery isn\'t available for this order.'**
  String get errorCodNotAvailable;

  /// PRICE_CHANGED
  ///
  /// In en, this message translates to:
  /// **'Prices have changed. Please review your updated bill.'**
  String get errorPriceChanged;

  /// PAYMENT_VERIFICATION_FAILED
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t confirm your payment. Please check your order status before paying again.'**
  String get errorPaymentVerificationFailed;

  /// INVALID_STATE_TRANSITION
  ///
  /// In en, this message translates to:
  /// **'This action is no longer available. Please refresh and try again.'**
  String get errorInvalidStateTransition;

  /// OFFER_EXPIRED (rider app)
  ///
  /// In en, this message translates to:
  /// **'This order offer has expired.'**
  String get errorOfferExpired;

  /// OFFER_TAKEN (rider app)
  ///
  /// In en, this message translates to:
  /// **'This order was assigned to another rider.'**
  String get errorOfferTaken;

  /// OUTSIDE_GEOFENCE (rider app)
  ///
  /// In en, this message translates to:
  /// **'You\'re too far from the location. Move closer and try again.'**
  String get errorOutsideGeofence;

  /// DELIVERY_OTP_INVALID (rider app)
  ///
  /// In en, this message translates to:
  /// **'That delivery OTP is incorrect.'**
  String get errorDeliveryOtpInvalid;

  /// DELIVERY_OTP_LOCKED (rider app)
  ///
  /// In en, this message translates to:
  /// **'Too many wrong OTP attempts. Please contact support.'**
  String get errorDeliveryOtpLocked;

  /// CASH_LIMIT_EXCEEDED (rider app)
  ///
  /// In en, this message translates to:
  /// **'You\'ve reached your cash limit. Deposit cash to continue.'**
  String get errorCashLimitExceeded;

  /// MAINTENANCE (HTTP 503)
  ///
  /// In en, this message translates to:
  /// **'We\'re down for maintenance. Please try again soon.'**
  String get errorMaintenance;

  /// RATE_LIMITED (HTTP 429)
  ///
  /// In en, this message translates to:
  /// **'Too many requests. Please wait a moment and try again.'**
  String get errorRateLimited;

  /// SERVICE_UNAVAILABLE (HTTP 503)
  ///
  /// In en, this message translates to:
  /// **'Jivo is temporarily unavailable. Please try again in a few minutes.'**
  String get errorServiceUnavailable;

  /// OTP_INVALID with details.attempts_remaining.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{That OTP is incorrect. No attempts left: please request a new OTP.} =1{That OTP is incorrect. 1 attempt left.} other{That OTP is incorrect. {count} attempts left.}}'**
  String errorOtpInvalidAttempts(int count);

  /// OTP_RATE_LIMITED / RATE_LIMITED with details.retry_after_seconds, rounded up to minutes.
  ///
  /// In en, this message translates to:
  /// **'{minutes, plural, =1{Too many attempts. Please try again in 1 minute.} other{Too many attempts. Please try again in {minutes} minutes.}}'**
  String errorTryAgainInMinutes(int minutes);
}

class _JivoCoreLocalizationsDelegate
    extends LocalizationsDelegate<JivoCoreLocalizations> {
  const _JivoCoreLocalizationsDelegate();

  @override
  Future<JivoCoreLocalizations> load(Locale locale) {
    return SynchronousFuture<JivoCoreLocalizations>(
      lookupJivoCoreLocalizations(locale),
    );
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en'].contains(locale.languageCode);

  @override
  bool shouldReload(_JivoCoreLocalizationsDelegate old) => false;
}

JivoCoreLocalizations lookupJivoCoreLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return JivoCoreLocalizationsEn();
  }

  throw FlutterError(
    'JivoCoreLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
