// ignore_for_file: type=lint, unused_import, duplicate_ignore
//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'faq.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class Faq {
  /// Returns a new [Faq] instance.
  Faq({
    required this.id,

    required this.category,

    required this.question,

    required this.answer,
  });

  @JsonKey(name: r'id', required: true, includeIfNull: false)
  final int id;

  /// Group heading. Entries of one category are consecutive in the list.
  @JsonKey(name: r'category', required: true, includeIfNull: false)
  final String category;

  @JsonKey(name: r'question', required: true, includeIfNull: false)
  final String question;

  /// Plain text; show as text, never as HTML.
  @JsonKey(name: r'answer', required: true, includeIfNull: false)
  final String answer;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Faq &&
          other.id == id &&
          other.category == category &&
          other.question == question &&
          other.answer == answer;

  @override
  int get hashCode =>
      id.hashCode + category.hashCode + question.hashCode + answer.hashCode;

  factory Faq.fromJson(Map<String, dynamic> json) => _$FaqFromJson(json);

  Map<String, dynamic> toJson() => _$FaqToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
