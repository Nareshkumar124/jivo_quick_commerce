import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/repositories.dart';
import '../domain/order_rating.dart';

/// The order's rating (null: not rated yet).
final orderRatingProvider = FutureProvider.autoDispose
    .family<OrderRating?, int>(
      (ref, orderId) => ref.watch(ratingRepositoryProvider).fetch(orderId),
    );

/// The rate-order form.
@immutable
class RatingFormState {
  const RatingFormState({
    this.orderStars = 0,
    this.riderStars,
    this.tags = const {},
    this.submitting = false,
    this.error,
  });

  /// 0 until the customer picks.
  final int orderStars;
  final int? riderStars;
  final Set<RatingTag> tags;
  final bool submitting;

  /// Why the last submit failed.
  final Object? error;

  /// Order stars are picked, and a rider tag comes with rider stars (the
  /// server refuses POLITE_RIDER / RUDE_RIDER without them).
  bool get canSubmit =>
      orderStars > 0 &&
      !submitting &&
      (riderStars != null || !tags.any((tag) => tag.needsRider));

  /// The tags the form offers now.
  List<RatingTag> get offeredTags =>
      RatingTag.forStars(orderStars, riderRated: riderStars != null);

  RatingFormState copyWith({
    int? orderStars,
    int? riderStars,
    Set<RatingTag>? tags,
    bool? submitting,
    Object? error,
    bool clearError = false,
  }) => RatingFormState(
    orderStars: orderStars ?? this.orderStars,
    riderStars: riderStars ?? this.riderStars,
    tags: tags ?? this.tags,
    submitting: submitting ?? this.submitting,
    error: clearError ? null : (error ?? this.error),
  );
}

/// Rates one delivered order (`03 §2.10`, P7).
class RatingFormController extends Notifier<RatingFormState> {
  RatingFormController(this.orderId);

  final int orderId;

  @override
  RatingFormState build() => const RatingFormState();

  /// Picks the order's stars. Tags that don't fit the new rating (a
  /// "late delivery" tag after switching to 5 stars) are dropped.
  void setOrderStars(int stars) {
    final offered = RatingTag.forStars(
      stars,
      riderRated: state.riderStars != null,
    ).toSet();
    state = state.copyWith(
      orderStars: stars,
      tags: state.tags.intersection(offered),
      clearError: true,
    );
  }

  void setRiderStars(int stars) =>
      state = state.copyWith(riderStars: stars, clearError: true);

  /// Toggles an offered tag (a rider tag only once the rider is rated).
  void toggleTag(RatingTag tag) {
    if (!state.offeredTags.contains(tag)) return;
    final tags = {...state.tags};
    if (!tags.remove(tag)) tags.add(tag);
    state = state.copyWith(tags: tags, clearError: true);
  }

  /// Sends the rating once. Returns it, or null on failure (kept in
  /// [RatingFormState.error]) or when nothing can be sent yet.
  Future<OrderRating?> submit(String comment) async {
    if (!state.canSubmit) return null;
    state = state.copyWith(submitting: true, clearError: true);
    try {
      final rating = await ref
          .read(ratingRepositoryProvider)
          .submit(
            orderId,
            OrderRatingInput(
              orderStars: state.orderStars,
              riderStars: state.riderStars,
              tags: state.tags,
              comment: comment.trim(),
            ),
          );
      if (!ref.mounted) return rating;
      ref.invalidate(orderRatingProvider(orderId));
      state = state.copyWith(submitting: false);
      return rating;
    } catch (error) {
      if (ref.mounted) {
        state = state.copyWith(submitting: false, error: error);
      }
      return null;
    }
  }
}

final ratingFormProvider = NotifierProvider.autoDispose
    .family<RatingFormController, RatingFormState, int>(
      RatingFormController.new,
    );
