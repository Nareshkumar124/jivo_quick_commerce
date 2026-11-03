import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jivo_core/jivo_core.dart';

import '../../../../l10n/generated/app_localizations.dart';
import '../../../../shared/formatting/formatters.dart';
import '../../../../shared/widgets/state_views.dart';
import '../cart_controller.dart';

/// Optional rider tip: ₹10 / ₹20 / ₹30 / custom (`03 §2.8`). The selected
/// chip is whatever tip the server's bill holds; choosing a chip sends that
/// amount (`PATCH /cart/ {tip}`), choosing it again removes the tip.
class TipSelector extends ConsumerWidget {
  const TipSelector({super.key});

  /// The preset chips, in rupees (`03 §2.8`).
  static const presets = [10, 20, 30];

  /// The largest custom tip the app accepts: the server's `CART_MAX_TIP`
  /// default (₹500, `06 §2.5`, DL-44). The server still validates it.
  static const maxCustomTip = 500;

  static String _amount(int rupees) => '$rupees.00';

  Future<void> _set(BuildContext context, WidgetRef ref, String tip) async {
    try {
      await ref.read(cartProvider.notifier).setTip(tip);
    } catch (error) {
      if (context.mounted) {
        showMessage(context, describeErrorWithDetails(context, error));
      }
    }
  }

  Future<void> _custom(BuildContext context, WidgetRef ref) async {
    final rupees = await showDialog<int>(
      context: context,
      builder: (_) => const _CustomTipDialog(max: maxCustomTip),
    );
    if (rupees != null && context.mounted) {
      await _set(context, ref, _amount(rupees));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final tip = ref.watch(cartProvider.select((c) => c.snapshot.bill?.tip));
    final busy = ref.watch(cartProvider.select((c) => c.updating));
    final current = tip ?? '0.00';
    final hasTip = !isZeroAmount(current);
    final isPreset = presets.any((p) => isSameAmount(current, _amount(p)));
    final isCustom = hasTip && !isPreset;

    return Column(
      key: const Key('tip-selector'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          header: true,
          child: Text(l10n.tipTitle, style: theme.textTheme.titleMedium),
        ),
        Text(
          l10n.tipBody,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: JivoSpacing.sm),
        Wrap(
          spacing: JivoSpacing.sm,
          runSpacing: JivoSpacing.sm,
          children: [
            for (final rupees in presets)
              () {
                final label = formatRupees(_amount(rupees));
                final selected = isSameAmount(current, _amount(rupees));
                return Semantics(
                  label: l10n.tipChipSemantics(label),
                  child: ChoiceChip(
                    key: ValueKey('tip-$rupees'),
                    label: Text(label),
                    selected: selected,
                    onSelected: busy
                        ? null
                        : (_) => _set(
                            context,
                            ref,
                            selected ? '0.00' : _amount(rupees),
                          ),
                  ),
                );
              }(),
            ChoiceChip(
              key: const Key('tip-custom'),
              label: Text(isCustom ? formatRupees(current) : l10n.tipCustom),
              selected: isCustom,
              onSelected: busy
                  ? null
                  : (_) => isCustom
                        ? _set(context, ref, '0.00')
                        : _custom(context, ref),
            ),
          ],
        ),
      ],
    );
  }
}

class _CustomTipDialog extends StatefulWidget {
  const _CustomTipDialog({required this.max});

  final int max;

  @override
  State<_CustomTipDialog> createState() => _CustomTipDialogState();
}

class _CustomTipDialogState extends State<_CustomTipDialog> {
  final _field = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _field.dispose();
    super.dispose();
  }

  void _submit() {
    final value = int.tryParse(_field.text.trim());
    if (value == null || value < 1 || value > widget.max) {
      setState(
        () =>
            _error = AppLocalizations.of(context).tipCustomInvalid(widget.max),
      );
      return;
    }
    Navigator.pop(context, value);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.tipCustomTitle),
      content: TextField(
        key: const Key('tip-custom-field'),
        controller: _field,
        autofocus: true,
        keyboardType: TextInputType.number,
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter('${widget.max}'.length),
        ],
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => _submit(),
        decoration: InputDecoration(
          labelText: l10n.tipCustomLabel,
          errorText: _error,
          errorMaxLines: 2,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        TextButton(
          key: const Key('tip-custom-save'),
          onPressed: _submit,
          child: Text(l10n.save),
        ),
      ],
    );
  }
}
