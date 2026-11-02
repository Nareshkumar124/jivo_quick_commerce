// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'jivo_core_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class JivoCoreLocalizationsEn extends JivoCoreLocalizations {
  JivoCoreLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get errorGeneric => 'Something went wrong. Please try again.';

  @override
  String get errorNetwork =>
      'No internet connection. Check your connection and try again.';

  @override
  String get errorTimeout =>
      'This is taking longer than usual. Please try again.';

  @override
  String get errorCancelled => 'The request was cancelled.';

  @override
  String get errorServer =>
      'Our servers are having trouble. Please try again in a moment.';

  @override
  String get errorValidation =>
      'Some details look incorrect. Please check and try again.';

  @override
  String get errorOtpInvalid =>
      'That OTP is incorrect. Please check and try again.';

  @override
  String get errorOtpExpired =>
      'That OTP has expired. Please request a new one.';

  @override
  String get errorOtpRateLimited =>
      'Too many attempts. Please wait a few minutes and try again.';

  @override
  String get errorAuthRequired => 'Please log in to continue.';

  @override
  String get errorTokenInvalid =>
      'Your session has expired. Please log in again.';

  @override
  String get errorPermissionDenied => 'You don\'t have access to this.';

  @override
  String get errorNotFound => 'We couldn\'t find what you were looking for.';

  @override
  String get errorAppUpdateRequired =>
      'A new version of the app is available. Please update to continue.';

  @override
  String get errorNotServiceable => 'We don\'t deliver to this location yet.';

  @override
  String get errorStoreClosed =>
      'The store is closed right now. Please try again later.';

  @override
  String get errorStockUnavailable =>
      'Some items are out of stock or have limited quantity.';

  @override
  String get errorMaxQtyExceeded =>
      'You\'ve reached the maximum quantity for this item.';

  @override
  String get errorMinOrderNotMet =>
      'Your cart is below the minimum order value.';

  @override
  String get errorCouponInvalid => 'This coupon code isn\'t valid.';

  @override
  String get errorCouponExpired => 'This coupon has expired.';

  @override
  String get errorCouponNotEligible =>
      'This coupon doesn\'t apply to your cart.';

  @override
  String get errorCouponUsageExceeded =>
      'You\'ve already used this coupon the maximum number of times.';

  @override
  String get errorCodNotAvailable =>
      'Cash on delivery isn\'t available for this order.';

  @override
  String get errorPriceChanged =>
      'Prices have changed. Please review your updated bill.';

  @override
  String get errorPaymentVerificationFailed =>
      'We couldn\'t confirm your payment. Please check your order status before paying again.';

  @override
  String get errorInvalidStateTransition =>
      'This action is no longer available. Please refresh and try again.';

  @override
  String get errorOfferExpired => 'This order offer has expired.';

  @override
  String get errorOfferTaken => 'This order was assigned to another rider.';

  @override
  String get errorOutsideGeofence =>
      'You\'re too far from the location. Move closer and try again.';

  @override
  String get errorDeliveryOtpInvalid => 'That delivery OTP is incorrect.';

  @override
  String get errorDeliveryOtpLocked =>
      'Too many wrong OTP attempts. Please contact support.';

  @override
  String get errorCashLimitExceeded =>
      'You\'ve reached your cash limit. Deposit cash to continue.';

  @override
  String get errorMaintenance =>
      'We\'re down for maintenance. Please try again soon.';

  @override
  String get errorRateLimited =>
      'Too many requests. Please wait a moment and try again.';

  @override
  String get errorServiceUnavailable =>
      'Jivo is temporarily unavailable. Please try again in a few minutes.';

  @override
  String get errorStoreNotFound =>
      'This store isn\'t available any more. Please choose your location again.';

  @override
  String errorOtpInvalidAttempts(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'That OTP is incorrect. $count attempts left.',
      one: 'That OTP is incorrect. 1 attempt left.',
      zero:
          'That OTP is incorrect. No attempts left: please request a new OTP.',
    );
    return '$_temp0';
  }

  @override
  String errorTryAgainInMinutes(int minutes) {
    String _temp0 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: 'Too many attempts. Please try again in $minutes minutes.',
      one: 'Too many attempts. Please try again in 1 minute.',
    );
    return '$_temp0';
  }
}
