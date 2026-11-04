import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/primary_action_bar.dart';
import '../../../shared/widgets/sensitive_number_field.dart';
import '../domain/image_picking.dart';
import '../domain/kyc_document.dart';
import '../domain/masking.dart';
import '../domain/validators.dart';
import 'onboarding_controllers.dart';
import 'onboarding_providers.dart';
import 'onboarding_text.dart';

/// Capture and upload one KYC document: camera or gallery, compression to
/// <= 1 MB, a preview with Retake, the document number (masked once typed),
/// then upload. Closes itself when the upload succeeds.
class DocumentCaptureScreen extends ConsumerStatefulWidget {
  const DocumentCaptureScreen({
    required this.type,
    this.recovered,
    this.fromProfile = false,
    super.key,
  });

  final KycDocumentType type;

  /// Opened from the ACTIVE rider's profile documents (04 §2.9) rather than
  /// the application steps.
  final bool fromProfile;

  /// A photo recovered after Android stopped the app mid-capture.
  final PickedImage? recovered;

  @override
  ConsumerState<DocumentCaptureScreen> createState() =>
      _DocumentCaptureScreenState();
}

class _DocumentCaptureScreenState extends ConsumerState<DocumentCaptureScreen> {
  final _number = TextEditingController();
  FieldError? _numberError;

  KycDocumentType get _type => widget.type;

  DocumentCaptureController get _controller =>
      ref.read(documentCaptureControllerProvider(_type).notifier);

  @override
  void initState() {
    super.initState();
    // The RC carries the vehicle number given at registration.
    if (_type == KycDocumentType.vehicleRc) {
      _number.text =
          ref.read(riderProfileControllerProvider).value?.vehicleNumber ?? '';
    }
    final recovered = widget.recovered;
    if (recovered != null) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _controller.recover(recovered),
      );
    }
  }

  @override
  void dispose() {
    _number.dispose();
    super.dispose();
  }

  Future<void> _upload() async {
    FocusScope.of(context).unfocus();
    final error = validateDocumentNumber(_type, _number.text);
    setState(() => _numberError = error);
    if (error != null) return;
    await _controller.upload(number: _type.hasNumber ? _number.text : null);
  }

  String _masked(String value) => _type == KycDocumentType.aadhaarFront
      ? Masking.aadhaar(value)
      : Masking.trailing(value);

  (TextInputType, List<TextInputFormatter>) _numberInput() => switch (_type) {
    KycDocumentType.aadhaarFront => (
      TextInputType.number,
      [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(12),
      ],
    ),
    KycDocumentType.pan => (
      TextInputType.visiblePassword,
      [
        const UpperCaseTextFormatter(),
        FilteringTextInputFormatter.allow(RegExp('[A-Za-z0-9]')),
        LengthLimitingTextInputFormatter(10),
      ],
    ),
    KycDocumentType.drivingLicence => (
      TextInputType.visiblePassword,
      [
        const UpperCaseTextFormatter(),
        FilteringTextInputFormatter.allow(RegExp('[A-Za-z0-9 -]')),
        LengthLimitingTextInputFormatter(20),
      ],
    ),
    KycDocumentType.vehicleRc => (
      TextInputType.visiblePassword,
      [
        const UpperCaseTextFormatter(),
        FilteringTextInputFormatter.allow(RegExp('[A-Za-z0-9 ]')),
        LengthLimitingTextInputFormatter(14),
      ],
    ),
    KycDocumentType.photo || KycDocumentType.aadhaarBack => (
      TextInputType.text,
      const <TextInputFormatter>[],
    ),
  };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final state = ref.watch(documentCaptureControllerProvider(_type));

    ref.listen(documentCaptureControllerProvider(_type), (previous, next) {
      if (next.step == CaptureStep.done && previous?.step != CaptureStep.done) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.docUploaded(documentName(l10n, _type)))),
        );
        if (context.canPop()) {
          context.pop();
        } else {
          context.go(
            widget.fromProfile ? Routes.profileDocuments : Routes.documents,
          );
        }
      }
    });

    final Widget body = switch (state.step) {
      CaptureStep.choose => _ChooseSource(
        type: _type,
        problem: state.problem,
        onPick: _controller.pick,
      ),
      CaptureStep.processing || CaptureStep.done => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(l10n.captureProcessing, key: const Key('capture-processing')),
          ],
        ),
      ),
      CaptureStep.preview || CaptureStep.uploading => Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: ColoredBox(
                    color: theme.colorScheme.surfaceContainerHighest,
                    child: Image.memory(
                      state.image!.bytes,
                      key: const Key('capture-preview'),
                      height: 280,
                      fit: BoxFit.contain,
                      gaplessPlayback: true,
                      errorBuilder: (_, _, _) => const SizedBox(
                        height: 280,
                        child: Icon(Icons.image_not_supported, size: 64),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.captureReady,
                  key: const Key('capture-ready'),
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 4),
                Text(l10n.captureCheck, style: theme.textTheme.bodyLarge),
                if (_type.hasNumber) ...[
                  const SizedBox(height: 16),
                  Builder(
                    builder: (context) {
                      final (keyboard, formatters) = _numberInput();
                      return SensitiveNumberField(
                        fieldKey: const Key('capture-number'),
                        controller: _number,
                        label: documentNumberLabel(l10n, _type),
                        masked: _masked,
                        maskedHelper: l10n.numberMaskedHelper,
                        keyboardType: keyboard,
                        inputFormatters: formatters,
                        textCapitalization:
                            _type == KycDocumentType.aadhaarFront
                            ? TextCapitalization.none
                            : TextCapitalization.characters,
                        errorText: _numberError == null
                            ? null
                            : fieldErrorText(l10n, _numberError!),
                        onChanged: (_) {
                          if (_numberError != null) {
                            setState(() => _numberError = null);
                          }
                        },
                      );
                    },
                  ),
                ],
              ],
            ),
          ),
          PrimaryActionBar(
            buttonKey: const Key('capture-upload'),
            label: l10n.captureUpload,
            busy: state.step == CaptureStep.uploading,
            onPressed: _upload,
            errorKey: const Key('capture-upload-error'),
            error: state.uploadError == null
                ? null
                : onboardingErrorText(context, state.uploadError!),
            secondary: [
              OutlinedButton.icon(
                key: const Key('capture-retake'),
                onPressed: state.step == CaptureStep.uploading
                    ? null
                    : _controller.retake,
                icon: const Icon(Icons.replay),
                label: Text(l10n.captureRetake),
              ),
            ],
          ),
        ],
      ),
    };

    return Scaffold(
      appBar: AppBar(title: Text(documentName(l10n, _type))),
      body: body,
    );
  }
}

/// Before a photo is picked: what a good photo looks like, any problem with
/// the last one, then camera (primary) or gallery.
class _ChooseSource extends StatelessWidget {
  const _ChooseSource({
    required this.type,
    required this.problem,
    required this.onPick,
  });

  final KycDocumentType type;
  final CaptureProblem? problem;
  final void Function(ImagePickSource source) onPick;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final problemText = switch (problem) {
      null => null,
      CaptureProblem.pickerUnavailable => l10n.captureProblemPicker,
      CaptureProblem.unreadable => l10n.captureProblemUnreadable,
      CaptureProblem.tooLarge => l10n.captureProblemTooLarge,
    };
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Icon(
                type.isSelfie ? Icons.face : Icons.document_scanner_outlined,
                size: 96,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(height: 24),
              Text(
                type.isSelfie ? l10n.captureHintPhoto : l10n.captureHintCard,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium,
              ),
            ],
          ),
        ),
        PrimaryActionBar(
          buttonKey: const Key('capture-camera'),
          label: l10n.captureTakePhoto,
          onPressed: () => onPick(ImagePickSource.camera),
          errorKey: const Key('capture-problem'),
          error: problemText,
          secondary: [
            OutlinedButton.icon(
              key: const Key('capture-gallery'),
              onPressed: () => onPick(ImagePickSource.gallery),
              icon: const Icon(Icons.photo_library_outlined),
              label: Text(l10n.captureChooseGallery),
            ),
          ],
        ),
      ],
    );
  }
}
