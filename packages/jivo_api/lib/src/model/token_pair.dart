// ignore_for_file: type=lint, unused_import, duplicate_ignore
//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'token_pair.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class TokenPair {
  /// Returns a new [TokenPair] instance.
  TokenPair({required this.access, required this.refresh});

  /// New access token (15 minutes).
  @JsonKey(name: r'access', required: true, includeIfNull: false)
  final String access;

  /// New refresh token (30 days). Replace the stored one; the old one is revoked.
  @JsonKey(name: r'refresh', required: true, includeIfNull: false)
  final String refresh;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TokenPair && other.access == access && other.refresh == refresh;

  @override
  int get hashCode => access.hashCode + refresh.hashCode;

  factory TokenPair.fromJson(Map<String, dynamic> json) =>
      _$TokenPairFromJson(json);

  Map<String, dynamic> toJson() => _$TokenPairToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
