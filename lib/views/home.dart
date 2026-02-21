import 'package:flutter/material.dart';
import 'package:muno_watch/models/driver_models.dart';
import 'package:muno_watch/views/settings.dart';

import 'DriverTripScreen.dart';

class HomeScreen extends StatefulWidget {
  final Driver? driver;

  const HomeScreen({super.key, this.driver});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      return 'Good morning';
    } else if (hour < 17) {
      return 'Good afternoon';
    } else {
      return 'Good evening';
    }
  }

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

                        // Show different content based on selected tab
                        if (_currentIndex == 0) ...[
                          const SizedBox(height: 30),

                          // Greeting Card with Stats
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  const Color.fromARGB(255, 13, 137, 246),
                                  const Color.fromARGB(255, 13, 137, 246).withValues(alpha: 0.8),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${_getGreeting()}, ${widget.driver?.name ?? 'Driver'}!',
                                  style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Ready to earn? Start accepting rides',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.white.withValues(alpha: 0.9),
                                  ),
                                ),
                                const SizedBox(height: 20),
                                
                                // Quick Stats Row
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                                  children: [
                                    _buildQuickStat(
                                      'Rating',
                                      '${widget.driver?.rating.toStringAsFixed(1) ?? '4.8'}',
                                      Icons.star,
                                      Colors.amber,
                                    ),
                                    _buildQuickStat(
                                      'Trips',
                                      '${widget.driver?.totalRides ?? '0'}',
                                      Icons.route,
                                      Colors.white,
                                    ),
                                    _buildQuickStat(
                                      'Vehicle',
                                      _getVehicleIcon(),
                                      Icons.directions_car,
                                      Colors.white,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 40),

                          // Services Section
                          const Text(
                            'Available Services',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),

                          const SizedBox(height: 20),

                          // Order a Car Card
                          _buildServiceCard(
                            title: 'Drive a Car',
                            icon: Icons.directions_car,
                            color: Colors.blue,
                            subtitle: '4-wheeler rides',
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => DriverTripScreen(
                                    accountType: 'Car',
                                    driverId: widget.driver?.id,
                                  ),
                                ),
                              );
                            },
                          ),

                          const SizedBox(height: 16),

                          // Order a Motorcycle Card
                          _buildServiceCard(
                            title: 'Ride a Motorcycle',
                            icon: Icons.two_wheeler,
                            color: Colors.green,
                            subtitle: 'Boda boda rides',
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => DriverTripScreen(
                                    accountType: 'Motorcycle',
                                    driverId: widget.driver?.id,
                                  ),
                                ),
                              );
                            },
                          ),

                          const SizedBox(height: 16),

                          // Order a Bike Card
                          _buildServiceCard(
                            title: 'Ride a Bike',
                            icon: Icons.pedal_bike,
                            color: Colors.orange,
                            subtitle: 'Eco-friendly rides',
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => DriverTripScreen(
                                    accountType: 'Bike',
                                    driverId: widget.driver?.id,
                                  ),
                                ),
                              );
                            },
                          ),

                          const SizedBox(height: 40),

                          // Today's Earnings Preview
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: const Color(0xFF2A2A3A),
                              borderRadius: BorderRadius.circular(15),
                              border: Border.all(color: const Color(0xFF3A3A4A)),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Today\'s Earnings',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.white.withValues(alpha: 0.7),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    const Text(
                                      'UGX 0',
                                      style: TextStyle(
                                        fontSize: 28,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.green.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(
                                    Icons.trending_up,
                                    color: Colors.green,
                                    size: 32,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 40),
                        ],
                      ],
                    ),
                  ),
                ),
              ),

              // Bottom Navigation Bar Space
              Container(
                height: 70,
                color: Colors.transparent,
              ),
            ],
          ),

          // Bottom Navigation Bar
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
                        setState(() {
                          _currentIndex = 0;
                        });
                      },
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.home,
                            color: _currentIndex == 0
                                ? const Color.fromARGB(255, 13, 137, 246)
                                : const Color(0xFF666666),
                            size: 28,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Home',
                            style: TextStyle(
                              color: _currentIndex == 0
                                  ? const Color.fromARGB(255, 13, 137, 246)
                                  : const Color(0xFF666666),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Empty space in the middle for logo
                  Container(width: 80),

                  // Settings Navigation Item
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const ProfileScreen(),
                          ),
                        );
                      },
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.settings,
                            color: _currentIndex == 1
                                ? const Color.fromARGB(255, 13, 137, 246)
                                : const Color(0xFF666666),
                            size: 28,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Settings',
                            style: TextStyle(
                              color: _currentIndex == 1
                                  ? const Color.fromARGB(255, 13, 137, 246)
                                  : const Color(0xFF666666),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Floating Logo
          Positioned(
            left: MediaQuery.of(context).size.width / 2 - 40,
            bottom: 30,
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: const Color.fromARGB(255, 22, 22, 34),
                borderRadius: BorderRadius.circular(40),
                border: Border.all(color: const Color(0xFF3A3A4A), width: 2),
              ),
              child: Center(
                child: Container(
                  width: 70,
                  height: 70,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color.fromARGB(255, 13, 137, 246),
                  ),
                  child: const Icon(
                    Icons.directions_car,
                    color: Colors.white,
                    size: 40,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStat(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 4),
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
            color: Colors.white.withValues(alpha: 0.8),
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  String _getVehicleIcon() {
    if (widget.driver?.vehicleType.toLowerCase().contains('car') ?? false) {
      return 'Car';
    } else if (widget.driver?.vehicleType.toLowerCase().contains('motorcycle') ?? false) {
      return 'Boda';
    } else if (widget.driver?.vehicleType.toLowerCase().contains('bike') ?? false) {
      return 'Bike';
    }
    return 'Car';
  }

  Widget _buildServiceCard({
    required String title,
    required IconData icon,
    required Color color,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF2A2A3A),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF3A3A4A), width: 1),
        ),
        child: Row(
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Icon(icon, color: color, size: 32),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.arrow_forward_ios,
                color: color,
                size: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }
}