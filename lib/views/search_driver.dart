import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

// Mock driver model
class Driver {
  final String id;
  final String name;
  final String carModel;
  final String plateNumber;
  final double rating;
  final LatLng location;
  final double distance;
  final double fare;
  final String eta;

  Driver({
    required this.id,
    required this.name,
    required this.carModel,
    required this.plateNumber,
    required this.rating,
    required this.location,
    required this.distance,
    required this.fare,
    required this.eta,
  });
}

class MapScreen1 extends StatefulWidget {
  @override
  _MapScreen1State createState() => _MapScreen1State();
}

class _MapScreen1State extends State<MapScreen1> {
  late GoogleMapController mapController;
  TextEditingController pickupController = TextEditingController();
  TextEditingController dropOffController = TextEditingController();
  
  LatLng? currentLocation = const LatLng(0.0, 0.0);
  LatLng? pickupLocation;
  LatLng? dropOffLocation;
  Set<Marker> markers = {};
  bool _isLoading = true;
  bool _isSearchingDrivers = false;
  List<Driver> _availableDrivers = [];

  // Mock driver data (in real app, this would come from an API)
  final List<Driver> _mockDrivers = [
    Driver(
      id: '1',
      name: 'John Kamya',
      carModel: 'Toyota Premio',
      plateNumber: 'UBA 123A',
      rating: 4.8,
      location: LatLng(0.3476, 32.5825),
      distance: 0.8,
      fare: 12000,
      eta: '3 min',
    ),
    Driver(
      id: '2',
      name: 'David Ssemwanga',
      carModel: 'Toyota Wish',
      plateNumber: 'UBB 456B',
      rating: 4.9,
      location: LatLng(0.3480, 32.5830),
      distance: 1.2,
      fare: 15000,
      eta: '5 min',
    ),
    Driver(
      id: '3',
      name: 'Micheal Okello',
      carModel: 'Toyota Noah',
      plateNumber: 'UBC 789C',
      rating: 4.7,
      location: LatLng(0.3465, 32.5810),
      distance: 1.5,
      fare: 13000,
      eta: '7 min',
    ),
    Driver(
      id: '4',
      name: 'Robert Mugisha',
      carModel: 'Honda Fit',
      plateNumber: 'UBD 012D',
      rating: 4.6,
      location: LatLng(0.3490, 32.5840),
      distance: 2.0,
      fare: 11000,
      eta: '9 min',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  void _onMapCreated(GoogleMapController controller) {
    mapController = controller;
    if (currentLocation != null && currentLocation!.latitude != 0.0) {
      mapController.animateCamera(
        CameraUpdate.newLatLngZoom(currentLocation!, 14),
      );
    }
  }

  Future<void> _getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _updateLocationWithDefault();
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _updateLocationWithDefault();
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        _updateLocationWithDefault();
        return;
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
      ).timeout(const Duration(seconds: 10));

      setState(() {
        currentLocation = LatLng(position.latitude, position.longitude);
        _isLoading = false;
      });

      if (mapController != null) {
        mapController.animateCamera(
          CameraUpdate.newLatLngZoom(currentLocation!, 14),
        );
      }
    } catch (e) {
      print("Error fetching location: $e");
      _updateLocationWithDefault();
    }
  }

  void _updateLocationWithDefault() {
    setState(() {
      // Kampala coordinates as default
      currentLocation = const LatLng(0.3476, 32.5825);
      _isLoading = false;
    });
  }

  Future<void> _setPickupLocation() async {
    if (pickupController.text.isEmpty) return;
    
    try {
      List<Location> locations = await locationFromAddress(pickupController.text);
      if (locations.isNotEmpty) {
        setState(() {
          pickupLocation = LatLng(locations.first.latitude, locations.first.longitude);
          _addMarker('pickup', pickupLocation!, 'Pickup');
        });
        
        if (mapController != null) {
          mapController.animateCamera(
            CameraUpdate.newLatLng(pickupLocation!),
          );
        }
      }
    } catch (e) {
      print("Error getting pickup location: $e");
      _showSnackBar('Could not find pickup location');
    }
  }

  Future<void> _setDropOffLocation() async {
    if (dropOffController.text.isEmpty) return;
    
    try {
      List<Location> locations = await locationFromAddress(dropOffController.text);
      if (locations.isNotEmpty) {
        setState(() {
          dropOffLocation = LatLng(locations.first.latitude, locations.first.longitude);
          _addMarker('dropOff', dropOffLocation!, 'Drop Off');
        });
        
        if (pickupLocation != null && dropOffLocation != null) {
          _fitBoundsToMarkers();
        }
      }
    } catch (e) {
      print("Error getting drop-off location: $e");
      _showSnackBar('Could not find drop-off location');
    }
  }

  void _searchForDrivers() async {
    if (pickupLocation == null || dropOffLocation == null) {
      _showSnackBar('Please set both pickup and drop-off locations');
      return;
    }

    setState(() {
      _isSearchingDrivers = true;
    });

    // Simulate API call delay
    await Future.delayed(Duration(seconds: 2));

    // Filter nearby drivers (in real app, this would be API call)
    // For demo, we're using mock data
    setState(() {
      _availableDrivers = _mockDrivers;
      _isSearchingDrivers = false;
    });

    // Show driver markers on map
    _showDriverMarkers();
    
    // Navigate to driver selection screen
    _showDriverSelectionSheet();
  }

  void _showDriverMarkers() {
    setState(() {
      // Clear existing driver markers
      markers.removeWhere((marker) => marker.markerId.value.startsWith('driver_'));
      
      // Add driver markers
      for (var driver in _availableDrivers) {
        markers.add(Marker(
          markerId: MarkerId('driver_${driver.id}'),
          position: driver.location,
          infoWindow: InfoWindow(title: driver.name),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
        ));
      }
    });
  }

  void _showDriverSelectionSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.7,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Available Drivers',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              Divider(height: 0),
              Expanded(
                child: ListView.builder(
                  padding: EdgeInsets.all(16),
                  itemCount: _availableDrivers.length,
                  itemBuilder: (context, index) {
                    final driver = _availableDrivers[index];
                    return _buildDriverCard(driver);
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDriverCard(Driver driver) {
    return Card(
      margin: EdgeInsets.only(bottom: 12),
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
                      driver.name,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      '${driver.carModel} • ${driver.plateNumber}',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ],
                ),
                Chip(
                  label: Text('${driver.rating} ⭐'),
                  backgroundColor: Colors.amber[50],
                ),
              ],
            ),
            SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.location_on, size: 16, color: Colors.grey),
                SizedBox(width: 8),
                Text('${driver.distance} km away'),
                SizedBox(width: 16),
                Icon(Icons.timer, size: 16, color: Colors.grey),
                SizedBox(width: 8),
                Text('ETA: ${driver.eta}'),
              ],
            ),
            SizedBox(height: 12),
            Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'UGX ${driver.fare.toStringAsFixed(0)}',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.green[700],
                  ),
                ),
                ElevatedButton(
                  onPressed: () => _confirmBooking(driver),
                  child: Text('Select'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _confirmBooking(Driver driver) {
    Navigator.pop(context); // Close bottom sheet
    _showSnackBar('Booking confirmed with ${driver.name}');
    
    // In a real app, you would navigate to a booking confirmation screen
    // Navigator.push(context, MaterialPageRoute(
    //   builder: (context) => BookingConfirmationScreen(
    //     driver: driver,
    //     pickup: pickupLocation!,
    //     dropoff: dropOffLocation!,
    //   ),
    // ));
  }

  void _fitBoundsToMarkers() {
    if (pickupLocation == null || dropOffLocation == null) return;
    
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
      mapController.animateCamera(
        CameraUpdate.newLatLngBounds(bounds, 100),
      );
    }
  }

  void _addMarker(String markerId, LatLng position, String title) {
    setState(() {
      markers.removeWhere((marker) => marker.markerId.value == markerId);
      markers.add(Marker(
        markerId: MarkerId(markerId),
        position: position,
        infoWindow: InfoWindow(title: title),
        icon: BitmapDescriptor.defaultMarkerWithHue(
          markerId == 'pickup' ? BitmapDescriptor.hueGreen : BitmapDescriptor.hueRed,
        ),
      ));
    });
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Find a Driver'),
        backgroundColor: Colors.green,
        actions: [
          IconButton(
            icon: Icon(Icons.my_location),
            onPressed: () {
              if (currentLocation != null && mapController != null) {
                mapController.animateCamera(
                  CameraUpdate.newLatLngZoom(currentLocation!, 14),
                );
              }
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          GoogleMap(
            onMapCreated: _onMapCreated,
            initialCameraPosition: CameraPosition(
              target: currentLocation!,
              zoom: 12,
            ),
            markers: markers,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            compassEnabled: true,
          ),
          
          if (_isLoading)
            Center(
              child: Container(
                padding: EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 10),
                    Text('Getting your location...'),
                  ],
                ),
              ),
            ),
          
          if (_isSearchingDrivers)
            Center(
              child: Container(
                padding: EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 10),
                    Text('Searching for drivers...'),
                  ],
                ),
              ),
            ),
          
          Positioned(
            bottom: 20,
            left: 10,
            right: 10,
            child: Container(
              padding: EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(color: Colors.black26, blurRadius: 5, spreadRadius: 1),
                ],
              ),
              child: Column(
                children: [
                  TextField(
                    controller: pickupController,
                    decoration: InputDecoration(
                      labelText: 'Pick Up',
                      suffixIcon: IconButton(
                        icon: Icon(Icons.search),
                        onPressed: _setPickupLocation,
                      ),
                    ),
                    onSubmitted: (value) => _setPickupLocation(),
                  ),
                  SizedBox(height: 10),
                  TextField(
                    controller: dropOffController,
                    decoration: InputDecoration(
                      labelText: 'Drop Off',
                      suffixIcon: IconButton(
                        icon: Icon(Icons.search),
                        onPressed: _setDropOffLocation,
                      ),
                    ),
                    onSubmitted: (value) => _setDropOffLocation(),
                  ),
                  SizedBox(height: 15),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _searchForDrivers,
                          child: _isSearchingDrivers
                              ? Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                      ),
                                    ),
                                    SizedBox(width: 10),
                                    Text('Searching...'),
                                  ],
                                )
                              : Text('Find Drivers'),
                          style: ElevatedButton.styleFrom(
                            padding: EdgeInsets.symmetric(vertical: 15),
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                    ],
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