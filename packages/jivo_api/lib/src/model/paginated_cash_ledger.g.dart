// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'paginated_cash_ledger.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$PaginatedCashLedgerCWProxy {
  PaginatedCashLedger count(int count);

  PaginatedCashLedger next(String? next);

  PaginatedCashLedger previous(String? previous);

  PaginatedCashLedger results(List<CashLedgerEntry> results);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `PaginatedCashLedger(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// PaginatedCashLedger(...).copyWith(id: 12, name: "My name")
  /// ````
  PaginatedCashLedger call({
    int count,
    String? next,
    String? previous,
    List<CashLedgerEntry> results,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfPaginatedCashLedger.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfPaginatedCashLedger.copyWith.fieldName(...)`
class _$PaginatedCashLedgerCWProxyImpl implements _$PaginatedCashLedgerCWProxy {
  const _$PaginatedCashLedgerCWProxyImpl(this._value);

  final PaginatedCashLedger _value;

  @override
  PaginatedCashLedger count(int count) => this(count: count);

  @override
  PaginatedCashLedger next(String? next) => this(next: next);

  @override
  PaginatedCashLedger previous(String? previous) => this(previous: previous);

  @override
  PaginatedCashLedger results(List<CashLedgerEntry> results) =>
      this(results: results);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `PaginatedCashLedger(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// PaginatedCashLedger(...).copyWith(id: 12, name: "My name")
  /// ````
  PaginatedCashLedger call({
    Object? count = const $CopyWithPlaceholder(),
    Object? next = const $CopyWithPlaceholder(),
    Object? previous = const $CopyWithPlaceholder(),
    Object? results = const $CopyWithPlaceholder(),
  }) {
    return PaginatedCashLedger(
      count: count == const $CopyWithPlaceholder()
          ? _value.count
          // ignore: cast_nullable_to_non_nullable
          : count as int,
      next: next == const $CopyWithPlaceholder()
          ? _value.next
          // ignore: cast_nullable_to_non_nullable
          : next as String?,
      previous: previous == const $CopyWithPlaceholder()
          ? _value.previous
          // ignore: cast_nullable_to_non_nullable
          : previous as String?,
      results: results == const $CopyWithPlaceholder()
          ? _value.results
          // ignore: cast_nullable_to_non_nullable
          : results as List<CashLedgerEntry>,
    );
  }
}

extension $PaginatedCashLedgerCopyWith on PaginatedCashLedger {
  /// Returns a callable class that can be used as follows: `instanceOfPaginatedCashLedger.copyWith(...)` or like so:`instanceOfPaginatedCashLedger.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$PaginatedCashLedgerCWProxy get copyWith =>
      _$PaginatedCashLedgerCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PaginatedCashLedger _$PaginatedCashLedgerFromJson(Map<String, dynamic> json) =>
    $checkedCreate('PaginatedCashLedger', json, ($checkedConvert) {
      $checkKeys(
        json,
        requiredKeys: const ['count', 'next', 'previous', 'results'],
      );
      final val = PaginatedCashLedger(
        count: $checkedConvert('count', (v) => (v as num).toInt()),
        next: $checkedConvert('next', (v) => v as String?),
        previous: $checkedConvert('previous', (v) => v as String?),
        results: $checkedConvert(
          'results',
          (v) => (v as List<dynamic>)
              .map((e) => CashLedgerEntry.fromJson(e as Map<String, dynamic>))
              .toList(),
        ),
      );
      return val;
    });

Map<String, dynamic> _$PaginatedCashLedgerToJson(
  PaginatedCashLedger instance,
) => <String, dynamic>{
  'count': instance.count,
  'next': instance.next,
  'previous': instance.previous,
  'results': instance.results.map((e) => e.toJson()).toList(),
};
