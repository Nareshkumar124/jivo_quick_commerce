// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'store_status.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$StoreStatusCWProxy {
  StoreStatus id(int id);

  StoreStatus name(String name);

  StoreStatus isOpen(bool isOpen);

  StoreStatus opensAt(DateTime? opensAt);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `StoreStatus(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// StoreStatus(...).copyWith(id: 12, name: "My name")
  /// ````
  StoreStatus call({int id, String name, bool isOpen, DateTime? opensAt});
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfStoreStatus.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfStoreStatus.copyWith.fieldName(...)`
class _$StoreStatusCWProxyImpl implements _$StoreStatusCWProxy {
  const _$StoreStatusCWProxyImpl(this._value);

  final StoreStatus _value;

  @override
  StoreStatus id(int id) => this(id: id);

  @override
  StoreStatus name(String name) => this(name: name);

  @override
  StoreStatus isOpen(bool isOpen) => this(isOpen: isOpen);

  @override
  StoreStatus opensAt(DateTime? opensAt) => this(opensAt: opensAt);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `StoreStatus(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// StoreStatus(...).copyWith(id: 12, name: "My name")
  /// ````
  StoreStatus call({
    Object? id = const $CopyWithPlaceholder(),
    Object? name = const $CopyWithPlaceholder(),
    Object? isOpen = const $CopyWithPlaceholder(),
    Object? opensAt = const $CopyWithPlaceholder(),
  }) {
    return StoreStatus(
      id: id == const $CopyWithPlaceholder()
          ? _value.id
          // ignore: cast_nullable_to_non_nullable
          : id as int,
      name: name == const $CopyWithPlaceholder()
          ? _value.name
          // ignore: cast_nullable_to_non_nullable
          : name as String,
      isOpen: isOpen == const $CopyWithPlaceholder()
          ? _value.isOpen
          // ignore: cast_nullable_to_non_nullable
          : isOpen as bool,
      opensAt: opensAt == const $CopyWithPlaceholder()
          ? _value.opensAt
          // ignore: cast_nullable_to_non_nullable
          : opensAt as DateTime?,
    );
  }
}

extension $StoreStatusCopyWith on StoreStatus {
  /// Returns a callable class that can be used as follows: `instanceOfStoreStatus.copyWith(...)` or like so:`instanceOfStoreStatus.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$StoreStatusCWProxy get copyWith => _$StoreStatusCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

StoreStatus _$StoreStatusFromJson(Map<String, dynamic> json) => $checkedCreate(
  'StoreStatus',
  json,
  ($checkedConvert) {
    $checkKeys(json, requiredKeys: const ['id', 'name', 'is_open', 'opens_at']);
    final val = StoreStatus(
      id: $checkedConvert('id', (v) => (v as num).toInt()),
      name: $checkedConvert('name', (v) => v as String),
      isOpen: $checkedConvert('is_open', (v) => v as bool),
      opensAt: $checkedConvert(
        'opens_at',
        (v) => v == null ? null : DateTime.parse(v as String),
      ),
    );
    return val;
  },
  fieldKeyMap: const {'isOpen': 'is_open', 'opensAt': 'opens_at'},
);

Map<String, dynamic> _$StoreStatusToJson(StoreStatus instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'is_open': instance.isOpen,
      'opens_at': instance.opensAt?.toIso8601String(),
    };
