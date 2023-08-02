import 'package:decimal/decimal.dart';

typedef GridValueConverter = int Function(int value);

class GridValueRange {
  final num from;
  final num to;
  final bool reversed;
  late final int? criticalValue;

  Decimal d(num s) => Decimal.parse(s.toString());

  num get length => criticalValue != null
      ? (d(criticalValue!) - d(from) + (d(to) - d(-criticalValue!)))
          .toDouble()
          .abs()
      : ((d(to) - d(from))).toDouble().abs();

  GridValueRange.zero()
      : to = 0,
        from = 0,
        reversed = false;
  GridValueRange(this.from, this.to, {int? critical})
      : criticalValue = critical,
        reversed = false {
    if (critical != null) {
      assert(critical > from);
    }
  }
  GridValueRange.reverse(this.from, this.to, {int? critical})
      : criticalValue = critical,
        reversed = true {
    if (critical != null) {
      assert(critical < from);
    }
  }

  Stream<num> divideIterable(int divides) {
    return intervalIterable(length / divides);
  }

  Stream<num> intervalIterable(num interval) async* {
    double length = 0;
    while (length < this.length) {
      length += interval;
      num value = getRangeValue(length);
      yield value;
    }
  }

  double getRangeDistance(num value) {
    Decimal result = Decimal.fromInt(0);
    if (reversed) {
      if (criticalValue != null) {
        if (value > criticalValue!) {
          result = d(from) - d(value);
        } else {
          result = d(from) - d(criticalValue! * 2) + d(value);
        }
      } else {
        result = d(from) - d(value);
      }
    } else {
      if (criticalValue != null) {
        if (value < criticalValue!) {
          result = d(value) - d(from);
        } else {
          result = d(criticalValue! * 2) - d(from) + d(value);
        }
      } else {
        result = d(value) - d(from);
      }
    }

    return result.toDouble();
  }

  double getRangeValue(num length) {
    Decimal value = d(from);
    if (!reversed) {
      value += d(length);
      if (criticalValue != null && value > d(criticalValue!)) {
        value = value - d(criticalValue! * 2);
      }
    } else {
      value -= d(length);
      if (criticalValue != null && value < d(criticalValue!)) {
        value = value - d(criticalValue! * 2);
      }
    }

    return value.toDouble();
  }

  bool contains(num value) {
    bool result = false;
    if (reversed) {
      if (criticalValue != null) {
        result =
            value >= criticalValue! && value < -criticalValue! && value >= to;
      } else {
        result = value <= from && value >= to;
      }
    } else {
      if (criticalValue != null) {
        result = value >= from &&
            value <= criticalValue! &&
            value > -criticalValue! &&
            value <= to;
      } else {
        result = value >= from && value <= to;
      }
    }

    return result;
  }
}
