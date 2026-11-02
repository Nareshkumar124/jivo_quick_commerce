// ignore_for_file: type=lint, unused_import, duplicate_ignore
import 'package:jivo_api/src/model/account_delete_request.dart';
import 'package:jivo_api/src/model/account_deletion.dart';
import 'package:jivo_api/src/model/address.dart';
import 'package:jivo_api/src/model/address_request.dart';
import 'package:jivo_api/src/model/app_config.dart';
import 'package:jivo_api/src/model/auth_session.dart';
import 'package:jivo_api/src/model/category_node.dart';
import 'package:jivo_api/src/model/category_tile.dart';
import 'package:jivo_api/src/model/category_tree.dart';
import 'package:jivo_api/src/model/collection_detail.dart';
import 'package:jivo_api/src/model/collection_rail.dart';
import 'package:jivo_api/src/model/device.dart';
import 'package:jivo_api/src/model/device_request.dart';
import 'package:jivo_api/src/model/error_body.dart';
import 'package:jivo_api/src/model/error_envelope.dart';
import 'package:jivo_api/src/model/health_checks.dart';
import 'package:jivo_api/src/model/health_live.dart';
import 'package:jivo_api/src/model/health_ready.dart';
import 'package:jivo_api/src/model/home_banner.dart';
import 'package:jivo_api/src/model/home_feed.dart';
import 'package:jivo_api/src/model/image_set.dart';
import 'package:jivo_api/src/model/logout_request.dart';
import 'package:jivo_api/src/model/me.dart';
import 'package:jivo_api/src/model/notify_me.dart';
import 'package:jivo_api/src/model/notify_me_request.dart';
import 'package:jivo_api/src/model/nutrition_row.dart';
import 'package:jivo_api/src/model/nutrition_table.dart';
import 'package:jivo_api/src/model/otp_send_request.dart';
import 'package:jivo_api/src/model/otp_sent.dart';
import 'package:jivo_api/src/model/otp_settings.dart';
import 'package:jivo_api/src/model/otp_verify_request.dart';
import 'package:jivo_api/src/model/paginated_address_list.dart';
import 'package:jivo_api/src/model/paginated_product_card_list.dart';
import 'package:jivo_api/src/model/patched_address_request.dart';
import 'package:jivo_api/src/model/patched_me_request.dart';
import 'package:jivo_api/src/model/policy_urls.dart';
import 'package:jivo_api/src/model/product_card.dart';
import 'package:jivo_api/src/model/product_detail.dart';
import 'package:jivo_api/src/model/rider_location_settings.dart';
import 'package:jivo_api/src/model/search_suggestion.dart';
import 'package:jivo_api/src/model/search_suggestions.dart';
import 'package:jivo_api/src/model/serviceability.dart';
import 'package:jivo_api/src/model/store_status.dart';
import 'package:jivo_api/src/model/support_contacts.dart';
import 'package:jivo_api/src/model/token_pair.dart';
import 'package:jivo_api/src/model/token_refresh_request.dart';
import 'package:jivo_api/src/model/unit_price.dart';
import 'package:jivo_api/src/model/variant_detail.dart';
import 'package:jivo_api/src/model/variant_summary.dart';

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
    case 'BannerLinkTypeEnum':
    case 'CategoryNode':
      return CategoryNode.fromJson(value as Map<String, dynamic>) as ReturnType;
    case 'CategoryTile':
      return CategoryTile.fromJson(value as Map<String, dynamic>) as ReturnType;
    case 'CategoryTree':
      return CategoryTree.fromJson(value as Map<String, dynamic>) as ReturnType;
    case 'CollectionDetail':
      return CollectionDetail.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'CollectionRail':
      return CollectionRail.fromJson(value as Map<String, dynamic>)
          as ReturnType;
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
    case 'HomeBanner':
      return HomeBanner.fromJson(value as Map<String, dynamic>) as ReturnType;
    case 'HomeFeed':
      return HomeFeed.fromJson(value as Map<String, dynamic>) as ReturnType;
    case 'ImageSet':
      return ImageSet.fromJson(value as Map<String, dynamic>) as ReturnType;
    case 'LogoutRequest':
      return LogoutRequest.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'Me':
      return Me.fromJson(value as Map<String, dynamic>) as ReturnType;
    case 'NotifyMe':
      return NotifyMe.fromJson(value as Map<String, dynamic>) as ReturnType;
    case 'NotifyMeRequest':
      return NotifyMeRequest.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'NutritionRow':
      return NutritionRow.fromJson(value as Map<String, dynamic>) as ReturnType;
    case 'NutritionTable':
      return NutritionTable.fromJson(value as Map<String, dynamic>)
          as ReturnType;
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
    case 'PaginatedProductCardList':
      return PaginatedProductCardList.fromJson(value as Map<String, dynamic>)
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
    case 'ProductCard':
      return ProductCard.fromJson(value as Map<String, dynamic>) as ReturnType;
    case 'ProductDetail':
      return ProductDetail.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'RiderLocationSettings':
      return RiderLocationSettings.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'RiderStatusEnum':
    case 'SearchSuggestion':
      return SearchSuggestion.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'SearchSuggestionTypeEnum':
    case 'SearchSuggestions':
      return SearchSuggestions.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'Serviceability':
      return Serviceability.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'StockStatusEnum':
    case 'StoreStatus':
      return StoreStatus.fromJson(value as Map<String, dynamic>) as ReturnType;
    case 'SupportContacts':
      return SupportContacts.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'TokenPair':
      return TokenPair.fromJson(value as Map<String, dynamic>) as ReturnType;
    case 'TokenRefreshRequest':
      return TokenRefreshRequest.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'UnitPrice':
      return UnitPrice.fromJson(value as Map<String, dynamic>) as ReturnType;
    case 'VariantDetail':
      return VariantDetail.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'VariantSummary':
      return VariantSummary.fromJson(value as Map<String, dynamic>)
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
