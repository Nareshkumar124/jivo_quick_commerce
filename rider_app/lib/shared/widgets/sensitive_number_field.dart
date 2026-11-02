import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Upper-cases typed letters (PAN, IFSC, vehicle and licence numbers).
class UpperCaseTextFormatter extends TextInputFormatter {
  const UpperCaseTextFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) => newValue.copyWith(text: newValue.text.toUpperCase());
}

/// A field for a document or bank account number (09 §3.3, D-14):
/// - readable while the rider types it;
/// - obscured once they move on, with only the masked form ([masked], e.g.
///   `XXXX XXXX 1234`) shown under it;
/// - no keyboard suggestions or autocorrect, so the number is not learned
///   by the keyboard;
/// - optionally no paste ([allowPaste]), for confirm fields.
class SensitiveNumberField extends StatefulWidget {
  const SensitiveNumberField({
    required this.controller,
    required this.label,
    required this.masked,
    required this.maskedHelper,
    this.fieldKey,
    this.hint,
    this.errorText,
    this.keyboardType = TextInputType.number,
    this.inputFormatters = const [],
    this.textCapitalization = TextCapitalization.none,
    this.allowPaste = true,
    this.onChanged,
    super.key,
  });

  final TextEditingController controller;
  final String label;

  /// The masked form of the current text.
  final String Function(String value) masked;

  /// Helper text for the masked form, e.g. `Entered as XXXX XXXX 1234`.
  final String Function(String masked) maskedHelper;
  final Key? fieldKey;
  final String? hint;
  final String? errorText;
  final TextInputType keyboardType;
  final List<TextInputFormatter> inputFormatters;
  final TextCapitalization textCapitalization;
  final bool allowPaste;
  final ValueChanged<String>? onChanged;

  @override
  State<SensitiveNumberField> createState() => _SensitiveNumberFieldState();
}

class _SensitiveNumberFieldState extends State<SensitiveNumberField> {
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(_onFocusChange);
  }

  void _onFocusChange() => setState(() {});

  @override
  void dispose() {
    _focus
      ..removeListener(_onFocusChange)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = widget.controller.text;
    final hidden = !_focus.hasFocus && text.isNotEmpty;
    return TextField(
      key: widget.fieldKey,
      controller: widget.controller,
      focusNode: _focus,
      obscureText: hidden,
      autocorrect: false,
      enableSuggestions: false,
      enableIMEPersonalizedLearning: false,
      keyboardType: widget.keyboardType,
      textCapitalization: widget.textCapitalization,
      inputFormatters: widget.inputFormatters,
      enableInteractiveSelection: widget.allowPaste,
      contextMenuBuilder: widget.allowPaste
          ? (context, state) => AdaptiveTextSelectionToolbar.editableText(
              editableTextState: state,
            )
          : null,
      style: Theme.of(context).textTheme.titleLarge,
      decoration: InputDecoration(
        labelText: widget.label,
        hintText: widget.hint,
        errorText: widget.errorText,
        helperText: hidden && widget.errorText == null
            ? widget.maskedHelper(widget.masked(text))
            : null,
      ),
      onChanged: widget.onChanged,
    );
  }
}
