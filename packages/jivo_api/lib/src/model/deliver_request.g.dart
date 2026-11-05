// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'deliver_request.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$DeliverRequestCWProxy {
  DeliverRequest otp(String otp);

  DeliverRequest cod(CodCollectionRequest? cod);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `DeliverRequest(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// DeliverRequest(...).copyWith(id: 12, name: "My name")
  /// ````
  DeliverRequest call({String otp, CodCollectionRequest? cod});
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfDeliverRequest.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfDeliverRequest.copyWith.fieldName(...)`
class _$DeliverRequestCWProxyImpl implements _$DeliverRequestCWProxy {
  const _$DeliverRequestCWProxyImpl(this._value);

  final DeliverRequest _value;

  @override
  DeliverRequest otp(String otp) => this(otp: otp);

  @override
  DeliverRequest cod(CodCollectionRequest? cod) => this(cod: cod);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `DeliverRequest(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// DeliverRequest(...).copyWith(id: 12, name: "My name")
  /// ````
  DeliverRequest call({
    Object? otp = const $CopyWithPlaceholder(),
    Object? cod = const $CopyWithPlaceholder(),
  }) {
    return DeliverRequest(
      otp: otp == const $CopyWithPlaceholder()
          ? _value.otp
          // ignore: cast_nullable_to_non_nullable
          : otp as String,
      cod: cod == const $CopyWithPlaceholder()
          ? _value.cod
          // ignore: cast_nullable_to_non_nullable
          : cod as CodCollectionRequest?,
    );
  }
}

extension $DeliverRequestCopyWith on DeliverRequest {
  /// Returns a callable class that can be used as follows: `instanceOfDeliverRequest.copyWith(...)` or like so:`instanceOfDeliverRequest.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$DeliverRequestCWProxy get copyWith => _$DeliverRequestCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

DeliverRequest _$DeliverRequestFromJson(Map<String, dynamic> json) =>
    $checkedCreate('DeliverRequest', json, ($checkedConvert) {
      $checkKeys(json, requiredKeys: const ['otp']);
      final val = DeliverRequest(
        otp: $checkedConvert('otp', (v) => v as String),
        cod: $checkedConvert(
          'cod',
          (v) => v == null
              ? null
              : CodCollectionRequest.fromJson(v as Map<String, dynamic>),
        ),
      );
      return val;
    });

Map<String, dynamic> _$DeliverRequestToJson(DeliverRequest instance) =>
    <String, dynamic>{'otp': instance.otp, 'cod': ?instance.cod?.toJson()};
