import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

const kGoogleApiKey = "AIzaSyDJ53HjRqauguIbbfgRKtBq_yy1eX7Q4HI";

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  late GoogleMapController mapController;
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
        title: Text(isPickup ? 'Search Pickup Location' : 'Search Drop Off Location'),
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

      mapController.animateCamera(
        CameraUpdate.newLatLngBounds(bounds, 100),
      );
    } else if (pickupLocation != null) {
      _moveCameraToLocation(pickupLocation!);
    } else if (dropOffLocation != null) {
      _moveCameraToLocation(dropOffLocation!);
    }
  }

  void _moveCameraToLocation(LatLng location) {
    mapController.animateCamera(
      CameraUpdate.newLatLngZoom(location, 14),
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

  void _showRideConfirmation(BuildContext context) {
    if (pickupLocation == null || dropOffLocation == null) {
      _showErrorSnackbar('Please select both pickup and drop-off locations');
      return;
    }
    
    double distance = _calculateDistanceInKm();
    double fare = _calculateFare(distance, 'car');
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RideConfirmationScreen(
          pickupAddress: pickupController.text,
          dropOffAddress: dropOffController.text,
          distance: distance,
          estimatedFare: fare,
          pickupLocation: pickupLocation!,
          dropOffLocation: dropOffLocation!,
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
                      Text('Searching...', style: TextStyle(color: Colors.grey)),
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
                      const Icon(Icons.error_outline, color: Colors.red, size: 64),
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
                    
                    Positioned(
                      top: MediaQuery.of(context).padding.top + 16,
                      left: 16,
                      right: 16,
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
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
                          child: const Icon(Icons.my_location, color: Colors.blue),
                          mini: true,
                        ),
                      ),
                    ),
                    
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
                            onPressed: () => _showRideConfirmation(context),
                            style: ElevatedButton.styleFrom(
                              minimumSize: const Size(double.infinity, 56),
                              backgroundColor: const Color(0xFF1A73E8),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                            child: const Text(
                              'Confirm Ride',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
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
  void dispose() {
    pickupController.dispose();
    dropOffController.dispose();
    super.dispose();
  }
}

class RideConfirmationScreen extends StatefulWidget {
  final String pickupAddress;
  final String dropOffAddress;
  final double distance;
  final double estimatedFare;
  final LatLng pickupLocation;
  final LatLng dropOffLocation;

  const RideConfirmationScreen({
    super.key,
    required this.pickupAddress,
    required this.dropOffAddress,
    required this.distance,
    required this.estimatedFare,
    required this.pickupLocation,
    required this.dropOffLocation,
  });

  @override
  State<RideConfirmationScreen> createState() => _RideConfirmationScreenState();
}

class _RideConfirmationScreenState extends State<RideConfirmationScreen> {
  String? _selectedVehicleType = 'car';
  bool _isFindingDriver = false;
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
    },
  ];

  Future<void> _makePhoneCall(String phoneNumber) async {
    final Uri launchUri = Uri(
      scheme: 'tel',
      path: phoneNumber,
    );
    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not launch phone dialer'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Confirm Ride'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          onPressed: () {
            if (_assignedDriver != null && !_isFindingDriver) {
              _showCancelConfirmationDialog();
            } else {
              Navigator.pop(context);
            }
          },
        ),
      ),
      body: _isFindingDriver && _assignedDriver != null
          ? _buildDriverAssignedView()
          : _buildRideSelectionView(),
    );
  }

  void _showCancelConfirmationDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Ride?'),
        content: const Text('Are you sure you want to cancel this ride?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text('Yes, Cancel'),
          ),
        ],
      ),
    );
  }

  Widget _buildRideSelectionView() {
    final currencyFormat = NumberFormat.currency(
      symbol: 'UGX ',
      decimalDigits: 0,
    );

    List<Map<String, dynamic>> filteredDrivers = _availableDrivers
        .where((driver) => driver['vehicleType'] == _selectedVehicleType)
        .toList();

    return WillPopScope(
      onWillPop: () async {
        if (_assignedDriver != null && !_isFindingDriver) {
          _showCancelConfirmationDialog();
          return false;
        }
        return true;
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Card(
                elevation: 3,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.circle, color: Colors.green, size: 16),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              widget.pickupAddress,
                              style: const TextStyle(fontSize: 16),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const Padding(
                        padding: EdgeInsets.only(left: 7),
                        child: SizedBox(
                          height: 20,
                          width: 2,
                          child: ColoredBox(color: Colors.grey),
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.only(left: 7),
                        child: SizedBox(
                          height: 20,
                          width: 2,
                          child: ColoredBox(color: Colors.grey),
                        ),
                      ),
                      Row(
                        children: [
                          const Icon(Icons.location_on, color: Colors.red, size: 16),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              widget.dropOffAddress,
                              style: const TextStyle(fontSize: 16),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Divider(),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Distance:',
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                          Text(
                            '${widget.distance.toStringAsFixed(1)} km',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 24),
              
              const Text(
                'Select Vehicle Type',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    const SizedBox(width: 8),
                    _buildVehicleTypeOption(
                      'car',
                      Icons.directions_car,
                      'Car',
                      currencyFormat.format(widget.estimatedFare),
                    ),
                    const SizedBox(width: 12),
                    _buildVehicleTypeOption(
                      'motorcycle',
                      Icons.motorcycle,
                      'Boda',
                      currencyFormat.format(widget.estimatedFare * 0.7),
                    ),
                    const SizedBox(width: 12),
                    _buildVehicleTypeOption(
                      'bike',
                      Icons.directions_bike,
                      'Bike',
                      currencyFormat.format(widget.estimatedFare * 0.5),
                    ),
                    const SizedBox(width: 8),
                  ],
                ),
              ),
              
              const SizedBox(height: 24),
              
              Text(
                'Available ${_selectedVehicleType == 'car' ? 'Drivers' : _selectedVehicleType == 'motorcycle' ? 'Riders' : 'Cyclists'}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              
              if (filteredDrivers.isEmpty)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Column(
                      children: [
                        const Icon(
                          Icons.warning,
                          size: 64,
                          color: Colors.orange,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No ${_selectedVehicleType == 'car' ? 'drivers' : _selectedVehicleType == 'motorcycle' ? 'riders' : 'cyclists'} available',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                Column(
                  children: filteredDrivers.map((driver) {
                    double finalFare = widget.estimatedFare * driver['fareMultiplier'];
                    
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      driver['name'],
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      driver['vehicleModel'],
                                      style: TextStyle(
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                    if ((driver['plateNumber'] as String).isNotEmpty)
                                      Text(
                                        driver['plateNumber'],
                                        style: TextStyle(
                                          color: Colors.grey[600],
                                          fontSize: 12,
                                        ),
                                      ),
                                  ],
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      currencyFormat.format(finalFare),
                                      style: const TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF1A73E8),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        const Icon(
                                          Icons.star,
                                          color: Colors.amber,
                                          size: 16,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(driver['rating'].toString()),
                                      ],
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.access_time,
                                      color: Colors.green,
                                      size: 16,
                                    ),
                                    const SizedBox(width: 4),
                                    Text('${driver['eta']} away'),
                                  ],
                                ),
                                ElevatedButton(
                                  onPressed: () => _assignDriver(driver),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF1A73E8),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  child: const Text('Book Now'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVehicleTypeOption(
      String type, IconData icon, String label, String price) {
    bool isSelected = _selectedVehicleType == type;
    
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedVehicleType = type;
        });
      },
      child: Container(
        width: 100,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF1A73E8).withOpacity(0.1) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? const Color(0xFF1A73E8) : Colors.grey[300]!,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isSelected ? const Color(0xFF1A73E8) : Colors.grey[600],
              size: 32,
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? const Color(0xFF1A73E8) : Colors.grey[600],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              price,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDriverAssignedView() {
    if (_assignedDriver == null) return Container();
    
    return WillPopScope(
      onWillPop: () async {
        _showCancelConfirmationDialog();
        return false;
      },
      child: Scaffold(
        body: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF1A73E8), Color(0xFF4285F4)],
                  ),
                ),
                child: Column(
                  children: [
                    if (_isFindingDriver)
                      Column(
                        children: [
                          const CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Finding a driver...',
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      )
                    else
                      Column(
                        children: [
                          const Icon(
                            Icons.check_circle,
                            color: Colors.white,
                            size: 64,
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Driver Assigned!',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'ETA: ${_assignedDriver!['eta']}',
                            style: const TextStyle(
                              fontSize: 18,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
              
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Card(
                      elevation: 3,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          children: [
                            CircleAvatar(
                              radius: 40,
                              backgroundColor: Colors.grey[200],
                              child: Icon(
                                _selectedVehicleType == 'car'
                                    ? Icons.person
                                    : _selectedVehicleType == 'motorcycle'
                                        ? Icons.motorcycle
                                        : Icons.directions_bike,
                                size: 40,
                                color: const Color(0xFF1A73E8),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _assignedDriver!['name'],
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _assignedDriver!['vehicleModel'],
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey[600],
                              ),
                            ),
                            if ((_assignedDriver!['plateNumber'] as String).isNotEmpty)
                              Text(
                                _assignedDriver!['plateNumber'],
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[600],
                                ),
                              ),
                            const SizedBox(height: 16),
                            const Divider(),
                            const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                children: [
                                  IconButton(
                                    icon: const Icon(
                                      Icons.phone,
                                      color: Color(0xFF1A73E8),
                                      size: 28,
                                    ),
                                    onPressed: () => _makePhoneCall(_assignedDriver!['phone']),
                                  ),
                                  const SizedBox(height: 4),
                                  const Text(
                                    'Contact',
                                    style: TextStyle(color: Colors.grey),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _assignedDriver!['phone'],
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              Column(
                                children: [
                                  const Icon(
                                    Icons.star,
                                    color: Colors.amber,
                                    size: 28,
                                  ),
                                  const SizedBox(height: 8),
                                  const Text(
                                    'Rating',
                                    style: TextStyle(color: Colors.grey),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _assignedDriver!['rating'].toString(),
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
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
                  
                  const SizedBox(height: 24),
                  
                  const Text(
                    'Trip Details',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Pickup:', style: TextStyle(color: Colors.grey)),
                              Expanded(
                                child: Text(
                                  widget.pickupAddress,
                                  textAlign: TextAlign.right,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Drop-off:', style: TextStyle(color: Colors.grey)),
                              Expanded(
                                child: Text(
                                  widget.dropOffAddress,
                                  textAlign: TextAlign.right,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Distance:', style: TextStyle(color: Colors.grey)),
                              Text('${widget.distance.toStringAsFixed(1)} km'),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Fare:', style: TextStyle(color: Colors.grey)),
                              Text(
                                NumberFormat.currency(symbol: 'UGX ', decimalDigits: 0)
                                    .format(widget.estimatedFare * _assignedDriver!['fareMultiplier']),
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1A73E8),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 32),
                  
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => _makePhoneCall(_assignedDriver!['phone']),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            minimumSize: const Size(0, 50),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.phone),
                              SizedBox(width: 8),
                              Text('Call Driver'),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _showCancelConfirmationDialog,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            minimumSize: const Size(0, 50),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.cancel),
                              SizedBox(width: 8),
                              Text('Cancel Ride'),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ]),
        ),
      ),
    );
  }

  void _assignDriver(Map<String, dynamic> driver) {
    setState(() {
      _isFindingDriver = true;
      _assignedDriver = driver;
    });
    
    Future.delayed(const Duration(seconds: 2), () {
      setState(() {
        _isFindingDriver = false;
      });
    });
  }
}