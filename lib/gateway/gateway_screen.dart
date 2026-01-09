import 'package:flutter/material.dart';
import 'sync_service.dart';

class GatewayScreen extends StatelessWidget {
  const GatewayScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final syncService = SyncService();

    return Scaffold(
      appBar: AppBar(title: const Text('Gateway Node')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.cloud_upload, size: 80, color: Colors.blue),
            const SizedBox(height: 20),
            const Text(
              'Gateway Mode Active',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(
                'This device sends mesh data to the command center when internet is available.',
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 30),
            ValueListenableBuilder<bool>(
              valueListenable: syncService.isSyncing,
              builder: (context, syncing, _) {
                if (syncing) {
                  return Column(
                    children: [
                      const CircularProgressIndicator(),
                      const SizedBox(height: 10),
                      ValueListenableBuilder<int>(
                        valueListenable: syncService.pendingCount,
                        builder: (context, count, _) {
                          return Text('Syncing $count messages...');
                        },
                      ),
                    ],
                  );
                }
                return ElevatedButton(
                  onPressed: syncService.syncData,
                  child: const Text('Force Sync Now'),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
