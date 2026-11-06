// ignore_for_file: type=lint, unused_import, duplicate_ignore
//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:json_annotation/json_annotation.dart';

/// * `PHOTO` - Photo (selfie) * `AADHAAR_FRONT` - Aadhaar (front) * `AADHAAR_BACK` - Aadhaar (back) * `PAN` - PAN card * `DL` - Driving licence * `RC` - Vehicle RC
enum RiderDocumentTypeEnum {
  @JsonValue(r'PHOTO')
  PHOTO(r'PHOTO'),
  @JsonValue(r'AADHAAR_FRONT')
  AADHAAR_FRONT(r'AADHAAR_FRONT'),
  @JsonValue(r'AADHAAR_BACK')
  AADHAAR_BACK(r'AADHAAR_BACK'),
  @JsonValue(r'PAN')
  PAN(r'PAN'),
  @JsonValue(r'DL')
  DL(r'DL'),
  @JsonValue(r'RC')
  RC(r'RC'),
  @JsonValue(r'unknown_default_open_api')
  unknownDefaultOpenApi(r'unknown_default_open_api');

  const RiderDocumentTypeEnum(this.value);

  final String value;

  @override
  String toString() => value;
}
