import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jivo_core/jivo_core.dart';

import '../../../../l10n/generated/app_localizations.dart';
import '../../../../shared/widgets/state_views.dart';
import '../../domain/cart.dart';
import '../cart_controller.dart';

/// Delivery instructions (`03 §2.8`): chips that save as they are toggled,
/// plus a free-text note saved with its button or the keyboard action.
class InstructionsSelector extends ConsumerStatefulWidget {
  const InstructionsSelector({super.key});

  @override
  ConsumerState<InstructionsSelector> createState() =>
      _InstructionsSelectorState();
}

class _InstructionsSelectorState extends ConsumerState<InstructionsSelector> {
  late final TextEditingController _note;

  @override
  void initState() {
    super.initState();
    _note = TextEditingController(
      text: ref.read(cartProvider).snapshot.instructions.note,
    )..addListener(_changed);
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  void _changed() => setState(() {});

  DeliveryInstructions get _saved =>
      ref.read(cartProvider).snapshot.instructions;

  Future<void> _save(DeliveryInstructions instructions, {String? done}) async {
    try {
      await ref.read(cartProvider.notifier).setInstructions(instructions);
      if (done != null && mounted) showMessage(context, done);
    } catch (error) {
      if (mounted) {
        showMessage(context, describeErrorWithDetails(context, error));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final instructions = ref.watch(
      cartProvider.select((c) => c.snapshot.instructions),
    );
    final busy = ref.watch(cartProvider.select((c) => c.updating));
    final noteChanged = _note.text.trim() != instructions.note.trim();

    String label(InstructionTag tag) => switch (tag) {
      InstructionTag.dontRingBell => l10n.instructionDontRingBell,
      InstructionTag.leaveAtDoor => l10n.instructionLeaveAtDoor,
      InstructionTag.avoidCalling => l10n.instructionAvoidCalling,
    };

    return Column(
      key: const Key('instructions-selector'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          header: true,
          child: Text(
            l10n.instructionsTitle,
            style: theme.textTheme.titleMedium,
          ),
        ),
        const SizedBox(height: JivoSpacing.sm),
        Wrap(
          spacing: JivoSpacing.sm,
          runSpacing: JivoSpacing.sm,
          children: [
            for (final tag in InstructionTag.values)
              FilterChip(
                key: ValueKey('instruction-${tag.wireValue}'),
                label: Text(label(tag)),
                selected: instructions.tags.contains(tag),
                onSelected: busy
                    ? null
                    : (selected) {
                        final tags = {..._saved.tags};
                        selected ? tags.add(tag) : tags.remove(tag);
                        _save(_saved.copyWith(tags: tags));
                      },
              ),
          ],
        ),
        const SizedBox(height: JivoSpacing.md),
        TextField(
          key: const Key('instructions-note'),
          controller: _note,
          maxLength: DeliveryInstructions.maxNoteLength,
          minLines: 1,
          maxLines: 3,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => noteChanged
              ? _save(
                  _saved.copyWith(note: _note.text.trim()),
                  done: l10n.instructionsSaved,
                )
              : null,
          decoration: InputDecoration(
            labelText: l10n.instructionsNoteLabel,
            suffixIcon: noteChanged
                ? IconButton(
                    key: const Key('instructions-save'),
                    tooltip: l10n.save,
                    onPressed: busy
                        ? null
                        : () => _save(
                            _saved.copyWith(note: _note.text.trim()),
                            done: l10n.instructionsSaved,
                          ),
                    icon: const Icon(Icons.check),
                  )
                : null,
          ),
        ),
      ],
    );
  }
}
