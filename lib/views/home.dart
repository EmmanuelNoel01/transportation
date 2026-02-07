import 'package:flutter/material.dart';
import 'package:muno_watch/views/settings.dart'; 

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0; // Track which tab is active (0 = Home, 1 = Profile)

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

                          // Greeting
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: const Color.fromARGB(255, 13, 137, 246),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Good evening, Noel!',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Welcome back to your dashboard',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.white.withOpacity(0.8),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 90),

                          // Services Section
                          const Text(
                            'Our Services',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),

                          const SizedBox(height: 20),

                          // Order a Car Card
                          _buildServiceCard(
                            title: 'Order a Car',
                            icon: Icons.directions_car,
                            color: Colors.blue,
                            onTap: () {
                              print('Order a Car tapped');
                            },
                          ),

                          const SizedBox(height: 16),

                          // Order a Motorcycle Card
                          _buildServiceCard(
                            title: 'Order a Motorcycle',
                            icon: Icons.two_wheeler,
                            color: Colors.green,
                            onTap: () {
                              print('Order a Motorcycle tapped');
                            },
                          ),

                          const SizedBox(height: 16),

                          // Order a Bike Card
                          _buildServiceCard(
                            title: 'Order a Bike',
                            icon: Icons.pedal_bike,
                            color: Colors.orange,
                            onTap: () {
                              print('Order a Bike tapped');
                            },
                          ),

                          const SizedBox(height: 40),
                        ],
                      ],
                    ),
                  ),
                ),
              ),

              // Bottom Navigation Bar (invisible/transparent background)
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
                            size: 44,
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Empty space in the middle where logo will sit on top
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
                            size: 44,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Floating Logo - Positioned above the navigation bar
          Positioned(
            left: MediaQuery.of(context).size.width / 2 - 40,
            bottom: 30, // Positioned higher than the nav bar
            child: GestureDetector(
              onTap: () {
                // Add logo tap action if needed
                print('Logo tapped');
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

  Widget _buildServiceCard({
    required String title,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF2A2A3A),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF3A3A4A), width: 1),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios,
              color: Color(0xFF666666),
              size: 18,
            ),
          ],
        ),
      ),
    );
  }
}