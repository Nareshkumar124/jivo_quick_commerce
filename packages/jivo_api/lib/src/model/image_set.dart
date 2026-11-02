// ignore_for_file: type=lint, unused_import, duplicate_ignore
//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'image_set.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class ImageSet {
  /// Returns a new [ImageSet] instance.
  ImageSet({
    required this.thumbnail,

    required this.medium,

    required this.large,

    required this.altText,
  });

  /// About 256 px wide: cart lines, suggestions.
  @JsonKey(name: r'thumbnail', required: true, includeIfNull: false)
  final String thumbnail;

  /// About 512 px wide: product tiles, category grid.
  @JsonKey(name: r'medium', required: true, includeIfNull: false)
  final String medium;

  /// About 1024 px wide: detail gallery and zoom, banners.
  @JsonKey(name: r'large', required: true, includeIfNull: false)
  final String large;

  /// Accessibility label (may be empty).
  @JsonKey(name: r'alt_text', required: true, includeIfNull: false)
  final String altText;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ImageSet &&
          other.thumbnail == thumbnail &&
          other.medium == medium &&
          other.large == large &&
          other.altText == altText;

  @override
  int get hashCode =>
      thumbnail.hashCode + medium.hashCode + large.hashCode + altText.hashCode;

  factory ImageSet.fromJson(Map<String, dynamic> json) =>
      _$ImageSetFromJson(json);

  Map<String, dynamic> toJson() => _$ImageSetToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
