import 'package:flutter/material.dart';

import 'features/sos/sos_screen.dart';
import 'features/ptt/ptt_screen.dart';
import 'features/alerts/hazard_screen.dart';
import 'gateway/gateway_screen.dart';

class RescueApp extends StatelessWidget {
  const RescueApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Rescue Mesh',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int index = 0;

  final screens = const [
    SosScreen(),
    PttScreen(),
    HazardScreen(),
    GatewayScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: screens[index],
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed, // Needed for 4+ items
        currentIndex: index,
        onTap: (i) => setState(() => index = i),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.warning),
            label: 'SOS',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.mic),
            label: 'PTT',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.water),
            label: 'Alerts',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.cloud_upload),
            label: 'Gateway',
          ),
        ],
      ),
    );
  }
}
