// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'order_invoice.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$OrderInvoiceCWProxy {
  OrderInvoice invoiceNumber(String invoiceNumber);

  OrderInvoice issuedAt(DateTime issuedAt);

  OrderInvoice url(String url);

  OrderInvoice expiresAt(DateTime expiresAt);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `OrderInvoice(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// OrderInvoice(...).copyWith(id: 12, name: "My name")
  /// ````
  OrderInvoice call({
    String invoiceNumber,
    DateTime issuedAt,
    String url,
    DateTime expiresAt,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfOrderInvoice.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfOrderInvoice.copyWith.fieldName(...)`
class _$OrderInvoiceCWProxyImpl implements _$OrderInvoiceCWProxy {
  const _$OrderInvoiceCWProxyImpl(this._value);

  final OrderInvoice _value;

  @override
  OrderInvoice invoiceNumber(String invoiceNumber) =>
      this(invoiceNumber: invoiceNumber);

  @override
  OrderInvoice issuedAt(DateTime issuedAt) => this(issuedAt: issuedAt);

  @override
  OrderInvoice url(String url) => this(url: url);

  @override
  OrderInvoice expiresAt(DateTime expiresAt) => this(expiresAt: expiresAt);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `OrderInvoice(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// OrderInvoice(...).copyWith(id: 12, name: "My name")
  /// ````
  OrderInvoice call({
    Object? invoiceNumber = const $CopyWithPlaceholder(),
    Object? issuedAt = const $CopyWithPlaceholder(),
    Object? url = const $CopyWithPlaceholder(),
    Object? expiresAt = const $CopyWithPlaceholder(),
  }) {
    return OrderInvoice(
      invoiceNumber: invoiceNumber == const $CopyWithPlaceholder()
          ? _value.invoiceNumber
          // ignore: cast_nullable_to_non_nullable
          : invoiceNumber as String,
      issuedAt: issuedAt == const $CopyWithPlaceholder()
          ? _value.issuedAt
          // ignore: cast_nullable_to_non_nullable
          : issuedAt as DateTime,
      url: url == const $CopyWithPlaceholder()
          ? _value.url
          // ignore: cast_nullable_to_non_nullable
          : url as String,
      expiresAt: expiresAt == const $CopyWithPlaceholder()
          ? _value.expiresAt
          // ignore: cast_nullable_to_non_nullable
          : expiresAt as DateTime,
    );
  }
}

extension $OrderInvoiceCopyWith on OrderInvoice {
  /// Returns a callable class that can be used as follows: `instanceOfOrderInvoice.copyWith(...)` or like so:`instanceOfOrderInvoice.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$OrderInvoiceCWProxy get copyWith => _$OrderInvoiceCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

OrderInvoice _$OrderInvoiceFromJson(Map<String, dynamic> json) =>
    $checkedCreate(
      'OrderInvoice',
      json,
      ($checkedConvert) {
        $checkKeys(
          json,
          requiredKeys: const [
            'invoice_number',
            'issued_at',
            'url',
            'expires_at',
          ],
        );
        final val = OrderInvoice(
          invoiceNumber: $checkedConvert('invoice_number', (v) => v as String),
          issuedAt: $checkedConvert(
            'issued_at',
            (v) => DateTime.parse(v as String),
          ),
          url: $checkedConvert('url', (v) => v as String),
          expiresAt: $checkedConvert(
            'expires_at',
            (v) => DateTime.parse(v as String),
          ),
        );
        return val;
      },
      fieldKeyMap: const {
        'invoiceNumber': 'invoice_number',
        'issuedAt': 'issued_at',
        'expiresAt': 'expires_at',
      },
    );

Map<String, dynamic> _$OrderInvoiceToJson(OrderInvoice instance) =>
    <String, dynamic>{
      'invoice_number': instance.invoiceNumber,
      'issued_at': instance.issuedAt.toIso8601String(),
      'url': instance.url,
      'expires_at': instance.expiresAt.toIso8601String(),
    };
