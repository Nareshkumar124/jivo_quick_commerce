import 'package:dio/dio.dart';
import 'package:jivo_api/jivo_api.dart'
    show
        Address,
        AddressLabelEnum,
        AddressRequest,
        JivoApi,
        PatchedAddressRequest;
import 'package:jivo_core/jivo_core.dart';

import '../domain/saved_address.dart';

abstract interface class AddressRepository {
  /// The caller's addresses, default first. Throws [ApiError].
  Future<List<SavedAddress>> list();

  Future<SavedAddress> create(AddressInput input);

  Future<SavedAddress> update(int id, AddressInput input);

  Future<void> delete(int id);

  Future<SavedAddress> setDefault(int id);
}

/// The backend stores coordinates to 6 decimal places.
double roundCoordinate(double value) => (value * 1e6).roundToDouble() / 1e6;

String? _blankToNull(String? value) {
  final trimmed = value?.trim();
  return trimmed == null || trimmed.isEmpty ? null : trimmed;
}

class ApiAddressRepository implements AddressRepository {
  const ApiAddressRepository(this._api);

  final JivoApi _api;

  static const _pageSize = 100;

  @override
  Future<List<SavedAddress>> list() => _guard(() async {
    final addresses = <SavedAddress>[];
    for (var page = 1; ; page++) {
      final result = (await _api.getAddressesApi().addressesList(
        page: page,
        pageSize: _pageSize,
      )).data!;
      addresses.addAll(result.results.map(_fromApi));
      if (result.next == null) return addresses;
    }
  });

  @override
  Future<SavedAddress> create(AddressInput input) => _guard(
    () async => _fromApi(
      (await _api.getAddressesApi().addressesCreate(
        addressRequest: _toRequest(input),
      )).data!,
    ),
  );

  @override
  Future<SavedAddress> update(int id, AddressInput input) => _guard(() async {
    final request = _toRequest(input);
    final patch = PatchedAddressRequest(
      label: request.label,
      customLabel: input.customLabel?.trim() ?? '',
      receiverName: request.receiverName,
      receiverPhone: request.receiverPhone,
      house: request.house,
      buildingStreet: request.buildingStreet,
      landmark: input.landmark?.trim() ?? '',
      area: input.area?.trim() ?? '',
      city: request.city,
      state: request.state,
      pincode: request.pincode,
      lat: request.lat,
      lng: request.lng,
    );
    return _fromApi(
      (await _api.getAddressesApi().addressesUpdate(
        id: id,
        patchedAddressRequest: patch,
      )).data!,
    );
  });

  @override
  Future<void> delete(int id) =>
      _guard(() => _api.getAddressesApi().addressesDelete(id: id));

  @override
  Future<SavedAddress> setDefault(int id) => _guard(
    () async => _fromApi(
      (await _api.getAddressesApi().addressesSetDefault(id: id)).data!,
    ),
  );

  static AddressRequest _toRequest(AddressInput input) => AddressRequest(
    label: switch (input.label) {
      AddressLabel.home => AddressLabelEnum.home,
      AddressLabel.work => AddressLabelEnum.work,
      AddressLabel.other => AddressLabelEnum.other,
    },
    customLabel: _blankToNull(input.customLabel),
    receiverName: _blankToNull(input.receiverName),
    receiverPhone: _blankToNull(input.receiverPhone),
    house: input.house.trim(),
    buildingStreet: input.buildingStreet.trim(),
    landmark: _blankToNull(input.landmark),
    area: _blankToNull(input.area),
    city: input.city.trim(),
    state: input.state.trim(),
    pincode: input.pincode.trim(),
    lat: roundCoordinate(input.lat),
    lng: roundCoordinate(input.lng),
  );

  static SavedAddress _fromApi(Address a) => SavedAddress(
    id: a.id,
    isDefault: a.isDefault,
    isServiceable: a.isServiceable,
    input: AddressInput(
      label: switch (a.label) {
        AddressLabelEnum.home => AddressLabel.home,
        AddressLabelEnum.work => AddressLabel.work,
        _ => AddressLabel.other,
      },
      customLabel: _blankToNull(a.customLabel),
      house: a.house,
      buildingStreet: a.buildingStreet,
      landmark: _blankToNull(a.landmark),
      area: _blankToNull(a.area),
      city: a.city,
      state: a.state,
      pincode: a.pincode,
      receiverName: _blankToNull(a.receiverName),
      receiverPhone: _blankToNull(a.receiverPhone),
      lat: a.lat,
      lng: a.lng,
    ),
  );
}

Future<T> _guard<T>(Future<T> Function() call) async {
  try {
    return await call();
  } on DioException catch (e) {
    throw ApiError.fromDioException(e);
  }
}

/// TODO(api): a backend stand-in for `--dart-define=FAKE_API=true` and tests.
/// Mirrors the contract: the first address becomes the default; deleting
/// the default promotes the most recent remaining one.
class FakeAddressRepository implements AddressRepository {
  FakeAddressRepository([List<SavedAddress>? initial]) : _items = [...?initial];

  final List<SavedAddress> _items;
  ApiError? listError;
  ApiError? saveError;
  final List<AddressInput> saved = [];
  int _nextId = 100;

  List<SavedAddress> get items => List.unmodifiable(_items);

  @override
  Future<List<SavedAddress>> list() async {
    final error = listError;
    if (error != null) throw error;
    return [
      ..._items.where((a) => a.isDefault),
      ..._items.where((a) => !a.isDefault),
    ];
  }

  @override
  Future<SavedAddress> create(AddressInput input) async {
    final error = saveError;
    if (error != null) throw error;
    saved.add(input);
    final address = SavedAddress(
      id: _nextId++,
      input: input,
      isDefault: _items.isEmpty,
    );
    _items.add(address);
    return address;
  }

  @override
  Future<SavedAddress> update(int id, AddressInput input) async {
    final error = saveError;
    if (error != null) throw error;
    saved.add(input);
    final index = _items.indexWhere((a) => a.id == id);
    if (index < 0) {
      throw const ApiError(code: ApiErrorCode.notFound, statusCode: 404);
    }
    final updated = SavedAddress(
      id: id,
      input: input,
      isDefault: _items[index].isDefault,
    );
    _items[index] = updated;
    return updated;
  }

  @override
  Future<void> delete(int id) async {
    final index = _items.indexWhere((a) => a.id == id);
    if (index < 0) {
      throw const ApiError(code: ApiErrorCode.notFound, statusCode: 404);
    }
    final removed = _items.removeAt(index);
    if (removed.isDefault && _items.isNotEmpty) {
      final last = _items.removeLast();
      _items.add(SavedAddress(id: last.id, input: last.input, isDefault: true));
    }
  }

  @override
  Future<SavedAddress> setDefault(int id) async {
    for (var i = 0; i < _items.length; i++) {
      final a = _items[i];
      _items[i] = SavedAddress(id: a.id, input: a.input, isDefault: a.id == id);
    }
    return _items.firstWhere((a) => a.id == id);
  }
}
