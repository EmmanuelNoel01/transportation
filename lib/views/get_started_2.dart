import 'package:flutter/material.dart';
import 'package:muno_watch/views/login.dart';
import 'package:muno_watch/views/signup.dart';

class OnboardingScreen3 extends StatelessWidget {
  const OnboardingScreen3({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:  const Color.fromARGB(255, 22, 22, 34),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              // Status bar time (9:41)
              const SizedBox(
                height: 40,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    '9:41',
                    style: TextStyle(
                      color: Colors.black87,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Illustration
                    Container(
                      height: 250,
                      width: 250,
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(125),
                      ),
                      child: Center(
                        child: Icon(
                          Icons.security_sharp,
                          size: 120,
                          color: Colors.blue[700],
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 30), // Reduced space
                    
                    // Page Indicator Dots (ADDED THIS)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Second dot (inactive/hollow)
                        Container(
                          width: 8,
                          height: 8,
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          decoration: BoxDecoration(
                            color: Colors.grey[300],
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        
                        // Third dot (inactive/hollow)
                        Container(
                          width: 8,
                          height: 8,
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          decoration: BoxDecoration(
                            color: Colors.grey[300],
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        // First dot (active/filled)
                        Container(
                          width: 24,
                          height: 8,
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          decoration: BoxDecoration(
                            color: const Color.fromARGB(255, 13, 137, 246),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        
                      ],
                    ),
                    
                    const SizedBox(height: 30), // Space between dots and text
                    
                    // Title
                    const Text(
                      'Safe & Secure Payments',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        height: 1.3,
                      ),
                    ),
                    
                    const SizedBox(height: 20),
                    
                    // Description
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20.0),
                      child: Text(
                        'Pay with MTN Mobile Money, Airtel Money, or Cash on Delivery. Your choice.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.grey[700],
                          fontSize: 16,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
              // Next Button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: () {
                    // Use Navigator.push to navigate to next screen
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const SignInScreen(), // Changed to GetStarted1
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color.fromARGB(255, 13, 137, 246),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Next',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}