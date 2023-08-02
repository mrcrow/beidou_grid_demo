import 'dart:ui';

import 'geometry_operator.dart';
import 'geometry_shape.dart';
import 'line_segment.dart';
import 'point.dart';
import 'polyline.dart';

class Polygon extends GeometryInfo {
  final String identifier;
  late Point gravityCenter;

  final Path _path = Path();
  Path get path => _path;

  bool _closed = false;
  bool get isClosed => _closed;
  bool get isEmpty => _points.isEmpty;

  final List<Point> _points = [];
  List<Point> get points => _points;

  List<LineSegment> get lineSegments {
    List<LineSegment> results = [];

    List<Point> source = _points.map((e) => e.copy()).toList();
    for (int i = 0; i < source.length; i++) {
      int startIndex = i;
      int endIndex = i + 1;
      if (endIndex == source.length) {
        endIndex = 0;
      }

      Point start = source[startIndex];
      Point end = source[endIndex];
      results.add(LineSegment(start, end));
    }

    return results;
  }

  Polyline? get polyline {
    if (_points.length < 2) return null;

    List<Point> source = _points.map((e) => e.copy()).toList();
    if (source.length == 2) return Polyline(points: source);

    if (_closed) {
      Point first = source.first;
      source.add(first.copy());
    }

    return Polyline(points: source);
  }

  Polygon(this.identifier,
      {List<Point>? points, Map<String, dynamic>? properties})
      : super(properties) {
    if (points != null && points.isNotEmpty) {
      for (var element in points) {
        addPoint(element);
      }

      closeShape();
    }
  }

  void addPoint(Point point) {
    if (_closed) return;
    if (_points.contains(point)) return;

    _points.add(point);
    if (_points.length == 1) {
      _path.moveTo(point.x, point.y);
    } else {
      _path.lineTo(point.x, point.y);
    }
  }

  void closeShape() {
    path.close();
    _closed = true;
    _generateGravityCenter();
  }

  void _generateGravityCenter() {
    double x = 0, y = 0, factor = 0;
    for (var value in lineSegments) {
      double temp =
          (value.end.y * value.start.x - value.end.x * value.start.y) / 2.0;
      factor += temp;
      y += temp * (value.end.y + value.start.y) / 3.0;
      x += temp * (value.end.x + value.start.x) / 3.0;
    }

    gravityCenter = Point(x / factor, y / factor);
  }

  void reset() {
    _path.reset();
    _points.clear();
    _closed = false;
  }

  List<Point>? intersectionPointsTo(LineSegment segment) {
    List<Point> results = [];
    for (LineSegment element in lineSegments) {
      Point? point = element.intersectionPoint(segment);
      if (point != null) {
        results.add(point);
      }
    }

    if (results.isNotEmpty) {
      return results;
    }

    return null;
  }

  bool intersectWith(Polygon polygon) {
    bool intersect = false;

    for (LineSegment line in lineSegments) {
      for (LineSegment targetLine in polygon.lineSegments) {
        if (line.intersectWith(targetLine)) {
          intersect = true;
          break;
        }
      }
    }

    return intersect;
  }

  bool shareLinesWith(Polygon polygon) {
    assert(isClosed && polygon.isClosed,
        'Polygons should be closed before relation determine');

    List<LineSegment> fromSegments = lineSegments;
    List<LineSegment> toSegments = polygon.lineSegments;

    for (LineSegment fromSegment in fromSegments) {
      for (LineSegment toSegment in toSegments) {
        if (!fromSegment.parallelTo(toSegment)) break;
        if (fromSegment == toSegment || fromSegment == toSegment.reversed) {
          return true;
        }

        GeometryRelation fromFRelation =
            toSegment.relationTo(fromSegment.start);
        GeometryRelation fromTRelation = toSegment.relationTo(fromSegment.end);
        GeometryRelation toFRelation = fromSegment.relationTo(toSegment.start);
        GeometryRelation toTRelation = fromSegment.relationTo(toSegment.end);

        List<Point> onPoints = [];

        if (fromFRelation == GeometryRelation.contains) {
          onPoints.add(fromSegment.start);
        }

        if (fromTRelation == GeometryRelation.contains) {
          onPoints.add(fromSegment.end);
        }

        if (toFRelation == GeometryRelation.contains) {
          onPoints.add(toSegment.start);
        }

        if (toTRelation == GeometryRelation.contains) {
          onPoints.add(toSegment.end);
        }

        if (onPoints.isNotEmpty) {
          return true;
        }
      }
    }

    return false;
  }

  List<Point> relationMarkedPoints(Polygon polygon) {
    assert(isClosed && polygon.isClosed && polyline != null,
        'Polygons should be closed before relation determine');

    List<Point> source = polyline!.points;
    for (int i = 0; i < source.length; i++) {
      Point point = source[i];
      GeometryRelation relation = polygon.relationToPoint(point);
      point['relation'] = relation.rawValue;
    }

    return source;
  }

  void markPolylineRelation(Polyline polyline) {
    List<Point> points = polyline.points;
    for (int i = 0; i < points.length; i++) {
      Point point = points[i];
      GeometryRelation relation = relationToPoint(point);
      polyline.setPointProperty(i, 'relation', relation.rawValue);
    }
  }

  Polyline? relationMarkedPolyline(Polygon polygon) {
    assert(isClosed && polygon.isClosed,
        'Polygons should be closed before relation determine');

    Polyline? line = polygon.polyline;
    if (line == null) return null;

    markPolylineRelation(line);

    return line;
  }

  GeometryRelation relationToPoint(Point point) {
    assert(isClosed, 'Polygon should be closed before relation determine');

    GeometryRelation relation = GeometryRelation.isolated;
    Polyline? line = polyline;
    if (line != null) {
      GeometryRelation lineRelation = polyline!.relationTo(point);
      switch (lineRelation) {
        case GeometryRelation.isolated:
          if (_path.contains(Offset(point.x, point.y))) {
            relation = GeometryRelation.contains;
          }
          break;

        case GeometryRelation.contains:
          relation = GeometryRelation.onLines;
          break;

        default:
          break;
      }
    }

    return relation;
  }

  GeometryRelation relationToPolygon(Polygon polygon) {
    assert(isClosed && polygon.isClosed,
        'Polygons should be closed before operation');
    bool shareLines = shareLinesWith(polygon);

    Polyline? fromLine = relationMarkedPolyline(polygon);
    Polyline? toLine = polygon.relationMarkedPolyline(this);
    assert(fromLine != null && toLine != null,
        'Relation marked polyline should not be null');

    Polyline fromPolyline = fromLine!;
    Polyline toPolyline = toLine!;

    String key = 'relation';
    int fromInsides = fromPolyline.numberOfPointProperty(
        key, GeometryRelation.contains.rawValue);
    int toInsides = toPolyline.numberOfPointProperty(
        key, GeometryRelation.contains.rawValue);
    int fromOutsides = fromPolyline.numberOfPointProperty(
        key, GeometryRelation.isolated.rawValue);
    int toOutsides = toPolyline.numberOfPointProperty(
        key, GeometryRelation.isolated.rawValue);

    GeometryRelation relation = GeometryRelation.intersected;
    if (shareLines) {
      if (fromInsides + toInsides == 0) {
        relation = GeometryRelation.onLines;
      } else {
        // no insides
        if (fromOutsides == 0 && toOutsides > 0) {
          relation = GeometryRelation.beenInvolved;
        } else if (fromOutsides > 0 && toOutsides == 0) {
          relation = GeometryRelation.contains;
        } else {
          relation = GeometryRelation.intersected;
        }
      }
    } else {
      if (!intersectWith(polygon)) {
        if (fromInsides == 0 && toInsides == 0) {
          relation = GeometryRelation.isolated;
        } else if (fromOutsides == 0 && toOutsides > 0) {
          relation = GeometryRelation.beenInvolved;
        } else if (fromOutsides > 0 && toOutsides == 0) {
          relation = GeometryRelation.contains;
        }
      }
    }

    return relation;
  }

  List<Polygon>? operation(PathOperation operation, Polygon other) {
    switch (operation) {
      case PathOperation.intersect:
        return intersect(other);
      case PathOperation.union:
        {
          var result = union(other);
          if (result != null) {
            return [result];
          }

          return null;
        }
      case PathOperation.difference:
        return difference(other);
      case PathOperation.reverseDifference:
        return reverseDifference(other);
      case PathOperation.xor:
        return xor(other);
    }
  }

  List<Polygon>? intersect(Polygon other) {
    assert(isClosed && other.isClosed,
        'Polygons should be closed before operation');
    return PolygonOperator.intersect(this, other);
  }

  Polygon? union(Polygon other) {
    assert(isClosed && other.isClosed,
        'Polygons should be closed before operation');
    return PolygonOperator.union(this, other);
  }

  List<Polygon>? difference(Polygon other) {
    assert(isClosed && other.isClosed,
        'Polygons should be closed before operation');
    return PolygonOperator.difference(this, other);
  }

  List<Polygon>? reverseDifference(Polygon other) {
    assert(isClosed && other.isClosed,
        'Polygons should be closed before operation');
    return PolygonOperator.reverseDifference(this, other);
  }

  List<Polygon>? xor(Polygon other) {
    assert(isClosed && other.isClosed,
        'Polygons should be closed before operation');
    return PolygonOperator.xor(this, other);
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
    coordinates.add([_points.first.y, _points.first.x]); // close polygon

    Map<String, dynamic> map = {
      'type': 'Feature',
      'geometry': {
        'type': 'Polygon',
        'coordinates': [coordinates]
      },
      'properties': properties ?? this.properties
    };

    return map;
  }

  @override
  String toString() {
    String _string = '\nid -> $identifier\n';
    _string += properties.isEmpty ? '' : 'props -> ${properties.toString()}\n';

    for (int i = 0; i < _points.length; i++) {
      Point point = _points[i];
      _string += '[$i]${point.toString()}\n';
    }

    return _string;
  }

  @override
  Polygon copy() => Polygon(identifier,
      points: _points.map((e) => e.copy()).toList(), properties: properties);

  @override
  Polygon copyWith(
          {String? identifier,
          List<Point>? points,
          Map<String, dynamic>? properties}) =>
      Polygon(identifier ?? this.identifier,
          points: points ?? this.points, properties: properties);

  @override
  int get hashCode => _points.hashCode;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is Polygon &&
            runtimeType == other.runtimeType &&
            _points == other.points;
  }
}
