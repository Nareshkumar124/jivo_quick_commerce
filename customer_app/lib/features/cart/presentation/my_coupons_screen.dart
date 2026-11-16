import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:jivo_core/jivo_core.dart';

import '../../../app/redirect.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/formatting/formatters.dart';
import '../../../shared/widgets/state_views.dart';
import '../domain/cart.dart';
import 'cart_texts.dart';
import 'widgets/coupon_sheet.dart';

/// Account > My coupons: every coupon `GET /cart/coupons/` lists for the
/// customer, including personal rewards. Copy a code, then paste it in the
/// cart. The repository adds the store id.
class MyCouponsScreen extends ConsumerWidget {
  const MyCouponsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final coupons = ref.watch(cartCouponsProvider);

    Future<void> refresh() async {
      ref.invalidate(cartCouponsProvider);
      try {
        await ref.read(cartCouponsProvider.future);
      } catch (_) {
        // The error view shows it.
      }
    }

    Widget scrollable(Widget child) => LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: child,
        ),
      ),
    );

    final Widget body = switch (coupons) {
      AsyncData(:final value) when value.isEmpty => scrollable(
        EmptyView(
          message: l10n.myCouponsEmpty,
          icon: Icons.local_offer_outlined,
        ),
      ),
      AsyncData(:final value) => ListView.separated(
        key: const Key('my-coupons-list'),
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(JivoSpacing.gutter),
        itemCount: value.length,
        separatorBuilder: (_, _) => const SizedBox(height: JivoSpacing.md),
        itemBuilder: (context, index) => MyCouponCard(offer: value[index]),
      ),
      AsyncError(:final error)
          when ApiError.from(error).code == ApiErrorCode.storeNotFound =>
        scrollable(
          EmptyView(
            message: l10n.couponsNeedLocation,
            icon: Icons.location_on_outlined,
            action: FilledButton(
              key: const Key('my-coupons-choose-location'),
              onPressed: () => context.push(Routes.location),
              child: Text(l10n.couponsChooseLocation),
            ),
          ),
        ),
      AsyncError(:final error) => scrollable(
        ErrorRetryView(
          error: error,
          onRetry: () => ref.invalidate(cartCouponsProvider),
        ),
      ),
      _ => const SkeletonList(),
    };

    return Scaffold(
      appBar: AppBar(title: Text(l10n.myCoupons)),
      body: RefreshIndicator(onRefresh: refresh, child: body),
    );
  }
}

/// One coupon: title, copyable code chip, terms, expiry and, when it can't
/// be used now, the server's reason.
class MyCouponCard extends StatelessWidget {
  const MyCouponCard({required this.offer, super.key});

  final CouponOffer offer;

  Future<void> _copy(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    await Clipboard.setData(ClipboardData(text: offer.code));
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(l10n.couponCodeCopied(offer.code))),
      );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final endsAt = offer.endsAt;
    final minOrder = offer.minOrderValue;
    final showMin = minOrder != null && !isZeroAmount(minOrder);

    return Card(
      key: ValueKey('my-coupon-${offer.code}'),
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(JivoSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (offer.isPersonal) ...[
              CouponForYouLabel(code: offer.code),
              const SizedBox(height: JivoSpacing.xs),
            ],
            Text(
              offer.title,
              style: theme.textTheme.titleMedium?.copyWith(
                color: offer.isEligible ? null : muted,
              ),
            ),
            const SizedBox(height: JivoSpacing.xs),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: Semantics(
                button: true,
                label: l10n.couponCopySemantics(offer.code),
                excludeSemantics: true,
                child: InkWell(
                  key: ValueKey('my-coupon-copy-${offer.code}'),
                  borderRadius: BorderRadius.circular(JivoRadii.sm),
                  onTap: () => _copy(context),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      minHeight: kJivoMinTouchTarget,
                    ),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: JivoSpacing.md,
                        vertical: JivoSpacing.xs,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(color: theme.colorScheme.primary),
                        borderRadius: BorderRadius.circular(JivoRadii.sm),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              offer.code,
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                          ),
                          const SizedBox(width: JivoSpacing.sm),
                          Icon(
                            Icons.copy_rounded,
                            size: 18,
                            color: theme.colorScheme.primary,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: JivoSpacing.xs),
            Text(
              offer.description,
              style: theme.textTheme.bodyMedium?.copyWith(color: muted),
            ),
            if (showMin)
              Text(
                l10n.couponMinOrder(formatRupees(minOrder)),
                style: theme.textTheme.bodySmall?.copyWith(color: muted),
              ),
            if (endsAt != null)
              Text(
                l10n.couponExpiresOn(formatDate(endsAt)),
                style: theme.textTheme.bodySmall?.copyWith(color: muted),
              ),
            if (!offer.isEligible)
              Padding(
                padding: const EdgeInsets.only(top: JivoSpacing.xs),
                child: Text(
                  couponIneligibleText(l10n, offer),
                  key: ValueKey('my-coupon-problem-${offer.code}'),
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// The "For you" tag on a personal coupon.
class CouponForYouLabel extends StatelessWidget {
  const CouponForYouLabel({required this.code, super.key});

  final String code;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      key: ValueKey('coupon-for-you-$code'),
      padding: const EdgeInsets.symmetric(
        horizontal: JivoSpacing.sm,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(JivoRadii.sm),
      ),
      child: Text(
        AppLocalizations.of(context).couponForYou,
        style: theme.textTheme.labelMedium?.copyWith(
          color: theme.colorScheme.onPrimaryContainer,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
