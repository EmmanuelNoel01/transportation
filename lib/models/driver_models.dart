class Driver {
  final int id;
  final String name;
  final String email;
  final String? profileImage;
  final String vehicleType;
  final String vehicleModel;
  final String plateNumber;
  final double rating;
  final int totalRides;
  final bool isOnline;
  final bool isAvailable;
  final double? currentLatitude;
  final double? currentLongitude;

  Driver({
    required this.id,
    required this.name,
    required this.email,
    this.profileImage,
    required this.vehicleType,
    required this.vehicleModel,
    required this.plateNumber,
    required this.rating,
    required this.totalRides,
    required this.isOnline,
    required this.isAvailable,
    this.currentLatitude,
    this.currentLongitude,
  });

  factory Driver.fromJson(Map<String, dynamic> json) {
    // Helper function to safely parse double values
    double parseDouble(dynamic value) {
      if (value == null) return 0.0;
      if (value is double) return value;
      if (value is int) return value.toDouble();
      if (value is String) {
        // Try to parse string to double
        return double.tryParse(value) ?? 0.0;
      }
      return 0.0;
    }

    // Helper function to safely parse int values
    int parseInt(dynamic value) {
      if (value == null) return 0;
      if (value is int) return value;
      if (value is double) return value.toInt();
      if (value is String) {
        return int.tryParse(value) ?? 0;
      }
      return 0;
    }

    // Helper function to safely parse boolean values
    bool parseBool(dynamic value) {
      if (value == null) return false;
      if (value is bool) return value;
      if (value is int) return value == 1;
      if (value is String) {
        return value.toLowerCase() == 'true' || value == '1';
      }
      return false;
    }

    return Driver(
      id: parseInt(json['id']),
      name: json['name']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      profileImage: json['profile_image']?.toString(),
      vehicleType: json['vehicle_type']?.toString() ?? '',
      vehicleModel: json['vehicle_model']?.toString() ?? '',
      plateNumber: json['plate_number']?.toString() ?? '',
      rating: parseDouble(json['rating']),
      totalRides: parseInt(json['total_rides']),
      isOnline: parseBool(json['is_online']),
      isAvailable: parseBool(json['is_available']),
      currentLatitude: json['current_latitude'] != null
          ? parseDouble(json['current_latitude'])
          : null,
      currentLongitude: json['current_longitude'] != null
          ? parseDouble(json['current_longitude'])
          : null,
    );
  }
}

class TripRequest {
  final int id;
  final String passengerName;
  final double pickupLat;
  final double pickupLng;
  final String pickupAddress;
  final double dropoffLat;
  final double dropoffLng;
  final String dropoffAddress;
  final double distance;
  final double fare;
  final String vehicleType;
  final int estimatedDuration;

  TripRequest({
    required this.id,
    required this.passengerName,
    required this.pickupLat,
    required this.pickupLng,
    required this.pickupAddress,
    required this.dropoffLat,
    required this.dropoffLng,
    required this.dropoffAddress,
    required this.distance,
    required this.fare,
    required this.vehicleType,
    required this.estimatedDuration,
  });

  factory TripRequest.fromJson(Map<String, dynamic> json) {
    // Helper function to safely parse double values
    double parseDouble(dynamic value) {
      if (value == null) return 0.0;
      if (value is double) return value;
      if (value is int) return value.toDouble();
      if (value is String) {
        return double.tryParse(value) ?? 0.0;
      }
      return 0.0;
    }

    // Helper function to safely parse int values
    int parseInt(dynamic value) {
      if (value == null) return 0;
      if (value is int) return value;
      if (value is double) return value.toInt();
      if (value is String) {
        return int.tryParse(value) ?? 0;
      }
      return 0;
    }

    return TripRequest(
      id: parseInt(json['id']),
      passengerName: json['passengerName']?.toString() ?? 
                      json['name']?.toString() ?? 
                      'Unknown',
      pickupLat: parseDouble(json['pickupLat'] ?? json['pickup_latitude']),
      pickupLng: parseDouble(json['pickupLng'] ?? json['pickup_longitude']),
      pickupAddress: json['pickupAddress']?.toString() ?? 
                     json['pickup_address']?.toString() ?? 
                     '',
      dropoffLat: parseDouble(json['dropoffLat'] ?? json['dropoff_latitude']),
      dropoffLng: parseDouble(json['dropoffLng'] ?? json['dropoff_longitude']),
      dropoffAddress: json['dropoffAddress']?.toString() ?? 
                      json['dropoff_address']?.toString() ?? 
                      '',
      distance: parseDouble(json['distance'] ?? json['distance_km']),
      fare: parseDouble(json['fare'] ?? json['total_fare']),
      vehicleType: json['vehicleType']?.toString() ?? 
                   json['vehicle_type']?.toString() ?? 
                   '',
      estimatedDuration: parseInt(json['estimatedDuration'] ?? 
                                   json['estimated_duration_minutes'] ?? 
                                   json['eta']),
    );
  }
}

class Ride {
  final int id;
  final int passengerId;
  final int? driverId;
  final String passengerName;
  final String? driverName;
  final String vehicleType;
  final double pickupLat;
  final double pickupLng;
  final String pickupAddress;
  final double dropoffLat;
  final double dropoffLng;
  final String dropoffAddress;
  final double distance;
  final double fare;
  final String status;
  final DateTime createdAt;
  final DateTime? assignedAt;
  final DateTime? startedAt;
  final DateTime? completedAt;

  Ride({
    required this.id,
    required this.passengerId,
    this.driverId,
    required this.passengerName,
    this.driverName,
    required this.vehicleType,
    required this.pickupLat,
    required this.pickupLng,
    required this.pickupAddress,
    required this.dropoffLat,
    required this.dropoffLng,
    required this.dropoffAddress,
    required this.distance,
    required this.fare,
    required this.status,
    required this.createdAt,
    this.assignedAt,
    this.startedAt,
    this.completedAt,
  });

  factory Ride.fromJson(Map<String, dynamic> json) {
    // Helper function to safely parse double values
    double parseDouble(dynamic value) {
      if (value == null) return 0.0;
      if (value is double) return value;
      if (value is int) return value.toDouble();
      if (value is String) {
        return double.tryParse(value) ?? 0.0;
      }
      return 0.0;
    }

    // Helper function to safely parse int values
    int parseInt(dynamic value) {
      if (value == null) return 0;
      if (value is int) return value;
      if (value is double) return value.toInt();
      if (value is String) {
        return int.tryParse(value) ?? 0;
      }
      return 0;
    }

    // Helper function to safely parse DateTime
    DateTime? parseDateTime(dynamic value) {
      if (value == null) return null;
      if (value is DateTime) return value;
      if (value is String) {
        return DateTime.tryParse(value);
      }
      return null;
    }

    return Ride(
      id: parseInt(json['id']),
      passengerId: parseInt(json['passenger_id']),
      driverId: parseInt(json['driver_id']),
      passengerName: json['passenger_name']?.toString() ?? '',
      driverName: json['driver_name']?.toString(),
      vehicleType: json['vehicle_type']?.toString() ?? '',
      pickupLat: parseDouble(json['pickup_latitude']),
      pickupLng: parseDouble(json['pickup_longitude']),
      pickupAddress: json['pickup_address']?.toString() ?? '',
      dropoffLat: parseDouble(json['dropoff_latitude']),
      dropoffLng: parseDouble(json['dropoff_longitude']),
      dropoffAddress: json['dropoff_address']?.toString() ?? '',
      distance: parseDouble(json['distance_km']),
      fare: parseDouble(json['total_fare']),
      status: json['status']?.toString() ?? 'unknown',
      createdAt: parseDateTime(json['created_at']) ?? DateTime.now(),
      assignedAt: parseDateTime(json['assigned_at']),
      startedAt: parseDateTime(json['started_at']),
      completedAt: parseDateTime(json['completed_at']),
    );
  }
}

class CompletedTrip {
  final int id;
  final String passengerName;
  final String pickupAddress;
  final String dropoffAddress;
  final double fare;
  final String status;
  final DateTime createdAt;
  final double? rating;

  CompletedTrip({
    required this.id,
    required this.passengerName,
    required this.pickupAddress,
    required this.dropoffAddress,
    required this.fare,
    required this.status,
    required this.createdAt,
    this.rating,
  });

  factory CompletedTrip.fromJson(Map<String, dynamic> json) {
    // Helper function to safely parse double values
    double parseDouble(dynamic value) {
      if (value == null) return 0.0;
      if (value is double) return value;
      if (value is int) return value.toDouble();
      if (value is String) {
        return double.tryParse(value) ?? 0.0;
      }
      return 0.0;
    }

    // Helper function to safely parse int values
    int parseInt(dynamic value) {
      if (value == null) return 0;
      if (value is int) return value;
      if (value is double) return value.toInt();
      if (value is String) {
        return int.tryParse(value) ?? 0;
      }
      return 0;
    }

    // Helper function to safely parse DateTime
    DateTime parseDateTime(dynamic value) {
      if (value == null) return DateTime.now();
      if (value is DateTime) return value;
      if (value is String) {
        return DateTime.tryParse(value) ?? DateTime.now();
      }
      return DateTime.now();
    }

    return CompletedTrip(
      id: parseInt(json['id']),
      passengerName: json['passenger_name']?.toString() ?? '',
      pickupAddress: json['pickup_address']?.toString() ?? '',
      dropoffAddress: json['dropoff_address']?.toString() ?? '',
      fare: parseDouble(json['total_fare']),
      status: json['status']?.toString() ?? 'unknown',
      createdAt: parseDateTime(json['created_at']),
      rating: json['rating'] != null ? parseDouble(json['rating']) : null,
    );
  }
}

class DriverStats {
  final int totalRides;
  final double totalEarnings;
  final double rating;
  final int totalRatings;
  final int todayRides;
  final double todayEarnings;
  final double acceptanceRate;
  final double cancellationRate;

  DriverStats({
    required this.totalRides,
    required this.totalEarnings,
    required this.rating,
    required this.totalRatings,
    required this.todayRides,
    required this.todayEarnings,
    required this.acceptanceRate,
    required this.cancellationRate,
  });

  factory DriverStats.fromJson(Map<String, dynamic> json) {
    // Helper function to safely parse double values
    double parseDouble(dynamic value) {
      if (value == null) return 0.0;
      if (value is double) return value;
      if (value is int) return value.toDouble();
      if (value is String) {
        return double.tryParse(value) ?? 0.0;
      }
      return 0.0;
    }

    // Helper function to safely parse int values
    int parseInt(dynamic value) {
      if (value == null) return 0;
      if (value is int) return value;
      if (value is double) return value.toInt();
      if (value is String) {
        return int.tryParse(value) ?? 0;
      }
      return 0;
    }

    return DriverStats(
      totalRides: parseInt(json['total_rides']),
      totalEarnings: parseDouble(json['total_earnings']),
      rating: parseDouble(json['rating']),
      totalRatings: parseInt(json['total_ratings']),
      todayRides: parseInt(json['today_rides']),
      todayEarnings: parseDouble(json['today_earnings']),
      acceptanceRate: parseDouble(json['acceptance_rate']),
      cancellationRate: parseDouble(json['cancellation_rate']),
    );
  }
}