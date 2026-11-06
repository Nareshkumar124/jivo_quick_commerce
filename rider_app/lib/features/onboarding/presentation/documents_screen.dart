import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:jivo_core/jivo_core.dart';

import '../../../app/routes.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/primary_action_bar.dart';
import '../../launch/presentation/blocking_message.dart';
import '../domain/kyc_document.dart';
import '../domain/rider_profile.dart';
import 'onboarding_providers.dart';
import 'onboarding_text.dart';

/// Document upload (04 §2.2, screen 4): every required document with its
/// status (needed, in review, approved, rejected with the reviewer's note)
/// and the masked number. Tapping one opens its capture screen (upload,
/// replace or re-upload). Approved documents are locked.
class DocumentsScreen extends ConsumerStatefulWidget {
  const DocumentsScreen({this.fromProfile = false, super.key});

  /// From the ACTIVE rider's profile (04 §2.9): the documents and their
  /// review status, without the application steps (no step counter, no
  /// Continue). A document ops rejected (or a missing one) can be uploaded
  /// again; approved ones stay locked.
  final bool fromProfile;

  @override
  ConsumerState<DocumentsScreen> createState() => _DocumentsScreenState();
}

class _DocumentsScreenState extends ConsumerState<DocumentsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _recoverLostPhoto());
  }

  String _captureRoute(KycDocumentType type) => widget.fromProfile
      ? Routes.profileDocumentCapture(type.wireValue)
      : Routes.documentCapture(type.wireValue);

  /// Android may have stopped the app while the camera was open (low RAM):
  /// the photo comes back now and goes to the document it was taken for.
  Future<void> _recoverLostPhoto() async {
    final pending = ref.read(pendingCaptureStoreProvider);
    final type = await pending.read();
    if (type == null) return;
    final lost = await ref.read(kycImagePickerProvider).retrieveLost();
    await pending.clear();
    if (lost == null || !mounted) return;
    await context.push(_captureRoute(type), extra: lost);
  }

  Future<void> _continue(RiderProfile profile) async {
    if (!profile.hasBankAccount) {
      context.go(Routes.bankDetails);
      return;
    }
    // Back to the status screen; a reload picks up a status change (e.g. a
    // rejected application going back to review).
    final reload = ref.read(riderProfileControllerProvider.notifier).reload();
    context.pop();
    await reload;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final profileState = ref.watch(riderProfileControllerProvider);
    final profile = profileState.value;

    final Widget body;
    Widget? bottom;
    if (profile == null) {
      body = profileState.hasError
          ? BlockingMessage(
              icon: Icons.cloud_off,
              title: l10n.onboardingLoadError,
              body: onboardingErrorText(
                context,
                ApiError.from(profileState.error!),
              ),
              actions: [
                FilledButton(
                  onPressed: () => ref
                      .read(riderProfileControllerProvider.notifier)
                      .reload(),
                  child: Text(l10n.retry),
                ),
              ],
            )
          : const Center(child: CircularProgressIndicator());
    } else {
      final firstTime =
          !widget.fromProfile &&
          profile.stage == OnboardingStage.needsDocuments &&
          profile.rejectedDocuments.isEmpty;
      body = ListView(
        key: const Key('documents-list'),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          if (firstTime) ...[
            Text(
              l10n.onboardingStepOf(2, 3),
              style: theme.textTheme.labelLarge,
            ),
            const SizedBox(height: 4),
          ],
          Text(
            widget.fromProfile
                ? l10n.documentsProfileIntro
                : l10n.documentsIntro,
            style: theme.textTheme.bodyLarge,
          ),
          if (widget.fromProfile && !profile.documentsComplete) ...[
            const SizedBox(height: 12),
            _AttentionBanner(
              text: l10n.documentsNeedAttention(
                profile.missingDocuments.length +
                    profile.rejectedDocuments.length,
              ),
            ),
          ],
          const SizedBox(height: 16),
          for (final type in profile.requiredDocuments)
            _DocumentTile(
              type: type,
              document: profile.documentOf(type),
              onOpen: () => context.push(_captureRoute(type)),
            ),
        ],
      );
      // The bottom bar, so the "uploaded" snack bar appears above Continue
      // instead of covering it.
      bottom = PrimaryActionBar(
        buttonKey: const Key('documents-continue'),
        label: profile.hasBankAccount ? l10n.done : l10n.documentsContinue,
        hint: profile.documentsComplete
            ? null
            : l10n.documentsProgress(
                profile.documentsDone,
                profile.requiredDocuments.length,
              ),
        onPressed: profile.documentsComplete ? () => _continue(profile) : null,
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(l10n.documentsTitle)),
      body: body,
      bottomNavigationBar: widget.fromProfile ? null : bottom,
    );
  }
}

class _DocumentTile extends StatelessWidget {
  const _DocumentTile({
    required this.type,
    required this.document,
    required this.onOpen,
  });

  final VoidCallback onOpen;

  final KycDocumentType type;
  final RiderDocument? document;

  static IconData _icon(KycDocumentType type) => switch (type) {
    KycDocumentType.photo => Icons.face,
    KycDocumentType.aadhaarFront ||
    KycDocumentType.aadhaarBack => Icons.badge_outlined,
    KycDocumentType.pan => Icons.credit_card,
    KycDocumentType.drivingLicence => Icons.card_membership,
    KycDocumentType.vehicleRc => Icons.two_wheeler,
  };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final doc = document;
    final status = doc?.status;
    final statusColor = switch (status) {
      null => scheme.onSurfaceVariant,
      DocumentReviewStatus.pending => scheme.primary,
      DocumentReviewStatus.approved => scheme.primary,
      DocumentReviewStatus.rejected => scheme.error,
    };
    final canOpen = doc?.canReplace ?? true;
    final action = doc == null
        ? l10n.docActionUpload
        : status == DocumentReviewStatus.rejected
        ? l10n.docActionReupload
        : l10n.docActionReplace;

    return Card(
      key: Key('doc-${type.wireValue}'),
      shape: status == DocumentReviewStatus.rejected
          ? RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: scheme.error, width: 2),
            )
          : null,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: canOpen ? onOpen : null,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 80),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(_icon(type), size: 36, color: scheme.primary),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        documentName(l10n, type),
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        documentStatusLabel(l10n, status),
                        key: Key('doc-${type.wireValue}-status'),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: statusColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (doc?.numberMasked case final masked?)
                        Text(masked, style: theme.textTheme.bodyMedium),
                      if (status == DocumentReviewStatus.rejected &&
                          doc?.reviewNote != null)
                        Text(
                          doc!.reviewNote!,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: scheme.error,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                if (canOpen)
                  Text(
                    action,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: scheme.primary,
                    ),
                  )
                else if (status == DocumentReviewStatus.approved)
                  Icon(Icons.verified, color: scheme.primary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Profile mode: some documents need a (new) upload.
class _AttentionBanner extends StatelessWidget {
  const _AttentionBanner({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      key: const Key('documents-attention'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.errorContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: scheme.onErrorContainer),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: scheme.onErrorContainer,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
