import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jivo_core/jivo_core.dart';

import '../../../app/repositories.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/widgets/state_views.dart';
import '../data/ticket_photo_picker.dart';
import '../domain/support_models.dart';

/// The message for a support error: photo problems (type, size, count, a
/// 413 from the server or a proxy) in the app's words, everything else
/// through jivo_core's error messages.
String describeSupportError(BuildContext context, Object error) {
  final l10n = AppLocalizations.of(context);
  final problem = switch (error) {
    TicketPhotoException(:final problem) => problem,
    ApiError(statusCode: 413) => TicketPhotoProblem.rejectedSize,
    _ => null,
  };
  return switch (problem) {
    TicketPhotoProblem.unsupportedType => l10n.ticketPhotoUnsupported,
    TicketPhotoProblem.tooLarge => l10n.ticketPhotoTooLarge(
      ticketPhotoMaxBytes ~/ (1024 * 1024),
    ),
    TicketPhotoProblem.tooMany => l10n.ticketPhotoTooMany(
      ticketPhotosPerMessage,
    ),
    TicketPhotoProblem.rejectedSize => l10n.ticketPhotoRejectedSize,
    null => describeErrorWithDetails(context, error),
  };
}

/// Asks camera or gallery, picks a photo and checks it against the API's
/// limits. Returns it, or null when cancelled or refused (the reason is
/// shown in a snackbar).
Future<PendingTicketPhoto?> pickTicketPhoto(
  BuildContext context,
  WidgetRef ref, {
  required int alreadyPicked,
}) async {
  final l10n = AppLocalizations.of(context);
  if (alreadyPicked >= ticketPhotosPerMessage) {
    showMessage(context, l10n.ticketPhotoTooMany(ticketPhotosPerMessage));
    return null;
  }
  final source = await showModalBottomSheet<TicketPhotoSource>(
    context: context,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            key: const Key('photo-camera'),
            leading: const Icon(Icons.photo_camera_outlined),
            title: Text(l10n.ticketPhotoCamera),
            onTap: () => Navigator.pop(context, TicketPhotoSource.camera),
          ),
          ListTile(
            key: const Key('photo-gallery'),
            leading: const Icon(Icons.photo_library_outlined),
            title: Text(l10n.ticketPhotoGallery),
            onTap: () => Navigator.pop(context, TicketPhotoSource.gallery),
          ),
        ],
      ),
    ),
  );
  if (source == null || !context.mounted) return null;
  TicketPhotoFile? file;
  try {
    file = await ref.read(ticketPhotoPickerProvider).pick(source);
  } on Object {
    if (context.mounted) showMessage(context, l10n.ticketPhotoPickFailed);
    return null;
  }
  if (file == null || !context.mounted) return null;
  final problem = checkTicketPhoto(file);
  if (problem != null) {
    showMessage(
      context,
      describeSupportError(context, TicketPhotoException(problem)),
    );
    return null;
  }
  return PendingTicketPhoto(file);
}

/// The photos picked for a message, each removable, and an add button
/// until [ticketPhotosPerMessage].
class PickedPhotoStrip extends StatelessWidget {
  const PickedPhotoStrip({
    required this.photos,
    required this.enabled,
    required this.onRemove,
    super.key,
  });

  final List<PendingTicketPhoto> photos;
  final bool enabled;
  final ValueChanged<PendingTicketPhoto> onRemove;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SizedBox(
      height: 72,
      child: ListView(
        key: const Key('picked-photos'),
        scrollDirection: Axis.horizontal,
        children: [
          for (final (i, photo) in photos.indexed)
            Padding(
              padding: const EdgeInsets.only(right: JivoSpacing.sm),
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(JivoRadii.sm),
                    child: Image.memory(
                      photo.file.bytes,
                      width: 72,
                      height: 72,
                      fit: BoxFit.cover,
                      semanticLabel: l10n.ticketPhotoOpen(i + 1),
                      errorBuilder: (_, _, _) => const SizedBox.square(
                        dimension: 72,
                        child: Icon(Icons.image_outlined),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 0,
                    right: 0,
                    child: IconButton(
                      key: Key('remove-photo-$i'),
                      tooltip: l10n.ticketPhotoRemove(i + 1),
                      constraints: const BoxConstraints(
                        minWidth: 48,
                        minHeight: 48,
                      ),
                      onPressed: enabled ? () => onRemove(photo) : null,
                      icon: Icon(
                        Icons.cancel,
                        size: 20,
                        color: Theme.of(context).colorScheme.onInverseSurface,
                        shadows: const [Shadow(blurRadius: 4)],
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// A message's photos as thumbnails; a tap shows one full screen. The
/// URLs are signed and short-lived: an expired one shows a placeholder
/// until the thread is refreshed.
class MessagePhotos extends StatelessWidget {
  const MessagePhotos({required this.photos, super.key});

  final List<TicketPhoto> photos;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Wrap(
      spacing: JivoSpacing.sm,
      runSpacing: JivoSpacing.sm,
      children: [
        for (final (i, photo) in photos.indexed)
          Semantics(
            button: true,
            label: l10n.ticketPhotoOpen(i + 1),
            child: InkWell(
              key: Key('message-photo-${photo.key}'),
              onTap: () => showDialog<void>(
                context: context,
                builder: (context) => Dialog(
                  child: InteractiveViewer(
                    child: Image.network(
                      photo.url,
                      errorBuilder: (_, _, _) => Padding(
                        padding: const EdgeInsets.all(JivoSpacing.lg),
                        child: Text(l10n.ticketPhotoUnavailable),
                      ),
                    ),
                  ),
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(JivoRadii.sm),
                child: Image.network(
                  photo.url,
                  width: 96,
                  height: 96,
                  fit: BoxFit.cover,
                  excludeFromSemantics: true,
                  errorBuilder: (_, _, _) => const SizedBox.square(
                    dimension: 96,
                    child: Icon(Icons.broken_image_outlined),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
