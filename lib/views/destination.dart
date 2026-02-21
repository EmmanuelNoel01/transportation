// ignore_for_file: prefer_const_constructors, sort_child_properties_last

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import 'home.dart';

const kGoogleApiKey = "AIzaSyDJ53HjRqauguIbbfgRKtBq_yy1eX7Q4HI";

class MapScreen extends StatefulWidget {
  final String? selectedVehicleType;

  const MapScreen({super.key, this.selectedVehicleType = 'car'});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  GoogleMapController?
      mapController; // Make nullable to prevent late initialization error
  TextEditingController pickupController = TextEditingController();
  TextEditingController dropOffController = TextEditingController();

  LatLng? currentLocation;
  LatLng? pickupLocation;
  LatLng? dropOffLocation;

  Set<Marker> markers = {};
  Set<Polyline> polylines = {};

  bool _isLoading = true;
  String? _errorMessage;
  bool _isPickupSearching = false;
  bool _isDropOffSearching = false;

  static const CameraPosition _defaultCamera = CameraPosition(
    target: LatLng(0.3136, 32.5811),
    zoom: 14,
  );

  @override
  void initState() {
    super.initState();
    _initializeLocation();
  }

  Future<void> _initializeLocation() async {
    try {
      await _getCurrentLocation();
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = "Failed to initialize location: ${e.toString()}";
      });
    }
  }

  Future<void> _getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception("Location services are disabled");
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception("Location permissions denied");
        }
      }

      if (permission == LocationPermission.deniedForever) {
        throw Exception("Location permissions permanently denied");
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        currentLocation = LatLng(position.latitude, position.longitude);
        _isLoading = false;
      });

      _setPickupFromCurrentLocation();
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString();
      });
    }
  }

  void _onMapCreated(GoogleMapController controller) {
    mapController = controller;
    if (currentLocation != null) {
      _moveCameraToLocation(currentLocation!);
    }
  }

  Future<void> _searchLocation(BuildContext context, bool isPickup) async {
    final TextEditingController searchController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
            isPickup ? 'Search Pickup Location' : 'Search Drop Off Location'),
        content: TextField(
          controller: searchController,
          decoration: const InputDecoration(
            hintText: 'Enter address or place name',
            prefixIcon: Icon(Icons.search),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _performSearch(searchController.text, isPickup);
            },
            child: const Text('Search'),
          ),
        ],
      ),
    );
  }

  Future<void> _performSearch(String query, bool isPickup) async {
    if (query.isEmpty) return;

    if (isPickup) {
      setState(() => _isPickupSearching = true);
    } else {
      setState(() => _isDropOffSearching = true);
    }

    try {
      List<Location> locations = await locationFromAddress(query);

      if (locations.isNotEmpty) {
        final location = locations.first;
        final LatLng latLng = LatLng(location.latitude, location.longitude);

        List<Placemark> placemarks = await placemarkFromCoordinates(
          location.latitude,
          location.longitude,
        );

        String address = placemarks.isNotEmpty
            ? '${placemarks.first.street ?? ''}, ${placemarks.first.locality ?? ''}'
            : query;

        if (isPickup) {
          await _setPickupLocation(latLng, address);
        } else {
          await _setDropOffLocation(latLng, address);
        }
      } else {
        _showErrorSnackbar('Location not found');
      }
    } catch (e) {
      _showErrorSnackbar('Error searching location: ${e.toString()}');
    } finally {
      if (isPickup) {
        setState(() => _isPickupSearching = false);
      } else {
        setState(() => _isDropOffSearching = false);
      }
    }
  }

  Future<void> _setPickupLocation(LatLng location, String address) async {
    setState(() {
      pickupLocation = location;
      pickupController.text = address;
    });

    _addMarker('pickup', location, 'Pickup', BitmapDescriptor.hueGreen);
    await _updateCameraForBothLocations();
  }

  Future<void> _setDropOffLocation(LatLng location, String address) async {
    setState(() {
      dropOffLocation = location;
      dropOffController.text = address;
    });

    _addMarker('dropOff', location, 'Drop Off', BitmapDescriptor.hueRed);
    await _updateCameraForBothLocations();

    if (pickupLocation != null) {
      await _getRouteBetweenPoints();
    }
  }

  Future<void> _setPickupFromCurrentLocation() async {
    if (currentLocation != null) {
      try {
        List<Placemark> placemarks = await placemarkFromCoordinates(
          currentLocation!.latitude,
          currentLocation!.longitude,
        );

        String address = placemarks.isNotEmpty
            ? '${placemarks.first.street ?? ''}, ${placemarks.first.locality ?? ''}'
            : 'Current Location';

        await _setPickupLocation(currentLocation!, address);
      } catch (e) {
        await _setPickupLocation(currentLocation!, 'Current Location');
      }
    }
  }

  void _addMarker(String id, LatLng position, String title, double hue) {
    setState(() {
      markers.removeWhere((marker) => marker.markerId.value == id);
      markers.add(Marker(
        markerId: MarkerId(id),
        position: position,
        infoWindow: InfoWindow(title: title),
        icon: BitmapDescriptor.defaultMarkerWithHue(hue),
      ));
    });
  }

  Future<void> _getRouteBetweenPoints() async {
    if (pickupLocation == null || dropOffLocation == null) return;

    setState(() {
      polylines.clear();
      polylines.add(Polyline(
        polylineId: const PolylineId('route'),
        points: [pickupLocation!, dropOffLocation!],
        color: Colors.blue,
        width: 4,
        startCap: Cap.roundCap,
        endCap: Cap.roundCap,
      ));
    });
  }

  void _clearRoute() {
    setState(() {
      polylines.clear();
    });
  }

  void _clearAll() {
    setState(() {
      pickupController.clear();
      dropOffController.clear();
      pickupLocation = null;
      dropOffLocation = null;
      markers.removeWhere((m) => m.markerId.value != 'current');
      _clearRoute();
    });
  }

  Future<void> _updateCameraForBothLocations() async {
    if (pickupLocation != null && dropOffLocation != null) {
      LatLngBounds bounds = LatLngBounds(
        southwest: LatLng(
          pickupLocation!.latitude < dropOffLocation!.latitude
              ? pickupLocation!.latitude
              : dropOffLocation!.latitude,
          pickupLocation!.longitude < dropOffLocation!.longitude
              ? pickupLocation!.longitude
              : dropOffLocation!.longitude,
        ),
        northeast: LatLng(
          pickupLocation!.latitude > dropOffLocation!.latitude
              ? pickupLocation!.latitude
              : dropOffLocation!.latitude,
          pickupLocation!.longitude > dropOffLocation!.longitude
              ? pickupLocation!.longitude
              : dropOffLocation!.longitude,
        ),
      );

      if (mapController != null) {
        mapController!.animateCamera(
          CameraUpdate.newLatLngBounds(bounds, 100),
        );
      }
    } else if (pickupLocation != null) {
      _moveCameraToLocation(pickupLocation!);
    } else if (dropOffLocation != null) {
      _moveCameraToLocation(dropOffLocation!);
    }
  }

  void _moveCameraToLocation(LatLng location) {
    if (mapController != null) {
      mapController!.animateCamera(
        CameraUpdate.newLatLngZoom(location, 14),
      );
    }
  }

  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  double _calculateDistanceInKm() {
    if (pickupLocation == null || dropOffLocation == null) return 0.0;

    double distanceInMeters = Geolocator.distanceBetween(
      pickupLocation!.latitude,
      pickupLocation!.longitude,
      dropOffLocation!.latitude,
      dropOffLocation!.longitude,
    );

    return distanceInMeters / 1000;
  }

  double _calculateFare(double distance, String vehicleType) {
    double baseFare;
    double perKmRate;

    switch (vehicleType) {
      case 'motorcycle':
        baseFare = 2000;
        perKmRate = 1500;
        break;
      case 'bike':
        baseFare = 1000;
        perKmRate = 800;
        break;
      case 'car':
      default:
        baseFare = 3000;
        perKmRate = 2000;
    }

    double fare = baseFare + (distance * perKmRate);
    return fare.roundToDouble();
  }

  void _confirmRide() {
    if (pickupLocation == null || dropOffLocation == null) {
      _showErrorSnackbar('Please select both pickup and drop-off locations');
      return;
    }

    double distance = _calculateDistanceInKm();
    double fare = _calculateFare(distance, widget.selectedVehicleType!);

    // Navigate to searching screen first
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SearchingDriverScreen(
          pickupAddress: pickupController.text,
          dropOffAddress: dropOffController.text,
          distance: distance,
          estimatedFare: fare,
          pickupLocation: pickupLocation!,
          dropOffLocation: dropOffLocation!,
          vehicleType: widget.selectedVehicleType!,
        ),
      ),
    );
  }

  Widget _buildLocationField(
    String label,
    IconData icon,
    Color color,
    TextEditingController controller,
    bool isLoading,
    VoidCallback onTap,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: isLoading
                ? Row(
                    children: [
                      const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      const SizedBox(width: 10),
                      Text('Searching...',
                          style: TextStyle(color: Colors.grey)),
                    ],
                  )
                : GestureDetector(
                    onTap: onTap,
                    child: AbsorbPointer(
                      child: TextField(
                        controller: controller,
                        decoration: InputDecoration(
                          hintText: label,
                          border: InputBorder.none,
                          hintStyle: TextStyle(color: Colors.grey[600]),
                        ),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline,
                          color: Colors.red, size: 64),
                      const SizedBox(height: 16),
                      Text(
                        _errorMessage!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.red),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _getCurrentLocation,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : Stack(
                  children: [
                    GoogleMap(
                      onMapCreated: _onMapCreated,
                      initialCameraPosition: _defaultCamera,
                      markers: markers,
                      polylines: polylines,
                      myLocationEnabled: true,
                      myLocationButtonEnabled: false,
                      zoomControlsEnabled: false,
                    ),

                    // Back Button - Added at top left corner
                    Positioned(
                      top: MediaQuery.of(context).padding.top + 16,
                      left: 16,
                      child: GestureDetector(
                        onTap: () {
                          Navigator.pop(context);
                        },
                        child: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black12,
                                  blurRadius: 8,
                                  spreadRadius: 1,
                                ),
                              ],
                            ),
                            child: IconButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (context) => HomeScreen()),
                                );
                              },
                              icon: const Icon(
                                Icons.arrow_back_ios,
                                color: Colors.black,
                                size: 24,
                              ),
                            )),
                      ),
                    ),

                    // Location Input Container
                    Positioned(
                      top: MediaQuery.of(context).padding.top + 16,
                      left: 72, // Adjusted to make space for back button
                      right: 16,
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            // ignore: prefer_const_constructors
                            BoxShadow(
                              color: Colors.black12,
                              blurRadius: 20,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            _buildLocationField(
                              'Pick Up',
                              Icons.location_on,
                              Colors.green,
                              pickupController,
                              _isPickupSearching,
                              () => _searchLocation(context, true),
                            ),
                            const SizedBox(height: 12),
                            Container(
                              height: 2,
                              color: Colors.grey[200],
                              margin: const EdgeInsets.symmetric(horizontal: 8),
                            ),
                            const SizedBox(height: 12),
                            _buildLocationField(
                              'Drop Off',
                              Icons.location_on,
                              Colors.red,
                              dropOffController,
                              _isDropOffSearching,
                              () => _searchLocation(context, false),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // My Location Button
                    Positioned(
                      bottom: 100,
                      right: 16,
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black26,
                              blurRadius: 4,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                        child: FloatingActionButton(
                          heroTag: 'locationBtn',
                          onPressed: () {
                            if (currentLocation != null) {
                              _moveCameraToLocation(currentLocation!);
                            }
                          },
                          backgroundColor: Colors.white,
                          child:
                              const Icon(Icons.my_location, color: Colors.blue),
                          mini: true,
                        ),
                      ),
                    ),

                    // Clear All Button
                    Positioned(
                      bottom: 150,
                      right: 16,
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black26,
                              blurRadius: 4,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                        child: FloatingActionButton(
                          heroTag: 'clearBtn',
                          onPressed: _clearAll,
                          backgroundColor: Colors.white,
                          child: const Icon(Icons.clear, color: Colors.red),
                          mini: true,
                        ),
                      ),
                    ),

                    // Confirm Ride Button
                    if (pickupLocation != null && dropOffLocation != null)
                      Positioned(
                        bottom: 20,
                        left: 16,
                        right: 16,
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black26,
                                blurRadius: 10,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: ElevatedButton(
                            onPressed: _confirmRide,
                            style: ElevatedButton.styleFrom(
                              minimumSize: const Size(double.infinity, 56),
                              backgroundColor: const Color(0xFF1A73E8),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.directions_car,
                                    color: Colors.white),
                                const SizedBox(width: 8),
                                const Text(
                                  'Confirm Ride',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.black26,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    widget.selectedVehicleType == 'car'
                                        ? 'Car'
                                        : widget.selectedVehicleType ==
                                                'motorcycle'
                                            ? 'Boda'
                                            : 'Bike',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
    );
  }

  @override
  void dispose() {
    mapController?.dispose();
    pickupController.dispose();
    dropOffController.dispose();
    super.dispose();
  }
}

class SearchingDriverScreen extends StatefulWidget {
  final String pickupAddress;
  final String dropOffAddress;
  final double distance;
  final double estimatedFare;
  final LatLng pickupLocation;
  final LatLng dropOffLocation;
  final String vehicleType;

  const SearchingDriverScreen({
    super.key,
    required this.pickupAddress,
    required this.dropOffAddress,
    required this.distance,
    required this.estimatedFare,
    required this.pickupLocation,
    required this.dropOffLocation,
    required this.vehicleType,
  });

  @override
  State<SearchingDriverScreen> createState() => _SearchingDriverScreenState();
}

class _SearchingDriverScreenState extends State<SearchingDriverScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  bool _isFindingDriver = true;
  Map<String, dynamic>? _assignedDriver;

  final List<Map<String, dynamic>> _availableDrivers = [
    {
      'id': '1',
      'name': 'John Kamya',
      'phone': '+256772123456',
      'vehicleType': 'car',
      'vehicleModel': 'Toyota Premio',
      'plateNumber': 'UAA 123A',
      'rating': 4.8,
      'distance': 2.1,
      'eta': '5 min',
      'fareMultiplier': 1.0,
      'imageUrl': '',
    },
    {
      'id': '2',
      'name': 'David Omondi',
      'phone': '+256752234567',
      'vehicleType': 'motorcycle',
      'vehicleModel': 'Bajaj Boxer',
      'plateNumber': 'UBB 456B',
      'rating': 4.5,
      'distance': 1.2,
      'eta': '3 min',
      'fareMultiplier': 0.7,
      'imageUrl': '',
    },
    {
      'id': '3',
      'name': 'Sarah Nalubega',
      'phone': '+256712345678',
      'vehicleType': 'car',
      'vehicleModel': 'Nissan X-Trail',
      'plateNumber': 'UCC 789C',
      'rating': 4.9,
      'distance': 3.5,
      'eta': '8 min',
      'fareMultiplier': 1.0,
      'imageUrl': '',
    },
    {
      'id': '4',
      'name': 'Peter Okello',
      'phone': '+256782456789',
      'vehicleType': 'bike',
      'vehicleModel': 'Mountain Bike',
      'plateNumber': '',
      'rating': 4.3,
      'distance': 0.8,
      'eta': '2 min',
      'fareMultiplier': 0.5,
      'imageUrl': '',
    },
  ];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    _animation = Tween<double>(begin: 0.8, end: 1.2).animate(_controller);

    // Simulate finding driver
    _findNearestDriver();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _findNearestDriver() async {
    // Simulate API call to backend
    await Future.delayed(const Duration(seconds: 3));

    // Find nearest driver matching vehicle type
    List<Map<String, dynamic>> matchingDrivers = _availableDrivers
        .where((driver) => driver['vehicleType'] == widget.vehicleType)
        .toList();

    if (matchingDrivers.isNotEmpty) {
      // Sort by distance and take the nearest
      matchingDrivers.sort((a, b) => a['distance'].compareTo(b['distance']));
      setState(() {
        _assignedDriver = matchingDrivers.first;
        _isFindingDriver = false;
      });
      _controller.stop();
    } else {
      // No driver found - show error after delay
      await Future.delayed(const Duration(seconds: 2));
      _showNoDriverDialog();
    }
  }

  void _showNoDriverDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('No Driver Available'),
        content: Text(
          'Sorry, no ${widget.vehicleType == 'car' ? 'drivers' : widget.vehicleType == 'motorcycle' ? 'riders' : 'cyclists'} '
          'are available near your pickup location. '
          'Please try again later or change your vehicle type.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _makePhoneCall(String phoneNumber) async {
    try {
      // Clean the phone number
      String cleanedNumber = phoneNumber.trim();

      // Remove any non-numeric characters except +
      if (!cleanedNumber.startsWith('+')) {
        // Add default country code if missing
        cleanedNumber =
            '+256${cleanedNumber.replaceAll(RegExp(r'[^0-9]'), '')}';
      }

      // Create the phone URL
      final Uri phoneUri = Uri(
        scheme: 'tel',
        path: cleanedNumber,
      );

      // Check if the device can handle the URL
      bool canLaunch = await canLaunchUrl(phoneUri);

      if (canLaunch) {
        await launchUrl(phoneUri);
      } else {
        // Fallback: Show phone number for manual dialing
        _showPhoneNumberDialog(cleanedNumber);
      }
    } catch (e) {
      // Fallback: Show phone number for manual dialing
      _showPhoneNumberDialog(phoneNumber);
    }
  }

  void _showPhoneNumberDialog(String phoneNumber) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Call Driver'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Unable to launch phone dialer automatically.'),
            const SizedBox(height: 10),
            Text(
              'Phone: $phoneNumber',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.blue,
              ),
            ),
            const SizedBox(height: 10),
            const Text('Please copy this number and dial manually.'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
          TextButton(
            onPressed: () {
              // Copy to clipboard
              Clipboard.setData(ClipboardData(text: phoneNumber));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Phone number copied to clipboard'),
                  backgroundColor: Colors.green,
                ),
              );
              Navigator.pop(context);
            },
            child: const Text('Copy'),
          ),
        ],
      ),
    );
  }

  void _cancelRideAndReturn() {
    Navigator.pop(context);
  }

  Widget _buildSearchingView() {
    return Scaffold(
      backgroundColor: const Color(0xFF1A73E8),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ScaleTransition(
            scale: _animation,
            child: const Icon(
              Icons.location_searching,
              color: Colors.white,
              size: 120,
            ),
          ),
          const SizedBox(height: 30),
          const Text(
            'Searching for drivers',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Looking for ${widget.vehicleType == 'car' ? 'drivers' : widget.vehicleType == 'motorcycle' ? 'riders' : 'cyclists'} '
            'near your location',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 16,
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: 20),
          const CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            strokeWidth: 4,
          ),
          const SizedBox(height: 30),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Pickup:',
                      style: TextStyle(color: Colors.white70),
                    ),
                    Expanded(
                      child: Text(
                        widget.pickupAddress,
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Vehicle:',
                      style: TextStyle(color: Colors.white70),
                    ),
                    Text(
                      widget.vehicleType == 'car'
                          ? 'Car'
                          : widget.vehicleType == 'motorcycle'
                              ? 'Motorcycle'
                              : 'Bicycle',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 40),
          ElevatedButton(
            onPressed: _cancelRideAndReturn,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF1A73E8),
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
            ),
            child: const Text(
              'Cancel Search',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDriverAssignedView() {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 22, 22, 34),
      appBar: AppBar(
        backgroundColor: const Color.fromARGB(255, 22, 22, 34),
        title: const Text(''),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          color: const Color(0xFF666666),
          onPressed: () => _showCancelConfirmationDialog(),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 1),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    const Color(0xFF1A73E8),
                    const Color(0xFF1A73E8).withOpacity(0.9),
                  ],
                ),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(30),
                  bottomRight: Radius.circular(30),
                ),
              ),
              child: Column(
                children: [
                  const Icon(
                    Icons.check_circle,
                    color: Colors.white,
                    size: 80,
                  ),
                  const SizedBox(height: 15),
                  Text(
                    '${_assignedDriver!['name']} is on the way!',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'ETA: ${_assignedDriver!['eta']}',
                    style: const TextStyle(
                      fontSize: 18,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Driver Card
                  Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 35,
                                backgroundColor:
                                    const Color(0xFF1A73E8).withOpacity(0.1),
                                child: Icon(
                                  widget.vehicleType == 'car'
                                      ? Icons.directions_car
                                      : widget.vehicleType == 'motorcycle'
                                          ? Icons.motorcycle
                                          : Icons.directions_bike,
                                  size: 40,
                                  color: const Color(0xFF1A73E8),
                                ),
                              ),
                              const SizedBox(width: 20),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _assignedDriver!['name'],
                                      style: const TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 5),
                                    Text(
                                      _assignedDriver!['vehicleModel'],
                                      style: TextStyle(
                                        fontSize: 16,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                    if ((_assignedDriver!['plateNumber']
                                            as String)
                                        .isNotEmpty)
                                      Text(
                                        _assignedDriver!['plateNumber'],
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              Column(
                                children: [
                                  IconButton(
                                    icon: const Icon(
                                      Icons.phone,
                                      color: Color(0xFF1A73E8),
                                      size: 30,
                                    ),
                                    onPressed: () => _makePhoneCall(
                                        _assignedDriver!['phone']),
                                  ),
                                  const SizedBox(height: 5),
                                  const Text(
                                    'Call',
                                    style: TextStyle(color: Colors.grey),
                                  ),
                                ],
                              ),
                              Column(
                                children: [
                                  const Icon(
                                    Icons.star,
                                    color: Colors.amber,
                                    size: 30,
                                  ),
                                  const SizedBox(height: 5),
                                  Text(
                                    '${_assignedDriver!['rating']}',
                                    style: const TextStyle(color: Colors.grey),
                                  ),
                                ],
                              ),
                              Column(
                                children: [
                                  const Icon(
                                    Icons.timer,
                                    color: Colors.green,
                                    size: 30,
                                  ),
                                  const SizedBox(height: 5),
                                  Text(
                                    '${_assignedDriver!['eta']}',
                                    style: const TextStyle(color: Colors.grey),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 25),

                  // Trip Details
                  const Text(
                    'Trip Details',
                    style: TextStyle(
                      fontSize: 20,
                      color: Color(0xFF666666),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 15),

                  Card(
                    elevation: 3,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          _buildTripDetailRow(
                            Icons.location_on,
                            Colors.green,
                            'Pickup',
                            widget.pickupAddress,
                          ),
                          const SizedBox(height: 15),
                          _buildTripDetailRow(
                            Icons.location_pin,
                            Colors.red,
                            'Drop-off',
                            widget.dropOffAddress,
                          ),
                          const SizedBox(height: 15),
                          _buildTripDetailRow(
                            Icons.directions,
                            Colors.blue,
                            'Distance',
                            '${widget.distance.toStringAsFixed(1)} km',
                          ),
                          const SizedBox(height: 15),
                          _buildTripDetailRow(
                            Icons.attach_money,
                            Colors.green,
                            'Fare',
                            NumberFormat.currency(
                              symbol: 'UGX ',
                              decimalDigits: 0,
                            ).format(widget.estimatedFare *
                                _assignedDriver!['fareMultiplier']),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 30),

                  // Action Buttons
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () =>
                              _makePhoneCall(_assignedDriver!['phone']),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            minimumSize: const Size(0, 55),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 15),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.phone),
                              SizedBox(width: 10),
                              Text(
                                'Call Driver',
                                style: TextStyle(fontSize: 16),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 15),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _showCancelConfirmationDialog,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                            minimumSize: const Size(0, 55),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 15),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.cancel),
                              SizedBox(width: 10),
                              Text(
                                'Cancel Ride',
                                style: TextStyle(fontSize: 16),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTripDetailRow(
      IconData icon, Color color, String title, String value) {
    return Row(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(width: 15),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 5),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showCancelConfirmationDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Ride?'),
        content: const Text(
            'Are you sure you want to cancel this ride? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('No, Continue'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _cancelRideAndReturn();
            },
            child: const Text('Yes, Cancel'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isFindingDriver) {
      return _buildSearchingView();
    } else if (_assignedDriver != null) {
      return _buildDriverAssignedView();
    } else {
      return _buildSearchingView();
    }
  }
}
