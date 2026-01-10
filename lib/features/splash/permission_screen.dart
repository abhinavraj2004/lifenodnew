import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/services/permission_service.dart';
import '../../core/bluetooth/nearby_service.dart';
import '../../app.dart';

class PermissionScreen extends StatefulWidget {
  const PermissionScreen({super.key});

  @override
  State<PermissionScreen> createState() => _PermissionScreenState();
}

class _PermissionScreenState extends State<PermissionScreen>
    with SingleTickerProviderStateMixin {
  final PermissionService _permissionService = PermissionService();
  bool _isLoading = true;
  PermissionResult? _permissionResult;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutBack),
    );
    _animationController.forward();
    _checkPermissions();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _checkPermissions() async {
    try {
      setState(() => _isLoading = true);

      final granted = await _permissionService.areAllPermissionsGranted();

      if (!mounted) return;

      if (granted) {
        _navigateToHome();
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error checking permissions: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _requestPermissions() async {
    setState(() => _isLoading = true);
    HapticFeedback.mediumImpact();

    final result = await _permissionService.requestAllPermissions();

    setState(() {
      _permissionResult = result;
      _isLoading = false;
    });

    if (result.allGranted) {
      // Start nearby service after permissions granted
      NearbyService().start();
      _navigateToHome();
    }
  }

  void _navigateToHome() {
    // Start nearby service before navigating
    NearbyService().start();

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            const HomeScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 500),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final isSmallScreen = screenHeight < 700;

    return Scaffold(
      backgroundColor: const Color(0xFF0f0f23),
      body: SafeArea(
        child: AnimatedBuilder(
          animation: _animationController,
          builder: (context, child) {
            return Opacity(
              opacity: _fadeAnimation.value,
              child: Transform.scale(
                scale: _scaleAnimation.value,
                child: child,
              ),
            );
          },
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight,
                  ),
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: isSmallScreen ? 20 : 32,
                      vertical: isSmallScreen ? 16 : 24,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(height: isSmallScreen ? 20 : 40),

                        // App Icon
                        Container(
                          width: isSmallScreen ? 80 : 120,
                          height: isSmallScreen ? 80 : 120,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFe63946), Color(0xFFff6b6b)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius:
                                BorderRadius.circular(isSmallScreen ? 20 : 30),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFe63946)
                                    .withValues(alpha: 0.4),
                                blurRadius: isSmallScreen ? 20 : 30,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: Icon(
                            Icons.wifi_tethering_rounded,
                            size: isSmallScreen ? 40 : 60,
                            color: Colors.white,
                          ),
                        ),

                        SizedBox(height: isSmallScreen ? 24 : 40),

                        // Title
                        Text(
                          'Rescue Mesh',
                          style: TextStyle(
                            fontSize: isSmallScreen ? 24 : 32,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: 1.2,
                          ),
                        ),

                        SizedBox(height: isSmallScreen ? 8 : 12),

                        Text(
                          'Emergency Communication Network',
                          style: TextStyle(
                            fontSize: isSmallScreen ? 13 : 16,
                            color: Colors.white.withValues(alpha: 0.7),
                          ),
                        ),

                        SizedBox(height: isSmallScreen ? 24 : 40),

                        // Permission Info Card
                        if (!_isLoading) ...[
                          Container(
                            padding: EdgeInsets.all(isSmallScreen ? 16 : 24),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1a1a2e),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.1),
                              ),
                            ),
                            child: Column(
                              children: [
                                Icon(
                                  Icons.security_rounded,
                                  size: isSmallScreen ? 36 : 48,
                                  color: Colors.white.withValues(alpha: 0.9),
                                ),
                                SizedBox(height: isSmallScreen ? 12 : 16),
                                Text(
                                  'Permissions Required',
                                  style: TextStyle(
                                    fontSize: isSmallScreen ? 17 : 20,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                                SizedBox(height: isSmallScreen ? 8 : 12),
                                Text(
                                  'Rescue Mesh needs the following permissions to enable device-to-device communication:',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: isSmallScreen ? 12 : 14,
                                    color: Colors.white.withValues(alpha: 0.7),
                                    height: 1.4,
                                  ),
                                ),
                                SizedBox(height: isSmallScreen ? 14 : 20),
                                _buildPermissionItem(
                                  Icons.bluetooth_rounded,
                                  'Bluetooth',
                                  'Connect with nearby devices',
                                  const Color(0xFF00b4d8),
                                  isSmallScreen,
                                ),
                                _buildPermissionItem(
                                  Icons.location_on_rounded,
                                  'Location',
                                  'Required for Bluetooth discovery',
                                  const Color(0xFF48cae4),
                                  isSmallScreen,
                                ),
                                _buildPermissionItem(
                                  Icons.wifi_rounded,
                                  'Nearby Wi-Fi',
                                  'Mesh network communication',
                                  const Color(0xFF9d4edd),
                                  isSmallScreen,
                                ),
                                _buildPermissionItem(
                                  Icons.mic_rounded,
                                  'Microphone',
                                  'Push-to-talk audio messages',
                                  const Color(0xFFe63946),
                                  isSmallScreen,
                                ),
                              ],
                            ),
                          ),

                          SizedBox(height: isSmallScreen ? 16 : 24),

                          // Show denied permissions if any
                          if (_permissionResult != null &&
                              _permissionResult!
                                  .deniedPermissions.isNotEmpty) ...[
                            Container(
                              padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
                              decoration: BoxDecoration(
                                color: const Color(0xFFe63946)
                                    .withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: const Color(0xFFe63946)
                                      .withValues(alpha: 0.3),
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.warning_rounded,
                                    color: Color(0xFFe63946),
                                    size: 20,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      'Some permissions were denied. Please grant all permissions.',
                                      style: TextStyle(
                                        color:
                                            Colors.white.withValues(alpha: 0.9),
                                        fontSize: isSmallScreen ? 11 : 13,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(height: isSmallScreen ? 10 : 16),
                            TextButton.icon(
                              onPressed: () =>
                                  _permissionService.openSettings(),
                              icon:
                                  const Icon(Icons.settings_rounded, size: 18),
                              label: const Text('Open Settings'),
                              style: TextButton.styleFrom(
                                foregroundColor: const Color(0xFF00b4d8),
                              ),
                            ),
                            const SizedBox(height: 8),
                          ],

                          // Grant Permissions Button
                          SizedBox(
                            width: double.infinity,
                            height: isSmallScreen ? 48 : 56,
                            child: ElevatedButton(
                              onPressed: _requestPermissions,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFe63946),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(
                                      isSmallScreen ? 12 : 16),
                                ),
                                elevation: 0,
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.check_circle_rounded,
                                      size: isSmallScreen ? 20 : 24),
                                  const SizedBox(width: 10),
                                  Text(
                                    'Grant Permissions',
                                    style: TextStyle(
                                      fontSize: isSmallScreen ? 14 : 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],

                        // Loading Indicator
                        if (_isLoading) ...[
                          const CircularProgressIndicator(
                            color: Color(0xFFe63946),
                            strokeWidth: 3,
                          ),
                          const SizedBox(height: 20),
                          Text(
                            'Checking permissions...',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.7),
                              fontSize: isSmallScreen ? 14 : 16,
                            ),
                          ),
                        ],

                        SizedBox(height: isSmallScreen ? 20 : 40),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildPermissionItem(
    IconData icon,
    String title,
    String description,
    Color color,
    bool isSmallScreen,
  ) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: isSmallScreen ? 5 : 8),
      child: Row(
        children: [
          Container(
            width: isSmallScreen ? 32 : 40,
            height: isSmallScreen ? 32 : 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(isSmallScreen ? 8 : 10),
            ),
            child: Icon(icon, color: color, size: isSmallScreen ? 16 : 20),
          ),
          SizedBox(width: isSmallScreen ? 10 : 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                    fontSize: isSmallScreen ? 13 : 15,
                  ),
                ),
                Text(
                  description,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: isSmallScreen ? 10 : 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
