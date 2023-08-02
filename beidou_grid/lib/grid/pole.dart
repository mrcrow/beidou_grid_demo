import 'package:beidou_grid/grid/range.dart';
import 'package:beidou_grid/grid/subdivision.dart';

enum PolarRegionType { polar, inner, outer }

class PolarRegion {
  PolarRegion({
    required this.regionID,
    required this.regionLatitudeRange,
    required this.regionLongitudeRange,
    required this.subdivisionRules,
  });

  final String regionID;
  final GridValueRange regionLatitudeRange;
  final GridValueRange regionLongitudeRange;
  final Map<String, GridSubdivisionRules> subdivisionRules;
}
