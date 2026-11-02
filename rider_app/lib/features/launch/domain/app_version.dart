/// Compares dotted version strings numerically: negative if [a] < [b], zero
/// if equal, positive if [a] > [b].
///
/// Tolerant of what servers and stores send: missing parts count as 0
/// (`1.2` == `1.2.0`), pre-release/build suffixes are ignored
/// (`1.2.0-beta+3` == `1.2.0`) and non-numeric parts count as 0.
int compareVersions(String a, String b) {
  final left = _parts(a);
  final right = _parts(b);
  final length = left.length > right.length ? left.length : right.length;
  for (var i = 0; i < length; i++) {
    final l = i < left.length ? left[i] : 0;
    final r = i < right.length ? right[i] : 0;
    if (l != r) return l.compareTo(r);
  }
  return 0;
}

List<int> _parts(String version) {
  final core = version.trim().split(RegExp('[-+]')).first;
  if (core.isEmpty) return const [];
  return [for (final part in core.split('.')) int.tryParse(part.trim()) ?? 0];
}
