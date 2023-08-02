import 'dart:math';
import 'dart:ui';

import 'geometry_shape.dart';
import 'point.dart';

class LineSegment extends GeometryInfo {
  final Point start;
  final Point end;
  final Path _path = Path();

  LineSegment(this.start, this.end, {Map<String, dynamic>? properties})
      : super(properties) {
    _path.moveTo(start.x, start.y);
    _path.lineTo(end.x, end.y);
  }

  bool contains(Point point) {
    return _path.contains(Offset(point.x, point.y));
  }

  LineSegment get reversed {
    return LineSegment(end.copy(), start.copy());
  }

  bool intersectWith(LineSegment segment) {
    if (!_quickRejectionExperiment(segment)) return false;
    return _straddleExperiment(segment);
  }

  bool parallelTo(LineSegment segment) {
    Point fromVector = Point(end.x - start.x, end.y - start.y);
    Point toVector =
        Point(segment.end.x - segment.start.x, segment.end.y - segment.start.y);
    double result = fromVector.x * toVector.y - toVector.x * fromVector.y;
    return result == 0;
  }

  GeometryRelation relationTo(Point point) {
    if (start == point || end == point) {
      return GeometryRelation.onEndPoint;
    }

    if (contains(point)) {
      return GeometryRelation.contains;
    }

    return GeometryRelation.isolated;
  }

  bool _quickRejectionExperiment(LineSegment segment) {
    bool a = min(start.x, end.x) <= max(segment.start.x, segment.end.x);
    bool b = min(segment.start.x, segment.end.x) <= max(start.x, end.x);
    bool c = min(start.y, end.y) <= max(segment.start.y, segment.end.y);
    bool d = min(segment.start.y, segment.end.y) <= max(start.y, end.y);
    bool result = (a == true && b == true && c == true && d == true);
    return result;
  }

  bool _straddleExperiment(LineSegment segment) {
    bool a = ((segment.start.x - start.x) * (segment.start.y - segment.end.y) -
                (segment.start.y - start.y) *
                    (segment.start.x - segment.end.x)) *
            ((segment.start.x - end.x) * (segment.start.y - segment.end.y) -
                (segment.start.y - end.y) * (segment.start.x - segment.end.x)) <
        0;
    bool b = ((start.x - segment.start.x) * (start.y - end.y) -
                (start.y - segment.start.y) * (start.x - end.x)) *
            ((start.x - segment.end.x) * (start.y - end.y) -
                (start.y - segment.end.y) * (start.x - end.x)) <
        0;
    if (a == true && b == true) {
      return true;
    }

    return false;
  }

  Point? intersectionPoint(LineSegment segment) {
    if (!intersectWith(segment)) return null;

    double tmpLeft, tmpRight;
    tmpLeft = (segment.end.x - segment.start.x) * (start.y - end.y) -
        (end.x - start.x) * (segment.start.y - segment.end.y);
    tmpRight = (start.y - segment.start.y) *
            (end.x - start.x) *
            (segment.end.x - segment.start.x) +
        segment.start.x *
            (segment.end.y - segment.start.y) *
            (end.x - start.x) -
        start.x * (end.y - start.y) * (segment.end.x - segment.start.x);
    double x = tmpRight / tmpLeft;

    tmpLeft = (start.x - end.x) * (segment.end.y - segment.start.y) -
        (end.y - start.y) * (segment.start.x - segment.end.x);
    tmpRight = end.y * (start.x - end.x) * (segment.end.y - segment.start.y) +
        (segment.end.x - end.x) *
            (segment.end.y - segment.start.y) *
            (start.y - end.y) -
        segment.end.y * (segment.start.x - segment.end.x) * (end.y - start.y);
    double y = tmpRight / tmpLeft;

    return Point(x, y);
  }

  @override
  void clearInfo() {
    super.clearInfo();
    start.clearInfo();
    end.clearInfo();
  }

  @override
  String toString() {
    String _string =
        properties.isEmpty ? '\n' : '\nprops -> ${properties.toString()}\n';
    _string += '[•]${start.toString()}\n';
    _string += '[*]${end.toString()}';
    return _string;
  }

  @override
  Map<String, dynamic> toGeoJSON({Map<String, dynamic>? properties}) {
    Map<String, dynamic> map = {
      'type': 'Feature',
      'geometry': {
        'type': 'LineString',
        'coordinates': [
          [start.y, start.x],
          [end.y, end.x]
        ]
      },
      'properties': properties ?? this.properties
    };

    return map;
  }

  @override
  LineSegment copy() =>
      LineSegment(start.copy(), end.copy(), properties: properties);

  @override
  LineSegment copyWith(
          {Point? start, Point? end, Map<String, dynamic>? properties}) =>
      LineSegment(start ?? this.start, end ?? this.end, properties: properties);

  @override
  int get hashCode => start.hashCode ^ end.hashCode;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is LineSegment &&
            runtimeType == other.runtimeType &&
            start == other.start &&
            end == other.end;
  }
}
