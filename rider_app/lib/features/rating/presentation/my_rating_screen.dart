import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../../shared/format/ist_format.dart';
import '../../../shared/widgets/paged_list_view.dart';
import '../domain/rider_rating.dart';
import 'rating_providers.dart';

String ratingTagName(AppLocalizations l10n, RatingTag tag) => switch (tag) {
  RatingTag.onTime => l10n.ratingTagOnTime,
  RatingTag.politeRider => l10n.ratingTagPolite,
  RatingTag.lateDelivery => l10n.ratingTagLate,
  RatingTag.rudeRider => l10n.ratingTagRude,
  RatingTag.unknown => l10n.ratingTagOther,
};

/// "My rating" (04 §2.9, P7): the server's average and count, the tags
/// customers chose most, then the recent ratings (stars, tags, order
/// number and date; no customer data).
class MyRatingScreen extends ConsumerWidget {
  const MyRatingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(myRatingProvider);
    final notifier = ref.read(myRatingProvider.notifier);
    final summary = state.header;
    final body = PagedListView(
      state: state,
      onRefresh: notifier.refresh,
      onLoadMore: notifier.loadMore,
      emptyText: l10n.ratingNoneYet,
      header: [if (summary != null) _SummaryCard(summary: summary)],
      itemBuilder: (context, rating) => _RatingTile(rating: rating),
    );
    return Scaffold(
      appBar: AppBar(title: Text(l10n.ratingTitle)),
      body: body,
    );
  }
}

class _Stars extends StatelessWidget {
  const _Stars({required this.halfStars, this.size = 20});

  /// 0–10 (9 = four and a half stars).
  final int halfStars;
  final double size;

  @override
  Widget build(BuildContext context) {
    const color = Color(0xFFF2A100);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 1; i <= 5; i++)
          Icon(
            halfStars >= i * 2
                ? Icons.star
                : halfStars == i * 2 - 1
                ? Icons.star_half
                : Icons.star_border,
            size: size,
            color: color,
          ),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.summary});

  final RatingSummary summary;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Card(
      key: const Key('rating-summary'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              summary.average ?? '–',
              key: const Key('rating-average'),
              style: theme.textTheme.displaySmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            _Stars(halfStars: summary.halfStars, size: 32),
            const SizedBox(height: 4),
            Text(
              l10n.ratingCount(summary.count),
              key: const Key('rating-count'),
              style: theme.textTheme.bodyLarge,
            ),
            if (summary.tagCounts.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final t in summary.tagCounts)
                    if (t.tag != RatingTag.unknown)
                      Chip(
                        key: Key('rating-tag-${t.tag.wireValue}'),
                        avatar: Icon(
                          t.tag.positive
                              ? Icons.thumb_up_alt_outlined
                              : Icons.thumb_down_alt_outlined,
                          size: 18,
                        ),
                        label: Text(
                          '${ratingTagName(l10n, t.tag)} · ${t.count}',
                        ),
                      ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _RatingTile extends StatelessWidget {
  const _RatingTile({required this.rating});

  final RiderRating rating;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final tags = [
      for (final tag in rating.tags)
        if (tag != RatingTag.unknown) ratingTagName(l10n, tag),
    ];
    return Card(
      key: Key('rating-${rating.id}'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Semantics(
                  label: l10n.ratingStars(rating.stars),
                  child: ExcludeSemantics(
                    child: _Stars(halfStars: rating.stars.clamp(0, 5) * 2),
                  ),
                ),
                const Spacer(),
                Text(
                  istDate(context, rating.ratedAt),
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
            if (tags.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(tags.join(' · '), style: theme.textTheme.bodyLarge),
            ],
            if (rating.orderNumber case final number?) ...[
              const SizedBox(height: 4),
              Text(number, style: theme.textTheme.bodySmall),
            ],
          ],
        ),
      ),
    );
  }
}
