import 'package:flutter/material.dart';
import 'hazard_service.dart';

class HazardScreen extends StatefulWidget {
  const HazardScreen({super.key});

  @override
  State<HazardScreen> createState() => _HazardScreenState();
}

class _HazardScreenState extends State<HazardScreen> {
  late Future<Map<String, dynamic>> _hazardFuture;
  late Future<bool> _floodFuture;

  @override
  void initState() {
    super.initState();
    _hazardFuture = HazardService.getHazardData();
    _floodFuture = HazardService.isInFloodZone();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Local Hazard Alerts')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            FutureBuilder<Map<String, dynamic>>(
              future: _hazardFuture,
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const CircularProgressIndicator();
                final data = snapshot.data!;
                return Card(
                  color: data['risk'] == 'CRITICAL'
                      ? Colors.red.withOpacity(0.3)
                      : null,
                  child: ListTile(
                    title: Text(
                      'Dam: ${data["dam"]}',
                      style: const TextStyle(
                          fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 8),
                        Text('Water Level: ${data["level"]}'),
                        Text('Risk Level: ${data["risk"]}',
                            style: TextStyle(
                                color: data['risk'] == 'CRITICAL'
                                    ? Colors.red
                                    : Colors.orange)),
                        Text('Updated: ${data["updated"]}'),
                      ],
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 20),
            FutureBuilder<bool>(
              future: _floodFuture,
              builder: (context, snapshot) {
                if (snapshot.data == true) {
                  return Container(
                    padding: const EdgeInsets.all(16),
                    color: Colors.red,
                    child: const Text(
                      'WARNING: YOU ARE IN A FLOOD ZONE. SEEK HIGHER GROUND.',
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ],
        ),
      ),
    );
  }
}
