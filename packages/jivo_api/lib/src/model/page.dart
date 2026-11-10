// ignore_for_file: type=lint, unused_import, duplicate_ignore
//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'page.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class Page {
  /// Returns a new [Page] instance.
  Page({
    required this.slug,

    required this.title,

    required this.html,

    required this.updatedAt,
  });

  /// about, terms, privacy, refund-policy, rider-agreement or rider-location-disclosure.
  @JsonKey(name: r'slug', required: true, includeIfNull: false)
  final String slug;

  @JsonKey(name: r'title', required: true, includeIfNull: false)
  final String title;

  /// Sanitised HTML: h1-h6, p, br, ul/ol/li, blockquote, strong/em/b/i and <a href> with https:, mailto: or tel: only. No attributes other than href, no scripts, styles, images or relative links. Still render it with the app's own safe HTML parser.
  @JsonKey(name: r'html', required: true, includeIfNull: false)
  final String html;

  /// Last edit (UTC).
  @JsonKey(name: r'updated_at', required: true, includeIfNull: false)
  final DateTime updatedAt;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Page &&
          other.slug == slug &&
          other.title == title &&
          other.html == html &&
          other.updatedAt == updatedAt;

  @override
  int get hashCode =>
      slug.hashCode + title.hashCode + html.hashCode + updatedAt.hashCode;

  factory Page.fromJson(Map<String, dynamic> json) => _$PageFromJson(json);

  Map<String, dynamic> toJson() => _$PageToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
