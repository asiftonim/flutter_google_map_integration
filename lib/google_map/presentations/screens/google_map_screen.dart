import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../controllers/map_controller.dart';


class GoogleMapScreen extends StatelessWidget {
  const GoogleMapScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(MapController());

    return Scaffold(
      body: SafeArea(
        child: Obx(() {
          return GoogleMap(
            onMapCreated: (GoogleMapController mapCtrl) {
              controller.mapController.complete(mapCtrl);
            },
            initialCameraPosition: MapController.initialCamera,
            myLocationEnabled: controller.locationAllowed.value,
            myLocationButtonEnabled: controller.locationAllowed.value,
            compassEnabled: true,
            markers: controller.markers,
            polylines: controller.polylines,
            onTap: controller.onMapTap,
          );
        }),
      ),
    );
  }
}
