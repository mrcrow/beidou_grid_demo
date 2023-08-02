import 'dart:math';

import 'geometry_shape.dart';

const double eps = 0.0000000001;

class Point extends GeometryInfo {
  final double x;
  final double y;
  Point(this.x, this.y, {Map<String, dynamic>? properties}) : super(properties);

  @override
  String toString() {
    String _string = '\n($x,$y)';
    if (properties.isNotEmpty) {
      _string = _string + '[${properties.toString()}]';
    }

    return _string;
  }

  @override
  Map<String, dynamic> toGeoJSON({Map<String, dynamic>? properties}) {
    Map<String, dynamic> map = {
      'type': 'Feature',
      'geometry': {
        'type': 'Point',
        'coordinates': [y, x]
      },
      'properties': properties ?? this.properties
    };

    return map;
  }

  @override
  int get hashCode => x.hashCode ^ y.hashCode;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is Point &&
            runtimeType == other.runtimeType &&
            distanceTo(other) <= eps;
  }

  double distanceTo(Point point) {
    return sqrt(pow(x - point.x, 2) + pow(y - point.y, 2));
  }

  @override
  Point copy() => Point(x, y, properties: properties);

  @override
  Point copyWith({double? x, double? y, Map<String, dynamic>? properties}) =>
      Point(x ?? this.x, y ?? this.y, properties: properties);
}
