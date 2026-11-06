import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../shared/paged_list_controller.dart';
import '../../../shared/paging.dart';
import '../../task/presentation/task_providers.dart';
import '../data/fake_rating_backend.dart';
import '../domain/rider_rating.dart';

/// The fake ratings (`FAKE_API` builds). Overridden in tests.
final fakeRatingBackendProvider = Provider<FakeRatingBackend>(
  (ref) => FakeRatingBackend(clock: ref.watch(clockProvider)),
);

/// The rider's ratings. TODO(api): only the fake until the backend's P7
/// ratings API merges; builds on the real API get
/// [UnavailableRatingRepository] (the screen says "not available yet" and
/// the profile keeps showing `rating_avg` from `GET /rider/me/`).
final ratingRepositoryProvider = Provider<RatingRepository>((ref) {
  if (ref.watch(riderWorkEnabledProvider) &&
      ref.watch(appEnvProvider).useFakeApi) {
    return ref.watch(fakeRatingBackendProvider);
  }
  return const UnavailableRatingRepository();
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
