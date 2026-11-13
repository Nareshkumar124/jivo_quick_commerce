import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../l10n/generated/app_localizations.dart';

/// Lets the customer type a quantity instead of tapping + many times (bulk
/// orders, e.g. 100 cartons of water). Opened by tapping the stepper's
/// number.
///
/// Digits only, prefilled with [current]. Allowed: 0 (removes the line) to
/// [max] (the stepper's cap, `orderable_quantity`), never 1 to [min] - 1.
/// Anything else is refused inline and nothing is sent. Returns the new
/// quantity, or null when cancelled or unchanged. The caller sends it in
/// one request; the server still checks it.
Future<int?> showQuantityDialog(
  BuildContext context, {
  required int current,
  required int max,
  required int min,
}) => showDialog<int>(
  context: context,
  builder: (context) =>
      _QuantityDialog(current: current, max: max, min: min < 1 ? 1 : min),
);

class _QuantityDialog extends StatefulWidget {
  const _QuantityDialog({
    required this.current,
    required this.max,
    required this.min,
  });

  final int current;
  final int max;
  final int min;

  @override
  State<_QuantityDialog> createState() => _QuantityDialogState();
}

class _QuantityDialogState extends State<_QuantityDialog> {
  late final _field = TextEditingController(text: '${widget.current}')
    ..selection = TextSelection(
      baseOffset: 0,
      extentOffset: '${widget.current}'.length,
    );
  String? _error;

  @override
  void dispose() {
    _field.dispose();
    super.dispose();
  }

  /// The inline reason [quantity] can't be sent, or null when it can.
  String? _problem(AppLocalizations l10n, int? quantity) {
    if (quantity == null) return l10n.typeQuantityEmpty;
    if (quantity > widget.max) {
      return widget.max <= 0 ? l10n.outOfStock : l10n.maxQtyReached(widget.max);
    }
    if (quantity > 0 && quantity < widget.min) {
      return l10n.minQtyPerOrder(widget.min);
    }
    return null;
  }

  void _submit() {
    final quantity = int.tryParse(_field.text);
    final problem = _problem(AppLocalizations.of(context), quantity);
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }
    Navigator.of(context).pop(quantity == widget.current ? null : quantity);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      key: const Key('qty-dialog'),
      title: Text(l10n.typeQuantityTitle),
      content: TextField(
        key: const Key('qty-field'),
        controller: _field,
        autofocus: true,
        keyboardType: TextInputType.number,
        textInputAction: TextInputAction.done,
        // Whole numbers only: no sign, decimal point or spaces.
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(5),
        ],
        decoration: InputDecoration(
          labelText: l10n.typeQuantityField,
          helperText: l10n.typeQuantityHint,
          errorText: _error,
          errorMaxLines: 3,
        ),
        onChanged: (_) {
          if (_error != null) setState(() => _error = null);
        },
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          key: const Key('qty-cancel'),
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          key: const Key('qty-update'),
          onPressed: _submit,
          child: Text(l10n.typeQuantityUpdate),
        ),
      ],
    );
  }
}
