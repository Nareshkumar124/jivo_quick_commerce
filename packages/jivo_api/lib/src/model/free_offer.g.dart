// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'free_offer.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$FreeOfferCWProxy {
  FreeOffer every(int every);

  FreeOffer paidUnits(int paidUnits);

  FreeOffer freeUnits(int freeUnits);

  FreeOffer unitsToNextFree(int unitsToNextFree);

  FreeOffer message(String message);

  FreeOffer notice(String? notice);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `FreeOffer(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// FreeOffer(...).copyWith(id: 12, name: "My name")
  /// ````
  FreeOffer call({
    int every,
    int paidUnits,
    int freeUnits,
    int unitsToNextFree,
    String message,
    String? notice,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfFreeOffer.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfFreeOffer.copyWith.fieldName(...)`
class _$FreeOfferCWProxyImpl implements _$FreeOfferCWProxy {
  const _$FreeOfferCWProxyImpl(this._value);

  final FreeOffer _value;

  @override
  FreeOffer every(int every) => this(every: every);

  @override
  FreeOffer paidUnits(int paidUnits) => this(paidUnits: paidUnits);

  @override
  FreeOffer freeUnits(int freeUnits) => this(freeUnits: freeUnits);

  @override
  FreeOffer unitsToNextFree(int unitsToNextFree) =>
      this(unitsToNextFree: unitsToNextFree);

  @override
  FreeOffer message(String message) => this(message: message);

  @override
  FreeOffer notice(String? notice) => this(notice: notice);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `FreeOffer(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// FreeOffer(...).copyWith(id: 12, name: "My name")
  /// ````
  FreeOffer call({
    Object? every = const $CopyWithPlaceholder(),
    Object? paidUnits = const $CopyWithPlaceholder(),
    Object? freeUnits = const $CopyWithPlaceholder(),
    Object? unitsToNextFree = const $CopyWithPlaceholder(),
    Object? message = const $CopyWithPlaceholder(),
    Object? notice = const $CopyWithPlaceholder(),
  }) {
    return FreeOffer(
      every: every == const $CopyWithPlaceholder()
          ? _value.every
          // ignore: cast_nullable_to_non_nullable
          : every as int,
      paidUnits: paidUnits == const $CopyWithPlaceholder()
          ? _value.paidUnits
          // ignore: cast_nullable_to_non_nullable
          : paidUnits as int,
      freeUnits: freeUnits == const $CopyWithPlaceholder()
          ? _value.freeUnits
          // ignore: cast_nullable_to_non_nullable
          : freeUnits as int,
      unitsToNextFree: unitsToNextFree == const $CopyWithPlaceholder()
          ? _value.unitsToNextFree
          // ignore: cast_nullable_to_non_nullable
          : unitsToNextFree as int,
      message: message == const $CopyWithPlaceholder()
          ? _value.message
          // ignore: cast_nullable_to_non_nullable
          : message as String,
      notice: notice == const $CopyWithPlaceholder()
          ? _value.notice
          // ignore: cast_nullable_to_non_nullable
          : notice as String?,
    );
  }
}

extension $FreeOfferCopyWith on FreeOffer {
  /// Returns a callable class that can be used as follows: `instanceOfFreeOffer.copyWith(...)` or like so:`instanceOfFreeOffer.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$FreeOfferCWProxy get copyWith => _$FreeOfferCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

FreeOffer _$FreeOfferFromJson(Map<String, dynamic> json) => $checkedCreate(
  'FreeOffer',
  json,
  ($checkedConvert) {
    $checkKeys(
      json,
      requiredKeys: const [
        'every',
        'paid_units',
        'free_units',
        'units_to_next_free',
        'message',
        'notice',
      ],
    );
    final val = FreeOffer(
      every: $checkedConvert('every', (v) => (v as num).toInt()),
      paidUnits: $checkedConvert('paid_units', (v) => (v as num).toInt()),
      freeUnits: $checkedConvert('free_units', (v) => (v as num).toInt()),
      unitsToNextFree: $checkedConvert(
        'units_to_next_free',
        (v) => (v as num).toInt(),
      ),
      message: $checkedConvert('message', (v) => v as String),
      notice: $checkedConvert('notice', (v) => v as String?),
    );
    return val;
  },
  fieldKeyMap: const {
    'paidUnits': 'paid_units',
    'freeUnits': 'free_units',
    'unitsToNextFree': 'units_to_next_free',
  },
);

Map<String, dynamic> _$FreeOfferToJson(FreeOffer instance) => <String, dynamic>{
  'every': instance.every,
  'paid_units': instance.paidUnits,
  'free_units': instance.freeUnits,
  'units_to_next_free': instance.unitsToNextFree,
  'message': instance.message,
  'notice': instance.notice,
};
