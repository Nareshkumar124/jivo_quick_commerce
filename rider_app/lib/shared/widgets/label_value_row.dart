import 'package:flutter/material.dart';

/// Above this text scale the value moves under the label (UX audit RA-16).
const double kStackLabelValueFrom = 1.5;

/// A label with a value on its right. Above 1.5x text the value is stacked
/// under the label so a long date or amount never squeezes the label or
/// overflows. Below that the value wraps inside a `Flexible`.
class LabelValueRow extends StatelessWidget {
  const LabelValueRow({
    super.key,
    required this.label,
    required this.value,
    this.leading,
  });

  final Widget label;
  final Widget value;

  /// Optional icon shown before the label.
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final scale = MediaQuery.textScalerOf(context).scale(10) / 10;
    final stacked = scale > kStackLabelValueFrom;
    final lead = leading == null
        ? const <Widget>[]
        : [leading!, const SizedBox(width: 12)];
    if (stacked) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ...lead,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [label, const SizedBox(height: 2), value],
            ),
          ),
        ],
      );
    }
    return Row(
      children: [
        ...lead,
        Expanded(child: label),
        const SizedBox(width: 8),
        Flexible(
          child: Align(alignment: Alignment.centerRight, child: value),
        ),
      ],
    );
  }
}
