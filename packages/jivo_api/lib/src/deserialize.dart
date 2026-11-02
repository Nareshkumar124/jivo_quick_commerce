// ignore_for_file: type=lint, unused_import, duplicate_ignore
import 'package:jivo_api/src/model/account_delete_request.dart';
import 'package:jivo_api/src/model/account_deletion.dart';
import 'package:jivo_api/src/model/address.dart';
import 'package:jivo_api/src/model/address_request.dart';
import 'package:jivo_api/src/model/app_config.dart';
import 'package:jivo_api/src/model/auth_session.dart';
import 'package:jivo_api/src/model/device.dart';
import 'package:jivo_api/src/model/device_request.dart';
import 'package:jivo_api/src/model/error_body.dart';
import 'package:jivo_api/src/model/error_envelope.dart';
import 'package:jivo_api/src/model/health_checks.dart';
import 'package:jivo_api/src/model/health_live.dart';
import 'package:jivo_api/src/model/health_ready.dart';
import 'package:jivo_api/src/model/logout_request.dart';
import 'package:jivo_api/src/model/me.dart';
import 'package:jivo_api/src/model/otp_send_request.dart';
import 'package:jivo_api/src/model/otp_sent.dart';
import 'package:jivo_api/src/model/otp_settings.dart';
import 'package:jivo_api/src/model/otp_verify_request.dart';
import 'package:jivo_api/src/model/paginated_address_list.dart';
import 'package:jivo_api/src/model/patched_address_request.dart';
import 'package:jivo_api/src/model/patched_me_request.dart';
import 'package:jivo_api/src/model/policy_urls.dart';
import 'package:jivo_api/src/model/rider_location_settings.dart';
import 'package:jivo_api/src/model/support_contacts.dart';
import 'package:jivo_api/src/model/token_pair.dart';
import 'package:jivo_api/src/model/token_refresh_request.dart';

final _regList = RegExp(r'^List<(.*)>$');
final _regSet = RegExp(r'^Set<(.*)>$');
final _regMap = RegExp(r'^Map<String,(.*)>$');

ReturnType deserialize<ReturnType, BaseType>(
  dynamic value,
  String targetType, {
  bool growable = true,
}) {
  switch (targetType) {
    case 'String':
      return '$value' as ReturnType;
    case 'int':
      return (value is int ? value : int.parse('$value')) as ReturnType;
    case 'bool':
      if (value is bool) {
        return value as ReturnType;
      }
      final valueString = '$value'.toLowerCase();
      return (valueString == 'true' || valueString == '1') as ReturnType;
    case 'double':
      return (value is double ? value : double.parse('$value')) as ReturnType;
    case 'AccountDeleteRequest':
      return AccountDeleteRequest.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'AccountDeletion':
      return AccountDeletion.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'Address':
      return Address.fromJson(value as Map<String, dynamic>) as ReturnType;
    case 'AddressLabelEnum':
    case 'AddressRequest':
      return AddressRequest.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'AppConfig':
      return AppConfig.fromJson(value as Map<String, dynamic>) as ReturnType;
    case 'AppEnum':
    case 'AuthSession':
      return AuthSession.fromJson(value as Map<String, dynamic>) as ReturnType;
    case 'Device':
      return Device.fromJson(value as Map<String, dynamic>) as ReturnType;
    case 'DeviceRequest':
      return DeviceRequest.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'ErrorBody':
      return ErrorBody.fromJson(value as Map<String, dynamic>) as ReturnType;
    case 'ErrorCodeEnum':
    case 'ErrorEnvelope':
      return ErrorEnvelope.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'HealthCheckStatusEnum':
    case 'HealthChecks':
      return HealthChecks.fromJson(value as Map<String, dynamic>) as ReturnType;
    case 'HealthLive':
      return HealthLive.fromJson(value as Map<String, dynamic>) as ReturnType;
    case 'HealthReady':
      return HealthReady.fromJson(value as Map<String, dynamic>) as ReturnType;
    case 'HealthStatusEnum':
    case 'LogoutRequest':
      return LogoutRequest.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'Me':
      return Me.fromJson(value as Map<String, dynamic>) as ReturnType;
    case 'OtpPurposeEnum':
    case 'OtpSendRequest':
      return OtpSendRequest.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'OtpSent':
      return OtpSent.fromJson(value as Map<String, dynamic>) as ReturnType;
    case 'OtpSettings':
      return OtpSettings.fromJson(value as Map<String, dynamic>) as ReturnType;
    case 'OtpVerifyRequest':
      return OtpVerifyRequest.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'PaginatedAddressList':
      return PaginatedAddressList.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'PatchedAddressRequest':
      return PatchedAddressRequest.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'PatchedMeRequest':
      return PatchedMeRequest.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'PlatformEnum':
    case 'PolicyUrls':
      return PolicyUrls.fromJson(value as Map<String, dynamic>) as ReturnType;
    case 'RiderLocationSettings':
      return RiderLocationSettings.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'RiderStatusEnum':
    case 'SupportContacts':
      return SupportContacts.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'TokenPair':
      return TokenPair.fromJson(value as Map<String, dynamic>) as ReturnType;
    case 'TokenRefreshRequest':
      return TokenRefreshRequest.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    default:
      RegExpMatch? match;

      if (value is List && (match = _regList.firstMatch(targetType)) != null) {
        targetType = match![1]!; // ignore: parameter_assignments
        return value
                .map<BaseType>(
                  (dynamic v) => deserialize<BaseType, BaseType>(
                    v,
                    targetType,
                    growable: growable,
                  ),
                )
                .toList(growable: growable)
            as ReturnType;
      }
      if (value is Set && (match = _regSet.firstMatch(targetType)) != null) {
        targetType = match![1]!; // ignore: parameter_assignments
        return value
                .map<BaseType>(
                  (dynamic v) => deserialize<BaseType, BaseType>(
                    v,
                    targetType,
                    growable: growable,
                  ),
                )
                .toSet()
            as ReturnType;
      }
      if (value is Map && (match = _regMap.firstMatch(targetType)) != null) {
        targetType = match![1]!.trim(); // ignore: parameter_assignments
        return Map<String, BaseType>.fromIterables(
          value.keys as Iterable<String>,
          value.values.map(
            (dynamic v) => deserialize<BaseType, BaseType>(
              v,
              targetType,
              growable: growable,
            ),
          ),
        ) as ReturnType;
      }
      break;
  }
  throw Exception('Cannot deserialize');
}
