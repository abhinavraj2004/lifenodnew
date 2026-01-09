import 'package:flutter/material.dart';
import 'sos_controller.dart';

class SosScreen extends StatelessWidget {
  const SosScreen({super.key});

  void _triggerSOS(BuildContext context, int priority, String label) async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('SOS will send in 10 seconds')),
    );

    await SosController.sendSOS(
      priority: priority,
      label: label,
    );

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('SOS Sent')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'SOS',
              style: TextStyle(
                color: Colors.red,
                fontSize: 48,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 30),

            ElevatedButton(
              onPressed: () => _triggerSOS(context, 1, 'MEDICAL'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Medical Emergency'),
            ),

            ElevatedButton(
              onPressed: () => _triggerSOS(context, 2, 'FOOD/WATER'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
              child: const Text('Food / Water'),
            ),

            ElevatedButton(
              onPressed: () => _triggerSOS(context, 3, 'TRAPPED'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.yellow),
              child: const Text('Trapped'),
            ),
          ],
        ),
      ),
    );
  }
}
