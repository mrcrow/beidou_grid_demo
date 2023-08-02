import 'package:beidou_grid/tools/geojson/geojson.dart';
import 'package:mapbox_gl/mapbox_gl.dart';

class GeometryHelper {
  static GeometryPoint point(LatLng coordinate) {
    List<dynamic> data = [coordinate.longitude, coordinate.latitude];
    return GeometryPoint(data);
  }

  static GeometryMultiPoint multiPoint(List<LatLng> coordinates) {
    List<dynamic> data =
        coordinates.map((e) => [e.longitude, e.latitude]).toList();
    return GeometryMultiPoint(data);
  }

  static GeometryLineString lineString(List<LatLng> coordinates) {
    List<dynamic> data =
        coordinates.map((e) => [e.longitude, e.latitude]).toList();
    return GeometryLineString(data);
  }

  static GeometryMultiLineString multiLineString(
      List<List<LatLng>> coordinates) {
    List<dynamic> data = coordinates
        .map((e) => e.map((i) => [i.longitude, i.latitude]).toList())
        .toList();
    return GeometryMultiLineString(data);
  }

  static GeometryPolygon polygon(List<LatLng> coordinates) {
    List<dynamic> data = [
      coordinates.map((e) => [e.longitude, e.latitude]).toList()
    ];
    return GeometryPolygon(data);
  }

  static GeometryMultiPolygon multiPolygon(List<List<LatLng>> coordinates) {
    List<dynamic> data = coordinates
        .map((e) => e.map((i) => [i.longitude, i.latitude]).toList())
        .toList();
    return GeometryMultiPolygon(data);
  }
}
