// ignore_for_file: type=lint, unused_import, duplicate_ignore
//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:jivo_api/src/model/error_code_enum.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'error_body.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class ErrorBody {
  /// Returns a new [ErrorBody] instance.
  ErrorBody({required this.code, required this.message, required this.details});

  /// Stable machine-readable error code (06 §6). Apps map codes to messages.  * `VALIDATION_ERROR` - Some fields are invalid. * `OTP_INVALID` - The OTP is incorrect. * `OTP_EXPIRED` - The OTP has expired. * `OTP_RATE_LIMITED` - Too many OTP requests. Try again later. * `AUTH_REQUIRED` - Authentication is required. * `TOKEN_INVALID` - The access token is invalid or expired. * `PERMISSION_DENIED` - You do not have permission to do this. * `NOT_FOUND` - Not found. * `APP_UPDATE_REQUIRED` - Please update the app to continue. * `NOT_SERVICEABLE` - We do not deliver to this location yet. * `STORE_CLOSED` - The store is not accepting orders right now. * `STOCK_UNAVAILABLE` - Some items are out of stock. * `MAX_QTY_EXCEEDED` - The maximum quantity for this item is exceeded. * `MIN_ORDER_NOT_MET` - The minimum order value is not met. * `COUPON_INVALID` - The coupon is not valid. * `COUPON_EXPIRED` - The coupon has expired. * `COUPON_NOT_ELIGIBLE` - This cart is not eligible for the coupon. * `COUPON_USAGE_EXCEEDED` - The coupon usage limit is reached. * `COD_NOT_AVAILABLE` - Cash on delivery is not available for this order. * `PRICE_CHANGED` - The bill has changed. Refresh the cart. * `PAYMENT_VERIFICATION_FAILED` - The payment could not be verified. * `INVALID_STATE_TRANSITION` - This action is not allowed right now. * `OFFER_EXPIRED` - The offer has expired. * `OFFER_TAKEN` - The offer was taken by another rider. * `OUTSIDE_GEOFENCE` - You are too far from the location. * `DELIVERY_OTP_INVALID` - The delivery OTP is incorrect. * `DELIVERY_OTP_LOCKED` - Too many wrong delivery OTP attempts. * `CASH_LIMIT_EXCEEDED` - The cash-in-hand limit is exceeded. * `MAINTENANCE` - The service is under maintenance. * `METHOD_NOT_ALLOWED` - This HTTP method is not allowed here. * `NOT_ACCEPTABLE` - The requested response format is not available. * `UNSUPPORTED_MEDIA_TYPE` - The request body format is not supported. * `RATE_LIMITED` - Too many requests. Try again later. * `SERVER_ERROR` - Something went wrong. Please try again. * `SERVICE_UNAVAILABLE` - The service is temporarily unavailable. * `STORE_NOT_FOUND` - This store is not available. Check serviceability again. * `PAYLOAD_TOO_LARGE` - The request body is too large.
  @JsonKey(
    name: r'code',
    required: true,
    includeIfNull: false,
    unknownEnumValue: ErrorCodeEnum.unknownDefaultOpenApi,
  )
  final ErrorCodeEnum code;

  /// Human-readable message (English).
  @JsonKey(name: r'message', required: true, includeIfNull: false)
  final String message;

  /// Extra data for the code; always an object, possibly empty. VALIDATION_ERROR: field name -> list of messages.
  @JsonKey(name: r'details', required: true, includeIfNull: false)
  final Map<String, Object> details;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ErrorBody &&
          other.code == code &&
          other.message == message &&
          other.details == details;

  @override
  int get hashCode => code.hashCode + message.hashCode + details.hashCode;

  factory ErrorBody.fromJson(Map<String, dynamic> json) =>
      _$ErrorBodyFromJson(json);

  Map<String, dynamic> toJson() => _$ErrorBodyToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
