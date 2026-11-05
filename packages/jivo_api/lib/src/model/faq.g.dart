// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'faq.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$FaqCWProxy {
  Faq id(int id);

  Faq category(String category);

  Faq question(String question);

  Faq answer(String answer);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `Faq(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// Faq(...).copyWith(id: 12, name: "My name")
  /// ````
  Faq call({int id, String category, String question, String answer});
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfFaq.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfFaq.copyWith.fieldName(...)`
class _$FaqCWProxyImpl implements _$FaqCWProxy {
  const _$FaqCWProxyImpl(this._value);

  final Faq _value;

  @override
  Faq id(int id) => this(id: id);

  @override
  Faq category(String category) => this(category: category);

  @override
  Faq question(String question) => this(question: question);

  @override
  Faq answer(String answer) => this(answer: answer);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `Faq(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// Faq(...).copyWith(id: 12, name: "My name")
  /// ````
  Faq call({
    Object? id = const $CopyWithPlaceholder(),
    Object? category = const $CopyWithPlaceholder(),
    Object? question = const $CopyWithPlaceholder(),
    Object? answer = const $CopyWithPlaceholder(),
  }) {
    return Faq(
      id: id == const $CopyWithPlaceholder()
          ? _value.id
          // ignore: cast_nullable_to_non_nullable
          : id as int,
      category: category == const $CopyWithPlaceholder()
          ? _value.category
          // ignore: cast_nullable_to_non_nullable
          : category as String,
      question: question == const $CopyWithPlaceholder()
          ? _value.question
          // ignore: cast_nullable_to_non_nullable
          : question as String,
      answer: answer == const $CopyWithPlaceholder()
          ? _value.answer
          // ignore: cast_nullable_to_non_nullable
          : answer as String,
    );
  }
}

extension $FaqCopyWith on Faq {
  /// Returns a callable class that can be used as follows: `instanceOfFaq.copyWith(...)` or like so:`instanceOfFaq.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$FaqCWProxy get copyWith => _$FaqCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Faq _$FaqFromJson(Map<String, dynamic> json) =>
    $checkedCreate('Faq', json, ($checkedConvert) {
      $checkKeys(
        json,
        requiredKeys: const ['id', 'category', 'question', 'answer'],
      );
      final val = Faq(
        id: $checkedConvert('id', (v) => (v as num).toInt()),
        category: $checkedConvert('category', (v) => v as String),
        question: $checkedConvert('question', (v) => v as String),
        answer: $checkedConvert('answer', (v) => v as String),
      );
      return val;
    });

Map<String, dynamic> _$FaqToJson(Faq instance) => <String, dynamic>{
  'id': instance.id,
  'category': instance.category,
  'question': instance.question,
  'answer': instance.answer,
};
