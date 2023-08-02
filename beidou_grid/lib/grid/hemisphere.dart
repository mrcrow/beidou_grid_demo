import 'package:mapbox_gl/mapbox_gl.dart';

import 'base.dart';
import 'range.dart';
import 'subdivision.dart';
import 'zone.dart';

enum GridHemisphereType {
  northeast,
  northwest,
  southeast,
  southwest,
}

extension GridHemisphereTypeRawValue on GridHemisphereType {
  int get rawValue {
    switch (this) {
      case GridHemisphereType.northeast:
        return 0;
      case GridHemisphereType.northwest:
        return 1;
      case GridHemisphereType.southeast:
        return 2;
      case GridHemisphereType.southwest:
        return 3;
    }
  }
}

class GridHemisphere {
  final GridHemisphereType type;
  final Map<String, GridSubdivisionRules> rules;
  GridHemisphere({required this.type, required this.rules});

  GridValueRange get latitudeRange {
    switch (type) {
      case GridHemisphereType.northeast:
      case GridHemisphereType.northwest:
        return GridValueRange(0, 88);
      case GridHemisphereType.southeast:
      case GridHemisphereType.southwest:
        return GridValueRange.reverse(0, -88);
    }
  }

  GridValueRange get longitudeRange {
    switch (type) {
      case GridHemisphereType.northeast:
      case GridHemisphereType.southeast:
        return GridValueRange(-20, 160);
      case GridHemisphereType.northwest:
      case GridHemisphereType.southwest:
        return GridValueRange.reverse(-20, 160, critical: -180);
    }
  }

  bool containsSubdivisionRule(int level) {
    return rules.containsKey(level.toString());
  }

  GridSubdivisionRules? getSubdivisionRule(int level) {
    String key = level.toString();
    return rules[key];
  }

  List<GridSubdivisionRules> getNestedSubdivisionRules(int level, [int? from]) {
    List<GridSubdivisionRules> results = [];
    for (int i = from ?? 1; i <= level; i++) {
      GridSubdivisionRules? rule = getSubdivisionRule(i);
      if (rule != null) {
        results.add(rule);
      }
    }

    return results;
  }

  String? getLevelSubdivisionCode(GridIndex index) {
    GridSubdivisionRules? rule = getSubdivisionRule(index.level);
    if (rule == null) {
      return null;
    }

    return rule.encodeAt(index);
  }

  GridRegion? zoomIn(GridRegion region, [GridIndex? nextIndex]) {
    int level = region.level + 1;
    GridSubdivisionRules? rule = getSubdivisionRule(level);
    if (rule == null) {
      return null;
    }

    LatLng coordinate = region.coordinate ?? region.center;
    num latitudeInterval = region.latitudeRange.length / rule.latitudeDivides;
    num longitudeInterval =
        region.longitudeRange.length / rule.longitudeDivides;

    int x;
    int y;
    if (nextIndex != null) {
      x = nextIndex.x;
      y = nextIndex.y;
    } else {
      num latitudeDistance =
          region.latitudeRange.getRangeDistance(coordinate.latitude);
      num longitudeDistance =
          region.longitudeRange.getRangeDistance(coordinate.longitude);

      x = (longitudeDistance / longitudeInterval).floor();
      y = (latitudeDistance / latitudeInterval).floor();
    }

    LatLng northeast;
    LatLng southwest;
    switch (type) {
      case GridHemisphereType.northeast:
        northeast = LatLng(
            region.latitudeRange
                .getRangeValue((y + 1) * latitudeInterval)
                .toDouble(),
            region.longitudeRange
                .getRangeValue((x + 1) * longitudeInterval)
                .toDouble());
        southwest = LatLng(
            region.latitudeRange.getRangeValue(y * latitudeInterval).toDouble(),
            region.longitudeRange
                .getRangeValue(x * longitudeInterval)
                .toDouble());
        break;
      case GridHemisphereType.northwest:
        northeast = LatLng(
            region.latitudeRange
                .getRangeValue((y + 1) * latitudeInterval)
                .toDouble(),
            region.longitudeRange
                .getRangeValue(x * longitudeInterval)
                .toDouble());
        southwest = LatLng(
            region.latitudeRange.getRangeValue(y * latitudeInterval).toDouble(),
            region.longitudeRange
                .getRangeValue((x + 1) * longitudeInterval)
                .toDouble());
        break;
      case GridHemisphereType.southeast:
        northeast = LatLng(
            region.latitudeRange.getRangeValue(y * latitudeInterval).toDouble(),
            region.longitudeRange
                .getRangeValue((x + 1) * longitudeInterval)
                .toDouble());
        southwest = LatLng(
            region.latitudeRange
                .getRangeValue((y + 1) * latitudeInterval)
                .toDouble(),
            region.longitudeRange
                .getRangeValue(x * longitudeInterval)
                .toDouble());
        break;
      case GridHemisphereType.southwest:
        northeast = LatLng(
            region.latitudeRange.getRangeValue(y * latitudeInterval).toDouble(),
            region.longitudeRange
                .getRangeValue(x * longitudeInterval)
                .toDouble());
        southwest = LatLng(
            region.latitudeRange
                .getRangeValue((y + 1) * latitudeInterval)
                .toDouble(),
            region.longitudeRange
                .getRangeValue((x + 1) * longitudeInterval)
                .toDouble());
        break;
    }

    GridIndex index = nextIndex ?? GridIndex(level: level, x: x, y: y);
    String? code = rule.encodeAt(index);
    if (code == null) {
      return null;
    }

    String gridCode = '${region.gridCode}$code';
    return GridRegion(
        hemisphere: region.hemisphere,
        level: level,
        northeast: northeast,
        southwest: southwest,
        coordinate: region.coordinate,
        gridCode: gridCode);
  }

  GridRegion? zoomOut(GridRegion region) {
    GridSubdivisionRules? rule = getSubdivisionRule(region.level);
    if (rule == null) {
      return null;
    }

    num latitudeInterval = region.latitudeRange.length;
    num longitudeInterval = region.longitudeRange.length;
    int x =
        ((longitudeInterval * rule.longitudeDivides) / region.center.longitude)
            .floor();
    int y = ((latitudeInterval * rule.latitudeDivides) / region.center.latitude)
        .floor();

    LatLng origin = LatLng(
        region.bounds.southwest.latitude - latitudeInterval * y,
        region.bounds.southwest.longitude - longitudeInterval * x);

    LatLng northeast = origin;
    LatLng southwest = LatLng(origin.latitude + latitudeInterval,
        origin.longitude + longitudeInterval);

    String gridCode = region.gridCode
        .substring(0, region.gridCode.length - rule.encodingLength);

    return GridRegion(
      hemisphere: region.hemisphere,
      level: region.level - 1,
      northeast: northeast,
      southwest: southwest,
      coordinate: region.coordinate,
      gridCode: gridCode,
    );
  }

  GridRegion? zoomTo(GridRegion region, int level) {
    bool contains = containsSubdivisionRule(level);
    if (contains == false) {
      return null;
    }

    GridRegion result = region;
    while (result.level != level) {
      if (result.level > level) {
        result = zoomOut(result)!;
      } else {
        result = zoomIn(result)!;
      }
    }

    return result;
  }
}
