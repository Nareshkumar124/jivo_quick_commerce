# jivo_api

The Dart API client and models for the Jivo Quick Commerce backend.

## Generated code: do not hand-edit

This package is **generated** from the backend's OpenAPI contract,
`backend/openapi/schema.yaml`, by the script `packages/tool/generate_api.sh`.

- **Never hand-edit** files in this package. Manual changes are overwritten
  on the next generation, and they let the client drift from the contract.
  This README and `analysis_options.yaml` are the only hand-maintained files.
- To pick up an API change, update `backend/openapi/schema.yaml` (owned by
  the backend), then regenerate. The script works from any directory. Then
  run `flutter pub get` in each app that uses this package:

  ```sh
  packages/tool/generate_api.sh
  (cd customer_app && flutter pub get)
  ```

- During parallel runs, regenerate once per sync point and by one actor only
  (see `docs/development-phase.md`).
- Contract gaps (missing endpoints, wrong shapes) go to the backend developer.
  Do not work around them here.
- CI regenerates the package and fails if the result differs from the commit.

## Generator (decision D-13)

- openapi-generator **7.26.0**, `dart-dio` generator, json_serializable models.
  The jar is downloaded from Maven Central, checked against a pinned SHA-256,
  and cached in `~/.cache/jivo/openapi-generator/`. It needs Java 11+ and
  python3.
- Before generating, `packages/tool/normalize_openapi.py` collapses a
  `oneOf` of same-type primitives into that type. drf-spectacular emits one for
  every blank-allowed format field (e.g. `Me.email`), and dart-dio would turn
  it into a model class that doesn't compile.
- Enums tolerate unknown values (`unknownDefaultOpenApi`), because additive
  API changes are allowed in v1.
- `format: decimal` maps to `String`, so money stays a decimal string and is
  never a double (`02 §5`). `date-time` maps to a UTC `DateTime`.
- The script also writes `pubspec.yaml` (keeping `resolution: workspace`), runs
  build_runner for the `.g.dart` parts, formats, and analyzes the result.

## Using the client

Pass the app's shared Dio (from `jivo_core`'s `createJivoDio`) **and** an
explicit interceptor list. Without `interceptors:`, the generated constructor
adds its own auth interceptors to that shared Dio.

```dart
final api = JivoApi(dio: ref.watch(dioProvider), interceptors: const []);
final cart = await api.getCartApi().cartRetrieve(xStoreId: storeId);
```

- Paths in the schema already include `/api/v1/`, so the Dio base URL is the
  backend origin (`AppEnv.apiBaseUrl`).
- Operations that declare the `X-Store-Id` header take it as a parameter.
- Errors surface as `DioException`. Convert them with `ApiError.from(e)` from
  jivo_core.

## Status

Generated from the Phase 1 contract: auth (OTP, token refresh, logout),
account (`me`, devices, deletion), `config/app`, addresses, and health. The generated
`ApiError` model has the same name as jivo_core's `ApiError`; import this
package with `show` (for example `show JivoApi`) where both are used.
