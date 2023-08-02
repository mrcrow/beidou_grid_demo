import 'package:beidou_grid/grid/zone.dart';
import 'package:flutter/material.dart';
import 'package:mapbox_gl/mapbox_gl.dart';

class MainProvider extends ChangeNotifier {
  int _zoomLevel = 1;
  int get zoomLevel => _zoomLevel;
  bool showZoomLevelBar = false;
  LatLng? _centerCoordinate;
  GridRegion? region;
  final RegularZone _zone = RegularZone();

  set center(LatLng coordinate) {
    _centerCoordinate = coordinate;
    updateGridRegion();
  }

  set zoomLevel(int level) {
    if (_zoomLevel == level) {
      return;
    }

    _zoomLevel = level;
    updateGridRegion();
  }

  void toggleZoomLevelBar() {
    showZoomLevelBar = !showZoomLevelBar;
    notifyListeners();
  }

  void updateGridRegion() {
    if (_centerCoordinate == null) {
      return;
    }

    region = _zone.regionAtCoordinate(_centerCoordinate!, _zoomLevel);
    print(region!.gridCode);
    notifyListeners();
  }
}
