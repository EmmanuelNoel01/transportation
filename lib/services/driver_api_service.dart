import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/driver_models.dart';

class DriverApiService {
  // Replace with your actual server URL
  static const String baseUrl = 'http://192.168.100.194/api/driver_api.php';
  
  // Headers for API requests
  static Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };

  // Helper method to safely parse JSON responses
  static dynamic _handleResponse(http.Response response) {
    if (response.statusCode == 200) {
      try {
        return json.decode(response.body);
      } catch (e) {
        throw Exception('Invalid JSON response: $e');
      }
    } else {
      throw Exception('Server error: ${response.statusCode} - ${response.body}');
    }
  }

  // Helper method to safely parse double values from API responses
  static double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) {
      return double.tryParse(value) ?? 0.0;
    }
    return 0.0;
  }

  // Helper method to safely parse int values from API responses
  static int _parseInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) {
      return int.tryParse(value) ?? 0;
    }
    return 0;
  }

  // Helper method to safely parse boolean values from API responses
  static bool _parseBool(dynamic value) {
    if (value == null) return false;
    if (value is bool) return value;
    if (value is int) return value == 1;
    if (value is String) {
      return value.toLowerCase() == 'true' || value == '1';
    }
    return false;
  }

  // ==================== DRIVER AUTHENTICATION ====================

  /// Driver Login
  static Future<Map<String, dynamic>> driverLogin(String email, String password) async {
    try {
      print('Attempting login for: $email');
      
      final response = await http.post(
        Uri.parse('$baseUrl?action=driver_login'),
        headers: _headers,
        body: json.encode({
          'email': email.trim(),
          'password': password,
        }),
      ).timeout(const Duration(seconds: 10));

      print('Login response status: ${response.statusCode}');
      print('Login response body: ${response.body}');

      final result = _handleResponse(response);

      if (result['success'] == true) {
        // Save driver data locally
        if (result['data'] != null && result['data']['user'] != null) {
          await _saveDriverData(result['data']['user']);
          
          // Create driver object with safe parsing
          final userData = result['data']['user'];
          final driver = Driver(
            id: _parseInt(userData['id']),
            name: userData['name']?.toString() ?? '',
            email: userData['email']?.toString() ?? '',
            profileImage: userData['profile_image']?.toString(),
            vehicleType: userData['vehicle_type']?.toString() ?? '',
            vehicleModel: userData['vehicle_model']?.toString() ?? '',
            plateNumber: userData['plate_number']?.toString() ?? '',
            rating: _parseDouble(userData['rating']),
            totalRides: _parseInt(userData['total_rides']),
            isOnline: _parseBool(userData['is_online']),
            isAvailable: _parseBool(userData['is_available']),
            currentLatitude: userData['current_latitude'] != null 
                ? _parseDouble(userData['current_latitude']) 
                : null,
            currentLongitude: userData['current_longitude'] != null 
                ? _parseDouble(userData['current_longitude']) 
                : null,
          );
          
          return {
            'success': true,
            'driver': driver,
            'message': result['message'] ?? 'Login successful'
          };
        } else {
          return {'success': false, 'message': 'Invalid response format'};
        }
      } else {
        return {'success': false, 'message': result['message'] ?? 'Login failed'};
      }
    } catch (e) {
      print('Login error: $e');
      return {'success': false, 'message': 'Network error: ${e.toString()}'};
    }
  }

  /// Driver Logout
  static Future<Map<String, dynamic>> driverLogout(int driverId) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl?action=driver_logout'),
        headers: _headers,
        body: json.encode({
          'driver_id': driverId,
        }),
      ).timeout(const Duration(seconds: 5));

      final result = _handleResponse(response);
      
      if (result['success'] == true) {
        await clearDriverData();
      }
      
      return {
        'success': result['success'] ?? false,
        'message': result['message'] ?? 'Logout completed',
      };
    } catch (e) {
      print('Logout error: $e');
      // Still clear local data even if server request fails
      await clearDriverData();
      return {'success': true, 'message': 'Logged out locally'};
    }
  }

  /// Driver Registration
  static Future<Map<String, dynamic>> registerDriver({
    required String name,
    required String email,
    required String password,
    required String dob,
    required String vehicleType,
    required String vehicleModel,
    required String plateNumber,
    String? vehicleColor,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl?action=register_driver'),
        headers: _headers,
        body: json.encode({
          'name': name.trim(),
          'email': email.trim(),
          'password': password,
          'DOB': dob,
          'vehicle_type': vehicleType.toLowerCase(),
          'vehicle_model': vehicleModel,
          'vehicle_color': vehicleColor,
          'plate_number': plateNumber.toUpperCase(),
        }),
      ).timeout(const Duration(seconds: 10));

      final result = _handleResponse(response);

      if (result['success'] == true) {
        return {
          'success': true, 
          'driverId': _parseInt(result['data']?['id']),
          'message': result['message'] ?? 'Registration successful'
        };
      } else {
        return {'success': false, 'message': result['message'] ?? 'Registration failed'};
      }
    } catch (e) {
      print('Registration error: $e');
      return {'success': false, 'message': 'Network error: ${e.toString()}'};
    }
  }

  // ==================== DRIVER STATUS & LOCATION ====================

  /// Update Driver Location
  static Future<Map<String, dynamic>> updateLocation({
    required int driverId,
    required double latitude,
    required double longitude,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl?action=update_location'),
        headers: _headers,
        body: json.encode({
          'driver_id': driverId,
          'latitude': latitude,
          'longitude': longitude,
        }),
      ).timeout(const Duration(seconds: 5));

      final result = _handleResponse(response);
      return {
        'success': result['success'] ?? false,
        'message': result['message'] ?? 'Location updated',
      };
    } catch (e) {
      print('Location update error: $e');
      return {'success': false, 'message': 'Network error: ${e.toString()}'};
    }
  }

  /// Toggle Driver Availability
  static Future<Map<String, dynamic>> toggleAvailability({
    required int driverId,
    required bool isAvailable,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl?action=toggle_availability'),
        headers: _headers,
        body: json.encode({
          'driver_id': driverId,
          'is_available': isAvailable ? 1 : 0,
        }),
      ).timeout(const Duration(seconds: 5));

      final result = _handleResponse(response);
      return {
        'success': result['success'] ?? false,
        'message': result['message'] ?? 'Availability updated',
      };
    } catch (e) {
      print('Toggle availability error: $e');
      return {'success': false, 'message': 'Network error: ${e.toString()}'};
    }
  }

  /// Get Driver Stats
  static Future<Map<String, dynamic>> getDriverStats(int driverId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl?action=driver_stats&driver_id=$driverId'),
        headers: _headers,
      ).timeout(const Duration(seconds: 5));

      final result = _handleResponse(response);

      if (result['success'] == true && result['data'] != null && result['data']['stats'] != null) {
        final statsData = result['data']['stats'];
        
        final stats = DriverStats(
          totalRides: _parseInt(statsData['total_rides']),
          totalEarnings: _parseDouble(statsData['total_earnings']),
          rating: _parseDouble(statsData['rating']),
          totalRatings: _parseInt(statsData['total_ratings']),
          todayRides: _parseInt(statsData['today_rides']),
          todayEarnings: _parseDouble(statsData['today_earnings']),
          acceptanceRate: _parseDouble(statsData['acceptance_rate']),
          cancellationRate: _parseDouble(statsData['cancellation_rate']),
        );
        
        return {'success': true, 'stats': stats};
      } else {
        return {'success': false, 'message': result['message'] ?? 'Failed to load stats'};
      }
    } catch (e) {
      print('Get stats error: $e');
      return {'success': false, 'message': 'Network error: ${e.toString()}'};
    }
  }

  // ==================== RIDE MANAGEMENT ====================

  /// Get Available Trips (for driver)
  static Future<Map<String, dynamic>> getAvailableTrips({
    required int driverId,
    required String vehicleType,
    required double latitude,
    required double longitude,
    double radius = 15,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl?action=get_available_trips'),
        headers: _headers,
        body: json.encode({
          'driver_id': driverId,
          'vehicle_type': vehicleType.toLowerCase(),
          'latitude': latitude,
          'longitude': longitude,
          'radius': radius,
        }),
      ).timeout(const Duration(seconds: 10));

      final result = _handleResponse(response);

      if (result['success'] == true) {
        List<TripRequest> trips = [];
        if (result['data'] != null && result['data']['trips'] != null) {
          trips = (result['data']['trips'] as List).map((t) {
            return TripRequest(
              id: _parseInt(t['id']),
              passengerName: t['passengerName']?.toString() ?? 'Unknown',
              pickupLat: _parseDouble(t['pickupLat']),
              pickupLng: _parseDouble(t['pickupLng']),
              pickupAddress: t['pickupAddress']?.toString() ?? '',
              dropoffLat: _parseDouble(t['dropoffLat']),
              dropoffLng: _parseDouble(t['dropoffLng']),
              dropoffAddress: t['dropoffAddress']?.toString() ?? '',
              distance: _parseDouble(t['distance']),
              fare: _parseDouble(t['fare']),
              vehicleType: t['vehicleType']?.toString() ?? vehicleType,
              estimatedDuration: _parseInt(t['estimatedDuration']),
            );
          }).toList();
        }
        return {
          'success': true, 
          'trips': trips,
          'count': trips.length
        };
      } else {
        return {'success': false, 'message': result['message'] ?? 'No trips found'};
      }
    } catch (e) {
      print('Get available trips error: $e');
      return {'success': false, 'message': 'Network error: ${e.toString()}'};
    }
  }

  /// Accept a Ride
  static Future<Map<String, dynamic>> acceptRide(int rideId, int driverId) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl?action=accept_ride'),
        headers: _headers,
        body: json.encode({
          'ride_id': rideId,
          'driver_id': driverId,
        }),
      ).timeout(const Duration(seconds: 5));

      final result = _handleResponse(response);
      
      return {
        'success': result['success'] ?? false,
        'message': result['message'] ?? 'Ride acceptance processed',
        'data': result['data'],
      };
    } catch (e) {
      print('Accept ride error: $e');
      return {'success': false, 'message': 'Network error: ${e.toString()}'};
    }
  }

  /// Update Ride Status
  static Future<Map<String, dynamic>> updateRideStatus({
    required int rideId,
    required int driverId,
    required String status,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl?action=update_ride_status'),
        headers: _headers,
        body: json.encode({
          'ride_id': rideId,
          'driver_id': driverId,
          'status': status,
        }),
      ).timeout(const Duration(seconds: 5));

      final result = _handleResponse(response);
      
      return {
        'success': result['success'] ?? false,
        'message': result['message'] ?? 'Status updated to $status',
      };
    } catch (e) {
      print('Update ride status error: $e');
      return {'success': false, 'message': 'Network error: ${e.toString()}'};
    }
  }

  /// Get Ride Details
  static Future<Map<String, dynamic>> getRideDetails(int rideId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl?action=get_ride&ride_id=$rideId'),
        headers: _headers,
      ).timeout(const Duration(seconds: 5));

      final result = _handleResponse(response);

      if (result['success'] == true && result['data'] != null && result['data']['ride'] != null) {
        final rideData = result['data']['ride'];
        
        // You can create a Ride object here if needed
        return {
          'success': true, 
          'ride': rideData,
          'message': 'Ride details retrieved'
        };
      } else {
        return {'success': false, 'message': result['message'] ?? 'Ride not found'};
      }
    } catch (e) {
      print('Get ride details error: $e');
      return {'success': false, 'message': 'Network error: ${e.toString()}'};
    }
  }

  /// Get Driver's Ride History
  static Future<Map<String, dynamic>> getDriverHistory(int driverId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl?action=driver_history&driver_id=$driverId'),
        headers: _headers,
      ).timeout(const Duration(seconds: 5));

      final result = _handleResponse(response);

      if (result['success'] == true) {
        List<CompletedTrip> trips = [];
        if (result['data'] != null && result['data']['rides'] != null) {
          trips = (result['data']['rides'] as List).map((r) {
            return CompletedTrip(
              id: _parseInt(r['id']),
              passengerName: r['passenger_name']?.toString() ?? 'Unknown',
              pickupAddress: r['pickup_address']?.toString() ?? '',
              dropoffAddress: r['dropoff_address']?.toString() ?? '',
              fare: _parseDouble(r['total_fare']),
              status: r['status']?.toString() ?? 'unknown',
              createdAt: DateTime.tryParse(r['created_at']?.toString() ?? '') ?? DateTime.now(),
              rating: r['rating'] != null ? _parseDouble(r['rating']) : null,
            );
          }).toList();
        }
        return {'success': true, 'trips': trips};
      } else {
        return {'success': false, 'message': result['message'] ?? 'Failed to load history'};
      }
    } catch (e) {
      print('Get driver history error: $e');
      return {'success': false, 'message': 'Network error: ${e.toString()}'};
    }
  }

  // ==================== LOCAL STORAGE ====================

  /// Save driver data to SharedPreferences
  static Future<void> _saveDriverData(Map<String, dynamic> driverData) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('driver_data', json.encode(driverData));
      
      // Save individual fields for easy access
      if (driverData['id'] != null) {
        await prefs.setInt('driver_id', _parseInt(driverData['id']));
      }
      if (driverData['name'] != null) {
        await prefs.setString('driver_name', driverData['name'].toString());
      }
      if (driverData['email'] != null) {
        await prefs.setString('driver_email', driverData['email'].toString());
      }
      if (driverData['vehicle_type'] != null) {
        await prefs.setString('vehicle_type', driverData['vehicle_type'].toString());
      }
      
      print('Driver data saved successfully');
    } catch (e) {
      print('Error saving driver data: $e');
    }
  }

  /// Get saved driver data
  static Future<Map<String, dynamic>?> getSavedDriverData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? dataString = prefs.getString('driver_data');
      if (dataString != null) {
        return json.decode(dataString);
      }
      return null;
    } catch (e) {
      print('Error getting driver data: $e');
      return null;
    }
  }

  /// Get driver ID
  static Future<int?> getDriverId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getInt('driver_id');
    } catch (e) {
      print('Error getting driver ID: $e');
      return null;
    }
  }

  /// Get driver name
  static Future<String?> getDriverName() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('driver_name');
    } catch (e) {
      return null;
    }
  }

  /// Get vehicle type
  static Future<String?> getVehicleType() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('vehicle_type');
    } catch (e) {
      return null;
    }
  }

  /// Clear all driver data (logout)
  static Future<void> clearDriverData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('driver_data');
      await prefs.remove('driver_id');
      await prefs.remove('driver_name');
      await prefs.remove('driver_email');
      await prefs.remove('vehicle_type');
      print('Driver data cleared');
    } catch (e) {
      print('Error clearing driver data: $e');
    }
  }

  /// Check if driver is logged in
  static Future<bool> isLoggedIn() async {
    final id = await getDriverId();
    return id != null && id > 0;
  }

  /// Get full driver object from local storage
  static Future<Driver?> getCurrentDriver() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? dataString = prefs.getString('driver_data');
      
      if (dataString == null) return null;
      
      final Map<String, dynamic> userData = json.decode(dataString);
      
      return Driver(
        id: _parseInt(userData['id']),
        name: userData['name']?.toString() ?? '',
        email: userData['email']?.toString() ?? '',
        profileImage: userData['profile_image']?.toString(),
        vehicleType: userData['vehicle_type']?.toString() ?? '',
        vehicleModel: userData['vehicle_model']?.toString() ?? '',
        plateNumber: userData['plate_number']?.toString() ?? '',
        rating: _parseDouble(userData['rating']),
        totalRides: _parseInt(userData['total_rides']),
        isOnline: _parseBool(userData['is_online']),
        isAvailable: _parseBool(userData['is_available']),
        currentLatitude: userData['current_latitude'] != null 
            ? _parseDouble(userData['current_latitude']) 
            : null,
        currentLongitude: userData['current_longitude'] != null 
            ? _parseDouble(userData['current_longitude']) 
            : null,
      );
    } catch (e) {
      print('Error getting current driver: $e');
      return null;
    }
  }
}