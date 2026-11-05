// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'rider_store.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$RiderStoreCWProxy {
  RiderStore id(int id);

  RiderStore name(String name);

  RiderStore city(String city);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `RiderStore(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// RiderStore(...).copyWith(id: 12, name: "My name")
  /// ````
  RiderStore call({int id, String name, String city});
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfRiderStore.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfRiderStore.copyWith.fieldName(...)`
class _$RiderStoreCWProxyImpl implements _$RiderStoreCWProxy {
  const _$RiderStoreCWProxyImpl(this._value);

  final RiderStore _value;

  @override
  RiderStore id(int id) => this(id: id);

  @override
  RiderStore name(String name) => this(name: name);

  @override
  RiderStore city(String city) => this(city: city);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `RiderStore(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// RiderStore(...).copyWith(id: 12, name: "My name")
  /// ````
  RiderStore call({
    Object? id = const $CopyWithPlaceholder(),
    Object? name = const $CopyWithPlaceholder(),
    Object? city = const $CopyWithPlaceholder(),
  }) {
    return RiderStore(
      id: id == const $CopyWithPlaceholder()
          ? _value.id
          // ignore: cast_nullable_to_non_nullable
          : id as int,
      name: name == const $CopyWithPlaceholder()
          ? _value.name
          // ignore: cast_nullable_to_non_nullable
          : name as String,
      city: city == const $CopyWithPlaceholder()
          ? _value.city
          // ignore: cast_nullable_to_non_nullable
          : city as String,
    );
  }
}

extension $RiderStoreCopyWith on RiderStore {
  /// Returns a callable class that can be used as follows: `instanceOfRiderStore.copyWith(...)` or like so:`instanceOfRiderStore.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$RiderStoreCWProxy get copyWith => _$RiderStoreCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

RiderStore _$RiderStoreFromJson(Map<String, dynamic> json) =>
    $checkedCreate('RiderStore', json, ($checkedConvert) {
      $checkKeys(json, requiredKeys: const ['id', 'name', 'city']);
      final val = RiderStore(
        id: $checkedConvert('id', (v) => (v as num).toInt()),
        name: $checkedConvert('name', (v) => v as String),
        city: $checkedConvert('city', (v) => v as String),
      );
      return val;
    });

Map<String, dynamic> _$RiderStoreToJson(RiderStore instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'city': instance.city,
    };
