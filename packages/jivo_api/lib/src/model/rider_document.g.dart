// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'rider_document.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$RiderDocumentCWProxy {
  RiderDocument docType(RiderDocumentTypeEnum docType);

  RiderDocument status(RiderDocumentStatusEnum status);

  RiderDocument docNumberMasked(String? docNumberMasked);

  RiderDocument reviewNote(String reviewNote);

  RiderDocument uploadedAt(DateTime uploadedAt);

  RiderDocument reviewedAt(DateTime? reviewedAt);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `RiderDocument(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// RiderDocument(...).copyWith(id: 12, name: "My name")
  /// ````
  RiderDocument call({
    RiderDocumentTypeEnum docType,
    RiderDocumentStatusEnum status,
    String? docNumberMasked,
    String reviewNote,
    DateTime uploadedAt,
    DateTime? reviewedAt,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfRiderDocument.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfRiderDocument.copyWith.fieldName(...)`
class _$RiderDocumentCWProxyImpl implements _$RiderDocumentCWProxy {
  const _$RiderDocumentCWProxyImpl(this._value);

  final RiderDocument _value;

  @override
  RiderDocument docType(RiderDocumentTypeEnum docType) =>
      this(docType: docType);

  @override
  RiderDocument status(RiderDocumentStatusEnum status) => this(status: status);

  @override
  RiderDocument docNumberMasked(String? docNumberMasked) =>
      this(docNumberMasked: docNumberMasked);

  @override
  RiderDocument reviewNote(String reviewNote) => this(reviewNote: reviewNote);

  @override
  RiderDocument uploadedAt(DateTime uploadedAt) => this(uploadedAt: uploadedAt);

  @override
  RiderDocument reviewedAt(DateTime? reviewedAt) =>
      this(reviewedAt: reviewedAt);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `RiderDocument(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// RiderDocument(...).copyWith(id: 12, name: "My name")
  /// ````
  RiderDocument call({
    Object? docType = const $CopyWithPlaceholder(),
    Object? status = const $CopyWithPlaceholder(),
    Object? docNumberMasked = const $CopyWithPlaceholder(),
    Object? reviewNote = const $CopyWithPlaceholder(),
    Object? uploadedAt = const $CopyWithPlaceholder(),
    Object? reviewedAt = const $CopyWithPlaceholder(),
  }) {
    return RiderDocument(
      docType: docType == const $CopyWithPlaceholder()
          ? _value.docType
          // ignore: cast_nullable_to_non_nullable
          : docType as RiderDocumentTypeEnum,
      status: status == const $CopyWithPlaceholder()
          ? _value.status
          // ignore: cast_nullable_to_non_nullable
          : status as RiderDocumentStatusEnum,
      docNumberMasked: docNumberMasked == const $CopyWithPlaceholder()
          ? _value.docNumberMasked
          // ignore: cast_nullable_to_non_nullable
          : docNumberMasked as String?,
      reviewNote: reviewNote == const $CopyWithPlaceholder()
          ? _value.reviewNote
          // ignore: cast_nullable_to_non_nullable
          : reviewNote as String,
      uploadedAt: uploadedAt == const $CopyWithPlaceholder()
          ? _value.uploadedAt
          // ignore: cast_nullable_to_non_nullable
          : uploadedAt as DateTime,
      reviewedAt: reviewedAt == const $CopyWithPlaceholder()
          ? _value.reviewedAt
          // ignore: cast_nullable_to_non_nullable
          : reviewedAt as DateTime?,
    );
  }
}

extension $RiderDocumentCopyWith on RiderDocument {
  /// Returns a callable class that can be used as follows: `instanceOfRiderDocument.copyWith(...)` or like so:`instanceOfRiderDocument.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$RiderDocumentCWProxy get copyWith => _$RiderDocumentCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

RiderDocument _$RiderDocumentFromJson(Map<String, dynamic> json) =>
    $checkedCreate(
      'RiderDocument',
      json,
      ($checkedConvert) {
        $checkKeys(
          json,
          requiredKeys: const [
            'doc_type',
            'status',
            'doc_number_masked',
            'review_note',
            'uploaded_at',
            'reviewed_at',
          ],
        );
        final val = RiderDocument(
          docType: $checkedConvert(
            'doc_type',
            (v) => $enumDecode(
              _$RiderDocumentTypeEnumEnumMap,
              v,
              unknownValue: RiderDocumentTypeEnum.unknownDefaultOpenApi,
            ),
          ),
          status: $checkedConvert(
            'status',
            (v) => $enumDecode(
              _$RiderDocumentStatusEnumEnumMap,
              v,
              unknownValue: RiderDocumentStatusEnum.unknownDefaultOpenApi,
            ),
          ),
          docNumberMasked: $checkedConvert(
            'doc_number_masked',
            (v) => v as String?,
          ),
          reviewNote: $checkedConvert('review_note', (v) => v as String),
          uploadedAt: $checkedConvert(
            'uploaded_at',
            (v) => DateTime.parse(v as String),
          ),
          reviewedAt: $checkedConvert(
            'reviewed_at',
            (v) => v == null ? null : DateTime.parse(v as String),
          ),
        );
        return val;
      },
      fieldKeyMap: const {
        'docType': 'doc_type',
        'docNumberMasked': 'doc_number_masked',
        'reviewNote': 'review_note',
        'uploadedAt': 'uploaded_at',
        'reviewedAt': 'reviewed_at',
      },
    );

Map<String, dynamic> _$RiderDocumentToJson(RiderDocument instance) =>
    <String, dynamic>{
      'doc_type': _$RiderDocumentTypeEnumEnumMap[instance.docType]!,
      'status': _$RiderDocumentStatusEnumEnumMap[instance.status]!,
      'doc_number_masked': instance.docNumberMasked,
      'review_note': instance.reviewNote,
      'uploaded_at': instance.uploadedAt.toIso8601String(),
      'reviewed_at': instance.reviewedAt?.toIso8601String(),
    };

const _$RiderDocumentTypeEnumEnumMap = {
  RiderDocumentTypeEnum.PHOTO: 'PHOTO',
  RiderDocumentTypeEnum.AADHAAR_FRONT: 'AADHAAR_FRONT',
  RiderDocumentTypeEnum.AADHAAR_BACK: 'AADHAAR_BACK',
  RiderDocumentTypeEnum.PAN: 'PAN',
  RiderDocumentTypeEnum.DL: 'DL',
  RiderDocumentTypeEnum.RC: 'RC',
  RiderDocumentTypeEnum.unknownDefaultOpenApi: 'unknown_default_open_api',
};

const _$RiderDocumentStatusEnumEnumMap = {
  RiderDocumentStatusEnum.PENDING: 'PENDING',
  RiderDocumentStatusEnum.APPROVED: 'APPROVED',
  RiderDocumentStatusEnum.REJECTED: 'REJECTED',
  RiderDocumentStatusEnum.unknownDefaultOpenApi: 'unknown_default_open_api',
};
