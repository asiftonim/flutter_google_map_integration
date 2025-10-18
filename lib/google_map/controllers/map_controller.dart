// lib/controllers/map_controller.dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:http/http.dart' as http;

class MapController extends GetxController {
  final Completer<GoogleMapController> mapController = Completer();

  // Reactive state
  var locationAllowed = false.obs;
  var currentLatLng = Rxn<LatLng>();
  var selectedLatLng = Rxn<LatLng>();
  var markers = <Marker>{}.obs;
  var polylines = <Polyline>{}.obs;

  static const CameraPosition initialCamera = CameraPosition(
    target: LatLng(23.8103, 90.4125), // Dhaka
    zoom: 14,
  );

  @override
  void onInit() {
    super.onInit();
    checkPermission();
  }

  /// 🔹 Permission Check
  Future<void> checkPermission() async {
    var status = await Permission.locationWhenInUse.request();
    if (status.isGranted) {
      locationAllowed.value = true;
      getCurrentLocation();
    } else {
      locationAllowed.value = false;
    }
  }

  /// 🔹 Get Current Location
  Future<void> getCurrentLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    Position position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );

    currentLatLng.value = LatLng(position.latitude, position.longitude);

    markers.clear();
    markers.add(
      Marker(
        markerId: const MarkerId("current"),
        position: currentLatLng.value!,
        infoWindow: const InfoWindow(title: "My Location"),
      ),
    );

    final GoogleMapController controller = await mapController.future;
    controller.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(target: currentLatLng.value!, zoom: 16),
      ),
    );
  }

  /// 🔹 Get Route using Google Directions API
  Future<void> getRoute(LatLng dest) async {
    if (currentLatLng.value == null) return;

    const apiKey = "YOUR_API_KEY"; // তোমার API Key বসাও
    final url =
        "https://maps.googleapis.com/maps/api/directions/json?origin=${currentLatLng.value!.latitude},${currentLatLng.value!.longitude}&destination=${dest.latitude},${dest.longitude}&key=$apiKey";

    final response = await http.get(Uri.parse(url));
    final data = json.decode(response.body);

    if (data["routes"].isNotEmpty) {
      final points = data["routes"][0]["overview_polyline"]["points"];
      final polylineCoords = _decodePolyline(points);

      polylines.clear();
      polylines.add(
        Polyline(
          polylineId: const PolylineId("route"),
          points: polylineCoords,
          color: Colors.blue,
          width: 5,
        ),
      );

      markers.removeWhere((m) => m.markerId.value == "selected");
      markers.add(
        Marker(
          markerId: const MarkerId("selected"),
          position: dest,
          infoWindow: const InfoWindow(title: "Destination"),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
        ),
      );
    }
  }

  /// 🔹 Decode polyline
  List<LatLng> _decodePolyline(String encoded) {
    List<LatLng> points = [];
    int index = 0, len = encoded.length;
    int lat = 0, lng = 0;

    while (index < len) {
      int b, shift = 0, result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlat = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
      lat += dlat;

      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlng = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
      lng += dlng;

      points.add(LatLng(lat / 1E5, lng / 1E5));
    }

    return points;
  }

  /// 🔹 Handle map tap
  void onMapTap(LatLng tappedPoint) {
    selectedLatLng.value = tappedPoint;
    getRoute(tappedPoint);
  }
}
