// ignore_for_file: type=lint, unused_import, duplicate_ignore
//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:jivo_api/src/model/free_variant.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'free_offer.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class FreeOffer {
  /// Returns a new [FreeOffer] instance.
  FreeOffer({
    required this.every,

    required this.paidUnits,

    required this.freeUnits,

    required this.unitsToNextFree,

    required this.message,

    required this.notice,

    required this.freeVariant,
  });

  /// Paid cartons per free carton (e.g. 10).
  // minimum: 1
  @JsonKey(name: r'every', required: true, includeIfNull: false)
  final int every;

  /// Paid cartons counted now.
  // minimum: 0
  @JsonKey(name: r'paid_units', required: true, includeIfNull: false)
  final int paidUnits;

  /// Free cartons earned: `paid_units` // `every`. The ones the store can supply are in `free_lines` (VOLUME_OFFER); see `notice` when they cannot be supplied.
  // minimum: 0
  @JsonKey(name: r'free_units', required: true, includeIfNull: false)
  final int freeUnits;

  /// Paid cartons still to add for one more free carton.
  // minimum: 1
  @JsonKey(name: r'units_to_next_free', required: true, includeIfNull: false)
  final int unitsToNextFree;

  /// Ready-made nudge, e.g. \"Add 8 more cartons to get 1 more free\".
  @JsonKey(name: r'message', required: true, includeIfNull: false)
  final String message;

  /// Set when a free carton was earned but the store cannot supply it (the fixed free size has no stock, ADR 0003; or no size in the cart has the stock, ADR 0002): no free carton is given. Show it as a notice; it does not block checkout. Null otherwise.
  @JsonKey(name: r'notice', required: true, includeIfNull: true)
  final String? notice;

  /// ADR 0003: the store's fixed free size; every free carton (this offer and rewards) is this size, e.g. \"Jivo Water 1 L x 12\". Shown also before a free carton is earned. Null when the store has none: the free cartons are then the cheapest size in the cart (ADR 0002).
  @JsonKey(name: r'free_variant', required: true, includeIfNull: true)
  final FreeVariant? freeVariant;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FreeOffer &&
          other.every == every &&
          other.paidUnits == paidUnits &&
          other.freeUnits == freeUnits &&
          other.unitsToNextFree == unitsToNextFree &&
          other.message == message &&
          other.notice == notice &&
          other.freeVariant == freeVariant;

  @override
  int get hashCode =>
      every.hashCode +
      paidUnits.hashCode +
      freeUnits.hashCode +
      unitsToNextFree.hashCode +
      message.hashCode +
      (notice == null ? 0 : notice.hashCode) +
      (freeVariant == null ? 0 : freeVariant.hashCode);

  factory FreeOffer.fromJson(Map<String, dynamic> json) =>
      _$FreeOfferFromJson(json);

  Map<String, dynamic> toJson() => _$FreeOfferToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
