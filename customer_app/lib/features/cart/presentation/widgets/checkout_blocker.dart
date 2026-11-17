import 'package:flutter/material.dart';
import 'package:jivo_core/jivo_core.dart';

/// Why checkout is blocked (the server's first blocker), above the
/// checkout button on the cart and checkout screens (CA-20): 14 sp / 500
/// with a leading info icon, so it isn't missed next to the button.
class CheckoutBlockerText extends StatelessWidget {
  const CheckoutBlockerText(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.error;
    return Padding(
      padding: const EdgeInsets.only(bottom: JivoSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ExcludeSemantics(
            child: Icon(Icons.info_outline, size: 20, color: color),
          ),
          const SizedBox(width: JivoSpacing.sm),
          Expanded(
            child: Text(
              text,
              key: const Key('checkout-blocked'),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: color,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Whether the bottom bars stack their total above a full-width button
/// (`customer.textScale.singleColumnFrom`, CA-20).
bool stackCheckoutBar(BuildContext context) =>
    MediaQuery.textScalerOf(context).scale(14) / 14 >= 1.5;
