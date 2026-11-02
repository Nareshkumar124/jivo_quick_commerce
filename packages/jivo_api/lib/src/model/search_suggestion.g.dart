// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'search_suggestion.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$SearchSuggestionCWProxy {
  SearchSuggestion type(SearchSuggestionTypeEnum type);

  SearchSuggestion text(String text);

  SearchSuggestion query(String query);

  SearchSuggestion id(int? id);

  SearchSuggestion slug(String? slug);

  SearchSuggestion image(ImageSet? image);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `SearchSuggestion(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// SearchSuggestion(...).copyWith(id: 12, name: "My name")
  /// ````
  SearchSuggestion call({
    SearchSuggestionTypeEnum type,
    String text,
    String query,
    int? id,
    String? slug,
    ImageSet? image,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfSearchSuggestion.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfSearchSuggestion.copyWith.fieldName(...)`
class _$SearchSuggestionCWProxyImpl implements _$SearchSuggestionCWProxy {
  const _$SearchSuggestionCWProxyImpl(this._value);

  final SearchSuggestion _value;

  @override
  SearchSuggestion type(SearchSuggestionTypeEnum type) => this(type: type);

  @override
  SearchSuggestion text(String text) => this(text: text);

  @override
  SearchSuggestion query(String query) => this(query: query);

  @override
  SearchSuggestion id(int? id) => this(id: id);

  @override
  SearchSuggestion slug(String? slug) => this(slug: slug);

  @override
  SearchSuggestion image(ImageSet? image) => this(image: image);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `SearchSuggestion(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// SearchSuggestion(...).copyWith(id: 12, name: "My name")
  /// ````
  SearchSuggestion call({
    Object? type = const $CopyWithPlaceholder(),
    Object? text = const $CopyWithPlaceholder(),
    Object? query = const $CopyWithPlaceholder(),
    Object? id = const $CopyWithPlaceholder(),
    Object? slug = const $CopyWithPlaceholder(),
    Object? image = const $CopyWithPlaceholder(),
  }) {
    return SearchSuggestion(
      type: type == const $CopyWithPlaceholder()
          ? _value.type
          // ignore: cast_nullable_to_non_nullable
          : type as SearchSuggestionTypeEnum,
      text: text == const $CopyWithPlaceholder()
          ? _value.text
          // ignore: cast_nullable_to_non_nullable
          : text as String,
      query: query == const $CopyWithPlaceholder()
          ? _value.query
          // ignore: cast_nullable_to_non_nullable
          : query as String,
      id: id == const $CopyWithPlaceholder()
          ? _value.id
          // ignore: cast_nullable_to_non_nullable
          : id as int?,
      slug: slug == const $CopyWithPlaceholder()
          ? _value.slug
          // ignore: cast_nullable_to_non_nullable
          : slug as String?,
      image: image == const $CopyWithPlaceholder()
          ? _value.image
          // ignore: cast_nullable_to_non_nullable
          : image as ImageSet?,
    );
  }
}

extension $SearchSuggestionCopyWith on SearchSuggestion {
  /// Returns a callable class that can be used as follows: `instanceOfSearchSuggestion.copyWith(...)` or like so:`instanceOfSearchSuggestion.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$SearchSuggestionCWProxy get copyWith => _$SearchSuggestionCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

SearchSuggestion _$SearchSuggestionFromJson(Map<String, dynamic> json) =>
    $checkedCreate('SearchSuggestion', json, ($checkedConvert) {
      $checkKeys(
        json,
        requiredKeys: const ['type', 'text', 'query', 'id', 'slug', 'image'],
      );
      final val = SearchSuggestion(
        type: $checkedConvert(
          'type',
          (v) => $enumDecode(
            _$SearchSuggestionTypeEnumEnumMap,
            v,
            unknownValue: SearchSuggestionTypeEnum.unknownDefaultOpenApi,
          ),
        ),
        text: $checkedConvert('text', (v) => v as String),
        query: $checkedConvert('query', (v) => v as String),
        id: $checkedConvert('id', (v) => (v as num?)?.toInt()),
        slug: $checkedConvert('slug', (v) => v as String?),
        image: $checkedConvert(
          'image',
          (v) =>
              v == null ? null : ImageSet.fromJson(v as Map<String, dynamic>),
        ),
      );
      return val;
    });

Map<String, dynamic> _$SearchSuggestionToJson(SearchSuggestion instance) =>
    <String, dynamic>{
      'type': _$SearchSuggestionTypeEnumEnumMap[instance.type]!,
      'text': instance.text,
      'query': instance.query,
      'id': instance.id,
      'slug': instance.slug,
      'image': instance.image?.toJson(),
    };

const _$SearchSuggestionTypeEnumEnumMap = {
  SearchSuggestionTypeEnum.product: 'product',
  SearchSuggestionTypeEnum.category: 'category',
  SearchSuggestionTypeEnum.keyword: 'keyword',
  SearchSuggestionTypeEnum.unknownDefaultOpenApi: 'unknown_default_open_api',
};
