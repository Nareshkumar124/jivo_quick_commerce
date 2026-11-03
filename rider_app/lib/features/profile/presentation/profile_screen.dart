import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:jivo_api/jivo_api.dart' show RiderStatusEnum;
import 'package:jivo_core/jivo_core.dart';

import '../../../app/routes.dart';
import '../../../l10n/app_localizations.dart';
import '../../auth/domain/indian_mobile.dart';
import '../../auth/domain/rider_account.dart';
import '../../auth/presentation/rider_account_controller.dart';
import '../../onboarding/domain/rider_profile.dart';
import '../../onboarding/presentation/onboarding_providers.dart';
import '../../onboarding/presentation/onboarding_text.dart';

/// Profile (04 §2.9, screen 18): photo, name, phone, home store, vehicle,
/// KYC status and rating, from `GET /rider/me/`, and the documents.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final profile = ref.watch(riderProfileControllerProvider);
    final value = profile.value;
    final Widget body;
    if (value != null) {
      body = _ProfileBody(profile: value);
    } else if (profile.hasError) {
      body = Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                onboardingErrorText(context, ApiError.from(profile.error!)),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              FilledButton(
                key: const Key('profile-retry'),
                onPressed: () =>
                    ref.read(riderProfileControllerProvider.notifier).reload(),
                child: Text(l10n.retry),
              ),
            ],
          ),
        ),
      );
    } else {
      body = const Center(child: CircularProgressIndicator());
    }
    return Scaffold(
      appBar: AppBar(title: Text(l10n.profileTitle)),
      body: body,
    );
  }
}

class _ProfileBody extends ConsumerWidget {
  const _ProfileBody({required this.profile});

  final RiderProfile profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final account = ref.watch(riderAccountControllerProvider);
    final phone = account is AccountLoaded ? account.user.phone : null;
    final store = profile.homeStore ?? profile.preferredStore;
    final photo = profile.photoUrl;
    final safePhoto = Uri.tryParse(photo ?? '')?.scheme == 'https';
    final vehicle = [
      vehicleName(l10n, profile.vehicleType),
      ?profile.vehicleNumber,
    ].join(' · ');

    return RefreshIndicator(
      onRefresh: ref.read(riderProfileControllerProvider.notifier).reload,
      child: ListView(
        key: const Key('profile-list'),
        padding: const EdgeInsets.all(16),
        children: [
          Center(
            child: CircleAvatar(
              key: const Key('profile-photo'),
              radius: 48,
              // Only an https URL (a short-lived signed URL from the private
              // bucket) is loaded.
              foregroundImage: safePhoto ? NetworkImage(photo!) : null,
              onForegroundImageError: safePhoto ? (_, _) {} : null,
              child: const Icon(Icons.person, size: 48),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            profile.fullName,
            key: const Key('profile-name'),
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall,
          ),
          if (phone != null)
            Text(
              IndianMobile.format(phone),
              key: const Key('profile-phone'),
              textAlign: TextAlign.center,
            ),
          const SizedBox(height: 16),
          Card(
            child: Column(
              children: [
                _InfoRow(
                  key: const Key('profile-store'),
                  icon: Icons.store,
                  label: l10n.profileHomeStore,
                  value: l10n.registerStoreOption(store.name, store.city),
                ),
                _InfoRow(
                  key: const Key('profile-vehicle'),
                  icon: Icons.two_wheeler,
                  label: l10n.profileVehicle,
                  value: vehicle,
                ),
                _InfoRow(
                  key: const Key('profile-kyc'),
                  icon: Icons.verified_user,
                  label: l10n.profileKycStatus,
                  value: _kycText(l10n, profile.status),
                ),
                _InfoRow(
                  key: const Key('profile-rating'),
                  icon: Icons.star,
                  label: l10n.profileRating,
                  value: profile.rating == null
                      ? l10n.profileNoRating
                      : l10n.profileRatingValue(profile.rating!),
                ),
                if (profile.bankAccount case final bank?)
                  _InfoRow(
                    key: const Key('profile-bank'),
                    icon: Icons.account_balance,
                    label: l10n.bankTitle,
                    value: l10n.bankSaved(bank.accountNumberMasked, bank.ifsc),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              key: const Key('profile-documents'),
              minTileHeight: 64,
              leading: const Icon(Icons.badge_outlined),
              title: Text(l10n.documentsTitle),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push(Routes.profileDocuments),
            ),
          ),
        ],
      ),
    );
  }

  static String _kycText(AppLocalizations l10n, RiderStatusEnum status) =>
      switch (status) {
        RiderStatusEnum.ACTIVE => l10n.profileKycApproved,
        RiderStatusEnum.PENDING_KYC => l10n.docStatusPending,
        RiderStatusEnum.REJECTED => l10n.statusRejectedTitle,
        RiderStatusEnum.SUSPENDED => l10n.statusSuspendedTitle,
        _ => l10n.statusUnknownTitle,
      };
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    super.key,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    child: Row(
      children: [
        Icon(icon, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: Theme.of(context).textTheme.bodySmall),
              Text(value, style: Theme.of(context).textTheme.titleMedium),
            ],
          ),
        ),
      ],
    ),
  );
}
