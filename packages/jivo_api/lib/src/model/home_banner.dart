// ignore_for_file: type=lint, unused_import, duplicate_ignore
//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:jivo_api/src/model/banner_link_type_enum.dart';
import 'package:jivo_api/src/model/image_set.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'home_banner.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class HomeBanner {
  /// Returns a new [HomeBanner] instance.
  HomeBanner({
    required this.id,

    required this.title,

    required this.image,

    required this.linkType,

    required this.linkValue,
  });

  @JsonKey(name: r'id', required: true, includeIfNull: false)
  final int id;

  /// Accessibility label / analytics name.
  @JsonKey(name: r'title', required: true, includeIfNull: false)
  final String title;

  /// Wide banner image (about 2.25:1).
  @JsonKey(name: r'image', required: true, includeIfNull: false)
  final ImageSet image;

  @JsonKey(
    name: r'link_type',
    required: true,
    includeIfNull: false,
    unknownEnumValue: BannerLinkTypeEnum.unknownDefaultOpenApi,
  )
  final BannerLinkTypeEnum linkType;

  /// category/collection/product: the target's slug. url: an absolute https URL. none: \"\". Ignore a banner whose target no longer opens (404).
  @JsonKey(name: r'link_value', required: true, includeIfNull: false)
  final String linkValue;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HomeBanner &&
          other.id == id &&
          other.title == title &&
          other.image == image &&
          other.linkType == linkType &&
          other.linkValue == linkValue;

  @override
  int get hashCode =>
      id.hashCode +
      title.hashCode +
      image.hashCode +
      linkType.hashCode +
      linkValue.hashCode;

  factory HomeBanner.fromJson(Map<String, dynamic> json) =>
      _$HomeBannerFromJson(json);

  Map<String, dynamic> toJson() => _$HomeBannerToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
