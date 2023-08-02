import 'dart:math';

import 'geometry_shape.dart';
import 'point.dart';
import 'line_segment.dart';
import 'polyline.dart';
import 'polygon.dart';

const String insidePoint = 'i';
const String intersectPoint = '*';
const String onLinePoint = '@';
const String outsidePoint = 'o';
const String operationKey = 'o-relation';

const String relationKey = 'relation';
const String polylineSourceKey = 'source';

const String outsideState = 'outside';
const String insideState = 'inside';
const String stateKey = 'state';

extension ListHelper on List {
  List reorder(int from) {
    assert(from < length, 'Invalid list reorder index');
    if (from == 0) return this;

    List head = sublist(0, from);
    List tail = sublist(from);
    tail.addAll(head);
    return tail;
  }

  List<List> loopExtractionWithJoint(int from, int to) {
    assert(from != to, 'Split will not work for this condition');

    int minValue = min(from, to);
    int maxValue = max(from, to);

    List body = sublist(minValue, maxValue + 1);
    List head = sublist(0, minValue + 1);
    List tail = sublist(maxValue);

    tail.addAll(head);

    if (from > to) {
      return [tail, body];
    } else {
      return [body, tail];
    }
  }
}

extension PointListHelper on List<Point> {
  List<Point> copy() => map((e) => e.copy()).toList();
}

class PolygonOperator {
  static Map<String, Polyline?> interruptionMarkedPolylineGroups(
      Polygon one, Polygon another) {
    Polyline? fromLine = another.relationMarkedPolyline(one);
    Polyline? toLine = one.relationMarkedPolyline(another);

    assert(fromLine != null && toLine != null,
        'Relation marked polylines should not be null');

    List<LineSegment> fromSegments = fromLine!.lineSegments;
    List<LineSegment> toSegments = toLine!.lineSegments;

    for (var fromSegment in fromSegments) {
      for (var toSegment in toSegments) {
        Point? intersection = fromSegment.intersectionPoint(toSegment);
        if (intersection != null) {
          intersection[relationKey] = GeometryRelation.intersected.rawValue;
          fromLine.insertPoint(
              intersection.copy(), fromSegment.start, fromSegment.end);
          toLine.insertPoint(
              intersection.copy(), toSegment.start, toSegment.end);
        } else {
          if (fromSegment.parallelTo(toSegment)) {
            if (fromSegment.relationTo(toSegment.start) ==
                GeometryRelation.contains) {
              fromLine.insertPoint(
                  toSegment.start.copy(), fromSegment.start, fromSegment.end);
            }

            if (fromSegment.relationTo(toSegment.end) ==
                GeometryRelation.contains) {
              fromLine.insertPoint(
                  toSegment.end.copy(), fromSegment.start, fromSegment.end);
            }

            if (toSegment.relationTo(fromSegment.start) ==
                GeometryRelation.contains) {
              toLine.insertPoint(
                  fromSegment.start.copy(), toSegment.start, toSegment.end);
            }

            if (toSegment.relationTo(fromSegment.end) ==
                GeometryRelation.contains) {
              toLine.insertPoint(
                  fromSegment.end.copy(), toSegment.start, toSegment.end);
            }
          }
        }
      }
    }

    addOperationAnnotation(fromLine);
    addOperationAnnotation(toLine);

    return {one.identifier: fromLine, another.identifier: toLine};
  }

  static void addOperationAnnotation(Polyline polyline) {
    List<Point> points = polyline.points;
    for (var point in points) {
      String string = point[relationKey];
      if (string == GeometryRelation.isolated.rawValue) {
        point[operationKey] = outsidePoint;
      } else if (string == GeometryRelation.onLines.rawValue) {
        point[operationKey] = onLinePoint;
      } else if (string == GeometryRelation.contains.rawValue) {
        point[operationKey] = insidePoint;
      } else if (string == GeometryRelation.intersected.rawValue) {
        point[operationKey] = intersectPoint;
      }
    }
  }

  static List<Point> preparePointsForSplitting(Polyline polyline) {
    int previousIndex(int index, List<Point> points) {
      int preIndex = index - 1;
      if (index == 0) {
        preIndex = points.length - 1;
      }

      return preIndex;
    }

    int nextIndex(int index, List<Point> points) {
      int nextIndex = index + 1;
      if (index == points.length - 1) {
        nextIndex = 0;
      }

      return nextIndex;
    }

    assert(
        polyline.isClosedPolyline, 'Seek will only work for closed polyline');
    int intersected =
        polyline.numberOfPointProperty(operationKey, intersectPoint);
    assert(intersected > 0, 'Intersections should be greater than zero');

    int reorderIndex = -1;
    List<Point> points = polyline.points;
    points.removeLast(); // remove closed point

    for (int i = 0; i < points.length; i++) {
      int pIndex = previousIndex(i, points);
      int nIndex = nextIndex(i, points);

      Point point = points[i];
      Point previousPoint = points[pIndex];
      Point nextPoint = points[nIndex];

      String currentType = point[operationKey];
      String previousType = previousPoint[operationKey];
      String nextType = nextPoint[operationKey];

      if ((previousType == intersectPoint || previousType == onLinePoint) &&
          currentType == outsidePoint) {
        reorderIndex = pIndex;
      } else if ((currentType == intersectPoint ||
              currentType == onLinePoint) &&
          nextType == outsidePoint) {
        reorderIndex = i;
      }
    }

    assert(reorderIndex != -1, 'Reorder index is not found');
    List<Point> results = points.reorder(reorderIndex) as List<Point>;
    results.add(results.first); // add back first point to close the polyline
    return results;
  }

  static Map<String, List<Polyline>?> splitPolylineByState(Polyline polyline) {
    bool splittingShouldStop(int index, int length) {
      return index == length - 1;
    }

    Polyline templatePolyline(bool inside, Point start) {
      Polyline line = Polyline(points: [start]);
      line[stateKey] = inside ? insideState : outsideState;
      return line;
    }

    List<Point> prepared = preparePointsForSplitting(polyline);

    List<Polyline> outsides = [];
    List<Polyline> insides = [];
    bool isInsideLine = false;

    Polyline temp = templatePolyline(isInsideLine, prepared.first);

    for (int i = 1; i < prepared.length; i++) {
      Point point = prepared[i];
      String annotation = point[operationKey];
      temp.addPoint(point);

      if (annotation == intersectPoint) {
        Polyline output = temp.copy();
        if (isInsideLine) {
          insides.add(output);
        } else {
          outsides.add(output);
        }

        if (!splittingShouldStop(i, prepared.length)) {
          isInsideLine = !isInsideLine;
          temp = templatePolyline(isInsideLine, point);
        }
      } else if (annotation == onLinePoint) {
        Polyline output = temp.copy();
        if (isInsideLine) {
          insides.add(output);
        } else {
          outsides.add(output);
        }

        if (!splittingShouldStop(i, prepared.length)) {
          Point next = prepared[i + 1];
          isInsideLine = next[operationKey] == insideState;
          temp = templatePolyline(isInsideLine, point);
        }
      }
    }

    return {insideState: insides, outsideState: outsides};
  }

  static List<Polyline>? findConnectablePolylineGroup(
      Polyline source, List<Polyline> lines) {
    return lines
        .where((element) => element.isConnectable(source) && element != source)
        .toList();
  }

  static List<Polygon>? mergePolylineGroups(
      String purpose, List<Polyline> one, List<Polyline> another) {
    List<Polyline> remains = [];
    List<Polygon> outputs = [];

    remains.addAll(one);
    remains.addAll(another);

    while (remains.isNotEmpty) {
      Polyline source = remains.first;
      List<Polyline>? lines = findConnectablePolylineGroup(source, remains);

      if (lines == null) {
        print('Error when finding connectable polylines');
      } else {
        for (var line in lines) {
          source.connect(line);
          remains.remove(line);
        }

        if (source.isClosedPolyline) {
          String identifier = '$purpose-${outputs.length}';
          Polygon output = Polygon(identifier, points: source.points.copy());
          output.clearInfo();
          outputs.add(output);
          remains.remove(source);
        }
      }
    }

    return outputs;
  }

  static List<Polygon>? intersect(Polygon one, Polygon another) {
    if (!one.intersectWith(another)) return null;

    Map<String, Polyline?> intersectionMarked =
        interruptionMarkedPolylineGroups(one, another);
    Polyline? oneLine = intersectionMarked[one.identifier];
    Polyline? anotherLine = intersectionMarked[another.identifier];

    assert(oneLine != null && anotherLine != null,
        'Both marked polylines should not be null');

    Map<String, List<Polyline>?> oneSplitted = splitPolylineByState(oneLine!);
    Map<String, List<Polyline>?> anotherSplitted =
        splitPolylineByState(anotherLine!);

    List<Polyline>? oneInsides = oneSplitted[insideState];
    List<Polyline>? anotherInsides = anotherSplitted[insideState];

    assert(oneInsides != null && anotherInsides != null,
        'Both inside polylines should not be null');

    List<Polygon>? results =
        mergePolylineGroups('intersect', oneInsides!, anotherInsides!);
    return results;
  }

  static Polygon? union(Polygon one, Polygon another) {
    if (one == another) return one;

    GeometryRelation relation = one.relationToPolygon(another);
    if (relation == GeometryRelation.contains) {
      return one;
    } else if (relation == GeometryRelation.beenInvolved) {
      return another;
    } else if (relation == GeometryRelation.intersected ||
        relation == GeometryRelation.onLines) {
      Map<String, Polyline?> intersectionMarked =
          interruptionMarkedPolylineGroups(one, another);
      Polyline? oneLine = intersectionMarked[one.identifier];
      Polyline? anotherLine = intersectionMarked[another.identifier];

      assert(oneLine != null && anotherLine != null,
          'Both marked polylines should not be null');

      Map<String, List<Polyline>?> oneSplitted = splitPolylineByState(oneLine!);
      Map<String, List<Polyline>?> anotherSplitted =
          splitPolylineByState(anotherLine!);

      List<Polyline>? oneOutsides = oneSplitted[outsideState];
      List<Polyline>? anotherOutsides = anotherSplitted[outsideState];

      assert(oneOutsides != null && anotherOutsides != null,
          'Both outside polylines should not be null');

      List<Polygon>? results =
          mergePolylineGroups('union', oneOutsides!, anotherOutsides!);
      return results?.first;
    }

    return null;
  }

  static List<Polygon>? difference(Polygon one, Polygon another) {
    if (!one.intersectWith(another)) return null;

    Map<String, Polyline?> intersectionMarked =
        interruptionMarkedPolylineGroups(one, another);
    Polyline? oneLine = intersectionMarked[one.identifier];
    Polyline? anotherLine = intersectionMarked[another.identifier];

    assert(oneLine != null && anotherLine != null,
        'Both marked polylines should not be null');

    Map<String, List<Polyline>?> oneSplitted = splitPolylineByState(oneLine!);
    Map<String, List<Polyline>?> anotherSplitted =
        splitPolylineByState(anotherLine!);

    List<Polyline>? oneOutsides = oneSplitted[outsideState];
    List<Polyline>? anotherInsides = anotherSplitted[insideState];

    assert(oneOutsides != null && anotherInsides != null,
        'Both polylines should not be null');

    List<Polygon>? results =
        mergePolylineGroups('difference', oneOutsides!, anotherInsides!);
    return results;
  }

  static List<Polygon>? reverseDifference(Polygon one, Polygon another) {
    if (!one.intersectWith(another)) return null;

    Map<String, Polyline?> intersectionMarked =
        interruptionMarkedPolylineGroups(one, another);
    Polyline? oneLine = intersectionMarked[one.identifier];
    Polyline? anotherLine = intersectionMarked[another.identifier];

    assert(oneLine != null && anotherLine != null,
        'Both marked polylines should not be null');

    Map<String, List<Polyline>?> oneSplitted = splitPolylineByState(oneLine!);
    Map<String, List<Polyline>?> anotherSplitted =
        splitPolylineByState(anotherLine!);

    List<Polyline>? oneInsides = oneSplitted[insideState];
    List<Polyline>? anotherOutside = anotherSplitted[outsideState];

    assert(oneInsides != null && anotherOutside != null,
        'Both polylines should not be null');

    List<Polygon>? results =
        mergePolylineGroups('reverse-difference', oneInsides!, anotherOutside!);
    return results;
  }

  static List<Polygon>? xor(Polygon one, Polygon another) {
    if (!one.intersectWith(another)) return null;

    List<Polygon> results = [];
    List<Polygon>? d = difference(one, another);
    if (d != null) {
      results.addAll(d);
    }

    List<Polygon>? r = reverseDifference(one, another);
    if (r != null) {
      results.addAll(r);
    }

    return results;
  }
}
