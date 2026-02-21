import 'package:flutter/material.dart';
import 'package:muno_watch/views/get_started.dart';
import 'package:muno_watch/views/settings.dart';
import 'package:muno_watch/views/splashscreen.dart';

import 'views/DriverTripScreen.dart';
import 'views/destination.dart';
import 'views/home.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Castro Transporters',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const AppEntryPoint(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class AppEntryPoint extends StatefulWidget {
  const AppEntryPoint({super.key});

  @override
  State<AppEntryPoint> createState() => _AppEntryPointState();
}

class _AppEntryPointState extends State<AppEntryPoint> {
  bool _showSplash = true;

  void _onSplashComplete() {
    setState(() {
      _showSplash = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return _showSplash
        ? SplashScreen(onAnimationComplete: _onSplashComplete)
        // : const OnboardingScreen1();
        // :  const DriverTripScreen(accountType: 'Car',);
        : const HomeScreen();
  }
}