import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../app/repositories.dart';
import '../data/device_location.dart';
import '../domain/saved_address.dart';

/// The saved addresses, default first (`03 §2.4`).
class AddressList extends AsyncNotifier<List<SavedAddress>> {
  @override
  Future<List<SavedAddress>> build() =>
      ref.read(addressRepositoryProvider).list();

  Future<void> reload() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(addressRepositoryProvider).list(),
    );
  }

  /// Throws [ApiError] so the screen can show it; the list stays.
  Future<void> setDefault(int id) async {
    await ref.read(addressRepositoryProvider).setDefault(id);
    await _refreshQuietly();
  }

  Future<void> delete(int id) async {
    await ref.read(addressRepositoryProvider).delete(id);
    await _refreshQuietly();
  }

  Future<void> _refreshQuietly() async {
    final result = await AsyncValue.guard(
      () => ref.read(addressRepositoryProvider).list(),
    );
    if (ref.mounted) state = result;
  }
}

final addressListProvider =
    AsyncNotifierProvider<AddressList, List<SavedAddress>>(
      AddressList.new,
      retry: noAutomaticRetry,
    );

@immutable
class AddressFormState {
  const AddressFormState({
    this.point,
    this.locating = false,
    this.locationFailure,
    this.saving = false,
    this.error,
  });

  /// The captured position. Editing keeps the saved one unless re-located.
  final GeoPoint? point;
  final bool locating;
  final LocationFailure? locationFailure;
  final bool saving;
  final Object? error;

  AddressFormState copyWith({
    GeoPoint? point,
    bool? locating,
    LocationFailure? locationFailure,
    bool clearFailure = false,
    bool? saving,
    Object? error,
    bool clearError = false,
  }) => AddressFormState(
    point: point ?? this.point,
    locating: locating ?? this.locating,
    locationFailure: clearFailure
        ? null
        : (locationFailure ?? this.locationFailure),
    saving: saving ?? this.saving,
    error: clearError ? null : (error ?? this.error),
  );
}

/// Add/edit address without a map: the pin is the device location.
class AddressFormController extends Notifier<AddressFormState> {
  @override
  AddressFormState build() => const AddressFormState();

  /// Starts from a saved address (edit).
  void initFrom(SavedAddress? address) {
    if (address == null) return;
    state = AddressFormState(
      point: (lat: address.input.lat, lng: address.input.lng),
    );
  }

  Future<void> locate() async {
    if (state.locating) return;
    state = state.copyWith(locating: true, clearFailure: true);
    try {
      final point = await ref.read(deviceLocationProvider).current();
      if (ref.mounted) state = state.copyWith(point: point, locating: false);
    } on LocationException catch (e) {
      if (ref.mounted) {
        state = state.copyWith(locating: false, locationFailure: e.reason);
      }
    }
  }

  Future<void> openSettings() async {
    final reason = state.locationFailure;
    if (reason != null) {
      await ref.read(deviceLocationProvider).openSettings(reason);
    }
  }

  /// Saves; [build] gets the captured point. Returns true on success.
  Future<bool> save({
    required int? id,
    required AddressInput Function(GeoPoint point) build,
  }) async {
    final point = state.point;
    if (point == null || state.saving) return false;
    state = state.copyWith(saving: true, clearError: true);
    try {
      final repository = ref.read(addressRepositoryProvider);
      final input = build(point);
      if (id == null) {
        await repository.create(input);
      } else {
        await repository.update(id, input);
      }
      ref.invalidate(addressListProvider);
      if (ref.mounted) state = state.copyWith(saving: false);
      return true;
    } catch (error) {
      if (ref.mounted) state = state.copyWith(saving: false, error: error);
      return false;
    }
  }
}

final addressFormProvider =
    NotifierProvider.autoDispose<AddressFormController, AddressFormState>(
      AddressFormController.new,
    );
