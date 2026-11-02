// ignore_for_file: type=lint, unused_import, duplicate_ignore
//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'policy_urls.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class PolicyUrls {
  /// Returns a new [PolicyUrls] instance.
  PolicyUrls({
    required this.terms,

    required this.privacy,

    required this.refund,
  });

  @JsonKey(name: r'terms', required: true, includeIfNull: false)
  final String terms;

  @JsonKey(name: r'privacy', required: true, includeIfNull: false)
  final String privacy;

  @JsonKey(name: r'refund', required: true, includeIfNull: false)
  final String refund;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PolicyUrls &&
          other.terms == terms &&
          other.privacy == privacy &&
          other.refund == refund;

  @override
  int get hashCode => terms.hashCode + privacy.hashCode + refund.hashCode;

  factory PolicyUrls.fromJson(Map<String, dynamic> json) =>
      _$PolicyUrlsFromJson(json);

  Map<String, dynamic> toJson() => _$PolicyUrlsToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
