// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'notify_me.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$NotifyMeCWProxy {
  NotifyMe id(int id);

  NotifyMe lat(double lat);

  NotifyMe lng(double lng);

  NotifyMe phone(String? phone);

  NotifyMe addressText(String? addressText);

  NotifyMe createdAt(DateTime createdAt);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `NotifyMe(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// NotifyMe(...).copyWith(id: 12, name: "My name")
  /// ````
  NotifyMe call({
    int id,
    double lat,
    double lng,
    String? phone,
    String? addressText,
    DateTime createdAt,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfNotifyMe.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfNotifyMe.copyWith.fieldName(...)`
class _$NotifyMeCWProxyImpl implements _$NotifyMeCWProxy {
  const _$NotifyMeCWProxyImpl(this._value);

  final NotifyMe _value;

  @override
  NotifyMe id(int id) => this(id: id);

  @override
  NotifyMe lat(double lat) => this(lat: lat);

  @override
  NotifyMe lng(double lng) => this(lng: lng);

  @override
  NotifyMe phone(String? phone) => this(phone: phone);

  @override
  NotifyMe addressText(String? addressText) => this(addressText: addressText);

  @override
  NotifyMe createdAt(DateTime createdAt) => this(createdAt: createdAt);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `NotifyMe(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// NotifyMe(...).copyWith(id: 12, name: "My name")
  /// ````
  NotifyMe call({
    Object? id = const $CopyWithPlaceholder(),
    Object? lat = const $CopyWithPlaceholder(),
    Object? lng = const $CopyWithPlaceholder(),
    Object? phone = const $CopyWithPlaceholder(),
    Object? addressText = const $CopyWithPlaceholder(),
    Object? createdAt = const $CopyWithPlaceholder(),
  }) {
    return NotifyMe(
      id: id == const $CopyWithPlaceholder()
          ? _value.id
          // ignore: cast_nullable_to_non_nullable
          : id as int,
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
      createdAt: createdAt == const $CopyWithPlaceholder()
          ? _value.createdAt
          // ignore: cast_nullable_to_non_nullable
          : createdAt as DateTime,
    );
  }
}

extension $NotifyMeCopyWith on NotifyMe {
  /// Returns a callable class that can be used as follows: `instanceOfNotifyMe.copyWith(...)` or like so:`instanceOfNotifyMe.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$NotifyMeCWProxy get copyWith => _$NotifyMeCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

NotifyMe _$NotifyMeFromJson(Map<String, dynamic> json) => $checkedCreate(
  'NotifyMe',
  json,
  ($checkedConvert) {
    $checkKeys(json, requiredKeys: const ['id', 'lat', 'lng', 'created_at']);
    final val = NotifyMe(
      id: $checkedConvert('id', (v) => (v as num).toInt()),
      lat: $checkedConvert('lat', (v) => (v as num).toDouble()),
      lng: $checkedConvert('lng', (v) => (v as num).toDouble()),
      phone: $checkedConvert('phone', (v) => v as String?),
      addressText: $checkedConvert('address_text', (v) => v as String?),
      createdAt: $checkedConvert(
        'created_at',
        (v) => DateTime.parse(v as String),
      ),
    );
    return val;
  },
  fieldKeyMap: const {'addressText': 'address_text', 'createdAt': 'created_at'},
);

Map<String, dynamic> _$NotifyMeToJson(NotifyMe instance) => <String, dynamic>{
  'id': instance.id,
  'lat': instance.lat,
  'lng': instance.lng,
  'phone': ?instance.phone,
  'address_text': ?instance.addressText,
  'created_at': instance.createdAt.toIso8601String(),
};
