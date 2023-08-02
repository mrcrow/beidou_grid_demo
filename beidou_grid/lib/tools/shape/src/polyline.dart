import 'dart:ui';

import 'package:flutter/material.dart';

import 'geometry_shape.dart';
import 'line_segment.dart';
import 'point.dart';

class Polyline extends GeometryInfo {
  final List<Point> _points = [];
  final Path _path = Path();

  List<Point> get points => _points;
  bool get isEmpty => _points.isEmpty;

  Point? get start => _points.isEmpty ? null : _points.first;
  Point? get end => _points.isEmpty ? null : _points.last;

  bool get isClosedPolyline => start != null && end != null && start == end;

  Polyline({List<Point>? points, Map<String, dynamic>? properties})
      : super(properties) {
    if (points != null && points.isNotEmpty) {
      for (var element in points) {
        addPoint(element);
      }
    }
  }

  List<LineSegment> get lineSegments {
    List<LineSegment> results = [];
    List<Point> source = _points.map((e) => e.copy()).toList();
    for (int i = 0; i < source.length - 1; i++) {
      Point start = source[i];
      Point end = source[i + 1];
      results.add(LineSegment(start, end));
    }

    return results;
  }

  void addPoint(Point point) {
    if (end != null && end == point) return;

    _points.add(point);
    if (_points.length == 1) {
      _path.moveTo(point.x, point.y);
    } else {
      _path.lineTo(point.x, point.y);
    }
  }

  void insertPoint(Point point, Point from, Point to) {
    if (_points.contains(point)) return;

    int fromIndex;
    if (from == start) {
      fromIndex = 0;
    } else {
      fromIndex = _points.indexOf(from);
    }

    int toIndex;
    if (to == end) {
      toIndex = _points.length - 1;
    } else {
      toIndex = _points.indexOf(to);
    }

    List<Point> internals = _points.sublist(fromIndex + 1, toIndex);

    if (internals.isEmpty) {
      int index = fromIndex + 1;
      _points.insert(index, point);
    } else {
      int index = _getInsertIndex(point, internals, from);
      int insertIndex = fromIndex + index + 1;
      _points.insert(insertIndex, point);
    }

    _reconstructPath();
  }

  void addPoints(List<Point> values) {
    for (var value in values) {
      addPoint(value);
    }
  }

  int _getInsertIndex(Point point, List<Point> internals, Point begin) {
    List<Point> points = internals.map((e) {
      double distance = e.distanceTo(begin);
      Point copy = e.copy();
      copy['distance'] = distance;
      return copy;
    }).toList();

    Point copy = point.copy();
    copy['distance'] = copy.distanceTo(begin);
    points.add(copy);

    points.sort((lh, rh) {
      double ld = lh['distance'];
      double rd = rh['distance'];
      return ld > rd ? 1 : 0;
    });
    int index = points.indexOf(point);

    return index;
  }

  void clear() {
    _points.clear();
    _path.reset();
  }

  void _reconstructPath() {
    _path.reset();
    bool moved = false;
    for (var point in _points) {
      if (moved) {
        _path.lineTo(point.x, point.y);
      } else {
        moved = true;
        _path.moveTo(point.x, point.y);
      }
    }
  }

  bool isConnectable(Polyline line) {
    if (isEmpty || line.isEmpty) return false;
    return start == line.start ||
        start == line.end ||
        end == line.start ||
        end == line.end;
  }

  void connect(Polyline line) {
    assert(!isClosedPolyline && !line.isClosedPolyline && isConnectable(line),
        'Connect failed with conditions');

    var source = points;
    var connectable = line.points.map((e) => e.copy()).toList();
    List<Point> results = [];
    if (start == line.start) {
      results.addAll(connectable.reversed);
      results.removeLast();
      results.addAll(source);
    } else if (start == line.end) {
      results.addAll(connectable);
      results.removeLast();
      results.addAll(source);
    } else if (end == line.start) {
      results.addAll(source);
      results.removeLast();
      results.addAll(connectable);
    } else if (end == line.end) {
      results.addAll(source);
      results.removeLast();
      results.addAll(connectable.reversed);
    } else {
      assert(false, 'Invalid connection condition');
    }

    clear();
    addPoints(results);
  }

  void setPointProperty(int index, String key, dynamic value) {
    assert(_points.length >= index && index >= 0);

    Point point = _points[index];
    point[key] = value;
  }

  dynamic getPointProperty(int index, String key) {
    assert(_points.length >= index && index >= 0);

    Point point = _points[index];
    return point[key];
  }

  int numberOfPointProperty(String key, dynamic value) {
    int number = 0;

    for (Point point in _points) {
      dynamic stored = point[key];
      if (stored == value) {
        number++;
      }
    }

    return number;
  }

  GeometryRelation relationTo(Point point) {
    if (_points.contains(point)) {
      return GeometryRelation.contains;
    }

    GeometryRelation relation = GeometryRelation.isolated;
    for (LineSegment segment in lineSegments) {
      GeometryRelation segmentRelation = segment.relationTo(point);
      if (segmentRelation == GeometryRelation.contains ||
          segmentRelation == GeometryRelation.onEndPoint) {
        relation = GeometryRelation.contains;
        break;
      }
    }

    return relation;
  }

  @override
  void clearInfo() {
    super.clearInfo();
    for (var value in _points) {
      value.clearInfo();
    }
  }

  @override
  Map<String, dynamic> toGeoJSON({Map<String, dynamic>? properties}) {
    List<dynamic> coordinates = _points.map((e) => [e.y, e.x]).toList();

    Map<String, dynamic> map = {
      'type': 'Feature',
      'geometry': {'type': 'LineString', 'coordinates': coordinates},
      'properties': properties ?? this.properties
    };

    return map;
  }

  @override
  String toString() {
    String _string =
        properties.isEmpty ? '\n' : '\nprops -> ${properties.toString()}\n';

    for (int i = 0; i < _points.length; i++) {
      Point point = _points[i];
      _string += '[$i]${point.toString()}\n';
    }

    return _string;
  }

  @override
  Polyline copy() => Polyline(
      points: points.map((e) => e.copy()).toList(), properties: properties);

  @override
  Polyline copyWith({List<Point>? points, Map<String, dynamic>? properties}) =>
      Polyline(points: points ?? this.points, properties: properties);

  @override
  int get hashCode => _points.hashCode;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is Polyline &&
            runtimeType == other.runtimeType &&
            _points == other.points;
  }
}
