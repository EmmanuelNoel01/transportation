import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:muno_watch/services/location_service.dart';
import 'package:muno_watch/views/DropoffMapScreen.dart';
import 'package:muno_watch/views/DriverTripScreen.dart';

import '../services/driver_api_service.dart' show DriverApiService;

class PickupMapScreen extends StatefulWidget {
  final Map<String, dynamic> trip;
  final int? driverId;

  const PickupMapScreen({
    super.key,
    required this.trip,
    this.driverId,
  });

  @override
  State<PickupMapScreen> createState() => _PickupMapScreenState();
}

class _PickupMapScreenState extends State<PickupMapScreen> {
  late GoogleMapController _mapController;
  LatLng _currentLocation = const LatLng(0.3136, 32.5811);
  late LatLng _pickupLocation;
  Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};
  bool _isNavigating = false;
  bool _isLoading = false;
  double _distanceToPickup = 0;
  int _etaToPickup = 0;
  Timer? _navigationTimer;
  Timer? _locationUpdateTimer;

  @override
  void initState() {
    super.initState();
    _initializeLocation();
    _updateRideStatus('driver_assigned');
  }

  @override
  void dispose() {
    _navigationTimer?.cancel();
    _locationUpdateTimer?.cancel();
    super.dispose();
  }

  Future<void> _initializeLocation() async {
    setState(() => _isLoading = true);

    try {
      // Get current location
      final position = await LocationService.getCurrentLocation();
      
      // Set pickup location from trip data
      _pickupLocation = LatLng(
        widget.trip['pickupLat'] ?? 0.3136,
        widget.trip['pickupLng'] ?? 32.5811,
      );

      // Calculate initial distance
      _distanceToPickup = LocationService.calculateDistance(
        position.latitude,
        position.longitude,
        _pickupLocation.latitude,
        _pickupLocation.longitude,
      );

      _etaToPickup = LocationService.calculateETA(_distanceToPickup, 30);

      setState(() {
        _currentLocation = LatLng(position.latitude, position.longitude);
        _isLoading = false;
      });

      _setupMap();
      _startLocationUpdates();
    } catch (e) {
      setState(() => _isLoading = false);
      _showErrorSnackbar('Failed to get location: $e');
    }
  }

  void _startLocationUpdates() {
    _locationUpdateTimer = Timer.periodic(const Duration(seconds: 10), (timer) async {
      if (!_isNavigating && mounted) {
        try {
          final position = await LocationService.getCurrentLocation();
          setState(() {
            _currentLocation = LatLng(position.latitude, position.longitude);
          });
          
          // Update marker
          _updateCurrentLocationMarker();
        } catch (e) {
          print('Location update failed: $e');
        }
      }
    });
  }

  void _updateCurrentLocationMarker() {
    setState(() {
      _markers.removeWhere((marker) => marker.markerId.value == 'current_location');
      _markers.add(Marker(
        markerId: const MarkerId('current_location'),
        position: _currentLocation,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
        infoWindow: const InfoWindow(title: 'Your Location'),
      ));
    });
  }

  void _setupMap() {
    // Set up markers
    _markers = {
      Marker(
        markerId: const MarkerId('current_location'),
        position: _currentLocation,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
        infoWindow: const InfoWindow(title: 'Your Location'),
      ),
      Marker(
        markerId: const MarkerId('pickup_location'),
        position: _pickupLocation,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        infoWindow: InfoWindow(title: 'Pickup: ${widget.trip['from']}'),
      ),
    };

    // Draw route to pickup
    _drawRouteToPickup();
  }

  void _drawRouteToPickup() {
    List<LatLng> polylineCoordinates = [
      _currentLocation,
      LatLng(
        (_currentLocation.latitude + _pickupLocation.latitude) / 2,
        (_currentLocation.longitude + _pickupLocation.longitude) / 2,
      ),
      _pickupLocation,
    ];

    setState(() {
      _polylines.add(Polyline(
        polylineId: const PolylineId('route_to_pickup'),
        color: Colors.blue,
        points: polylineCoordinates,
        width: 4,
      ));
    });
  }

  Future<void> _updateRideStatus(String status) async {
    if (widget.trip['id'] == null || widget.driverId == null) return;
    
    try {
      await DriverApiService.updateRideStatus(
        rideId: int.parse(widget.trip['id'].toString()),
        driverId: widget.driverId!,
        status: status,
      );
    } catch (e) {
      print('Failed to update ride status: $e');
    }
  }

  void _startNavigation() {
    setState(() {
      _isNavigating = true;
    });

    _updateRideStatus('driver_arrived');
    _simulateMovement();
  }

  void _simulateMovement() {
    if (!_isNavigating || _distanceToPickup <= 0) return;

    _navigationTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      if (_distanceToPickup > 0 && mounted) {
        setState(() {
          // Reduce distance by 100m every 2 seconds (approx 3 km/h)
          _distanceToPickup = max(0, _distanceToPickup - 0.1);
          _etaToPickup = (_distanceToPickup * 2).ceil();

          // Move current location closer to pickup
          _currentLocation = LatLng(
            _currentLocation.latitude +
                (_pickupLocation.latitude - _currentLocation.latitude) * 0.02,
            _currentLocation.longitude +
                (_pickupLocation.longitude - _currentLocation.longitude) * 0.02,
          );

          // Update marker
          _updateCurrentLocationMarker();

          // Update camera
          _mapController.animateCamera(
            CameraUpdate.newLatLng(_currentLocation),
          );
        });

        // Check if arrived
        if (_distanceToPickup <= 0.1) {
          timer.cancel();
          _arrivedAtPickup();
        }
      }
    });
  }

  void _arrivedAtPickup() {
    setState(() {
      _distanceToPickup = 0;
      _etaToPickup = 0;
      _isNavigating = false;
    });

    _navigationTimer?.cancel();
    _updateRideStatus('driver_arrived');
    _showArrivalDialog();
  }

  void _showArrivalDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2A2A3A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
        ),
        title: const Text(
          'Arrived at Pickup',
          style: TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.location_on, size: 50, color: Colors.green),
            const SizedBox(height: 15),
            Text(
              'You have arrived at ${widget.trip['from']}',
              style: const TextStyle(color: Colors.white70),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              'Passenger: ${widget.trip['passenger']}',
              style: const TextStyle(
                color: Colors.white, 
                fontWeight: FontWeight.bold
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'OK',
              style: TextStyle(color: Colors.blue),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              await _updateRideStatus('in_progress');
              if (mounted) {
                Navigator.pop(context);
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => DropoffMapScreen(
                      trip: widget.trip,
                      driverId: widget.driverId,
                    ),
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
            ),
            child: const Text('START TRIP'),
          ),
        ],
      ),
    );
  }

  void _cancelNavigation() {
    _navigationTimer?.cancel();
    setState(() {
      _isNavigating = false;
    });
  }

  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 22, 22, 34),
      appBar: AppBar(
        backgroundColor: const Color.fromARGB(255, 22, 22, 34),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () {
            _cancelNavigation();
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => DriverTripScreen(
                  accountType: widget.trip['vehicle_type'] ?? 'Car',
                  driverId: widget.driverId,
                ),
              ),
            );
          },
        ),
        title: const Text(
          'Navigate to Pickup',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                // Google Map
                GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: _currentLocation,
                    zoom: 15,
                  ),
                  onMapCreated: (controller) {
                    _mapController = controller;
                  },
                  markers: _markers,
                  polylines: _polylines,
                  myLocationEnabled: true,
                  myLocationButtonEnabled: true,
                  zoomControlsEnabled: false,
                  mapType: MapType.normal,
                  style: '''
                    [
                      {
                        "elementType": "geometry",
                        "stylers": [{"color": "#212121"}]
                      },
                      {
                        "elementType": "labels.icon",
                        "stylers": [{"visibility": "off"}]
                      },
                      {
                        "elementType": "labels.text.fill",
                        "stylers": [{"color": "#757575"}]
                      },
                      {
                        "elementType": "labels.text.stroke",
                        "stylers": [{"color": "#212121"}]
                      }
                    ]
                  ''',
                ),

                // Trip Info Overlay
                Positioned(
                  top: 20,
                  left: 20,
                  right: 20,
                  child: Container(
                    padding: const EdgeInsets.all(15),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2A2A3A),
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(color: const Color(0xFF3A3A4A)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: Colors.green.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Icon(Icons.person, color: Colors.green),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    widget.trip['passenger'] ?? 'Passenger',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  Text(
                                    'Passenger',
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.7),
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              widget.trip['amount'] ?? 'UGX 0',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 15),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'PICKUP',
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.7),
                                      fontSize: 12,
                                    ),
                                  ),
                                  Text(
                                    widget.trip['from'] ?? 'Unknown',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  'ETA',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.7),
                                    fontSize: 12,
                                  ),
                                ),
                                Text(
                                  '$_etaToPickup min',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                // Distance Info
                Positioned(
                  bottom: 150,
                  left: 20,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.directions_car,
                            color: Colors.white, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          '${_distanceToPickup.toStringAsFixed(1)} km to pickup',
                          style: const TextStyle(color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ),

                // Navigation Button
                Positioned(
                  bottom: 40,
                  left: 20,
                  right: 20,
                  child: ElevatedButton(
                    onPressed: _isNavigating ? _cancelNavigation : _startNavigation,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isNavigating ? Colors.red : Colors.blue,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _isNavigating ? Icons.stop : Icons.navigation,
                          size: 24,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          _isNavigating ? 'CANCEL NAVIGATION' : 'START NAVIGATION',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}