import 'geometry.dart';

enum GeoJSONType {
  feature,
  featureCollection,
  geometryCollection,
  point,
  multiPoint,
  lineString,
  multiLineString,
  polygon,
  multiPolygon
}

extension GeoJSONTypeRawValue on GeoJSONType {
  String get rawValue {
    var _str = '';
    switch (this) {
      case GeoJSONType.featureCollection:
        _str = 'FeatureCollection';
        break;
      case GeoJSONType.feature:
        _str = 'Feature';
        break;
      case GeoJSONType.point:
        _str = 'Point';
        break;
      case GeoJSONType.multiPoint:
        _str = 'MultiPoint';
        break;
      case GeoJSONType.lineString:
        _str = 'LineString';
        break;
      case GeoJSONType.multiLineString:
        _str = 'MultiLineString';
        break;
      case GeoJSONType.polygon:
        _str = 'Polygon';
        break;
      case GeoJSONType.multiPolygon:
        _str = 'MultiPolygon';
        break;
      case GeoJSONType.geometryCollection:
        _str = 'GeometryCollection';
        break;
    }

    return _str;
  }
}

abstract class GeoJSON {
  GeoJSONType get type;
  Map<String, dynamic> get geoJSON;
  BBox? get boundingBox;

  static GeoJSONType getGeoJSONType(String string) {
    switch (string) {
      case 'Point':
        return GeoJSONType.point;
      case 'MultiPoint':
        return GeoJSONType.multiPoint;
      case 'LineString':
        return GeoJSONType.lineString;
      case 'MultiLineString':
        return GeoJSONType.multiLineString;
      case 'Polygon':
        return GeoJSONType.polygon;
      case 'MultiPolygon':
        return GeoJSONType.multiPolygon;
      case 'Feature':
        return GeoJSONType.feature;
      case 'FeatureCollection':
        return GeoJSONType.featureCollection;
      case 'GeometryCollection':
      default:
        return GeoJSONType.geometryCollection;
    }
  }

  static List<String> getGeoJSONTypes() {
    return [
      'Point',
      'MultiPoint',
      'LineString',
      'MultiLineString',
      'Polygon',
      'MultiPolygon',
      'Feature',
      'FeatureCollection',
      'GeometryCollection'
    ];
  }

  static Map<String, dynamic> getForeignMembers(Map<String, dynamic> map) {
    Map<String, dynamic> copy = Map.of(map);
    copy.removeWhere((key, value) => [
          'type',
          'geometry',
          'properties',
          'bbox',
          'features',
          'geometries'
        ].contains(key));
    return copy;
  }

  factory GeoJSON.fromMap(Map<String, dynamic> map) {
    assert(map.containsKey('type'), 'GeoJSON must contains key `type`');
    assert(getGeoJSONTypes().contains(map['type']), 'Unknown GeoJSON type');

    GeoJSONType type = getGeoJSONType(map['type']);
    switch (type) {
      case GeoJSONType.point:
        return GeometryPoint.fromMap(map);
      case GeoJSONType.multiPoint:
        return GeometryMultiPoint.fromMap(map);
      case GeoJSONType.lineString:
        return GeometryLineString.fromMap(map);
      case GeoJSONType.multiLineString:
        return GeometryMultiLineString.fromMap(map);
      case GeoJSONType.polygon:
        return GeometryPolygon.fromMap(map);
      case GeoJSONType.multiPolygon:
        return GeometryMultiPolygon.fromMap(map);
      case GeoJSONType.feature:
        return GeoJSONFeature.fromMap(map);
      case GeoJSONType.featureCollection:
        return GeoJSONFeatureCollection.fromMap(map);
      case GeoJSONType.geometryCollection:
        return GeoJSONGeometryCollection.fromMap(map);
    }
  }
}

class GeoJSONFeature implements GeoJSON {
  final Geometry geometry;
  final Map<String, dynamic> properties;
  final Map<String, dynamic> foreignMembers = {};
  late List<String> _featureKeys;

  GeoJSONFeature({
    required this.geometry,
    required this.properties,
    Map<String, dynamic>? foreignMembers,
    List<String>? keys,
  }) {
    if (foreignMembers != null && foreignMembers.isNotEmpty) {
      this.foreignMembers.addAll(foreignMembers);
    }

    if (keys != null) {
      assert(
          keys.contains('geometry') &&
              keys.contains('properties') &&
              keys.contains('type'),
          'Invalid feature keys');
      _featureKeys = keys;
    } else {
      List<String> all = ['geometry', 'properties', 'type'];
      all.addAll(this.foreignMembers.keys);
      _featureKeys = all;
    }
  }

  factory GeoJSONFeature.fromMap(Map<String, dynamic> map) {
    String? type = map['type'];
    assert(type != null && type == 'Feature', 'Invalid geojson feature');

    var geometry = map['geometry'];
    assert(geometry != null && geometry is Map, 'Invalid feature geometry');

    Map<String, dynamic> properties = map['properties'] ?? <String, dynamic>{};
    Map<String, dynamic> foreignMembers = GeoJSON.getForeignMembers(map);
    return GeoJSONFeature(
        geometry: Geometry.fromMap(geometry),
        properties: properties,
        foreignMembers: foreignMembers,
        keys: map.keys.toList());
  }

  @override
  GeoJSONType type = GeoJSONType.feature;

  @override
  BBox? get boundingBox =>
      _featureKeys.contains('bbox') ? geometry.boundingBox : null;

  @override
  Map<String, dynamic> get geoJSON {
    Map<String, dynamic> results = {
      'type': type.rawValue,
      'geometry': geometry.geoJSON,
      'properties': properties,
      if (_featureKeys.contains('bbox') && boundingBox != null) ...{
        'bbox': boundingBox!.rawValue
      }
    };

    if (foreignMembers.isNotEmpty) {
      results.addAll(foreignMembers);
    }

    return results;
  }
}

class GeoJSONFeatureCollection implements GeoJSON {
  final List<GeoJSONFeature> features;
  final Map<String, dynamic> foreignMembers = {};
  late List<String> _featureKeys;

  GeoJSONFeatureCollection(
      {required this.features,
      Map<String, dynamic>? foreignMembers,
      List<String>? keys}) {
    if (foreignMembers != null && foreignMembers.isNotEmpty) {
      this.foreignMembers.addAll(foreignMembers);
    }

    if (keys != null) {
      assert(keys.contains('features') && keys.contains('type'),
          'Invalid feature collection keys');
      _featureKeys = keys;
    } else {
      List<String> all = ['features', 'type'];
      all.addAll(this.foreignMembers.keys);
      _featureKeys = all;
    }
  }

  factory GeoJSONFeatureCollection.fromMap(Map<String, dynamic> map) {
    String? type = map['type'];
    assert(type != null && type == 'FeatureCollection',
        'Invalid feature collection');

    var features = map['features'];
    assert(features != null && features is List, 'Invalid features');

    Map<String, dynamic> foreignMembers = GeoJSON.getForeignMembers(map);
    return GeoJSONFeatureCollection(
        features:
            (features as List).map((e) => GeoJSONFeature.fromMap(e)).toList(),
        foreignMembers: foreignMembers,
        keys: map.keys.toList());
  }

  @override
  GeoJSONType type = GeoJSONType.featureCollection;

  @override
  BBox? get boundingBox {
    List<double> latitudes = [];
    List<double> longitudes = [];
    if (_featureKeys.contains('bbox')) {
      for (var value in features) {
        BBox? boundingBox = value.geometry.boundingBox;
        if (boundingBox != null) {
          latitudes.add(boundingBox.latMin);
          latitudes.add(boundingBox.latMax);
          longitudes.add(boundingBox.longMin);
          longitudes.add(boundingBox.longMax);
        }
      }

      if (latitudes.isNotEmpty && longitudes.isNotEmpty) {
        latitudes.sort();
        longitudes.sort();
        return BBox(
            longitudes.first, latitudes.first, longitudes.last, latitudes.last);
      }
    }

    return null;
  }

  @override
  Map<String, dynamic> get geoJSON {
    Map<String, dynamic> results = {
      'type': type.rawValue,
      'features':
          features.isNotEmpty ? features.map((e) => e.geoJSON).toList() : [],
      if (_featureKeys.contains('bbox') && boundingBox != null) ...{
        'bbox': boundingBox!.rawValue
      }
    };

    if (foreignMembers.isNotEmpty) {
      results.addAll(foreignMembers);
    }

    return results;
  }
}

class GeoJSONGeometryCollection implements GeoJSON {
  final List<Geometry> geometries;
  final Map<String, dynamic> foreignMembers = {};
  late List<String> _featureKeys;

  GeoJSONGeometryCollection(
      {required this.geometries,
      Map<String, dynamic>? foreignMembers,
      List<String>? keys}) {
    if (foreignMembers != null && foreignMembers.isNotEmpty) {
      this.foreignMembers.addAll(foreignMembers);
    }

    if (keys != null) {
      assert(keys.contains('geometries') && keys.contains('properties'),
          'Invalid geometry collection keys');
      _featureKeys = keys;
    } else {
      List<String> all = ['geometries', 'properties'];
      all.addAll(this.foreignMembers.keys);
      _featureKeys = all;
    }
  }

  factory GeoJSONGeometryCollection.fromMap(Map<String, dynamic> map) {
    String? type = map['type'];
    assert(type != null && type == 'GeometryCollection',
        'Invalid geometry collection');

    var geometries = map['geometries'];
    assert(geometries != null && geometries is List, 'Invalid geometries');

    Map<String, dynamic> foreignMembers = GeoJSON.getForeignMembers(map);
    return GeoJSONGeometryCollection(
        geometries:
            (geometries as List).map((e) => Geometry.fromMap(e)).toList(),
        foreignMembers: foreignMembers,
        keys: map.keys.toList());
  }

  @override
  GeoJSONType type = GeoJSONType.geometryCollection;

  @override
  BBox? get boundingBox {
    List<double> latitudes = [];
    List<double> longitudes = [];
    if (_featureKeys.contains('bbox')) {
      for (var value in geometries) {
        BBox? boundingBox = value.boundingBox;
        if (boundingBox != null) {
          latitudes.add(boundingBox.latMin);
          latitudes.add(boundingBox.latMax);
          longitudes.add(boundingBox.longMin);
          longitudes.add(boundingBox.longMax);
        }
      }

      if (latitudes.isNotEmpty && longitudes.isNotEmpty) {
        latitudes.sort();
        longitudes.sort();
        return BBox(
            longitudes.first, latitudes.first, longitudes.last, latitudes.last);
      }
    }

    return null;
  }

  @override
  Map<String, dynamic> get geoJSON {
    Map<String, dynamic> results = {
      'type': type.rawValue,
      'geometries': geometries.isNotEmpty
          ? geometries.map((e) => e.geoJSON).toList()
          : [],
      if (_featureKeys.contains('bbox') && boundingBox != null) ...{
        'bbox': boundingBox!.rawValue
      }
    };

    if (foreignMembers.isNotEmpty) {
      results.addAll(foreignMembers);
    }

    return results;
  }
}
