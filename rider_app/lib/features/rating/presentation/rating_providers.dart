import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/env.dart';
import '../../../app/providers.dart';
import '../../../shared/paged_list_controller.dart';
import '../../../shared/paging.dart';
import '../data/api_rating_repository.dart';
import '../data/fake_rating_backend.dart';
import '../domain/rider_rating.dart';

/// The fake ratings (`FAKE_API` builds). Overridden in tests.
final fakeRatingBackendProvider = Provider<FakeRatingBackend>(
  (ref) => FakeRatingBackend(clock: ref.watch(clockProvider)),
);

/// The rider's ratings: `GET /rider/ratings/` in every flavor; the fake
/// only in the dev flavor with `FAKE_API` (DL-30, DL-32).
final ratingRepositoryProvider = Provider<RatingRepository>((ref) {
  if (ref.watch(appEnvProvider).useRiderFakes) {
    return ref.watch(fakeRatingBackendProvider);
  }
  return ApiRatingRepository(ref.watch(jivoApiProvider));
});

/// "My rating": the summary (header, from the latest page) and the recent
/// ratings, paged back by `before_id`.
final myRatingProvider =
    NotifierProvider.autoDispose<
      PagedListNotifier<RiderRating, RatingSummary>,
      PagedListState<RiderRating, RatingSummary>
    >(
      () => PagedListNotifier((ref, cursor) async {
        final summary = await ref
            .read(ratingRepositoryProvider)
            .fetch(beforeId: cursor);
        return (
          Page(items: summary.recent, nextPage: summary.nextBeforeId),
          summary,
        );
      }, keyOf: (rating) => rating.id),
    );
