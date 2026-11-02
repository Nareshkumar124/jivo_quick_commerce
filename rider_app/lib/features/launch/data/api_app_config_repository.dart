import 'package:jivo_api/jivo_api.dart' show AppConfig, JivoApi;
import 'package:jivo_core/jivo_core.dart';

import '../domain/app_config_repository.dart';

class ApiAppConfigRepository implements AppConfigRepository {
  const ApiAppConfigRepository(this._api);

  final JivoApi _api;

  @override
  Future<AppConfig> fetch() async {
    try {
      final response = await _api.getConfigApi().configApp();
      final config = response.data;
      if (config == null) throw const ApiError(code: ApiErrorCode.unknown);
      return config;
    } on Object catch (error) {
      throw ApiError.from(error);
    }
  }
}
