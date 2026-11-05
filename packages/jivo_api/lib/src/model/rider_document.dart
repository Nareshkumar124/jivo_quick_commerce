// ignore_for_file: type=lint, unused_import, duplicate_ignore
//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:jivo_api/src/model/rider_document_status_enum.dart';
import 'package:jivo_api/src/model/rider_document_type_enum.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'rider_document.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class RiderDocument {
  /// Returns a new [RiderDocument] instance.
  RiderDocument({
    required this.docType,

    required this.status,

    required this.docNumberMasked,

    required this.reviewNote,

    required this.uploadedAt,

    required this.reviewedAt,
  });

  @JsonKey(
    name: r'doc_type',
    required: true,
    includeIfNull: false,
    unknownEnumValue: RiderDocumentTypeEnum.unknownDefaultOpenApi,
  )
  final RiderDocumentTypeEnum docType;

  /// PENDING (in review), APPROVED (locked), REJECTED (upload a new copy).  * `PENDING` - In review * `APPROVED` - Approved * `REJECTED` - Rejected: upload a new copy
  @JsonKey(
    name: r'status',
    required: true,
    includeIfNull: false,
    unknownEnumValue: RiderDocumentStatusEnum.unknownDefaultOpenApi,
  )
  final RiderDocumentStatusEnum status;

  /// Masked number (\"XXXX XXXX 1234\" for Aadhaar, \"ABXXXXXX4F\" for PAN, the last 4 characters for DL/RC); null for the photo and the Aadhaar back.
  @JsonKey(name: r'doc_number_masked', required: true, includeIfNull: true)
  final String? docNumberMasked;

  /// Why ops rejected it (\"\" otherwise). Show it with REJECTED.
  @JsonKey(name: r'review_note', required: true, includeIfNull: false)
  final String reviewNote;

  @JsonKey(name: r'uploaded_at', required: true, includeIfNull: false)
  final DateTime uploadedAt;

  @JsonKey(name: r'reviewed_at', required: true, includeIfNull: true)
  final DateTime? reviewedAt;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RiderDocument &&
          other.docType == docType &&
          other.status == status &&
          other.docNumberMasked == docNumberMasked &&
          other.reviewNote == reviewNote &&
          other.uploadedAt == uploadedAt &&
          other.reviewedAt == reviewedAt;

  @override
  int get hashCode =>
      docType.hashCode +
      status.hashCode +
      (docNumberMasked == null ? 0 : docNumberMasked.hashCode) +
      reviewNote.hashCode +
      uploadedAt.hashCode +
      (reviewedAt == null ? 0 : reviewedAt.hashCode);

  factory RiderDocument.fromJson(Map<String, dynamic> json) =>
      _$RiderDocumentFromJson(json);

  Map<String, dynamic> toJson() => _$RiderDocumentToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
