import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jivo_core/jivo_core.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/widgets/skeletons.dart';
import '../domain/user_profile.dart';
import 'profile_controllers.dart';

/// The business category dropdown (`03 §2.2`), filled from
/// `GET /business-categories/`. Shows a skeleton while loading and an
/// inline message with Retry when the list fails; hidden when the list is
/// empty (the field is optional).
class BusinessCategoryField extends ConsumerWidget {
  const BusinessCategoryField({
    required this.value,
    required this.onChanged,
    this.currentName,
    this.errorText,
    this.enabled = true,
    super.key,
  });

  static const dropdownKey = Key('business-category');
  static const retryKey = Key('business-category-retry');

  /// The selected category id, or null.
  final int? value;
  final ValueChanged<int?> onChanged;

  /// The name of [value] from the user's profile, used when that category
  /// is no longer in the active list (so the saved choice still shows).
  final String? currentName;

  /// A server-side rejection to show under the field.
  final String? errorText;
  final bool enabled;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final categories = ref.watch(businessCategoriesProvider);
    return switch (categories) {
      AsyncData(:final value) => _dropdown(context, l10n, value),
      AsyncError() => _LoadError(
        onRetry: () => ref.invalidate(businessCategoriesProvider),
      ),
      _ => Semantics(
        label: l10n.businessCategoriesLoading,
        child: const ExcludeSemantics(
          child: SkeletonBox(height: 56, radius: JivoRadii.sm),
        ),
      ),
    };
  }

  Widget _dropdown(
    BuildContext context,
    AppLocalizations l10n,
    List<BusinessCategory> categories,
  ) {
    final options = [...categories];
    final selected = value;
    if (selected != null && !options.any((c) => c.id == selected)) {
      // A saved category that was since deactivated: keep it visible.
      options.add(
        BusinessCategory(id: selected, name: currentName ?? '', slug: ''),
      );
    }
    if (options.isEmpty) return const SizedBox.shrink();
    return DropdownButtonFormField<int>(
      key: dropdownKey,
      initialValue: selected,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: l10n.businessCategoryLabel,
        errorText: errorText,
        errorMaxLines: 3,
      ),
      hint: Text(l10n.businessCategoryHint),
      items: [
        for (final c in options)
          DropdownMenuItem<int>(
            value: c.id,
            child: Text(c.name, overflow: TextOverflow.ellipsis),
          ),
      ],
      onChanged: enabled ? onChanged : null,
    );
  }
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Expanded(
          child: Text(
            l10n.businessCategoriesError,
            style: TextStyle(color: scheme.error),
          ),
        ),
        TextButton(
          key: BusinessCategoryField.retryKey,
          style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
          onPressed: onRetry,
          child: Text(l10n.retry),
        ),
      ],
    );
  }
}
