import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jivo_core/jivo_core.dart';

import '../../../../app/repositories.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../../shared/formatting/formatters.dart';
import '../../../../shared/widgets/state_views.dart';
import '../../domain/cart.dart';
import '../cart_controller.dart';
import '../cart_texts.dart';

/// Coupons for the current cart, with eligibility and savings
/// (`GET /cart/coupons/`).
final cartCouponsProvider = FutureProvider.autoDispose<List<CouponOffer>>(
  (ref) => ref.watch(cartRepositoryProvider).coupons(),
);

/// Opens the coupon sheet (`03 §3` #21).
Future<void> showCouponSheet(BuildContext context) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      builder: (_) => const CouponSheet(),
    );

/// The eligible and ineligible coupons, plus manual code entry. Applying
/// one goes to the server; its `COUPON_*` error is shown under the field.
class CouponSheet extends ConsumerStatefulWidget {
  const CouponSheet({super.key});

  @override
  ConsumerState<CouponSheet> createState() => _CouponSheetState();
}

class _CouponSheetState extends ConsumerState<CouponSheet> {
  final _code = TextEditingController();
  String? _error;
  String? _applying;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _apply(String code) async {
    final l10n = AppLocalizations.of(context);
    final trimmed = code.trim();
    if (trimmed.isEmpty) {
      setState(() => _error = l10n.couponCodeRequired);
      return;
    }
    if (_applying != null) return;
    setState(() {
      _applying = trimmed;
      _error = null;
    });
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      await ref.read(cartProvider.notifier).applyCoupon(trimmed);
      final applied = ref.read(cartProvider).snapshot.coupon;
      if (!mounted) return;
      navigator.pop();
      if (applied != null) {
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(
                l10n.couponAppliedMessage(
                  applied.code,
                  formatRupees(applied.discount),
                ),
              ),
            ),
          );
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _applying = null;
        _error = _describe(error);
      });
    }
  }

  /// The server's coupon error, with its details (e.g. how much to add).
  String _describe(Object error) => cartErrorText(context, error);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final coupons = ref.watch(cartCouponsProvider);
    final busy = _applying != null;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.85,
        ),
        child: Column(
          key: const Key('coupon-sheet'),
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: JivoSpacing.gutter,
              ),
              child: Semantics(
                header: true,
                child: Text(
                  l10n.couponsTitle,
                  style: theme.textTheme.titleMedium,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(JivoSpacing.gutter),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextField(
                      key: const Key('coupon-code'),
                      controller: _code,
                      enabled: !busy,
                      textCapitalization: TextCapitalization.characters,
                      textInputAction: TextInputAction.done,
                      onSubmitted: _apply,
                      decoration: InputDecoration(
                        labelText: l10n.couponCodeLabel,
                        errorText: _error,
                        errorMaxLines: 3,
                      ),
                    ),
                  ),
                  const SizedBox(width: JivoSpacing.sm),
                  SizedBox(
                    height: kJivoMinTouchTarget + JivoSpacing.sm,
                    child: FilledButton(
                      key: const Key('coupon-apply-code'),
                      onPressed: busy ? null : () => _apply(_code.text),
                      child: _applying == _code.text.trim() && busy
                          ? const SizedBox.square(
                              dimension: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(l10n.couponApply),
                    ),
                  ),
                ],
              ),
            ),
            Flexible(
              child: switch (coupons) {
                AsyncData(:final value) when value.isEmpty => EmptyView(
                  message: l10n.couponsEmpty,
                  icon: Icons.local_offer_outlined,
                ),
                AsyncData(:final value) => ListView.separated(
                  shrinkWrap: true,
                  padding: const EdgeInsets.fromLTRB(
                    JivoSpacing.gutter,
                    0,
                    JivoSpacing.gutter,
                    JivoSpacing.xl,
                  ),
                  itemCount: value.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: JivoSpacing.md),
                  itemBuilder: (context, index) {
                    final offer = value[index];
                    return _CouponCard(
                      offer: offer,
                      applying: _applying == offer.code,
                      onApply: busy ? null : () => _apply(offer.code),
                    );
                  },
                ),
                AsyncError(:final error) => ErrorRetryView(
                  error: error,
                  onRetry: () => ref.invalidate(cartCouponsProvider),
                ),
                _ => const SizedBox(height: 240, child: SkeletonList()),
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _CouponCard extends StatelessWidget {
  const _CouponCard({
    required this.offer,
    required this.applying,
    required this.onApply,
  });

  final CouponOffer offer;
  final bool applying;
  final VoidCallback? onApply;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final eligible = offer.isEligible;
    final savings = offer.savings;
    final endsAt = offer.endsAt;
    final muted = theme.colorScheme.onSurfaceVariant;

    return Card(
      key: ValueKey('coupon-${offer.code}'),
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(JivoSpacing.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: MergeSemantics(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      offer.code,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: eligible ? null : muted,
                      ),
                    ),
                    Text(offer.title, style: theme.textTheme.bodyMedium),
                    Text(
                      offer.description,
                      style: theme.textTheme.bodySmall?.copyWith(color: muted),
                    ),
                    if (endsAt != null)
                      Text(
                        l10n.couponExpiresOn(formatDate(endsAt)),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: muted,
                        ),
                      ),
                    if (eligible && savings != null)
                      Text(
                        l10n.couponSavesOnCart(formatRupees(savings)),
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: context.jivoColors.success,
                        ),
                      ),
                    if (!eligible)
                      Text(
                        couponIneligibleText(l10n, offer),
                        key: ValueKey('coupon-problem-${offer.code}'),
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: theme.colorScheme.error,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            if (eligible && offer.isApplied)
              Padding(
                padding: const EdgeInsets.all(JivoSpacing.sm),
                child: Text(
                  l10n.couponAppliedBadge,
                  key: ValueKey('coupon-applied-${offer.code}'),
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: context.jivoColors.success,
                  ),
                ),
              )
            else if (eligible)
              TextButton(
                key: ValueKey('coupon-apply-${offer.code}'),
                onPressed: onApply,
                child: applying
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Semantics(
                        label: l10n.couponApplySemantics(offer.code),
                        excludeSemantics: true,
                        child: Text(l10n.couponApply),
                      ),
              ),
          ],
        ),
      ),
    );
  }
}
