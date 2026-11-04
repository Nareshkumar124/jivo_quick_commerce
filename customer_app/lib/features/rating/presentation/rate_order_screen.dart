import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:jivo_core/jivo_core.dart';

import '../../../app/redirect.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/widgets/state_views.dart';
import '../domain/order_rating.dart';
import 'rating_controllers.dart';

/// Rate a delivered order and its delivery partner (`03 §2.10`, screen #30,
/// Phase 7 built ahead on fakes): order stars (required), quick tags, rider
/// stars (optional) and a comment.
class RateOrderScreen extends ConsumerStatefulWidget {
  const RateOrderScreen({required this.orderId, this.initialStars, super.key});

  final int orderId;

  /// The stars tapped on the order detail (1–5), preselected.
  final int? initialStars;

  @override
  ConsumerState<RateOrderScreen> createState() => _RateOrderScreenState();
}

class _RateOrderScreenState extends ConsumerState<RateOrderScreen> {
  final _comment = TextEditingController();

  @override
  void initState() {
    super.initState();
    final stars = widget.initialStars;
    if (stars != null && stars >= 1 && stars <= 5) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final form = ref.read(ratingFormProvider(widget.orderId).notifier);
        if (ref.read(ratingFormProvider(widget.orderId)).orderStars == 0) {
          form.setOrderStars(stars);
        }
      });
    }
  }

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context);
    final rating = await ref
        .read(ratingFormProvider(widget.orderId).notifier)
        .submit(_comment.text);
    if (rating == null || !mounted) return;
    showMessage(context, l10n.ratingThanks);
    final router = GoRouter.of(context);
    if (router.canPop()) {
      router.pop(true);
    } else {
      router.go(Routes.order(widget.orderId));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final form = ref.watch(ratingFormProvider(widget.orderId));
    final controller = ref.read(ratingFormProvider(widget.orderId).notifier);
    final tags = RatingTag.forStars(form.orderStars);
    final error = form.error;

    Widget header(String text) => Semantics(
      header: true,
      child: Text(text, style: theme.textTheme.titleMedium),
    );

    return Scaffold(
      appBar: AppBar(title: Text(l10n.rateOrderTitle)),
      body: ListView(
        key: const Key('rate-order'),
        padding: const EdgeInsets.all(JivoSpacing.gutter),
        children: [
          header(l10n.rateOrderQuestion),
          const SizedBox(height: JivoSpacing.sm),
          StarRatingPicker(
            key: const Key('order-stars'),
            value: form.orderStars,
            onChanged: form.submitting ? null : controller.setOrderStars,
          ),
          if (tags.isNotEmpty) ...[
            const SizedBox(height: JivoSpacing.lg),
            header(
              form.orderStars >= 4
                  ? l10n.rateTagsPositive
                  : l10n.rateTagsNegative,
            ),
            const SizedBox(height: JivoSpacing.sm),
            Wrap(
              spacing: JivoSpacing.sm,
              runSpacing: JivoSpacing.sm,
              children: [
                for (final tag in tags)
                  FilterChip(
                    key: Key('tag-${tag.wireValue}'),
                    label: Text(ratingTagLabel(l10n, tag)),
                    selected: form.tags.contains(tag),
                    onSelected: form.submitting
                        ? null
                        : (_) => controller.toggleTag(tag),
                  ),
              ],
            ),
          ],
          const SizedBox(height: JivoSpacing.xl),
          header(l10n.rateRiderQuestion),
          Text(l10n.rateRiderOptional, style: theme.textTheme.bodySmall),
          const SizedBox(height: JivoSpacing.sm),
          StarRatingPicker(
            key: const Key('rider-stars'),
            value: form.riderStars ?? 0,
            onChanged: form.submitting ? null : controller.setRiderStars,
          ),
          const SizedBox(height: JivoSpacing.xl),
          TextField(
            key: const Key('rating-comment'),
            controller: _comment,
            enabled: !form.submitting,
            minLines: 3,
            maxLines: 6,
            maxLength: ratingCommentMaxLength,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              labelText: l10n.rateCommentLabel,
              hintText: l10n.rateCommentHint,
              alignLabelWithHint: true,
            ),
          ),
          if (error != null) ...[
            const SizedBox(height: JivoSpacing.sm),
            Text(
              describeErrorWithDetails(context, error),
              key: const Key('rating-error'),
              style: TextStyle(color: theme.colorScheme.error),
            ),
          ],
          const SizedBox(height: JivoSpacing.lg),
          if (form.orderStars == 0)
            Padding(
              padding: const EdgeInsets.only(bottom: JivoSpacing.sm),
              child: Text(
                l10n.rateChooseStars,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall,
              ),
            ),
          BusyButton(
            key: const Key('submit-rating'),
            label: l10n.rateSubmit,
            busy: form.submitting,
            onPressed: form.canSubmit ? _submit : null,
          ),
        ],
      ),
    );
  }
}

/// Five tappable stars, each a 48 dp target announced as "N stars".
/// A null [onChanged] shows the value read-only.
class StarRatingPicker extends StatelessWidget {
  const StarRatingPicker({
    required this.value,
    required this.onChanged,
    super.key,
  });

  /// 0–5.
  final int value;
  final ValueChanged<int>? onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final color = context.jivoColors.warning;
    final onChanged = this.onChanged;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var star = 1; star <= 5; star++)
          Semantics(
            selected: star == value,
            child: IconButton(
              key: Key('star-$star'),
              constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
              iconSize: 36,
              tooltip: l10n.rateStars(star),
              onPressed: onChanged == null ? null : () => onChanged(star),
              icon: Icon(
                star <= value ? Icons.star_rounded : Icons.star_border_rounded,
                color: star <= value ? color : null,
              ),
            ),
          ),
      ],
    );
  }
}

String ratingTagLabel(AppLocalizations l10n, RatingTag tag) => switch (tag) {
  RatingTag.onTime => l10n.rateTagOnTime,
  RatingTag.wellPacked => l10n.rateTagWellPacked,
  RatingTag.freshProducts => l10n.rateTagFresh,
  RatingTag.politeRider => l10n.rateTagPoliteRider,
  RatingTag.lateDelivery => l10n.rateTagLate,
  RatingTag.damagedItems => l10n.rateTagDamaged,
  RatingTag.missingItems => l10n.rateTagMissing,
  RatingTag.rudeRider => l10n.rateTagRudeRider,
};
