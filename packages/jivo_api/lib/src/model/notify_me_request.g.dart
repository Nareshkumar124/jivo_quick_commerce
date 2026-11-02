// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'notify_me_request.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$NotifyMeRequestCWProxy {
  NotifyMeRequest lat(double lat);

  NotifyMeRequest lng(double lng);

  NotifyMeRequest phone(String? phone);

  NotifyMeRequest addressText(String? addressText);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `NotifyMeRequest(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// NotifyMeRequest(...).copyWith(id: 12, name: "My name")
  /// ````
  NotifyMeRequest call({
    double lat,
    double lng,
    String? phone,
    String? addressText,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfNotifyMeRequest.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfNotifyMeRequest.copyWith.fieldName(...)`
class _$NotifyMeRequestCWProxyImpl implements _$NotifyMeRequestCWProxy {
  const _$NotifyMeRequestCWProxyImpl(this._value);

  final NotifyMeRequest _value;

  @override
  NotifyMeRequest lat(double lat) => this(lat: lat);

  @override
  NotifyMeRequest lng(double lng) => this(lng: lng);

  @override
  NotifyMeRequest phone(String? phone) => this(phone: phone);

  @override
  NotifyMeRequest addressText(String? addressText) =>
      this(addressText: addressText);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `NotifyMeRequest(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// NotifyMeRequest(...).copyWith(id: 12, name: "My name")
  /// ````
  NotifyMeRequest call({
    Object? lat = const $CopyWithPlaceholder(),
    Object? lng = const $CopyWithPlaceholder(),
    Object? phone = const $CopyWithPlaceholder(),
    Object? addressText = const $CopyWithPlaceholder(),
  }) {
    return NotifyMeRequest(
      lat: lat == const $CopyWithPlaceholder()
          ? _value.lat
          // ignore: cast_nullable_to_non_nullable
          : lat as double,
      lng: lng == const $CopyWithPlaceholder()
          ? _value.lng
          // ignore: cast_nullable_to_non_nullable
          : lng as double,
      phone: phone == const $CopyWithPlaceholder()
          ? _value.phone
          // ignore: cast_nullable_to_non_nullable
          : phone as String?,
      addressText: addressText == const $CopyWithPlaceholder()
          ? _value.addressText
          // ignore: cast_nullable_to_non_nullable
          : addressText as String?,
    );
  }
}

extension $NotifyMeRequestCopyWith on NotifyMeRequest {
  /// Returns a callable class that can be used as follows: `instanceOfNotifyMeRequest.copyWith(...)` or like so:`instanceOfNotifyMeRequest.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$NotifyMeRequestCWProxy get copyWith => _$NotifyMeRequestCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

NotifyMeRequest _$NotifyMeRequestFromJson(Map<String, dynamic> json) =>
    $checkedCreate('NotifyMeRequest', json, ($checkedConvert) {
      $checkKeys(json, requiredKeys: const ['lat', 'lng']);
      final val = NotifyMeRequest(
        lat: $checkedConvert('lat', (v) => (v as num).toDouble()),
        lng: $checkedConvert('lng', (v) => (v as num).toDouble()),
        phone: $checkedConvert('phone', (v) => v as String?),
        addressText: $checkedConvert('address_text', (v) => v as String?),
      );
      return val;
    }, fieldKeyMap: const {'addressText': 'address_text'});

Map<String, dynamic> _$NotifyMeRequestToJson(NotifyMeRequest instance) =>
    <String, dynamic>{
      'lat': instance.lat,
      'lng': instance.lng,
      'phone': ?instance.phone,
      'address_text': ?instance.addressText,
    };
