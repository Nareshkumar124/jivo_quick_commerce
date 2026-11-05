// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'current_offer.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$CurrentOfferCWProxy {
  CurrentOffer offer(RiderOffer? offer);

  CurrentOffer serverTime(DateTime serverTime);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `CurrentOffer(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// CurrentOffer(...).copyWith(id: 12, name: "My name")
  /// ````
  CurrentOffer call({RiderOffer? offer, DateTime serverTime});
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfCurrentOffer.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfCurrentOffer.copyWith.fieldName(...)`
class _$CurrentOfferCWProxyImpl implements _$CurrentOfferCWProxy {
  const _$CurrentOfferCWProxyImpl(this._value);

  final CurrentOffer _value;

  @override
  CurrentOffer offer(RiderOffer? offer) => this(offer: offer);

  @override
  CurrentOffer serverTime(DateTime serverTime) => this(serverTime: serverTime);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `CurrentOffer(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// CurrentOffer(...).copyWith(id: 12, name: "My name")
  /// ````
  CurrentOffer call({
    Object? offer = const $CopyWithPlaceholder(),
    Object? serverTime = const $CopyWithPlaceholder(),
  }) {
    return CurrentOffer(
      offer: offer == const $CopyWithPlaceholder()
          ? _value.offer
          // ignore: cast_nullable_to_non_nullable
          : offer as RiderOffer?,
      serverTime: serverTime == const $CopyWithPlaceholder()
          ? _value.serverTime
          // ignore: cast_nullable_to_non_nullable
          : serverTime as DateTime,
    );
  }
}

extension $CurrentOfferCopyWith on CurrentOffer {
  /// Returns a callable class that can be used as follows: `instanceOfCurrentOffer.copyWith(...)` or like so:`instanceOfCurrentOffer.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$CurrentOfferCWProxy get copyWith => _$CurrentOfferCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CurrentOffer _$CurrentOfferFromJson(Map<String, dynamic> json) =>
    $checkedCreate('CurrentOffer', json, ($checkedConvert) {
      $checkKeys(json, requiredKeys: const ['offer', 'server_time']);
      final val = CurrentOffer(
        offer: $checkedConvert(
          'offer',
          (v) =>
              v == null ? null : RiderOffer.fromJson(v as Map<String, dynamic>),
        ),
        serverTime: $checkedConvert(
          'server_time',
          (v) => DateTime.parse(v as String),
        ),
      );
      return val;
    }, fieldKeyMap: const {'serverTime': 'server_time'});

Map<String, dynamic> _$CurrentOfferToJson(CurrentOffer instance) =>
    <String, dynamic>{
      'offer': instance.offer?.toJson(),
      'server_time': instance.serverTime.toIso8601String(),
    };
