// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'serviceability.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$ServiceabilityCWProxy {
  Serviceability serviceable(bool serviceable);

  Serviceability store(StoreStatus? store);

  Serviceability etaMinutes(int? etaMinutes);

  Serviceability message(String? message);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `Serviceability(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// Serviceability(...).copyWith(id: 12, name: "My name")
  /// ````
  Serviceability call({
    bool serviceable,
    StoreStatus? store,
    int? etaMinutes,
    String? message,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfServiceability.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfServiceability.copyWith.fieldName(...)`
class _$ServiceabilityCWProxyImpl implements _$ServiceabilityCWProxy {
  const _$ServiceabilityCWProxyImpl(this._value);

  final Serviceability _value;

  @override
  Serviceability serviceable(bool serviceable) =>
      this(serviceable: serviceable);

  @override
  Serviceability store(StoreStatus? store) => this(store: store);

  @override
  Serviceability etaMinutes(int? etaMinutes) => this(etaMinutes: etaMinutes);

  @override
  Serviceability message(String? message) => this(message: message);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `Serviceability(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// Serviceability(...).copyWith(id: 12, name: "My name")
  /// ````
  Serviceability call({
    Object? serviceable = const $CopyWithPlaceholder(),
    Object? store = const $CopyWithPlaceholder(),
    Object? etaMinutes = const $CopyWithPlaceholder(),
    Object? message = const $CopyWithPlaceholder(),
  }) {
    return Serviceability(
      serviceable: serviceable == const $CopyWithPlaceholder()
          ? _value.serviceable
          // ignore: cast_nullable_to_non_nullable
          : serviceable as bool,
      store: store == const $CopyWithPlaceholder()
          ? _value.store
          // ignore: cast_nullable_to_non_nullable
          : store as StoreStatus?,
      etaMinutes: etaMinutes == const $CopyWithPlaceholder()
          ? _value.etaMinutes
          // ignore: cast_nullable_to_non_nullable
          : etaMinutes as int?,
      message: message == const $CopyWithPlaceholder()
          ? _value.message
          // ignore: cast_nullable_to_non_nullable
          : message as String?,
    );
  }
}

extension $ServiceabilityCopyWith on Serviceability {
  /// Returns a callable class that can be used as follows: `instanceOfServiceability.copyWith(...)` or like so:`instanceOfServiceability.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$ServiceabilityCWProxy get copyWith => _$ServiceabilityCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Serviceability _$ServiceabilityFromJson(Map<String, dynamic> json) =>
    $checkedCreate('Serviceability', json, ($checkedConvert) {
      $checkKeys(
        json,
        requiredKeys: const ['serviceable', 'store', 'eta_minutes', 'message'],
      );
      final val = Serviceability(
        serviceable: $checkedConvert('serviceable', (v) => v as bool),
        store: $checkedConvert(
          'store',
          (v) => v == null
              ? null
              : StoreStatus.fromJson(v as Map<String, dynamic>),
        ),
        etaMinutes: $checkedConvert('eta_minutes', (v) => (v as num?)?.toInt()),
        message: $checkedConvert('message', (v) => v as String?),
      );
      return val;
    }, fieldKeyMap: const {'etaMinutes': 'eta_minutes'});

Map<String, dynamic> _$ServiceabilityToJson(Serviceability instance) =>
    <String, dynamic>{
      'serviceable': instance.serviceable,
      'store': instance.store?.toJson(),
      'eta_minutes': instance.etaMinutes,
      'message': instance.message,
    };
