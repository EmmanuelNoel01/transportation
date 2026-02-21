import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:muno_watch/services/driver_api_service.dart';
import 'package:muno_watch/services/location_service.dart';
import 'package:muno_watch/views/DriverTripScreen.dart';

import 'PickupMapScreen.dart';

class DropoffMapScreen extends StatefulWidget {
  final Map<String, dynamic> trip;
  final int? driverId;

  const DropoffMapScreen({
    super.key,
    required this.trip,
    this.driverId,
  });

  @override
  State<DropoffMapScreen> createState() => _DropoffMapScreenState();
}

class _DropoffMapScreenState extends State<DropoffMapScreen> {
  late GoogleMapController _mapController;
  LatLng _currentLocation = const LatLng(0.3136, 32.5811);
  late LatLng _dropoffLocation;
  Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};
  bool _isNavigating = false;
  bool _hasPassenger = false;
  bool _isLoading = false;
  double _distanceToDropoff = 0;
  int _etaToDropoff = 0;
  double _tripProgress = 0.0;
  Timer? _progressTimer;
  Timer? _locationUpdateTimer;

  @override
  void initState() {
    super.initState();
    _initializeLocation();
  }

  @override
  void dispose() {
    _progressTimer?.cancel();
    _locationUpdateTimer?.cancel();
    super.dispose();
  }

  Future<void> _initializeLocation() async {
    setState(() => _isLoading = true);

    try {
      // Get current location
      final position = await LocationService.getCurrentLocation();
      
      // Set dropoff location from trip data
      _dropoffLocation = LatLng(
        widget.trip['dropoffLat'] ?? 0.3136,
        widget.trip['dropoffLng'] ?? 32.5811,
      );

      // Calculate initial distance
      _distanceToDropoff = LocationService.calculateDistance(
        position.latitude,
        position.longitude,
        _dropoffLocation.latitude,
        _dropoffLocation.longitude,
      );

      _etaToDropoff = LocationService.calculateETA(_distanceToDropoff, 30);

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
        infoWindow: const InfoWindow(title: 'Current Location'),
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
        infoWindow: const InfoWindow(title: 'Current Location'),
      ),
      Marker(
        markerId: const MarkerId('dropoff_location'),
        position: _dropoffLocation,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        infoWindow: InfoWindow(title: 'Dropoff: ${widget.trip['to']}'),
      ),
    };

    // Draw route to dropoff
    _drawRouteToDropoff();
  }

  void _drawRouteToDropoff() {
    List<LatLng> polylineCoordinates = [
      _currentLocation,
      LatLng(
        (_currentLocation.latitude + _dropoffLocation.latitude) / 2,
        (_currentLocation.longitude + _dropoffLocation.longitude) / 2,
      ),
      _dropoffLocation,
    ];

    setState(() {
      _polylines.add(Polyline(
        polylineId: const PolylineId('route_to_dropoff'),
        color: Colors.red,
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

  void _pickupPassenger() {
    setState(() {
      _hasPassenger = true;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Colors.green,
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 10),
            const Text('Passenger picked up'),
          ],
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _startNavigation() {
    if (!_hasPassenger) {
      _showErrorSnackbar('Please pick up passenger first');
      return;
    }

    setState(() {
      _isNavigating = true;
    });

    _updateRideStatus('in_progress');
    _startProgressSimulation();
  }

  void _cancelNavigation() {
    _progressTimer?.cancel();
    setState(() {
      _isNavigating = false;
    });
  }

  void _startProgressSimulation() {
    _progressTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      if (_tripProgress < 1.0 && mounted) {
        setState(() {
          _tripProgress += 0.02;
          _distanceToDropoff = max(0, _distanceToDropoff - 0.1);
          _etaToDropoff = (_distanceToDropoff * 2).ceil();
          
          // Move current location towards dropoff
          _currentLocation = LatLng(
            _currentLocation.latitude + 
                (_dropoffLocation.latitude - _currentLocation.latitude) * 0.02,
            _currentLocation.longitude + 
                (_dropoffLocation.longitude - _currentLocation.longitude) * 0.02,
          );

          _updateCurrentLocationMarker();

          _mapController.animateCamera(
            CameraUpdate.newLatLng(_currentLocation),
          );
        });

        if (_tripProgress >= 1.0 || _distanceToDropoff <= 0.1) {
          timer.cancel();
          _arrivedAtDropoff();
        }
      }
    });
  }

  void _arrivedAtDropoff() {
    setState(() {
      _isNavigating = false;
      _distanceToDropoff = 0;
      _etaToDropoff = 0;
      _tripProgress = 1.0;
    });

    _updateRideStatus('completed');
    _showCompletionDialog();
  }

  void _showCompletionDialog() {
    double earnings = 0;
    if (widget.trip['amount'] != null) {
      String amountStr = widget.trip['amount'].toString().replaceAll('UGX ', '').replaceAll(',', '');
      earnings = double.tryParse(amountStr) ?? 0;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2A2A3A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
        ),
        title: const Text(
          'Trip Completed!',
          style: TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.celebration, size: 50, color: Colors.green),
            const SizedBox(height: 15),
            Text(
              'You have arrived at ${widget.trip['to']}',
              style: const TextStyle(color: Colors.white70),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.3),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Earnings:',
                        style: TextStyle(color: Colors.white70),
                      ),
                      Text(
                        'UGX ${earnings.toStringAsFixed(0)}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Distance:',
                        style: TextStyle(color: Colors.white70),
                      ),
                      Text(
                        widget.trip['distance'] ?? '0 km',
                        style: const TextStyle(color: Colors.white),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
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
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
            ),
            child: const Text('BACK TO TRIPS'),
          ),
        ],
      ),
    );
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
                builder: (context) => PickupMapScreen(
                  trip: widget.trip,
                  driverId: widget.driverId,
                ),
              ),
            );
          },
        ),
        title: const Text(
          'Trip in Progress',
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
                                color: Colors.blue.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Icon(Icons.person, color: Colors.blue),
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
                                    _hasPassenger ? 'Onboard' : 'Waiting for pickup',
                                    style: TextStyle(
                                      color: _hasPassenger ? Colors.green : Colors.orange,
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
                        
                        // Progress Bar
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'DROPOFF',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.7),
                                    fontSize: 12,
                                  ),
                                ),
                                Text(
                                  'ETA: $_etaToDropoff min',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 5),
                            Text(
                              widget.trip['to'] ?? 'Unknown',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 10),
                            LinearProgressIndicator(
                              value: _tripProgress,
                              backgroundColor: Colors.grey[800],
                              color: Colors.green,
                              minHeight: 8,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            const SizedBox(height: 5),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  '${(_tripProgress * 100).toInt()}% Complete',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.7),
                                    fontSize: 12,
                                  ),
                                ),
                                Text(
                                  '${_distanceToDropoff.toStringAsFixed(1)} km left',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.7),
                                    fontSize: 12,
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

                // Passenger Status Button
                if (!_hasPassenger)
                  Positioned(
                    bottom: 150,
                    left: 20,
                    right: 20,
                    child: ElevatedButton(
                      onPressed: _pickupPassenger,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.person_add, size: 24),
                          SizedBox(width: 10),
                          Text(
                            'PICK UP PASSENGER',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
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
                    onPressed: _hasPassenger 
                        ? (_isNavigating ? _cancelNavigation : _startNavigation)
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: !_hasPassenger 
                          ? Colors.grey 
                          : _isNavigating 
                              ? Colors.red
                              : Colors.blue,
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
                          _isNavigating 
                              ? 'CANCEL NAVIGATION' 
                              : 'NAVIGATE TO DROPOFF',
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