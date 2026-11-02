/// Compares two app versions such as `1.2.0` and `1.10.0` numerically.
///
/// Returns a negative number if [a] < [b], zero if equal, positive if [a] >
/// [b]. Missing segments count as 0 (`1.2` == `1.2.0`). A pre-release or
/// build suffix (`1.2.0-dev`, `1.2.0+5`) is ignored, as are non-numeric
/// segments (treated as 0).
int compareAppVersions(String a, String b) {
  final left = _segments(a);
  final right = _segments(b);
  final length = left.length > right.length ? left.length : right.length;
  for (var i = 0; i < length; i++) {
    final l = i < left.length ? left[i] : 0;
    final r = i < right.length ? right[i] : 0;
    if (l != r) return l.compareTo(r);
  }
  return 0;
}

/// Whether [current] is below [minimum]. False when [minimum] is null or
/// empty (the backend sends null when it has no rule for the app/platform).
bool isVersionBelow(String current, String? minimum) {
  if (minimum == null || minimum.trim().isEmpty) return false;
  return compareAppVersions(current, minimum) < 0;
}

List<int> _segments(String version) {
  final core = version.trim().split(RegExp('[-+]')).first;
  if (core.isEmpty) return const [];
  return [for (final part in core.split('.')) int.tryParse(part) ?? 0];
}
