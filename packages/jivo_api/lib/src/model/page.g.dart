// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'page.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$PageCWProxy {
  Page slug(String slug);

  Page title(String title);

  Page html(String html);

  Page updatedAt(DateTime updatedAt);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `Page(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// Page(...).copyWith(id: 12, name: "My name")
  /// ````
  Page call({String slug, String title, String html, DateTime updatedAt});
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfPage.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfPage.copyWith.fieldName(...)`
class _$PageCWProxyImpl implements _$PageCWProxy {
  const _$PageCWProxyImpl(this._value);

  final Page _value;

  @override
  Page slug(String slug) => this(slug: slug);

  @override
  Page title(String title) => this(title: title);

  @override
  Page html(String html) => this(html: html);

  @override
  Page updatedAt(DateTime updatedAt) => this(updatedAt: updatedAt);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `Page(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// Page(...).copyWith(id: 12, name: "My name")
  /// ````
  Page call({
    Object? slug = const $CopyWithPlaceholder(),
    Object? title = const $CopyWithPlaceholder(),
    Object? html = const $CopyWithPlaceholder(),
    Object? updatedAt = const $CopyWithPlaceholder(),
  }) {
    return Page(
      slug: slug == const $CopyWithPlaceholder()
          ? _value.slug
          // ignore: cast_nullable_to_non_nullable
          : slug as String,
      title: title == const $CopyWithPlaceholder()
          ? _value.title
          // ignore: cast_nullable_to_non_nullable
          : title as String,
      html: html == const $CopyWithPlaceholder()
          ? _value.html
          // ignore: cast_nullable_to_non_nullable
          : html as String,
      updatedAt: updatedAt == const $CopyWithPlaceholder()
          ? _value.updatedAt
          // ignore: cast_nullable_to_non_nullable
          : updatedAt as DateTime,
    );
  }
}

extension $PageCopyWith on Page {
  /// Returns a callable class that can be used as follows: `instanceOfPage.copyWith(...)` or like so:`instanceOfPage.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$PageCWProxy get copyWith => _$PageCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Page _$PageFromJson(Map<String, dynamic> json) => $checkedCreate('Page', json, (
  $checkedConvert,
) {
  $checkKeys(json, requiredKeys: const ['slug', 'title', 'html', 'updated_at']);
  final val = Page(
    slug: $checkedConvert('slug', (v) => v as String),
    title: $checkedConvert('title', (v) => v as String),
    html: $checkedConvert('html', (v) => v as String),
    updatedAt: $checkedConvert(
      'updated_at',
      (v) => DateTime.parse(v as String),
    ),
  );
  return val;
}, fieldKeyMap: const {'updatedAt': 'updated_at'});

Map<String, dynamic> _$PageToJson(Page instance) => <String, dynamic>{
  'slug': instance.slug,
  'title': instance.title,
  'html': instance.html,
  'updated_at': instance.updatedAt.toIso8601String(),
};
