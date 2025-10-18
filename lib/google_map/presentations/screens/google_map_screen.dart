import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

class GoogleMapScreen extends StatefulWidget {
  const GoogleMapScreen({super.key});

  @override
  State<GoogleMapScreen> createState() => _GoogleMapScreenState();
}

class _GoogleMapScreenState extends State<GoogleMapScreen> {
  final Completer<GoogleMapController> _controller = Completer();

  static const CameraPosition _kInitial = CameraPosition(
    target: LatLng(23.8103, 90.4125), // Default Dhaka
    zoom: 14,
  );

  bool _locationAllowed = false;
  LatLng? _currentLatLng;
  LatLng? _selectedLatLng;

  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};

  @override
  void initState() {
    super.initState();
    _checkPermission();
  }

  Future<void> _checkPermission() async {
    var status = await Permission.locationWhenInUse.request();
    if (status.isGranted) {
      setState(() {
        _locationAllowed = true;
      });
      _getCurrentLocation();
    } else {
      setState(() {
        _locationAllowed = false;
      });
    }
  }

  Future<void> _getCurrentLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    Position position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );

    _currentLatLng = LatLng(position.latitude, position.longitude);

    setState(() {
      _markers.clear();
      _markers.add(
        Marker(
          markerId: const MarkerId("current"),
          position: _currentLatLng!,
          infoWindow: const InfoWindow(title: "My Location"),
        ),
      );
    });

    final GoogleMapController controller = await _controller.future;
    controller.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(target: _currentLatLng!, zoom: 16),
      ),
    );
  }

  Future<void> _getRoute(LatLng dest) async {
    if (_currentLatLng == null) return;

    const apiKey = "YOUR_API_KEY"; // <-- এখানে আপনার Google Maps API Key দিন
    final url =
        "https://maps.googleapis.com/maps/api/directions/json?origin=${_currentLatLng!.latitude},${_currentLatLng!.longitude}&destination=${dest.latitude},${dest.longitude}&key=$apiKey";

    final response = await http.get(Uri.parse(url));
    final data = json.decode(response.body);

    if (data["routes"].isNotEmpty) {
      final points = data["routes"][0]["overview_polyline"]["points"];
      final polylineCoords = _decodePolyline(points);

      setState(() {
        _polylines.clear();
        _polylines.add(
          Polyline(
            polylineId: const PolylineId("route"),
            points: polylineCoords,
            color: Colors.blue,
            width: 5,
          ),
        );

        _markers.removeWhere((m) => m.markerId.value == "selected");
        _markers.add(
          Marker(
            markerId: const MarkerId("selected"),
            position: dest,
            infoWindow: const InfoWindow(title: "Destination"),
            icon:
            BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
          ),
        );
      });
    }
  }

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

  void _onMapTap(LatLng tappedPoint) {
    _selectedLatLng = tappedPoint;
    _getRoute(tappedPoint);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        body: GoogleMap(
          markers: _markers,
          polylines: _polylines,
          initialCameraPosition: _kInitial,
          myLocationEnabled: _locationAllowed,
          myLocationButtonEnabled: _locationAllowed,
          compassEnabled: true,
          onMapCreated: (GoogleMapController controller) {
            _controller.complete(controller);
          },
          onTap: _onMapTap,
        ),
      ),
    );
  }
}
