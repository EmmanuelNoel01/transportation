import 'package:flutter/material.dart';
import 'package:muno_watch/views/home.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  int _currentIndex = 2; // Set to 2 to indicate we're on Profile screen

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 22, 22, 34),
      body: Stack(
        children: [
          // Main content area
          Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 100),

                        // Profile Card
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2A2A3A),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: const Color(0xFF3A3A4A),
                              width: 1,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Profile Title
                              Text(
                                'Profile',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey[400],
                                ),
                              ),
                              const SizedBox(height: 16),

                              // User Name
                              Row(
                                children: [
                                  Container(
                                    width: 60,
                                    height: 60,
                                    decoration: BoxDecoration(
                                      color: const Color.fromARGB(255, 13, 137, 246),
                                      borderRadius: BorderRadius.circular(30),
                                    ),
                                    child: const Center(
                                      child: Icon(
                                        Icons.person,
                                        color: Colors.white,
                                        size: 30,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Tanya Myroniuk',
                                          style: const TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.white,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          'Email: tanya@example.com',
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: Colors.grey[400],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    onPressed: () {
                                      // Edit profile action
                                      print('Edit profile tapped');
                                    },
                                    icon: Icon(
                                      Icons.edit,
                                      color: Colors.grey[400],
                                      size: 20,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 30),

                        // Trips Section
                        Text(
                          'Trips',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),

                        const SizedBox(height: 20),

                        // Trip History - Placeholders as instructed
                        _buildTripCard(
                          date: 'Today, 10:30 AM',
                          service: 'Car Ride',
                          from: 'Downtown',
                          to: 'Airport',
                          price: '\$25.50',
                          status: 'Completed',
                        ),

                        const SizedBox(height: 12),

                        _buildTripCard(
                          date: 'Yesterday, 3:15 PM',
                          service: 'Motorcycle',
                          from: 'Home',
                          to: 'Office',
                          price: '\$12.75',
                          status: 'Completed',
                        ),

                        const SizedBox(height: 12),

                        _buildTripCard(
                          date: 'Feb 5, 2026 - 9:00 AM',
                          service: 'Bike Ride',
                          from: 'Park',
                          to: 'Gym',
                          price: '\$8.00',
                          status: 'Completed',
                        ),

                        const SizedBox(height: 12),

                        _buildTripCard(
                          date: 'Feb 4, 2026 - 6:45 PM',
                          service: 'Car Ride',
                          from: 'Restaurant',
                          to: 'Home',
                          price: '\$18.25',
                          status: 'Completed',
                        ),

                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
              ),

              // Spacer for bottom navigation
              Container(
                height: 70,
                color: Colors.transparent,
              ),
            ],
          ),

          // Bottom Navigation Bar (without logo)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              height: 70,
              decoration: const BoxDecoration(
                color: Color.fromARGB(255, 22, 22, 34),
                border: Border(
                  top: BorderSide(color: Color(0xFF3A3A4A), width: 1),
                ),
              ),
              child: Row(
                children: [
                  // Home Navigation Item
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const HomeScreen(),
                          ),
                        );
                      },
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.home,
                            color: Colors.grey[600],
                            size: 44,
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Empty space in the middle where logo will sit on top
                  Container(width: 80),

                  // Profile Navigation Item (Active)
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.person,
                          color: const Color.fromARGB(255, 13, 137, 246),
                          size: 44,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Floating Logo - Positioned above the navigation bar
          Positioned(
            left: MediaQuery.of(context).size.width / 2 - 40,
            bottom: 30, // Same position as HomeScreen
            child: GestureDetector(
              onTap: () {
                // Add logo tap action if needed
                print('Logo tapped on Profile screen');
              },
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: const Color.fromARGB(255, 22, 22, 34),
                  borderRadius: BorderRadius.circular(40),
                ),
                child: Center(
                  child: SizedBox(
                    width: 70,
                    height: 70,
                    child: ClipOval(
                      child: Image.asset(
                        'assets/logo.png',
                        width: 40,
                        height: 40,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) {
                          return const Icon(
                            Icons.pedal_bike,
                            color: Colors.white,
                            size: 32,
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTripCard({
    required String date,
    required String service,
    required String from,
    required String to,
    required String price,
    required String status,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A3A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF3A3A4A),
          width: 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Service Icon
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color.fromARGB(255, 13, 137, 246).withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Icon(
                _getServiceIcon(service),
                color: const Color.fromARGB(255, 13, 137, 246),
                size: 22,
              ),
            ),
          ),
          const SizedBox(width: 16),
          
          // Trip Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      service,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      price,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  date,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[500],
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: Colors.green,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      from,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[400],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      to,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[400],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    status,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.green,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData _getServiceIcon(String service) {
    switch (service.toLowerCase()) {
      case 'car ride':
        return Icons.directions_car;
      case 'motorcycle':
        return Icons.two_wheeler;
      case 'bike ride':
        return Icons.pedal_bike;
      default:
        return Icons.directions_car;
    }
  }
}