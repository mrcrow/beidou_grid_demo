import 'dart:math';

import 'package:mapbox_gl/mapbox_gl.dart';

import 'geojson.dart';

class BBox {
  final double longMin;
  final double latMin;
  final double longMax;
  final double latMax;

  BBox(this.longMin, this.latMin, this.longMax, this.latMax);

  List<double> get rawValue {
    return [longMin, latMin, longMax, latMax];
  }

  BBox operator +(Object other) {
    assert(other is BBox);
    BBox another = other as BBox;
    List<double> longitudes = [
      longMin,
      longMax,
      another.longMax,
      another.longMin
    ];
    List<double> latitudes = [latMin, latMax, another.latMin, another.latMax];

    longitudes.sort();
    latitudes.sort();

    return BBox(
        longitudes.first, latitudes.first, longitudes.last, latitudes.last);
  }
}

abstract class Geometry implements GeoJSON {
  double get area;

  static getGeometryTypes() {
    return [
      'Point',
      'MultiPoint',
      'LineString',
      'MultiLineString',
      'Polygon',
      'MultiPolygon'
    ];
  }

  factory Geometry.fromMap(Map<String, dynamic> map) {
    assert(map.containsKey('type'), 'Geometry must contains key `type`');
    assert(GeoJSON.getGeoJSONTypes().contains(map['type']),
        'Unknown geometry type');
    return GeoJSON.fromMap(map) as Geometry;
  }

  static bool coordinateValidation(
      List<dynamic> coordinates, Type geometryType) {
    bool nestedLevel(int loop) {
      dynamic values = List.of(coordinates);
      bool valid = true;
      while (loop >= 0) {
        Type type = loop == 0 ? double : List;
        var inside = values.first;
        values = inside;
        valid = inside.runtimeType == type;

        if (!valid) break;
        loop--;
      }

      return valid;
    }

    switch (geometryType) {
      case GeometryPoint:
        return nestedLevel(0);
      case GeometryMultiPoint:
        return nestedLevel(1);
      case GeometryLineString:
        return nestedLevel(1);
      case GeometryMultiLineString:
        return nestedLevel(2);
      case GeometryPolygon:
        return nestedLevel(2);
      case GeometryMultiPolygon:
        return nestedLevel(3);
      default:
        return false;
    }
  }
}

class GeometryPoint implements Geometry {
  List<dynamic> _coordinates = [];
  LatLng get coordinate => LatLng(_coordinates.last, _coordinates.first);

  GeometryPoint(List<dynamic> coordinates)
      : assert(coordinates.length == 2, 'Invalid coordinate length'),
        _coordinates = coordinates;

  factory GeometryPoint.fromMap(Map<String, dynamic> map) {
    String? type = map['type'];
    assert(type != null && type == 'Point', 'Invalid point geometry');

    var coordinates = map['coordinates'];
    assert(
        coordinates != null &&
            Geometry.coordinateValidation(coordinates, GeometryPoint),
        'Invalid point coordinates');
    return GeometryPoint(coordinates);
  }

  @override
  GeoJSONType type = GeoJSONType.point;

  @override
  double get area => 0.0;

  @override
  Map<String, dynamic> get geoJSON =>
      {'type': type.rawValue, 'coordinates': _coordinates};

  @override
  BBox? get boundingBox => null;
}

class GeometryMultiPoint implements Geometry {
  List<dynamic> _coordinates = []; //List<List<double>>
  List<LatLng> get coordinates =>
      _coordinates.map((e) => LatLng(e.last, e.first)).toList();

  GeometryMultiPoint(List<dynamic> coordinates)
      : assert(coordinates.isNotEmpty,
            'The coordinates must contains one or more elements'),
        _coordinates = coordinates;
  factory GeometryMultiPoint.fromMap(Map<String, dynamic> map) {
    String? type = map['type'];
    assert(
        type != null && type == 'MultiPoint', 'Invalid multi-point geometry');

    var coordinates = map['coordinates'];
    assert(
        coordinates != null &&
            Geometry.coordinateValidation(coordinates, GeometryMultiPoint),
        'Invalid multi-point coordinates');
    return GeometryMultiPoint(coordinates);
  }

  @override
  GeoJSONType type = GeoJSONType.multiPoint;

  @override
  BBox? get boundingBox {
    List<double> latitudes = [];
    List<double> longitudes = [];

    for (var element in _coordinates) {
      latitudes.add(element.last);
      longitudes.add(element.first);
    }

    latitudes.sort();
    longitudes.sort();

    return BBox(
      longitudes.first,
      latitudes.first,
      longitudes.last,
      latitudes.last,
    );
  }

  @override
  Map<String, dynamic> get geoJSON =>
      {'type': type.rawValue, 'coordinates': _coordinates};

  @override
  double get area => 0.0;
}

class GeometryLineString implements Geometry {
  List<dynamic> _coordinates = []; //List<List<double>>
  List<LatLng> get coordinates => _coordinates.map((e) {
        List<double> element = e as List<double>;
        return LatLng(element.last, element.first);
      }).toList();

  GeometryLineString(List<dynamic> coordinates)
      : assert(coordinates.isNotEmpty,
            'The coordinates must contains one or more elements'),
        _coordinates = coordinates;
  factory GeometryLineString.fromMap(Map<String, dynamic> map) {
    String? type = map['type'];
    assert(
        type != null && type == 'LineString', 'Invalid line-string geometry');

    var coordinates = map['coordinates'];
    assert(
        coordinates != null &&
            Geometry.coordinateValidation(coordinates, GeometryLineString),
        'Invalid line-string coordinates');
    return GeometryLineString(coordinates);
  }

  @override
  GeoJSONType type = GeoJSONType.lineString;

  @override
  double get area => 0.0;

  @override
  BBox? get boundingBox {
    List<double> latitudes = [];
    List<double> longitudes = [];

    for (var element in _coordinates) {
      latitudes.add(element.last);
      longitudes.add(element.first);
    }

    latitudes.sort();
    longitudes.sort();

    return BBox(
      longitudes.first,
      latitudes.first,
      longitudes.last,
      latitudes.last,
    );
  }

  @override
  Map<String, dynamic> get geoJSON =>
      {'type': type.rawValue, 'coordinates': _coordinates};
}

class GeometryMultiLineString implements Geometry {
  List<dynamic> _coordinates = []; // List<List<List<double>>>
  List<List<LatLng>> get coordinates => _coordinates
      .map((e1) => (e1 as List)
          .map((e2) => LatLng((e2 as List).last, e2.first))
          .toList())
      .toList();

  GeometryMultiLineString(List<dynamic> coordinates)
      : assert(coordinates.isNotEmpty,
            'The coordinates must contains one or more elements'),
        _coordinates = coordinates;

  factory GeometryMultiLineString.fromMap(Map<String, dynamic> map) {
    String? type = map['type'];
    assert(type != null && type == 'MultiLineString',
        'Invalid multi-line-string geometry');

    var coordinates = map['coordinates'];
    assert(
        coordinates != null &&
            Geometry.coordinateValidation(coordinates, GeometryMultiLineString),
        'Invalid multi-lineString coordinates');
    return GeometryMultiLineString(coordinates);
  }

  @override
  GeoJSONType type = GeoJSONType.multiLineString;

  @override
  double get area => 0.0;

  @override
  BBox? get boundingBox {
    List<double> latitudes = [];
    List<double> longitudes = [];

    for (var element in _coordinates) {
      for (var item in element) {
        latitudes.add(item.last);
        longitudes.add(item.first);
      }
    }

    latitudes.sort();
    longitudes.sort();

    return BBox(
      longitudes.first,
      latitudes.first,
      longitudes.last,
      latitudes.last,
    );
  }

  @override
  Map<String, dynamic> get geoJSON =>
      {'type': type.rawValue, 'coordinates': _coordinates};
}

class GeometryPolygon implements Geometry {
  List<dynamic> _coordinates = []; // List<List<List<double>>>
  List<List<LatLng>> get coordinates => _coordinates
      .map((e1) => (e1 as List)
          .map((e2) => LatLng((e2 as List).last, e2.first))
          .toList())
      .toList();

  GeometryPolygon(List<dynamic> coordinates)
      : assert(coordinates.isNotEmpty,
            'The coordinates must contains one or more elements'),
        _coordinates = coordinates;

  factory GeometryPolygon.fromMap(Map<String, dynamic> map) {
    String? type = map['type'];
    assert(type != null && type == 'Polygon', 'Invalid polygon geometry');

    var coordinates = map['coordinates'];
    assert(
        coordinates != null &&
            Geometry.coordinateValidation(coordinates, GeometryPolygon),
        'Invalid polygon coordinates');
    return GeometryPolygon(coordinates);
  }

  @override
  GeoJSONType type = GeoJSONType.polygon;

  @override
  double get area {
    double _ringArea(List<List<double>> ringPos) {
      const kWGS84Radius = 6378137.0;
      const kDegreeToRadians = pi / 180.0;
      var _area = 0.0;
      for (var i = 0; i < ringPos.length - 1; i++) {
        var p1 = ringPos[i];
        var p2 = ringPos[i + 1];
        _area += (p2[0] * kDegreeToRadians - p1[0] * kDegreeToRadians) *
            (2.0 +
                sin(p1[1] * kDegreeToRadians) +
                sin(p2[1] * kDegreeToRadians));
      }
      _area = _area * kWGS84Radius * kWGS84Radius / 2.0;
      return _area.abs();
    }

    var exteriorRing = _coordinates[0];
    var _area = _ringArea(exteriorRing);
    for (var i = 1; i < _coordinates.length; i++) {
      var interiorRing = _coordinates[i];
      _area -= _ringArea(interiorRing);
    }
    return _area;
  }

  @override
  BBox? get boundingBox {
    List<double> latitudes = [];
    List<double> longitudes = [];

    for (var element in _coordinates) {
      for (var item in element) {
        latitudes.add(item.last);
        longitudes.add(item.first);
      }
    }

    latitudes.sort();
    longitudes.sort();

    return BBox(
      longitudes.first,
      latitudes.first,
      longitudes.last,
      latitudes.last,
    );
  }

  @override
  Map<String, dynamic> get geoJSON =>
      {'type': type.rawValue, 'coordinates': _coordinates};
}

class GeometryMultiPolygon implements Geometry {
  List<dynamic> _coordinates = []; //List<List<List<List<double>>>>
  List<List<LatLng>> get coordinates {
    List<List<LatLng>> results = [];
    for (var polygon in _coordinates) {
      List<LatLng> lines = [];
      for (var coordinates in polygon) {
        for (List coordinate in coordinates) {
          LatLng lng = LatLng(coordinate.last, coordinate.first);
          lines.add(lng);
        }
      }

      results.add(lines);
    }

    return results;
  }

  GeometryMultiPolygon(List<dynamic> coordinates)
      : assert(coordinates.isNotEmpty,
            'The coordinates must contains one or more elements'),
        _coordinates = coordinates;

  factory GeometryMultiPolygon.fromMap(Map<String, dynamic> map) {
    String? type = map['type'];
    assert(type != null && type == 'MultiPolygon',
        'Invalid multi-polygon geometry');

    var coordinates = map['coordinates'];
    assert(
        coordinates != null &&
            Geometry.coordinateValidation(coordinates, GeometryMultiPolygon),
        'Invalid multi-polygon coordinates');
    return GeometryMultiPolygon(coordinates);
  }

  @override
  GeoJSONType type = GeoJSONType.multiPolygon;

  @override
  double get area => 0.0;

  @override
  BBox? get boundingBox {
    List<double> latitudes = [];
    List<double> longitudes = [];

    for (var polygon in _coordinates) {
      for (var coordinates in polygon) {
        for (var item in coordinates) {
          latitudes.add(item.last);
          longitudes.add(item.first);
        }
      }
    }

    latitudes.sort();
    longitudes.sort();

    return BBox(
      longitudes.first,
      latitudes.first,
      longitudes.last,
      latitudes.last,
    );
  }

  @override
  Map<String, dynamic> get geoJSON =>
      {'type': type.rawValue, 'coordinates': _coordinates};
}
