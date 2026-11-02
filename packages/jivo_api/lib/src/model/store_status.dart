// ignore_for_file: type=lint, unused_import, duplicate_ignore
//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'store_status.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class StoreStatus {
  /// Returns a new [StoreStatus] instance.
  StoreStatus({
    required this.id,

    required this.name,

    required this.isOpen,

    required this.opensAt,
  });

  /// Send it as the `X-Store-Id` header on every catalog (and, from P3, cart) call.
  @JsonKey(name: r'id', required: true, includeIfNull: false)
  final int id;

  /// Display name, e.g. \"Jivo Sector 14, Gurugram\".
  @JsonKey(name: r'name', required: true, includeIfNull: false)
  final String name;

  /// True when the store is inside its opening hours and accepting orders. When false, browsing still works but checkout is disabled: show the store-closed banner.
  @JsonKey(name: r'is_open', required: true, includeIfNull: false)
  final bool isOpen;

  /// UTC time of the next opening (show it in IST, e.g. 'Opens at 7:00 AM' or 'Opens tomorrow at 7:00 AM'). Null when the store is open, and null when it is temporarily not accepting orders with no known reopening time.
  @JsonKey(name: r'opens_at', required: true, includeIfNull: true)
  final DateTime? opensAt;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StoreStatus &&
          other.id == id &&
          other.name == name &&
          other.isOpen == isOpen &&
          other.opensAt == opensAt;

  @override
  int get hashCode =>
      id.hashCode +
      name.hashCode +
      isOpen.hashCode +
      (opensAt == null ? 0 : opensAt.hashCode);

  factory StoreStatus.fromJson(Map<String, dynamic> json) =>
      _$StoreStatusFromJson(json);

  Map<String, dynamic> toJson() => _$StoreStatusToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
