import '../domain/location_point.dart';
import '../domain/point_store.dart';

/// Non-durable [PointStore], for tests and when no file system is available.
class InMemoryPointStore implements PointStore {
  InMemoryPointStore([List<LocationPoint> initial = const []])
    : _points = [...initial];

  final List<LocationPoint> _points;

  /// Number of [append] and [replaceAll] calls, for tests.
  int appendCalls = 0;
  int replaceCalls = 0;

  List<LocationPoint> get points => List.unmodifiable(_points);

  @override
  Future<List<LocationPoint>> load() async => [..._points];

  @override
  Future<void> append(List<LocationPoint> points) async {
    appendCalls++;
    _points.addAll(points);
  }

  @override
  Future<void> replaceAll(List<LocationPoint> points) async {
    replaceCalls++;
    _points
      ..clear()
      ..addAll(points);
  }
}
