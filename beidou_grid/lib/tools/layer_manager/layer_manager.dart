class LayerClusterItem {
  const LayerClusterItem(this.itemID, this.layerIDs);
  final String itemID;
  final List<String> layerIDs;
}

class LayerCluster {
  LayerCluster(this.type);
  final String type;
  final Map<String, LayerClusterItem> _items = {};
  final List<String> _itemIDs = [];
  List<LayerClusterItem> get items => _items.values.toList();

  bool isEmpty() {
    return _itemIDs.isEmpty;
  }

  bool _containsItem(String itemID) {
    return _itemIDs.contains(itemID);
  }

  bool addItem(LayerClusterItem item) {
    if (_containsItem(item.itemID)) return false;

    _items[item.itemID] = item;
    _itemIDs.add(item.itemID);
    return true;
  }

  LayerClusterItem? getItem(String itemID) {
    return _items[itemID];
  }

  bool removeItem(String itemID) {
    if (!_containsItem(itemID)) return false;

    _items.remove(itemID);
    _itemIDs.remove(itemID);
    return true;
  }

  List<String> layerIDs() {
    List<String> layers = [];
    _items.forEach((String key, LayerClusterItem value) {
      layers.addAll(value.layerIDs);
    });

    return layers;
  }

  String? firstLayerID() {
    if (isEmpty()) return null;

    String itemID = _itemIDs.first;
    LayerClusterItem? item = _items[itemID];
    if (item == null) return null;

    return item.layerIDs.first;
  }
}

class LayerPosition {
  LayerPosition();

  bool empty = true;
  String? belowLayerID;
  String? errorDescription;
}

class LayerManager {
  LayerManager();
  final List<String> _clusterTypes = [];
  final Map<String, LayerCluster> _clusters = {};

  bool registerClusterType(String clusterType,
      [bool? above, String? existingType]) {
    if (_containsClusterType(clusterType)) return false;

    if (existingType != null) {
      if (!_containsClusterType(existingType)) return false;

      bool aboveLayer = above ?? false;
      int index = _clusterTypes.indexOf(existingType);
      if (aboveLayer) {
        if (index == _clusterTypes.length - 1) {
          _clusterTypes.add(clusterType);
        } else {
          _clusterTypes.insert(index + 1, clusterType);
        }
      } else {
        _clusterTypes.insert(index, clusterType);
      }
    } else {
      _clusterTypes.add(clusterType);
    }

    return true;
  }

  bool _containsClusterType(String clusterType) {
    return _clusterTypes.contains(clusterType);
  }

  LayerCluster getLayerCluster(String clusterType) {
    LayerCluster? cluster = _clusters[clusterType];
    if (cluster == null) {
      cluster = LayerCluster(clusterType);
      _clusters[clusterType] = cluster;
    }

    return cluster;
  }

  LayerClusterItem? getLayerClusterItem(String clusterType, String clusterID) {
    LayerCluster cluster = getLayerCluster(clusterType);
    return cluster.getItem(clusterID);
  }

  LayerCluster? _getAboveLayerCluster(String clusterType) {
    int index = _clusterTypes.indexOf(clusterType);
    if (index == -1) {
      return null;
    } else {
      if (index == _clusterTypes.length - 1) {
        LayerCluster? cluster = _clusters[index];
        if (cluster != null && !cluster.isEmpty()) {
          return cluster;
        }
      } else {
        for (int i = index; index < _clusterTypes.length; i++) {
          String target = _clusterTypes[i];
          LayerCluster? cluster = _clusters[target];
          if (cluster != null && !cluster.isEmpty()) {
            return cluster;
          }
        }
      }
    }

    return null;
  }

  LayerPosition suggestedLayerPosition(String clusterType) {
    LayerPosition position = LayerPosition();

    LayerCluster cluster = getLayerCluster(clusterType);

    if (cluster.isEmpty()) {
      LayerCluster? above = _getAboveLayerCluster(clusterType);
      if (above == null) {
        position.errorDescription = 'No layer cluster exist';
      } else {
        String? belowLayerID = above.firstLayerID();
        if (belowLayerID != null) {
          position.empty = false;
          position.belowLayerID = belowLayerID;
        }
      }
    } else {
      String? belowLayerID = cluster.firstLayerID();
      if (belowLayerID != null) {
        position.empty = false;
        position.belowLayerID = belowLayerID;
      }
    }

    return position;
  }

  bool addClusterItem(LayerClusterItem item, String clusterType) {
    LayerCluster? cluster = getLayerCluster(clusterType);
    return cluster.addItem(item);
  }

  bool removeClusterItem(String itemID, String clusterType) {
    LayerCluster? cluster = _clusters[clusterType];
    if (cluster != null) {
      return cluster.removeItem(itemID);
    }

    return false;
  }

  bool clusterIsEmpty(String clusterType) {
    LayerCluster? cluster = getLayerCluster(clusterType);
    return cluster.isEmpty();
  }
}
