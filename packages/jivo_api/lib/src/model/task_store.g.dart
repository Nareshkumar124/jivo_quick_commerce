// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'task_store.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$TaskStoreCWProxy {
  TaskStore id(int id);

  TaskStore name(String name);

  TaskStore address(String address);

  TaskStore phone(String phone);

  TaskStore lat(double lat);

  TaskStore lng(double lng);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `TaskStore(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// TaskStore(...).copyWith(id: 12, name: "My name")
  /// ````
  TaskStore call({
    int id,
    String name,
    String address,
    String phone,
    double lat,
    double lng,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfTaskStore.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfTaskStore.copyWith.fieldName(...)`
class _$TaskStoreCWProxyImpl implements _$TaskStoreCWProxy {
  const _$TaskStoreCWProxyImpl(this._value);

  final TaskStore _value;

  @override
  TaskStore id(int id) => this(id: id);

  @override
  TaskStore name(String name) => this(name: name);

  @override
  TaskStore address(String address) => this(address: address);

  @override
  TaskStore phone(String phone) => this(phone: phone);

  @override
  TaskStore lat(double lat) => this(lat: lat);

  @override
  TaskStore lng(double lng) => this(lng: lng);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `TaskStore(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// TaskStore(...).copyWith(id: 12, name: "My name")
  /// ````
  TaskStore call({
    Object? id = const $CopyWithPlaceholder(),
    Object? name = const $CopyWithPlaceholder(),
    Object? address = const $CopyWithPlaceholder(),
    Object? phone = const $CopyWithPlaceholder(),
    Object? lat = const $CopyWithPlaceholder(),
    Object? lng = const $CopyWithPlaceholder(),
  }) {
    return TaskStore(
      id: id == const $CopyWithPlaceholder()
          ? _value.id
          // ignore: cast_nullable_to_non_nullable
          : id as int,
      name: name == const $CopyWithPlaceholder()
          ? _value.name
          // ignore: cast_nullable_to_non_nullable
          : name as String,
      address: address == const $CopyWithPlaceholder()
          ? _value.address
          // ignore: cast_nullable_to_non_nullable
          : address as String,
      phone: phone == const $CopyWithPlaceholder()
          ? _value.phone
          // ignore: cast_nullable_to_non_nullable
          : phone as String,
      lat: lat == const $CopyWithPlaceholder()
          ? _value.lat
          // ignore: cast_nullable_to_non_nullable
          : lat as double,
      lng: lng == const $CopyWithPlaceholder()
          ? _value.lng
          // ignore: cast_nullable_to_non_nullable
          : lng as double,
    );
  }
}

extension $TaskStoreCopyWith on TaskStore {
  /// Returns a callable class that can be used as follows: `instanceOfTaskStore.copyWith(...)` or like so:`instanceOfTaskStore.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$TaskStoreCWProxy get copyWith => _$TaskStoreCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

TaskStore _$TaskStoreFromJson(Map<String, dynamic> json) =>
    $checkedCreate('TaskStore', json, ($checkedConvert) {
      $checkKeys(
        json,
        requiredKeys: const ['id', 'name', 'address', 'phone', 'lat', 'lng'],
      );
      final val = TaskStore(
        id: $checkedConvert('id', (v) => (v as num).toInt()),
        name: $checkedConvert('name', (v) => v as String),
        address: $checkedConvert('address', (v) => v as String),
        phone: $checkedConvert('phone', (v) => v as String),
        lat: $checkedConvert('lat', (v) => (v as num).toDouble()),
        lng: $checkedConvert('lng', (v) => (v as num).toDouble()),
      );
      return val;
    });

Map<String, dynamic> _$TaskStoreToJson(TaskStore instance) => <String, dynamic>{
  'id': instance.id,
  'name': instance.name,
  'address': instance.address,
  'phone': instance.phone,
  'lat': instance.lat,
  'lng': instance.lng,
};
