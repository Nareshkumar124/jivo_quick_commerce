import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:jivo_core/jivo_core.dart';

import '../../../app/redirect.dart';
import '../../../app/theme.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/widgets/product_image.dart';
import '../../catalog/domain/catalog_models.dart';
import '../../location/domain/delivery_location.dart';
import '../../location/presentation/delivery_controller.dart';
import '../../location/presentation/location_options.dart';

/// The compact delivery header (home redesign, 2026-11-21): "Deliver to"
/// with the ETA as a small badge, the address with a chevron (opens the
/// address switcher) and the account button. Light, on the warm canvas;
/// it paints under the status bar and adds the top inset itself.
class HomeHeader extends StatelessWidget {
  const HomeHeader({required this.delivery, super.key});

  final DeliveryState delivery;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final location = delivery.location;
    final serviceability = delivery.serviceability;
    final eta = serviceability?.etaMinutes;
    // The delivery status: the ETA, or why there is none.
    final (String? status, _Tone tone) = switch ((location, serviceability)) {
      (null, _) => (null, _Tone.neutral),
      (_, null) => (l10n.checkingDelivery, _Tone.neutral),
      (_, Serviceability(serviceable: false)) => (
        l10n.notDeliveringHere,
        _Tone.warning,
      ),
      _ when eta != null => (l10n.deliveryIn(eta), _Tone.good),
      (_, Serviceability(storeClosed: true)) => (
        l10n.storeClosedHeadline,
        _Tone.warning,
      ),
      _ => (null, _Tone.neutral),
    };
    final address = location == null
        ? l10n.selectLocation
        : [location.title, ?location.subtitle].join(' · ');

    // A light header: dark status-bar icons.
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: customerLightScreenStyle,
      child: Padding(
        key: const Key('home-header'),
        padding: EdgeInsets.fromLTRB(
          JivoSpacing.gutter,
          MediaQuery.paddingOf(context).top + JivoSpacing.sm,
          JivoSpacing.xs,
          JivoSpacing.xs,
        ),
        child: Row(
          children: [
            Expanded(
              child: Semantics(
                button: true,
                hint: l10n.changeLocationSemantics,
                child: InkWell(
                  key: const Key('home-address'),
                  borderRadius: BorderRadius.circular(JivoRadii.md),
                  onTap: () => location == null
                      ? context.push(Routes.location)
                      : showAddressSwitcher(context),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      minHeight: kJivoMinTouchTarget,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Wrap(
                            spacing: JivoSpacing.sm,
                            runSpacing: 2,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              if (location != null)
                                Text(
                                  l10n.deliverTo,
                                  style: theme.textTheme.labelMedium?.copyWith(
                                    color: scheme.onSurfaceVariant,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              if (status != null)
                                _StatusBadge(text: status, tone: tone),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              ExcludeSemantics(
                                child: Icon(
                                  Icons.location_on_outlined,
                                  size: 18,
                                  color: scheme.primary,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  address,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.titleSmall,
                                ),
                              ),
                              ExcludeSemantics(
                                child: Icon(
                                  Icons.keyboard_arrow_down_rounded,
                                  size: 20,
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            IconButton(
              tooltip: l10n.accountTitle,
              color: scheme.onSurface,
              icon: const Icon(Icons.person_outline_rounded),
              onPressed: () => context.go(Routes.account),
            ),
          ],
        ),
      ),
    );
  }
}

enum _Tone { good, warning, neutral }

/// The ETA (or "Store closed", "Not delivering here") as a small pill.
class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.text, required this.tone});

  final String text;
  final _Tone tone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final cc = context.customerColors;
    final (background, icon, iconColor) = switch (tone) {
      _Tone.good => (cc.softTint, Icons.schedule_rounded, scheme.primary),
      _Tone.warning => (
        cc.warningTint,
        Icons.info_outline_rounded,
        context.jivoColors.warning,
      ),
      _Tone.neutral => (
        scheme.surfaceContainerHigh,
        Icons.schedule_rounded,
        scheme.onSurfaceVariant,
      ),
    };
    return Container(
      key: const Key('home-eta-badge'),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(JivoRadii.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ExcludeSemantics(child: Icon(icon, size: 14, color: iconColor)),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelMedium?.copyWith(
                color: tone == _Tone.good
                    ? scheme.onPrimaryContainer
                    : scheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Looks like a large rounded search field; opens the search screen.
class HomeSearchBar extends StatelessWidget {
  const HomeSearchBar({required this.hint, super.key});

  final String hint;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final cc = context.customerColors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        JivoSpacing.gutter,
        JivoSpacing.xs,
        JivoSpacing.gutter,
        JivoSpacing.md,
      ),
      child: Semantics(
        button: true,
        child: Material(
          color: scheme.surfaceContainerLowest,
          elevation: 1,
          shadowColor: cc.softShadow,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(JivoRadii.lg),
            side: BorderSide(color: cc.hairline),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            key: const Key('home-search'),
            onTap: () => context.push(Routes.search),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 52),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: JivoSpacing.lg,
                  vertical: JivoSpacing.sm,
                ),
                child: Row(
                  children: [
                    Icon(Icons.search_rounded, color: scheme.onSurfaceVariant),
                    const SizedBox(width: JivoSpacing.md),
                    Expanded(
                      child: Text(
                        hint,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A small strong section title with an optional subtle "See all".
class HomeSectionHeader extends StatelessWidget {
  const HomeSectionHeader({required this.title, this.onSeeAll, super.key});

  final String title;
  final VoidCallback? onSeeAll;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        JivoSpacing.gutter,
        JivoSpacing.lg,
        onSeeAll == null ? JivoSpacing.gutter : JivoSpacing.xs,
        onSeeAll == null ? JivoSpacing.sm : 0,
      ),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              header: true,
              child: Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleMedium,
              ),
            ),
          ),
          if (onSeeAll != null)
            TextButton(
              onPressed: onSeeAll,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                textStyle: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(AppLocalizations.of(context).seeAll),
                  const Icon(Icons.chevron_right_rounded, size: 18),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// The top-level categories from `GET /home/` as a compact horizontal row
/// of small image tiles; a tap opens the category's product list.
class HomeCategoryRow extends StatelessWidget {
  const HomeCategoryRow({required this.categories, super.key});

  final List<ProductCategory> categories;

  static const _well = 64.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cc = context.customerColors;
    final scale = (MediaQuery.textScalerOf(context).scale(14) / 14).clamp(
      1.0,
      2.0,
    );
    final width = 76 * scale.clamp(1.0, 1.4);
    // Two label lines at the current text size.
    final height = _well + 6 + 2 * 16 * scale + 4;
    return SizedBox(
      key: const Key('home-categories'),
      height: height,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: JivoSpacing.gutter),
        itemCount: categories.length,
        separatorBuilder: (_, _) => const SizedBox(width: JivoSpacing.sm),
        itemBuilder: (context, i) {
          final category = categories[i];
          return SizedBox(
            width: width,
            child: Semantics(
              button: true,
              label: category.name,
              excludeSemantics: true,
              child: InkWell(
                key: ValueKey('home-category-${category.slug}'),
                borderRadius: BorderRadius.circular(JivoRadii.md),
                onTap: () => context.push(Routes.category(category.slug)),
                child: Column(
                  children: [
                    Container(
                      width: _well,
                      height: _well,
                      decoration: BoxDecoration(
                        color: cc.imageWell,
                        borderRadius: BorderRadius.circular(JivoRadii.lg),
                      ),
                      clipBehavior: Clip.antiAlias,
                      padding: const EdgeInsets.all(8),
                      child: ProductImage(
                        url: category.imageUrl,
                        icon: Icons.category_outlined,
                        onWell: true,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      category.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
