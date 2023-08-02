import 'dart:math';

import 'package:beidou_grid/grid/zone.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mapbox_gl/mapbox_gl.dart';
import 'package:provider/provider.dart';

import '../tools/layer_manager/layer_manager.dart';
import 'provider.dart';

const String gridClusterType = 'grid-cluster';
const String locationClusterType = 'location-circle';

class MainPage extends StatelessWidget {
  MainPage({super.key});
  final String accessToken =
      'pk.eyJ1IjoibWljaGFlbHd1MDIwNCIsImEiOiJjanVlN2NiOXYwMGppNDRwYmtyN3NtcW1zIn0.gxv7yhHMKu-T_KyHm68j5g';
  final LatLng coordinate =
      const LatLng(39.993161111111114, 116.31260277777778);
  final String gridLayerCluster = 'grid-cluster';
  final LayerManager layerManager = LayerManager()
    ..registerClusterType(gridClusterType)
    ..registerClusterType(locationClusterType);

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (BuildContext context) => MainProvider(),
      builder: (context, child) => _buildPage(context),
    );
  }

  Widget _buildPage(BuildContext context) {
    MapboxMapController? _controller;
    Fill? lastGridFill;
    Circle? lastUserLocation;
    bool styleLoaded = false;

    Future<void> updateUserLocation() async {
      if (_controller == null || styleLoaded == false) {
        return;
      }

      CircleOptions options = CircleOptions(
          circleRadius: 8,
          circleColor: Colors.purple.toHexStringRGB(),
          geometry: _controller!.cameraPosition!.target);

      if (lastUserLocation != null) {
        await _controller!.removeCircle(lastUserLocation!);
        lastUserLocation = null;
      }

      lastUserLocation = await _controller!.addCircle(options);
    }

    Future<void> updateRegion(GridRegion? region) async {
      if (styleLoaded == false || region == null || _controller == null) {
        return;
      }

      List<LatLng> coordinates = [
        region.bounds.northeast,
        LatLng(region.bounds.northeast.latitude,
            region.bounds.southwest.longitude),
        region.bounds.southwest,
        LatLng(region.bounds.southwest.latitude,
            region.bounds.northeast.longitude),
        region.bounds.northeast,
      ];

      FillOptions options = FillOptions(
          fillColor: Colors.blue.toHexStringRGB(),
          fillOutlineColor: Colors.blue.toHexStringRGB(),
          fillOpacity: 0.6,
          geometry: [coordinates]);

      if (lastGridFill != null) {
        if (listEquals(lastGridFill!.options.geometry, options.geometry) ==
            true) {
          return;
        }

        await _controller!.removeFill(lastGridFill!);
        lastGridFill = null;
      }

      lastGridFill = await _controller!.addFill(options);
    }

    return Scaffold(
      appBar: AppBar(
        title: Consumer<MainProvider>(
            builder: (context, viewModel, _) => Text(viewModel.region != null
                ? viewModel.region!.gridCode
                : 'Beidou Grid Demo')),
      ),
      body: MapboxMap(
        accessToken: accessToken,
        styleString: MapboxStyles.LIGHT,
        logoViewMargins: const Point(-40, -40),
        attributionButtonMargins: const Point(-40, -40),
        initialCameraPosition: const CameraPosition(
            target: LatLng(39.92045962727456, 116.40608852301798)),
        trackCameraPosition: true,
        onMapCreated: (MapboxMapController controller) {
          _controller = controller;
        },
        onStyleLoadedCallback: () {
          styleLoaded = true;
        },
        onCameraIdle: () async {
          if (_controller?.cameraPosition == null) {
            return;
          }

          MainProvider viewModel = context.read<MainProvider>();
          viewModel.center = _controller!.cameraPosition!.target;
          await updateRegion(viewModel.region);
          await updateUserLocation();
        },
      ),
      floatingActionButton: Consumer<MainProvider>(
        builder: (context, viewModel, child) => SizedBox(
          width: 88,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Opacity(
                opacity: viewModel.showZoomLevelBar ? 1 : 0,
                child: ConstrainedBox(
                    constraints:
                        const BoxConstraints.expand(width: 96, height: 192),
                    child: ZoomLevelBar(
                        zoomLevel: viewModel.zoomLevel,
                        onTap: (index) async {
                          viewModel.zoomLevel = index + 1;
                          await updateRegion(viewModel.region);
                        })),
              ),
              const SizedBox(
                height: 12,
              ),
              ElevatedButton(
                child: viewModel.showZoomLevelBar
                    ? const Icon(Icons.close)
                    : Text(
                        viewModel.zoomLevel.toString(),
                        style:
                            const TextStyle(fontSize: 20, color: Colors.white),
                      ),
                onPressed: () => viewModel.toggleZoomLevelBar(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

typedef ZoomLevelBarTapCallback = void Function(int index);

class ZoomLevelBar extends StatefulWidget {
  final int zoomLevel;
  final ZoomLevelBarTapCallback onTap;
  const ZoomLevelBar({
    Key? key,
    required this.zoomLevel,
    required this.onTap,
  }) : super(key: key);

  @override
  State<ZoomLevelBar> createState() => _ZoomLevelBarState();
}

class _ZoomLevelBarState extends State<ZoomLevelBar> {
  @override
  Widget build(BuildContext context) {
    return Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(4),
          color: Colors.blue,
        ),
        child: ListView.separated(
          itemCount: 10,
          shrinkWrap: true,
          padding: const EdgeInsets.all(8.0),
          separatorBuilder: (context, index) => const Divider(
            color: Colors.white,
          ),
          itemBuilder: (context, index) => ZoomLevelTile(
            selected: index == widget.zoomLevel - 1,
            zoomLevel: index + 1,
            onTap: () => widget.onTap(index),
          ),
        ));
  }
}

class ZoomLevelTile extends StatelessWidget {
  const ZoomLevelTile({
    Key? key,
    required this.selected,
    required this.zoomLevel,
    required this.onTap,
  }) : super(key: key);
  final bool selected;
  final int zoomLevel;
  final GestureTapCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(4),
          color: selected ? Colors.white : Colors.transparent,
        ),
        height: 36,
        child: Center(
          child: Text(
            zoomLevel.toString(),
            maxLines: 1,
            style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 18,
                color: selected ? Colors.blue : Colors.white),
          ),
        ),
      ),
    );
  }
}
