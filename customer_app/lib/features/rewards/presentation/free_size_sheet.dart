import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:jivo_core/jivo_core.dart';

import '../../../app/redirect.dart';
import '../../../app/theme.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/formatting/formatters.dart';
import '../../../shared/widgets/product_image.dart';
import '../../../shared/widgets/state_views.dart';
import '../../cart/presentation/cart_controller.dart';
import '../../cart/presentation/cart_texts.dart';
import 'rewards_providers.dart';

/// The server wants a size for a free-carton reward: 400 with
/// `free_variant_id` (ADR 0002; a store with no fixed free size). The
/// caller then opens the size sheet instead of showing an error.
bool isFreeSizeRequired(Object error) {
  final apiError = ApiError.from(error);
  return apiError.code == ApiErrorCode.validationError &&
      apiError.details.containsKey('free_variant_id');
}

/// Opens the size picker for the free-carton reward [code] (ADR 0002) and
/// applies it to the cart with the size the customer picks. Returns true
/// once the server applied it (the cart then holds the free line).
///
/// Only a fallback since ADR 0003: a reward whose store has a fixed free
/// size is applied directly, with no sheet. [quantity] is the reward's
/// number of free cartons (the server's), for the copy.
Future<bool> showFreeSizeSheet(
  BuildContext context, {
  required String code,
  int quantity = 1,
}) async {
  final applied = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    builder: (context) => Theme(
      data: lightPageTheme(Theme.of(context)),
      child: FreeSizeSheet(code: code, quantity: quantity),
    ),
  );
  return applied ?? false;
}

/// "Pick a size for your free carton": the water sizes in stock at the
/// store ([freeCartonSizesProvider]), each with the server's MRP, then
/// "Add free carton", which is the cart's apply-coupon call with
/// `free_variant_id`. Its error (e.g. the size is no longer sold) shows
/// in the sheet; the sheet closes with `true` once applied. It also says
/// that the order still needs the store's minimum of paid cartons, and
/// when the reward will replace a coupon already on the cart.
class FreeSizeSheet extends ConsumerStatefulWidget {
  const FreeSizeSheet({required this.code, this.quantity = 1, super.key});

  final String code;

  /// Free cartons the reward gives (the server's number), for the copy.
  final int quantity;

  @override
  ConsumerState<FreeSizeSheet> createState() => _FreeSizeSheetState();
}

class _FreeSizeSheetState extends ConsumerState<FreeSizeSheet> {
  int? _picked;
  bool _applying = false;
  String? _error;

  /// The server wants more paid cartons first (`MIN_ORDER_UNITS`).
  bool _needsCartons = false;

  Future<void> _apply(int variantId) async {
    if (_applying) return;
    setState(() {
      _applying = true;
      _error = null;
      _needsCartons = false;
    });
    final navigator = Navigator.of(context);
    try {
      await ref
          .read(cartProvider.notifier)
          .applyCoupon(widget.code, freeVariantId: variantId);
      if (mounted) navigator.pop(true);
    } catch (error) {
      if (!mounted) return;
      final details = ApiError.from(error).details;
      setState(() {
        _applying = false;
        _error = cartErrorText(
          context,
          error,
          cart: ref.read(cartProvider).snapshot,
        );
        _needsCartons = details['reason'] == 'MIN_ORDER_UNITS';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final sizes = ref.watch(freeCartonSizesProvider);
    final cart = ref.watch(cartProvider.select((c) => c.snapshot));
    final thresholds = cart.thresholds;
    final minimum = thresholds?.minOrderUnits ?? 0;
    final otherCoupon = cart.coupon?.code;
    final replaces =
        otherCoupon != null &&
        otherCoupon.toUpperCase() != widget.code.toUpperCase();
    final options = sizes.value ?? const <FreeSizeOption>[];
    // One size only: it is the choice.
    final picked =
        _picked ?? (options.length == 1 ? options.single.variant.id : null);

    final Widget list = switch (sizes) {
      AsyncData(:final value) when value.isEmpty => EmptyView(
        key: const Key('free-size-empty'),
        message: l10n.freeSizeEmpty,
        icon: Icons.water_drop_outlined,
      ),
      AsyncData(:final value) => SingleChildScrollView(
        child: RadioGroup<int>(
          groupValue: picked,
          onChanged: (id) {
            if (id != null && !_applying) setState(() => _picked = id);
          },
          child: Column(
            key: const Key('free-size-list'),
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final option in value)
                RadioListTile<int>(
                  key: ValueKey('free-size-${option.variant.id}'),
                  value: option.variant.id,
                  enabled: !_applying,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: JivoSpacing.gutter,
                  ),
                  secondary: SizedBox.square(
                    dimension: 48,
                    child: ProductImage(url: option.variant.imageUrl),
                  ),
                  title: Text('${option.productName} ${option.variant.name}'),
                  subtitle: Text(
                    l10n.freeSizeWorth(displayRupees(option.variant.mrp)),
                  ),
                ),
            ],
          ),
        ),
      ),
      AsyncError(:final error)
          when ApiError.from(error).code == ApiErrorCode.storeNotFound =>
        EmptyView(
          key: const Key('free-size-no-store'),
          message: l10n.freeSizeNeedsLocation,
          icon: Icons.location_on_outlined,
          action: FilledButton(
            key: const Key('free-size-choose-location'),
            onPressed: () {
              Navigator.of(context).pop(false);
              context.push(Routes.location);
            },
            child: Text(l10n.couponsChooseLocation),
          ),
        ),
      AsyncError(:final error) => ErrorRetryView(
        error: error,
        onRetry: () => ref.invalidate(freeCartonSizesProvider),
      ),
      _ => const SizedBox(height: 200, child: SkeletonList()),
    };

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.85,
      ),
      child: Padding(
        key: const Key('free-size-sheet'),
        padding: const EdgeInsets.only(bottom: JivoSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: JivoSpacing.gutter,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Semantics(
                    header: true,
                    child: Text(
                      l10n.freeSizeTitle(widget.quantity),
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                  if (minimum > 0) ...[
                    const SizedBox(height: JivoSpacing.xs),
                    Text(
                      l10n.freeSizeMinNote(
                        minimum,
                        orderUnitLabel(l10n, thresholds),
                      ),
                      key: const Key('free-size-min-note'),
                      style: theme.textTheme.bodySmall?.copyWith(color: muted),
                    ),
                  ],
                  if (replaces) ...[
                    const SizedBox(height: JivoSpacing.xs),
                    Text(
                      l10n.freeSizeReplacesCoupon(otherCoupon),
                      key: const Key('free-size-replaces'),
                      style: theme.textTheme.bodySmall?.copyWith(color: muted),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: JivoSpacing.sm),
            Flexible(child: list),
            if (_error case final error?)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  JivoSpacing.gutter,
                  JivoSpacing.sm,
                  JivoSpacing.gutter,
                  0,
                ),
                child: Semantics(
                  liveRegion: true,
                  child: Text(
                    error,
                    key: const Key('free-size-error'),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.error,
                    ),
                  ),
                ),
              ),
            if (_needsCartons)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: JivoSpacing.gutter,
                ),
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: TextButton(
                    key: const Key('free-size-add-cartons'),
                    onPressed: () {
                      Navigator.of(context).pop(false);
                      context.push(Routes.allProducts);
                    },
                    child: Text(l10n.rewardAddCartons),
                  ),
                ),
              ),
            if (options.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  JivoSpacing.gutter,
                  JivoSpacing.md,
                  JivoSpacing.gutter,
                  0,
                ),
                child: BusyButton(
                  key: const Key('free-size-confirm'),
                  label: l10n.freeSizeConfirm(widget.quantity),
                  busy: _applying,
                  onPressed: picked == null ? null : () => _apply(picked),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
