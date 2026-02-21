import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:muno_watch/services/location_service.dart';
import 'package:muno_watch/models/driver_models.dart';
import 'package:muno_watch/views/PickupMapScreen.dart' show PickupMapScreen;
import 'package:muno_watch/services/driver_api_service.dart';
import 'package:muno_watch/views/home.dart';

class DriverTripScreen extends StatefulWidget {
  final String accountType;
  final int? driverId;

  const DriverTripScreen({
    super.key,
    required this.accountType,
    this.driverId,
  });

  @override
  State<DriverTripScreen> createState() => _DriverTripScreenState();
}

class _DriverTripScreenState extends State<DriverTripScreen> {
  bool _isOnline = false;
  bool _isLoading = false;
  List<CompletedTrip> _tripHistory = [];
  TripRequest? _currentTrip;
  DriverStats? _driverStats;
  Position? _currentPosition;
  Timer? _locationTimer;
  Timer? _tripCheckTimer;

  // Debug variables
  String _debugMessage = '';
  bool _showDebug = false;

  @override
  void initState() {
    super.initState();
    _loadDriverData();
    _initializeLocation();
  }

  @override
  void dispose() {
    _locationTimer?.cancel();
    _tripCheckTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadDriverData() async {
    if (widget.driverId == null) {
      _updateDebug('❌ No driver ID provided');
      return;
    }

    setState(() => _isLoading = true);
    _updateDebug('📊 Loading driver data...');

    try {
      // Load driver stats
      _updateDebug('📊 Fetching driver stats...');
      final statsResult = await DriverApiService.getDriverStats(widget.driverId!);
      if (statsResult['success']) {
        setState(() {
          _driverStats = statsResult['stats'];
        });
        _updateDebug('✅ Stats loaded: ${_driverStats?.todayRides} rides today');
      } else {
        _updateDebug('❌ Stats error: ${statsResult['message']}');
      }

      // Load trip history
      _updateDebug('📜 Fetching trip history...');
      final historyResult = await DriverApiService.getDriverHistory(widget.driverId!);
      if (historyResult['success']) {
        setState(() {
          _tripHistory = historyResult['trips'];
        });
        _updateDebug('✅ History loaded: ${_tripHistory.length} trips');
      } else {
        _updateDebug('❌ History error: ${historyResult['message']}');
      }
    } catch (e) {
      _updateDebug('❌ Error loading data: $e');
      _showErrorSnackbar('Failed to load driver data: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _initializeLocation() async {
    try {
      _updateDebug('📍 Getting current location...');
      _currentPosition = await LocationService.getCurrentLocation();
      _updateDebug('✅ Location: ${_currentPosition!.latitude}, ${_currentPosition!.longitude}');
      _startLocationUpdates();
    } catch (e) {
      _updateDebug('❌ Location error: $e');
      _showErrorSnackbar('Location error: $e');
    }
  }

  void _startLocationUpdates() {
    _locationTimer = Timer.periodic(const Duration(seconds: 30), (timer) async {
      if (_isOnline && widget.driverId != null && _currentPosition != null) {
        try {
          final position = await LocationService.getCurrentLocation();
          _currentPosition = position;

          // Update location on server
          _updateDebug('📍 Updating location to server...');
          await DriverApiService.updateLocation(
            driverId: widget.driverId!,
            latitude: position.latitude,
            longitude: position.longitude,
          );
          _updateDebug('✅ Location updated');
        } catch (e) {
          _updateDebug('❌ Location update failed: $e');
        }
      }
    });
  }

  Future<void> _toggleAvailability() async {
    if (widget.driverId == null) {
      _showErrorSnackbar('Driver not logged in');
      return;
    }

    setState(() => _isLoading = true);

    try {
      _updateDebug('🔄 Toggling availability...');
      final result = await DriverApiService.toggleAvailability(
        driverId: widget.driverId!,
        isAvailable: !_isOnline,
      );

      if (result['success']) {
        setState(() {
          _isOnline = !_isOnline;
        });

        if (_isOnline) {
          _updateDebug('✅ Now ONLINE - checking for trips every 5 seconds');
          _startCheckingForTrips();
          _showSuccessSnackbar('You are now online');
        } else {
          _updateDebug('⏹️ Now OFFLINE - stopped checking for trips');
          _tripCheckTimer?.cancel();
          _showSuccessSnackbar('You are now offline');
        }
      } else {
        _updateDebug('❌ Toggle failed: ${result['message']}');
        _showErrorSnackbar(result['message']);
      }
    } catch (e) {
      _updateDebug('❌ Toggle error: $e');
      _showErrorSnackbar('Failed to toggle availability: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _startCheckingForTrips() {
    _tripCheckTimer = Timer.periodic(const Duration(seconds: 5), (timer) async {
      if (_isOnline && _currentPosition != null && _currentTrip == null) {
        _updateDebug('🔍 Checking for new trips...');
        await _checkForNewTrips();
      }
    });
  }

  Future<void> _checkForNewTrips() async {
    if (widget.driverId == null) {
      _updateDebug('❌ Cannot check trips: No driver ID');
      return;
    }
    
    if (_currentPosition == null) {
      _updateDebug('❌ Cannot check trips: No location');
      return;
    }

    _updateDebug('📍 Current position: ${_currentPosition!.latitude}, ${_currentPosition!.longitude}');
    _updateDebug('🚗 Vehicle type: ${widget.accountType.toLowerCase()}');
    _updateDebug('🆔 Driver ID: ${widget.driverId}');

    try {
      final result = await DriverApiService.getAvailableTrips(
        driverId: widget.driverId!,
        vehicleType: widget.accountType.toLowerCase(),
        latitude: _currentPosition!.latitude,
        longitude: _currentPosition!.longitude,
      );

      _updateDebug('📦 API Response: $result');

      if (result['success'] == true) {
        final trips = result['trips'] as List;
        _updateDebug('✅ Found ${trips.length} available trips');
        
        if (trips.isNotEmpty) {
          _updateDebug('🎯 First trip: ${trips[0].pickupAddress} - UGX ${trips[0].fare}');
          setState(() {
            _currentTrip = trips[0];
          });
        } else {
          _updateDebug('ℹ️ No trips available at the moment');
        }
      } else {
        _updateDebug('❌ API error: ${result['message']}');
      }
    } catch (e) {
      _updateDebug('❌ Error checking trips: $e');
    }
  }

  Future<void> _acceptTrip() async {
    if (_currentTrip == null || widget.driverId == null) return;

    setState(() => _isLoading = true);
    _updateDebug('✅ Accepting trip ID: ${_currentTrip!.id}');

    try {
      // First accept the ride in the database
      final acceptResult = await DriverApiService.acceptRide(
        _currentTrip!.id, 
        widget.driverId!
      );
      
      _updateDebug('📦 Accept response: $acceptResult');
      
      if (acceptResult['success'] == true && mounted) {
        _updateDebug('✅ Trip accepted, navigating to pickup...');
        
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PickupMapScreen(
              trip: {
                'id': _currentTrip!.id.toString(),
                'passenger': _currentTrip!.passengerName,
                'from': _currentTrip!.pickupAddress,
                'to': _currentTrip!.dropoffAddress,
                'amount': 'UGX ${_currentTrip!.fare.toStringAsFixed(0)}',
                'distance': '${_currentTrip!.distance.toStringAsFixed(1)} km',
                'time': '$_estimatedDuration min',
                'pickupLat': _currentTrip!.pickupLat,
                'pickupLng': _currentTrip!.pickupLng,
                'dropoffLat': _currentTrip!.dropoffLat,
                'dropoffLng': _currentTrip!.dropoffLng,
                'vehicle_type': widget.accountType,
              },
              driverId: widget.driverId!,
            ),
          ),
        ).then((_) {
          _updateDebug('🔄 Returning from trip, reloading data...');
          _loadDriverData();
          setState(() {
            _currentTrip = null;
          });
        });
      } else {
        _updateDebug('❌ Accept failed: ${acceptResult['message']}');
        _showErrorSnackbar(acceptResult['message'] ?? 'Failed to accept ride');
      }
    } catch (e) {
      _updateDebug('❌ Accept error: $e');
      _showErrorSnackbar('Failed to accept trip: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _declineTrip() {
    _updateDebug('⛔ Declining trip ID: ${_currentTrip!.id}');
    setState(() {
      _currentTrip = null;
    });
    _showSuccessSnackbar('Trip declined');
  }

  int get _estimatedDuration {
    if (_currentTrip == null || _currentPosition == null) return 5;
    
    return LocationService.calculateETA(
      LocationService.calculateDistance(
        _currentPosition!.latitude,
        _currentPosition!.longitude,
        _currentTrip!.pickupLat,
        _currentTrip!.pickupLng,
      ),
      30,
    );
  }

  void _updateDebug(String message) {
    print('🔍 [DEBUG] $message');
    setState(() {
      _debugMessage = message;
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

  void _showSuccessSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
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
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const HomeScreen()),
          ),
        ),
        title: Text(
          '${widget.accountType} Driver',
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(
              _showDebug ? Icons.visibility_off : Icons.visibility,
              color: Colors.white,
            ),
            onPressed: () {
              setState(() {
                _showDebug = !_showDebug;
              });
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Debug message banner (if enabled)
                if (_showDebug && _debugMessage.isNotEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(8),
                    color: Colors.black87,
                    child: Text(
                      _debugMessage,
                      style: const TextStyle(color: Colors.yellow, fontSize: 12),
                    ),
                  ),

                // Header with driver info and stats
                Container(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      if (_driverStats != null) ...[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _buildStatCard(
                              'Today\'s Rides',
                              _driverStats!.todayRides.toString(),
                              Icons.today,
                              Colors.blue,
                            ),
                            _buildStatCard(
                              'Earnings',
                              'UGX ${_driverStats!.todayEarnings.toStringAsFixed(0)}',
                              Icons.money,
                              Colors.green,
                            ),
                            _buildStatCard(
                              'Rating',
                              _driverStats!.rating.toStringAsFixed(1),
                              Icons.star,
                              Colors.amber,
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                      ],
                      
                      // Availability toggle
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                            'Your Availability',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.white70,
                            ),
                          ),
                          const SizedBox(width: 20),
                          Switch(
                            value: _isOnline,
                            onChanged: (_) => _toggleAvailability(),
                            activeColor: Colors.green,
                            inactiveThumbColor: Colors.red,
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 10),
                      Text(
                        _isOnline 
                            ? 'You are online and receiving trips'
                            : 'You are offline',
                        style: TextStyle(
                          fontSize: 14,
                          color: _isOnline ? Colors.green : Colors.white70,
                        ),
                      ),

                      // Show current location
                      if (_currentPosition != null && _showDebug)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            '📍 ${_currentPosition!.latitude.toStringAsFixed(4)}, ${_currentPosition!.longitude.toStringAsFixed(4)}',
                            style: const TextStyle(color: Colors.blue, fontSize: 12),
                          ),
                        ),
                    ],
                  ),
                ),

                // Current trip or waiting message
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      children: [
                        if (_currentTrip != null) ...[
                          _buildCurrentTripCard(),
                        ] else if (_isOnline) ...[
                          _buildWaitingMessage(),
                        ] else ...[
                          _buildOfflineMessage(),
                        ],

                        // Trip History
                        if (_tripHistory.isNotEmpty) ...[
                          const SizedBox(height: 20),
                          const Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'Recent Trips',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          ..._tripHistory.map((trip) => _buildHistoryCard(trip)),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A3A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF3A3A4A)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentTripCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A3A),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.orange, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'New Trip Request',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.orange),
                ),
                child: const Text(
                  'WAITING',
                  style: TextStyle(
                    color: Colors.orange,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          
          Center(
            child: Text(
              'UGX ${_currentTrip!.fare.toStringAsFixed(0)}',
              style: const TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 20),
          
          _buildTripDetailRow(
            icon: Icons.person,
            title: 'Passenger',
            value: _currentTrip!.passengerName,
          ),
          const SizedBox(height: 12),
          
          _buildTripDetailRow(
            icon: Icons.location_on,
            title: 'From',
            value: _currentTrip!.pickupAddress,
          ),
          const SizedBox(height: 12),
          
          _buildTripDetailRow(
            icon: Icons.location_pin,
            title: 'To',
            value: _currentTrip!.dropoffAddress,
          ),
          const SizedBox(height: 12),
          
          Row(
            children: [
              Expanded(
                child: _buildTripDetailRow(
                  icon: Icons.directions,
                  title: 'Distance',
                  value: '${_currentTrip!.distance.toStringAsFixed(1)} km',
                ),
              ),
              Expanded(
                child: _buildTripDetailRow(
                  icon: Icons.timer,
                  title: 'ETA to pickup',
                  value: '$_estimatedDuration min',
                ),
              ),
            ],
          ),
          const SizedBox(height: 25),
          
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: _declineTrip,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text(
                    'DECLINE',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: ElevatedButton(
                  onPressed: _acceptTrip,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text(
                    'ACCEPT',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTripDetailRow({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Row(
      children: [
        Icon(icon, color: Colors.blue, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.white70,
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.white,
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

  Widget _buildWaitingMessage() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        children: [
          const Icon(
            Icons.timer,
            size: 80,
            color: Colors.white54,
          ),
          const SizedBox(height: 20),
          const Text(
            'Waiting for trips...',
            style: TextStyle(
              fontSize: 20,
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'You\'ll receive ${widget.accountType} trips here',
            style: const TextStyle(
              fontSize: 16,
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: 30),
          const CircularProgressIndicator(
            color: Colors.blue,
            backgroundColor: Colors.white24,
          ),
        ],
      ),
    );
  }

  Widget _buildOfflineMessage() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        children: [
          const Icon(
            Icons.offline_bolt,
            size: 80,
            color: Colors.white54,
          ),
          const SizedBox(height: 20),
          const Text(
            'Go online to receive trips',
            style: TextStyle(
              fontSize: 20,
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Toggle the switch above to start receiving ${widget.accountType.toLowerCase()} trips',
            style: const TextStyle(
              fontSize: 16,
              color: Colors.white70,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryCard(CompletedTrip trip) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A3A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF3A3A4A)),
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: Colors.blue.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(25),
            ),
            child: const Icon(Icons.check_circle, color: Colors.blue),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${trip.pickupAddress} → ${trip.dropoffAddress}',
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 5),
                Text(
                  trip.passengerName,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'UGX ${trip.fare.toStringAsFixed(0)}',
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                _formatTimeAgo(trip.createdAt),
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.white.withValues(alpha: 0.5),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatTimeAgo(DateTime dateTime) {
    final difference = DateTime.now().difference(dateTime);
    
    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }
}