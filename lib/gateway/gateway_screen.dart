import 'package:flutter/material.dart';
import 'sync_service.dart';

class GatewayScreen extends StatefulWidget {
  const GatewayScreen({super.key});

  @override
  State<GatewayScreen> createState() => _GatewayScreenState();
}

class _GatewayScreenState extends State<GatewayScreen>
    with TickerProviderStateMixin {
  final SyncService _syncService = SyncService();
  late AnimationController _rotateController;

  @override
  void initState() {
    super.initState();
    _rotateController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    _syncService.initAutoSync();
  }

  @override
  void dispose() {
    _rotateController.dispose();
    super.dispose();
  }

  void _handleSync() {
    _rotateController.repeat();
    _syncService.syncData().then((_) {
      _rotateController.stop();
      _rotateController.reset();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF1a1a2e), Color(0xFF16213e), Color(0xFF0f0f23)],
        ),
      ),
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: IntrinsicHeight(
                    child: Column(
                      children: [
                        const SizedBox(height: 40),
                        // Header
                        ShaderMask(
                          shaderCallback: (bounds) => const LinearGradient(
                            colors: [Color(0xFF9d4edd), Color(0xFFc77dff)],
                          ).createShader(bounds),
                          child: const Text(
                            'GATEWAY NODE',
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              letterSpacing: 4,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Bridge mesh data to cloud',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.white.withValues(alpha: 0.6),
                          ),
                        ),

                        const SizedBox(height: 60),

                        // Sync Button
                        ValueListenableBuilder<bool>(
                          valueListenable: _syncService.isSyncing,
                          builder: (context, syncing, _) {
                            return GestureDetector(
                              onTap: syncing ? null : _handleSync,
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  // Outer glow
                                  Container(
                                    width: 180,
                                    height: 180,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: const Color(0xFF9d4edd)
                                              .withValues(alpha: 0.3),
                                          blurRadius: 40,
                                          spreadRadius: 10,
                                        ),
                                      ],
                                    ),
                                  ),
                                  // Main circle
                                  Container(
                                    width: 140,
                                    height: 140,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: const LinearGradient(
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                        colors: [
                                          Color(0xFF9d4edd),
                                          Color(0xFF7b2cbf)
                                        ],
                                      ),
                                      border: Border.all(
                                        color:
                                            Colors.white.withValues(alpha: 0.2),
                                        width: 2,
                                      ),
                                    ),
                                    child: syncing
                                        ? RotationTransition(
                                            turns: _rotateController,
                                            child: const Icon(
                                              Icons.sync_rounded,
                                              size: 50,
                                              color: Colors.white,
                                            ),
                                          )
                                        : const Icon(
                                            Icons.cloud_upload_rounded,
                                            size: 50,
                                            color: Colors.white,
                                          ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),

                        const SizedBox(height: 40),

                        // Status
                        ValueListenableBuilder<bool>(
                          valueListenable: _syncService.isSyncing,
                          builder: (context, syncing, _) {
                            return ValueListenableBuilder<int>(
                              valueListenable: _syncService.pendingCount,
                              builder: (context, count, _) {
                                if (syncing) {
                                  return Text(
                                    'Syncing $count messages...',
                                    style: const TextStyle(
                                      fontSize: 18,
                                      color: Color(0xFFc77dff),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  );
                                }
                                return Text(
                                  'Tap to sync',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.white.withValues(alpha: 0.5),
                                  ),
                                );
                              },
                            );
                          },
                        ),

                        const Spacer(),

                        // Info Cards
                        _buildInfoTile(
                          icon: Icons.wifi_rounded,
                          title: 'Auto-Sync',
                          subtitle: 'Enabled when online',
                          active: true,
                        ),
                        const SizedBox(height: 12),
                        _buildInfoTile(
                          icon: Icons.storage_rounded,
                          title: 'Local Storage',
                          subtitle: 'SQLite Database',
                          active: false,
                        ),
                        const SizedBox(height: 12),
                        _buildInfoTile(
                          icon: Icons.cloud_rounded,
                          title: 'Cloud Target',
                          subtitle: 'Supabase (Mock)',
                          active: false,
                        ),

                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildInfoTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool active,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.white.withValues(alpha: 0.03),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.05),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF9d4edd).withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: const Color(0xFFc77dff), size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
          ),
          if (active)
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFF2a9d8f),
              ),
            ),
        ],
      ),
    );
  }
}
