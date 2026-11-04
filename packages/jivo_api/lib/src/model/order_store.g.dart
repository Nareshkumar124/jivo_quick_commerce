// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'order_store.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$OrderStoreCWProxy {
  OrderStore id(int id);

  OrderStore name(String name);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `OrderStore(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// OrderStore(...).copyWith(id: 12, name: "My name")
  /// ````
  OrderStore call({int id, String name});
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfOrderStore.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfOrderStore.copyWith.fieldName(...)`
class _$OrderStoreCWProxyImpl implements _$OrderStoreCWProxy {
  const _$OrderStoreCWProxyImpl(this._value);

  final OrderStore _value;

  @override
  OrderStore id(int id) => this(id: id);

  @override
  OrderStore name(String name) => this(name: name);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `OrderStore(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// OrderStore(...).copyWith(id: 12, name: "My name")
  /// ````
  OrderStore call({
    Object? id = const $CopyWithPlaceholder(),
    Object? name = const $CopyWithPlaceholder(),
  }) {
    return OrderStore(
      id: id == const $CopyWithPlaceholder()
          ? _value.id
          // ignore: cast_nullable_to_non_nullable
          : id as int,
      name: name == const $CopyWithPlaceholder()
          ? _value.name
          // ignore: cast_nullable_to_non_nullable
          : name as String,
    );
  }
}

extension $OrderStoreCopyWith on OrderStore {
  /// Returns a callable class that can be used as follows: `instanceOfOrderStore.copyWith(...)` or like so:`instanceOfOrderStore.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$OrderStoreCWProxy get copyWith => _$OrderStoreCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

OrderStore _$OrderStoreFromJson(Map<String, dynamic> json) =>
    $checkedCreate('OrderStore', json, ($checkedConvert) {
      $checkKeys(json, requiredKeys: const ['id', 'name']);
      final val = OrderStore(
        id: $checkedConvert('id', (v) => (v as num).toInt()),
        name: $checkedConvert('name', (v) => v as String),
      );
      return val;
    });

Map<String, dynamic> _$OrderStoreToJson(OrderStore instance) =>
    <String, dynamic>{'id': instance.id, 'name': instance.name};
