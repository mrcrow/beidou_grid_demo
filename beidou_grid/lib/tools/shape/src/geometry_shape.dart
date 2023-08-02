enum GeometryRelation {
  isolated, // for point, line, polygon
  onLines, // for point, line, polygon
  onEndPoint, // for point
  intersected, // for point, line, polygon
  contains, // for line, polygon
  beenInvolved // for line, polygon
}

extension GeometryRelationRawValue on GeometryRelation {
  String get rawValue {
    String _string = '';
    switch (this) {
      case GeometryRelation.isolated:
        _string = 'isolated';
        break;
      case GeometryRelation.onLines:
        _string = 'onLines';
        break;
      case GeometryRelation.onEndPoint:
        _string = 'onEndPoint';
        break;
      case GeometryRelation.intersected:
        _string = 'intersected';
        break;
      case GeometryRelation.contains:
        _string = 'contains';
        break;
      case GeometryRelation.beenInvolved:
        _string = 'beenInvolved';
        break;
    }

    return _string;
  }

  int get intValue {
    int _value = -1;
    switch (this) {
      case GeometryRelation.isolated:
        _value = 0;
        break;
      case GeometryRelation.onLines:
        _value = 1;
        break;
      case GeometryRelation.onEndPoint:
        _value = 2;
        break;
      case GeometryRelation.intersected:
        _value = 3;
        break;
      case GeometryRelation.contains:
        _value = 4;
        break;
      case GeometryRelation.beenInvolved:
        _value = 5;
        break;
    }

    return _value;
  }
}

class GeometryInfo {
  final Map<String, dynamic> _properties = <String, dynamic>{};
  GeometryInfo([Map<String, dynamic>? properties]) {
    if (properties != null && properties.isNotEmpty) {
      _properties.addAll(properties);
    }
  }

  external Map<String, dynamic> toGeoJSON({Map<String, dynamic>? properties});

  dynamic operator [](String key) {
    return _properties[key];
  }

  void operator []=(String key, dynamic value) {
    _properties[key] = value;
  }

  void clearInfo() {
    _properties.clear();
  }

  Map<String, dynamic> get properties => Map.of(_properties);

  GeometryInfo copy() => GeometryInfo(properties);

  GeometryInfo copyWith({Map<String, dynamic>? properties}) =>
      GeometryInfo(properties);

  @override
  int get hashCode => _properties.hashCode;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is GeometryInfo &&
            runtimeType == other.runtimeType &&
            _properties == other._properties;
  }
}
