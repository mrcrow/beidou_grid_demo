import 'package:mapbox_gl/mapbox_gl.dart';

import 'base.dart';
import 'hemisphere.dart';
import 'range.dart';
import 'subdivision.dart';

class GridRegion {
  final int level;
  final GridHemisphere hemisphere;
  final String gridCode;
  late final LatLngBounds bounds;
  late final GridValueRange latitudeRange;
  late final GridValueRange longitudeRange;

  LatLng? coordinate;
  LatLng get center {
    double southwestLongitude = bounds.southwest.longitude;
    double northeastLongitude = bounds.northeast.longitude;

    if ((southwestLongitude - northeastLongitude > 180) ||
        (northeastLongitude - southwestLongitude > 180)) {
      southwestLongitude += 360;
      southwestLongitude %= 360;
      northeastLongitude += 360;
      northeastLongitude %= 360;
    }

    return LatLng((bounds.southwest.latitude + bounds.northeast.latitude) / 2,
        (southwestLongitude + northeastLongitude) / 2);
  }

  GridRegion({
    required this.hemisphere,
    required this.level,
    required LatLng southwest,
    required LatLng northeast,
    this.coordinate,
    required this.gridCode,
  }) {
    bounds = LatLngBounds(southwest: southwest, northeast: northeast);
    _generateLatitudeRange();
    _generateLongitudeRange();
  }

  void _generateLatitudeRange() {
    switch (hemisphere.type) {
      case GridHemisphereType.northeast:
      case GridHemisphereType.northwest:
        {
          latitudeRange = GridValueRange(
              bounds.southwest.latitude, bounds.northeast.latitude);
        }
        break;
      case GridHemisphereType.southeast:
      case GridHemisphereType.southwest:
        {
          latitudeRange = GridValueRange.reverse(
              bounds.northeast.latitude, bounds.southwest.latitude);
        }
        break;
    }
  }

  void _generateLongitudeRange() {
    switch (hemisphere.type) {
      case GridHemisphereType.northeast:
      case GridHemisphereType.southeast:
        {
          longitudeRange = GridValueRange(
              bounds.southwest.longitude, bounds.northeast.longitude);
        }
        break;
      case GridHemisphereType.northwest:
      case GridHemisphereType.southwest:
        {
          if ((bounds.northeast.longitude < 0 &&
                  bounds.southwest.longitude < 0) ||
              (bounds.northeast.longitude > 0 &&
                  bounds.southwest.longitude > 0)) {
            longitudeRange = GridValueRange.reverse(
                bounds.northeast.longitude, bounds.southwest.longitude);
          } else {
            longitudeRange = GridValueRange.reverse(
                bounds.northeast.longitude, bounds.southwest.longitude,
                critical: -180);
          }
        }
        break;
    }
  }

  GridRegion? zoomIn() {
    return hemisphere.zoomIn(this);
  }

  GridRegion? zoomOut() {
    return hemisphere.zoomOut(this);
  }

  GridRegion? zoomTo(int level) {
    return hemisphere.zoomTo(this, level);
  }
}

mixin RegularGridLocator {
  GridRegion? getBaseRegionWithIndex(
      GridHemisphere hemisphere, GridIndex index);
  GridRegion? getBaseRegionWithCoordinate(LatLng coordinate);
  String? getBaseRegionGridCode(GridIndex index);
  GridRegion? regionAtCoordinate(LatLng coordinate, int level);
  GridRegion? parseGridCode(String gridCode);
}

abstract class GridZone {
  String get id;
  GridValueRange get latitudeRange;
  GridValueRange get longitudeRange;
  Map<String, GridSubdivisionRules> get rules;

  GridSubdivisionRules? getSubdivisionRule(int level);
}

class RegularZone with RegularGridLocator implements GridZone {
  RegularZone();

  @override
  String get id => 'regular_zone';

  @override
  GridValueRange get latitudeRange => GridValueRange(-88, 88);

  @override
  GridValueRange get longitudeRange => GridValueRange(-180, 180);

  @override
  GridSubdivisionRules? getSubdivisionRule(int level) {
    GridSubdivisionRules? rule = rules[level.toString()];
    return rule;
  }

  @override
  GridRegion? parseGridCode(String gridCode) {
    GridSubdivisionRules? first = getSubdivisionRule(1);
    if (first == null || first.encodingLength > gridCode.length) {
      return null;
    }

    String head = gridCode.substring(1, first.encodingLength + 1);
    GridIndex? firstIndex = first.parseIndex(head);
    if (firstIndex == null) {
      return null;
    }

    GridHemisphereType type;
    String hemispherePrefix = gridCode.substring(0, 1);
    if (hemispherePrefix == 'N') {
      type = firstIndex.x <= 30
          ? GridHemisphereType.northwest
          : GridHemisphereType.northeast;
    } else {
      type = firstIndex.x <= 30
          ? GridHemisphereType.southwest
          : GridHemisphereType.southeast;
    }

    GridHemisphere hemisphere = GridHemisphere(type: type, rules: rules);
    GridRegion? region = getBaseRegionWithIndex(hemisphere, firstIndex);
    if (region == null) {
      return null;
    }

    String body = gridCode.substring(first.encodingLength + 1);
    int level = 1;
    while (body.isNotEmpty) {
      level += 1;
      GridSubdivisionRules? rule = getSubdivisionRule(level);
      if (rule == null || rule.encodingLength > body.length) {
        break;
      }

      String next = body.substring(0, rule.encodingLength);
      body = body.substring(rule.encodingLength);
      if (rule.expression.hasMatch(next) == false) {
        break;
      }

      GridIndex? index = rule.parseIndex(next);
      if (index == null) {
        break;
      }

      GridRegion? nextRegion = hemisphere.zoomIn(region!, index);
      if (nextRegion == null) {
        break;
      }

      region = nextRegion;
    }

    return region;
  }

  @override
  Map<String, GridSubdivisionRules> get rules => {
        '1': GridSubdivisionRules.separated(
          1,
          44,
          60,
          GridEncodingGenerator.indexMapping(
              'VUTSRQPONMLKJIHGFEDCBAABCDEFGHIJKLMNOPQRSTUV', 1),
          GridEncodingGenerator.numberRange(GridValueRange(1, 60), 2)
            ..converter = (e) => e.length < 2 ? '0$e' : e,
          RegExp(r'(N|S)[0-6][0-9][A-V]'),
        ),
        '2': GridSubdivisionRules.separated(
          2,
          8,
          12,
          GridEncodingGenerator.numberRange(GridValueRange(0, 7), 1),
          GridEncodingGenerator.indexMapping('0123456789AB', 1),
          RegExp(r'([0-9]|[A-B])[0-7]'),
        ),
        '3': GridSubdivisionRules.union(
          3,
          3,
          2,
          GridEncodingGenerator.numberRange(GridValueRange(0, 5), 1),
          RegExp(r'[0-5]'),
        ),
        '4': GridSubdivisionRules.separated(
          4,
          10,
          15,
          GridEncodingGenerator.numberRange(GridValueRange(0, 9), 1),
          GridEncodingGenerator.indexMapping('0123456789ABCDE', 1),
          RegExp(r'([0-9]|[A-E])[0-9]'),
        ),
        '5': GridSubdivisionRules.separated(
          5,
          15,
          15,
          GridEncodingGenerator.indexMapping('0123456789ABCDE', 1),
          GridEncodingGenerator.indexMapping('0123456789ABCDE', 1),
          RegExp(r'([0-9]|[A-E])([0-9]|[A-E])'),
        ),
        '6': GridSubdivisionRules.union(
          6,
          2,
          2,
          GridEncodingGenerator.numberRange(GridValueRange(0, 3), 1),
          RegExp(r'[0-3]'),
        ),
        '7': GridSubdivisionRules.separated(
          7,
          8,
          8,
          GridEncodingGenerator.numberRange(GridValueRange(0, 7), 1),
          GridEncodingGenerator.numberRange(GridValueRange(0, 7), 1),
          RegExp(r'[0-7][0-7]'),
        ),
        '8': GridSubdivisionRules.separated(
          8,
          8,
          8,
          GridEncodingGenerator.numberRange(GridValueRange(0, 7), 1),
          GridEncodingGenerator.numberRange(GridValueRange(0, 7), 1),
          RegExp(r'[0-7][0-7]'),
        ),
        '9': GridSubdivisionRules.separated(
          9,
          8,
          8,
          GridEncodingGenerator.numberRange(GridValueRange(0, 7), 1),
          GridEncodingGenerator.numberRange(GridValueRange(0, 7), 1),
          RegExp(r'[0-7][0-7]'),
        ),
        '10': GridSubdivisionRules.separated(
          10,
          8,
          8,
          GridEncodingGenerator.numberRange(GridValueRange(0, 7), 1),
          GridEncodingGenerator.numberRange(GridValueRange(0, 7), 1),
          RegExp(r'[0-7][0-7]'),
        ),
      };

  GridHemisphereType _getHemisphereType(LatLng coordinate) {
    if (coordinate.longitude >= -20 && coordinate.longitude < 160) {
      if (coordinate.latitude > 0) {
        return GridHemisphereType.northeast;
      } else {
        return GridHemisphereType.southeast;
      }
    } else {
      if (coordinate.latitude > 0) {
        return GridHemisphereType.northwest;
      } else {
        return GridHemisphereType.southwest;
      }
    }
  }

  GridHemisphere _getHemisphere(LatLng coordinate) {
    GridHemisphereType type = _getHemisphereType(coordinate);
    return GridHemisphere(type: type, rules: rules);
  }

  @override
  GridRegion? regionAtCoordinate(LatLng coordinate, int level) {
    GridRegion? region = getBaseRegionWithCoordinate(coordinate);
    if (region == null) {
      return null;
    }

    if (level == 1) {
      return region;
    } else {
      return region.zoomTo(level);
    }
  }

  @override
  GridRegion? getBaseRegionWithIndex(
      GridHemisphere hemisphere, GridIndex index) {
    GridSubdivisionRules rule = getSubdivisionRule(1)!;
    num latitudeInterval = latitudeRange.length / rule.latitudeDivides;
    num longitudeInterval = longitudeRange.length / rule.longitudeDivides;

    LatLng northeast = LatLng(
        latitudeRange.getRangeValue(index.y * latitudeInterval),
        longitudeRange.getRangeValue(index.x * longitudeInterval));
    LatLng southwest = LatLng(
        latitudeRange.getRangeValue((index.y - 1) * latitudeInterval),
        longitudeRange.getRangeValue((index.x - 1) * longitudeInterval));

    String? gridCode = getBaseRegionGridCode(index);
    if (gridCode == null) {
      return null;
    }

    return GridRegion(
        hemisphere: hemisphere,
        level: index.level,
        northeast: northeast,
        southwest: southwest,
        coordinate: null,
        gridCode: gridCode);
  }

  @override
  GridRegion? getBaseRegionWithCoordinate(LatLng coordinate) {
    GridSubdivisionRules rule = getSubdivisionRule(1)!;
    num latitudeInterval = latitudeRange.length / rule.latitudeDivides;
    num longitudeInterval = longitudeRange.length / rule.longitudeDivides;
    num latitudeDistance = latitudeRange.getRangeDistance(coordinate.latitude);
    num longitudeDistance =
        longitudeRange.getRangeDistance(coordinate.longitude);

    int x = (longitudeDistance / longitudeInterval).floor();
    int y = (latitudeDistance / latitudeInterval).floor();

    LatLng northeast = LatLng(
        latitudeRange.getRangeValue((y + 1) * latitudeInterval),
        longitudeRange.getRangeValue((x + 1) * longitudeInterval));
    LatLng southwest = LatLng(latitudeRange.getRangeValue(y * latitudeInterval),
        longitudeRange.getRangeValue(x * longitudeInterval));

    GridIndex index = GridIndex(level: 1, x: x, y: y);
    String? gridCode = getBaseRegionGridCode(index);
    if (gridCode == null) {
      return null;
    }

    GridHemisphere hemisphere = _getHemisphere(coordinate);

    return GridRegion(
        hemisphere: hemisphere,
        level: index.level,
        northeast: northeast,
        southwest: southwest,
        coordinate: coordinate,
        gridCode: gridCode);
  }

  @override
  String? getBaseRegionGridCode(GridIndex index) {
    GridSubdivisionRules? rule = getSubdivisionRule(1);
    assert(rule != null);

    String prefix = index.y > 21 ? 'N' : 'S';
    String? body = rule?.encodeAt(index);
    if (body == null) {
      return null;
    }

    return '$prefix$body';
  }
}

class NorthPoleZone implements GridZone {
  NorthPoleZone();

  @override
  String get id => 'north_pole';

  @override
  GridValueRange get latitudeRange => GridValueRange(88, 90);

  @override
  GridValueRange get longitudeRange => GridValueRange(-180, 180);

  @override
  Map<String, GridSubdivisionRules> get rules => {};

  @override
  GridSubdivisionRules? getSubdivisionRule(int level) {
    // TODO: implement getSubdivisionRule
    throw UnimplementedError();
  }
}

class SouthPoleZone implements GridZone {
  SouthPoleZone();

  @override
  String get id => 'south_pole';

  @override
  GridValueRange get latitudeRange => GridValueRange(-90, -88);

  @override
  GridValueRange get longitudeRange => GridValueRange(-180, 180);

  @override
  GridRegion parseGridCode(String code) {
    throw UnimplementedError();
  }

  @override
  Map<String, GridSubdivisionRules> get rules => throw UnimplementedError();

  @override
  GridSubdivisionRules? getSubdivisionRule(int level) {
    // TODO: implement getSubdivisionRule
    throw UnimplementedError();
  }
}

class GlobalZones {
  static final GlobalZones _instance = GlobalZones._();
  factory GlobalZones() => _instance;

  GlobalZones._()
      : northPoleZone = NorthPoleZone(),
        southPoleZone = SouthPoleZone(),
        regularZone = RegularZone();

  final NorthPoleZone northPoleZone;
  final SouthPoleZone southPoleZone;
  final RegularZone regularZone;

  static String? getGridCode(LatLng coordinate, int level) {
    return GlobalZones()
        .regularZone
        .regionAtCoordinate(coordinate, level)
        ?.gridCode;
  }

  static LatLng? getCoordinate(String gridCode) {
    if (gridCodeValidation(gridCode) == false) {
      return null;
    }

    GridRegion? region = GlobalZones().regularZone.parseGridCode(gridCode);
    if (region == null) {
      return null;
    }

    return region.center;
  }

  static bool gridCodeValidation(String code) {
    GridRegion? region = GlobalZones().regularZone.parseGridCode(code);
    if (region == null) {
      return false;
    }

    return region.gridCode == code;
  }
}
