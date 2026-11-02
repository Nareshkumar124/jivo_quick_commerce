/// API paths scoped to a store: catalog (`06 §2.4`) and, from Phase 3, the
/// cart (`06 §2.5`).
const _storeScopedPrefixes = [
  '/api/v1/home/',
  '/api/v1/categories/',
  '/api/v1/products/',
  '/api/v1/search/',
  '/api/v1/collections/',
  '/api/v1/cart/',
];

/// The `X-Store-Id` header for a request to [path], or none: only
/// store-scoped calls carry it, and only once a store is known.
Map<String, String> storeHeaders(String path, int? storeId) {
  if (storeId == null) return const {};
  final uriPath = Uri.parse(path).path;
  final scoped = _storeScopedPrefixes.any(uriPath.startsWith);
  return scoped ? {'X-Store-Id': '$storeId'} : const {};
}
