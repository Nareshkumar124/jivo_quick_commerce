// ignore_for_file: type=lint, unused_import, duplicate_ignore
//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:json_annotation/json_annotation.dart';

/// * `COD_COLLECTED` - Cash collected * `DEPOSIT` - Deposited at the store * `ADJUSTMENT` - Adjustment
enum CashEntryTypeEnum {
  @JsonValue(r'COD_COLLECTED')
  COD_COLLECTED(r'COD_COLLECTED'),
  @JsonValue(r'DEPOSIT')
  DEPOSIT(r'DEPOSIT'),
  @JsonValue(r'ADJUSTMENT')
  ADJUSTMENT(r'ADJUSTMENT'),
  @JsonValue(r'unknown_default_open_api')
  unknownDefaultOpenApi(r'unknown_default_open_api');

  const CashEntryTypeEnum(this.value);

  final String value;

  @override
  String toString() => value;
}
