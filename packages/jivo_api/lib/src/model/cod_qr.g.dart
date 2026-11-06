// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'cod_qr.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$CodQrCWProxy {
  CodQr qrId(String qrId);

  CodQr imageUrl(String imageUrl);

  CodQr amount(String amount);

  CodQr status(CodQrStatusEnum status);

  CodQr expiresAt(DateTime expiresAt);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `CodQr(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// CodQr(...).copyWith(id: 12, name: "My name")
  /// ````
  CodQr call({
    String qrId,
    String imageUrl,
    String amount,
    CodQrStatusEnum status,
    DateTime expiresAt,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfCodQr.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfCodQr.copyWith.fieldName(...)`
class _$CodQrCWProxyImpl implements _$CodQrCWProxy {
  const _$CodQrCWProxyImpl(this._value);

  final CodQr _value;

  @override
  CodQr qrId(String qrId) => this(qrId: qrId);

  @override
  CodQr imageUrl(String imageUrl) => this(imageUrl: imageUrl);

  @override
  CodQr amount(String amount) => this(amount: amount);

  @override
  CodQr status(CodQrStatusEnum status) => this(status: status);

  @override
  CodQr expiresAt(DateTime expiresAt) => this(expiresAt: expiresAt);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `CodQr(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// CodQr(...).copyWith(id: 12, name: "My name")
  /// ````
  CodQr call({
    Object? qrId = const $CopyWithPlaceholder(),
    Object? imageUrl = const $CopyWithPlaceholder(),
    Object? amount = const $CopyWithPlaceholder(),
    Object? status = const $CopyWithPlaceholder(),
    Object? expiresAt = const $CopyWithPlaceholder(),
  }) {
    return CodQr(
      qrId: qrId == const $CopyWithPlaceholder()
          ? _value.qrId
          // ignore: cast_nullable_to_non_nullable
          : qrId as String,
      imageUrl: imageUrl == const $CopyWithPlaceholder()
          ? _value.imageUrl
          // ignore: cast_nullable_to_non_nullable
          : imageUrl as String,
      amount: amount == const $CopyWithPlaceholder()
          ? _value.amount
          // ignore: cast_nullable_to_non_nullable
          : amount as String,
      status: status == const $CopyWithPlaceholder()
          ? _value.status
          // ignore: cast_nullable_to_non_nullable
          : status as CodQrStatusEnum,
      expiresAt: expiresAt == const $CopyWithPlaceholder()
          ? _value.expiresAt
          // ignore: cast_nullable_to_non_nullable
          : expiresAt as DateTime,
    );
  }
}

extension $CodQrCopyWith on CodQr {
  /// Returns a callable class that can be used as follows: `instanceOfCodQr.copyWith(...)` or like so:`instanceOfCodQr.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$CodQrCWProxy get copyWith => _$CodQrCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CodQr _$CodQrFromJson(Map<String, dynamic> json) => $checkedCreate(
  'CodQr',
  json,
  ($checkedConvert) {
    $checkKeys(
      json,
      requiredKeys: const [
        'qr_id',
        'image_url',
        'amount',
        'status',
        'expires_at',
      ],
    );
    final val = CodQr(
      qrId: $checkedConvert('qr_id', (v) => v as String),
      imageUrl: $checkedConvert('image_url', (v) => v as String),
      amount: $checkedConvert('amount', (v) => v as String),
      status: $checkedConvert(
        'status',
        (v) => $enumDecode(
          _$CodQrStatusEnumEnumMap,
          v,
          unknownValue: CodQrStatusEnum.unknownDefaultOpenApi,
        ),
      ),
      expiresAt: $checkedConvert(
        'expires_at',
        (v) => DateTime.parse(v as String),
      ),
    );
    return val;
  },
  fieldKeyMap: const {
    'qrId': 'qr_id',
    'imageUrl': 'image_url',
    'expiresAt': 'expires_at',
  },
);

Map<String, dynamic> _$CodQrToJson(CodQr instance) => <String, dynamic>{
  'qr_id': instance.qrId,
  'image_url': instance.imageUrl,
  'amount': instance.amount,
  'status': _$CodQrStatusEnumEnumMap[instance.status]!,
  'expires_at': instance.expiresAt.toIso8601String(),
};

const _$CodQrStatusEnumEnumMap = {
  CodQrStatusEnum.PENDING: 'PENDING',
  CodQrStatusEnum.PAID: 'PAID',
  CodQrStatusEnum.EXPIRED: 'EXPIRED',
  CodQrStatusEnum.CANCELLED: 'CANCELLED',
  CodQrStatusEnum.unknownDefaultOpenApi: 'unknown_default_open_api',
};
