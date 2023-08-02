import 'base.dart';
import 'range.dart';

enum EncodingGeneratorType {
  indexMapping,
  numberRange,
}

typedef EncodeConverter = String Function(String value);

class GridEncodingGenerator {
  final EncodingGeneratorType type;
  final GridValueRange _range;
  final String _string;
  final int encodingLength;
  EncodeConverter? converter;

  GridEncodingGenerator.indexMapping(this._string, this.encodingLength)
      : type = EncodingGeneratorType.indexMapping,
        _range = GridValueRange.zero();

  GridEncodingGenerator.numberRange(this._range, this.encodingLength)
      : type = EncodingGeneratorType.numberRange,
        _string = '';

  bool containsEncoding(String encoding) {
    if (type == EncodingGeneratorType.indexMapping) {
      return _string.contains(encoding);
    } else {
      num number = int.parse(encoding);
      return _range.contains(number);
    }
  }

  String? encodeAtIndex(int index) {
    String code = '';
    if (type == EncodingGeneratorType.indexMapping) {
      code = _string.substring(index, index + 1);
    } else {
      int value = _range.getRangeValue(index).toInt();
      code = value.toString();
    }

    if (converter != null) {
      code = converter!(code);
    }

    return code;
  }

  int? decodeWithString(String code) {
    if (containsEncoding(code) == false) {
      return null;
    }

    if (type == EncodingGeneratorType.indexMapping) {
      return _string.indexOf(code);
    } else {
      num number = int.parse(code);
      int index = (number - _range.from).toInt();
      return index;
    }
  }
}

enum GridSubdivisionEncodingType {
  separated,
  union,
}

class GridSubdivisionRules {
  final int level;
  final int latitudeDivides;
  final int longitudeDivides;
  final GridSubdivisionEncodingType encoding;
  int get encodingLength => encoding == GridSubdivisionEncodingType.separated
      ? latitudeGenerator!.encodingLength + longitudeGenerator!.encodingLength
      : unionGenerator!.encodingLength;

  final RegExp expression;
  GridEncodingGenerator? _latitudeGenerator;
  GridEncodingGenerator? get latitudeGenerator => _latitudeGenerator;
  GridEncodingGenerator? _longitudeGenerator;
  GridEncodingGenerator? get longitudeGenerator => _longitudeGenerator;
  GridEncodingGenerator? _unionGenerator;
  GridEncodingGenerator? get unionGenerator => _unionGenerator;

  GridSubdivisionRules._(
    this.level,
    this.latitudeDivides,
    this.longitudeDivides,
    this.encoding,
    this._latitudeGenerator,
    this._longitudeGenerator,
    this._unionGenerator,
    this.expression,
  ) : assert(_latitudeGenerator != null ||
            _longitudeGenerator != null ||
            _unionGenerator != null);

  GridSubdivisionRules.union(
    this.level,
    this.latitudeDivides,
    this.longitudeDivides,
    this._unionGenerator,
    this.expression,
  ) : encoding = GridSubdivisionEncodingType.union;

  GridSubdivisionRules.separated(
    this.level,
    this.latitudeDivides,
    this.longitudeDivides,
    this._latitudeGenerator,
    this._longitudeGenerator,
    this.expression,
  ) : encoding = GridSubdivisionEncodingType.separated;

  GridSubdivisionRules copyWith({
    int? level,
    int? latitudeDivides,
    int? longitudeDivides,
    GridSubdivisionEncodingType? encoding,
    GridEncodingGenerator? latitudeGenerator,
    GridEncodingGenerator? longitudeGenerator,
    GridEncodingGenerator? unionGenerator,
    int? encodingLength,
    RegExp? expression,
  }) =>
      GridSubdivisionRules._(
        level ?? this.level,
        latitudeDivides ?? this.latitudeDivides,
        longitudeDivides ?? this.longitudeDivides,
        encoding ?? this.encoding,
        latitudeGenerator,
        longitudeGenerator,
        unionGenerator,
        expression ?? this.expression,
      );

  GridIndex? parseIndex(String code) {
    GridIndex? index;
    if (encoding == GridSubdivisionEncodingType.separated) {
      String xCode = code.substring(0, longitudeGenerator!.encodingLength);
      String yCode = code.substring(longitudeGenerator!.encodingLength);
      int? x = longitudeGenerator!.decodeWithString(xCode);
      int? y = latitudeGenerator!.decodeWithString(yCode);

      if (x != null && y != null) {
        index = GridIndex(level: level, x: x, y: y);
      }
    } else {
      int? union = unionGenerator!.decodeWithString(code);
      if (union != null) {
        int x = union % longitudeDivides;
        int y = (union - x) ~/ longitudeDivides;
        index = GridIndex(level: level, x: x, y: y);
      }
    }

    return index;
  }

  String? encodeAt(GridIndex index) {
    String? code;
    if (encoding == GridSubdivisionEncodingType.separated) {
      String? xCode = longitudeGenerator?.encodeAtIndex(index.x);
      String? yCode = latitudeGenerator?.encodeAtIndex(index.y);
      if (xCode == null || yCode == null) {
        return null;
      }

      code = '$xCode$yCode';
    } else {
      int codeIndex = index.x + index.y * longitudeDivides;
      code = unionGenerator?.encodeAtIndex(codeIndex);
    }

    return code;
  }
}
