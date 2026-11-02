// ignore_for_file: type=lint, unused_import, duplicate_ignore
//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:json_annotation/json_annotation.dart';

/// * `VALIDATION_ERROR` - Some fields are invalid. * `OTP_INVALID` - The OTP is incorrect. * `OTP_EXPIRED` - The OTP has expired. * `OTP_RATE_LIMITED` - Too many OTP requests. Try again later. * `AUTH_REQUIRED` - Authentication is required. * `TOKEN_INVALID` - The access token is invalid or expired. * `PERMISSION_DENIED` - You do not have permission to do this. * `NOT_FOUND` - Not found. * `APP_UPDATE_REQUIRED` - Please update the app to continue. * `NOT_SERVICEABLE` - We do not deliver to this location yet. * `STORE_CLOSED` - The store is not accepting orders right now. * `STOCK_UNAVAILABLE` - Some items are out of stock. * `MAX_QTY_EXCEEDED` - The maximum quantity for this item is exceeded. * `MIN_ORDER_NOT_MET` - The minimum order value is not met. * `COUPON_INVALID` - The coupon is not valid. * `COUPON_EXPIRED` - The coupon has expired. * `COUPON_NOT_ELIGIBLE` - This cart is not eligible for the coupon. * `COUPON_USAGE_EXCEEDED` - The coupon usage limit is reached. * `COD_NOT_AVAILABLE` - Cash on delivery is not available for this order. * `PRICE_CHANGED` - The bill has changed. Refresh the cart. * `PAYMENT_VERIFICATION_FAILED` - The payment could not be verified. * `INVALID_STATE_TRANSITION` - This action is not allowed right now. * `OFFER_EXPIRED` - The offer has expired. * `OFFER_TAKEN` - The offer was taken by another rider. * `OUTSIDE_GEOFENCE` - You are too far from the location. * `DELIVERY_OTP_INVALID` - The delivery OTP is incorrect. * `DELIVERY_OTP_LOCKED` - Too many wrong delivery OTP attempts. * `CASH_LIMIT_EXCEEDED` - The cash-in-hand limit is exceeded. * `MAINTENANCE` - The service is under maintenance. * `METHOD_NOT_ALLOWED` - This HTTP method is not allowed here. * `NOT_ACCEPTABLE` - The requested response format is not available. * `UNSUPPORTED_MEDIA_TYPE` - The request body format is not supported. * `RATE_LIMITED` - Too many requests. Try again later. * `SERVER_ERROR` - Something went wrong. Please try again. * `SERVICE_UNAVAILABLE` - The service is temporarily unavailable.
enum ErrorCodeEnum {
  @JsonValue(r'VALIDATION_ERROR')
  VALIDATION_ERROR(r'VALIDATION_ERROR'),
  @JsonValue(r'OTP_INVALID')
  OTP_INVALID(r'OTP_INVALID'),
  @JsonValue(r'OTP_EXPIRED')
  OTP_EXPIRED(r'OTP_EXPIRED'),
  @JsonValue(r'OTP_RATE_LIMITED')
  OTP_RATE_LIMITED(r'OTP_RATE_LIMITED'),
  @JsonValue(r'AUTH_REQUIRED')
  AUTH_REQUIRED(r'AUTH_REQUIRED'),
  @JsonValue(r'TOKEN_INVALID')
  TOKEN_INVALID(r'TOKEN_INVALID'),
  @JsonValue(r'PERMISSION_DENIED')
  PERMISSION_DENIED(r'PERMISSION_DENIED'),
  @JsonValue(r'NOT_FOUND')
  NOT_FOUND(r'NOT_FOUND'),
  @JsonValue(r'APP_UPDATE_REQUIRED')
  APP_UPDATE_REQUIRED(r'APP_UPDATE_REQUIRED'),
  @JsonValue(r'NOT_SERVICEABLE')
  NOT_SERVICEABLE(r'NOT_SERVICEABLE'),
  @JsonValue(r'STORE_CLOSED')
  STORE_CLOSED(r'STORE_CLOSED'),
  @JsonValue(r'STOCK_UNAVAILABLE')
  STOCK_UNAVAILABLE(r'STOCK_UNAVAILABLE'),
  @JsonValue(r'MAX_QTY_EXCEEDED')
  MAX_QTY_EXCEEDED(r'MAX_QTY_EXCEEDED'),
  @JsonValue(r'MIN_ORDER_NOT_MET')
  MIN_ORDER_NOT_MET(r'MIN_ORDER_NOT_MET'),
  @JsonValue(r'COUPON_INVALID')
  COUPON_INVALID(r'COUPON_INVALID'),
  @JsonValue(r'COUPON_EXPIRED')
  COUPON_EXPIRED(r'COUPON_EXPIRED'),
  @JsonValue(r'COUPON_NOT_ELIGIBLE')
  COUPON_NOT_ELIGIBLE(r'COUPON_NOT_ELIGIBLE'),
  @JsonValue(r'COUPON_USAGE_EXCEEDED')
  COUPON_USAGE_EXCEEDED(r'COUPON_USAGE_EXCEEDED'),
  @JsonValue(r'COD_NOT_AVAILABLE')
  COD_NOT_AVAILABLE(r'COD_NOT_AVAILABLE'),
  @JsonValue(r'PRICE_CHANGED')
  PRICE_CHANGED(r'PRICE_CHANGED'),
  @JsonValue(r'PAYMENT_VERIFICATION_FAILED')
  PAYMENT_VERIFICATION_FAILED(r'PAYMENT_VERIFICATION_FAILED'),
  @JsonValue(r'INVALID_STATE_TRANSITION')
  INVALID_STATE_TRANSITION(r'INVALID_STATE_TRANSITION'),
  @JsonValue(r'OFFER_EXPIRED')
  OFFER_EXPIRED(r'OFFER_EXPIRED'),
  @JsonValue(r'OFFER_TAKEN')
  OFFER_TAKEN(r'OFFER_TAKEN'),
  @JsonValue(r'OUTSIDE_GEOFENCE')
  OUTSIDE_GEOFENCE(r'OUTSIDE_GEOFENCE'),
  @JsonValue(r'DELIVERY_OTP_INVALID')
  DELIVERY_OTP_INVALID(r'DELIVERY_OTP_INVALID'),
  @JsonValue(r'DELIVERY_OTP_LOCKED')
  DELIVERY_OTP_LOCKED(r'DELIVERY_OTP_LOCKED'),
  @JsonValue(r'CASH_LIMIT_EXCEEDED')
  CASH_LIMIT_EXCEEDED(r'CASH_LIMIT_EXCEEDED'),
  @JsonValue(r'MAINTENANCE')
  MAINTENANCE(r'MAINTENANCE'),
  @JsonValue(r'METHOD_NOT_ALLOWED')
  METHOD_NOT_ALLOWED(r'METHOD_NOT_ALLOWED'),
  @JsonValue(r'NOT_ACCEPTABLE')
  NOT_ACCEPTABLE(r'NOT_ACCEPTABLE'),
  @JsonValue(r'UNSUPPORTED_MEDIA_TYPE')
  UNSUPPORTED_MEDIA_TYPE(r'UNSUPPORTED_MEDIA_TYPE'),
  @JsonValue(r'RATE_LIMITED')
  RATE_LIMITED(r'RATE_LIMITED'),
  @JsonValue(r'SERVER_ERROR')
  SERVER_ERROR(r'SERVER_ERROR'),
  @JsonValue(r'SERVICE_UNAVAILABLE')
  SERVICE_UNAVAILABLE(r'SERVICE_UNAVAILABLE'),
  @JsonValue(r'unknown_default_open_api')
  unknownDefaultOpenApi(r'unknown_default_open_api');

  const ErrorCodeEnum(this.value);

  final String value;

  @override
  String toString() => value;
}
