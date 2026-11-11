import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jivo_core/helpers.dart';

import '../../../app/repositories.dart';
import '../../location/data/reverse_geocoder.dart';
import '../../location/domain/delivery_location.dart';
import '../../location/presentation/delivery_controller.dart';
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
    // The delivery location must not keep a deleted address's id.
    await ref.read(deliveryProvider.notifier).forgetAddress(id);
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
    this.pinLine,
    this.parts,
    this.locating = false,
    this.locationFailure,
    this.saving = false,
    this.error,
  });

  /// The address's pin (`03 §2.4`: required). Editing keeps the saved one
  /// until the customer moves it.
  final GeoPoint? point;

  /// The address under [point] when known: the map picker's or the
  /// geocoder's line, the saved address, or the delivery location carried
  /// over. Null for a bare GPS fix.
  final String? pinLine;

  /// What the geocoder found at [point]; the form fills its empty fields.
  final AddressParts? parts;
  final bool locating;
  final LocationFailure? locationFailure;
  final bool saving;
  final Object? error;

  AddressFormState copyWith({
    GeoPoint? point,
    String? pinLine,
    bool clearPinLine = false,
    AddressParts? parts,
    bool? locating,
    LocationFailure? locationFailure,
    bool clearFailure = false,
    bool? saving,
    Object? error,
    bool clearError = false,
  }) => AddressFormState(
    point: point ?? this.point,
    pinLine: clearPinLine ? null : (pinLine ?? this.pinLine),
    parts: parts ?? this.parts,
    locating: locating ?? this.locating,
    locationFailure: clearFailure
        ? null
        : (locationFailure ?? this.locationFailure),
    saving: saving ?? this.saving,
    error: clearError ? null : (error ?? this.error),
  );
}

/// Add/edit an address (`03 §2.4`, CA-07): the pin comes first, from the
/// map picker, the delivery location carried over ("Save this location"),
/// the saved address (edit) or, without a map, the device location.
class AddressFormController extends Notifier<AddressFormState> {
  @override
  AddressFormState build() => const AddressFormState();

  /// Starts from a saved address (edit) or from the delivery location the
  /// customer already chose ([initial], e.g. a map pin).
  void start({SavedAddress? existing, DeliveryLocation? initial}) {
    if (existing != null) {
      state = AddressFormState(
        point: (lat: existing.input.lat, lng: existing.input.lng),
        pinLine: existing.summary,
      );
    } else if (initial != null) {
      state = AddressFormState(point: initial.point, pinLine: initial.subtitle);
      unawaited(_lookUp(initial.point));
    }
  }

  /// A pin from the map picker, with the address it showed.
  Future<void> setPin(GeoPoint point, {String? line}) async {
    state = state.copyWith(
      point: point,
      pinLine: line,
      clearPinLine: line == null,
      clearFailure: true,
    );
    await _lookUp(point);
  }

  /// Address parts for prefilling, only where a map (and so the geocoder's
  /// config) is available.
  Future<void> _lookUp(GeoPoint point) async {
    final bool hasMap;
    try {
      hasMap = await ref.read(mapsAvailableProvider.future);
    } catch (_) {
      return;
    }
    if (!hasMap || !ref.mounted) return;
    final parts = await ref.read(reverseGeocoderProvider).partsAt(point);
    if (!ref.mounted || parts == null || state.point != point) return;
    state = state.copyWith(parts: parts, pinLine: state.pinLine ?? parts.line);
  }

  Future<void> locate() async {
    if (state.locating) return;
    state = state.copyWith(locating: true, clearFailure: true);
    try {
      final point = await ref.read(deviceLocationProvider).current();
      if (!ref.mounted) return;
      state = state.copyWith(point: point, locating: false, clearPinLine: true);
      await _lookUp(point);
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

  /// Saves; [build] gets the pin. Returns the saved address, or null (the
  /// error is in [AddressFormState.error]).
  Future<SavedAddress?> save({
    required int? id,
    required AddressInput Function(GeoPoint point) build,
  }) async {
    final point = state.point;
    if (point == null || state.saving) return null;
    state = state.copyWith(saving: true, clearError: true);
    try {
      final repository = ref.read(addressRepositoryProvider);
      final input = build(point);
      final saved = id == null
          ? await repository.create(input)
          : await repository.update(id, input);
      ref.invalidate(addressListProvider);
      if (ref.mounted) state = state.copyWith(saving: false);
      return saved;
    } catch (error) {
      if (ref.mounted) state = state.copyWith(saving: false, error: error);
      return null;
    }
  }
}

final addressFormProvider =
    NotifierProvider.autoDispose<AddressFormController, AddressFormState>(
      AddressFormController.new,
    );
