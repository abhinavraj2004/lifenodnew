import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'features/sos/sos_screen.dart';
import 'features/sos/sos_controller.dart';
import 'features/ptt/ptt_screen.dart';
import 'features/alerts/hazard_screen.dart';
import 'features/messages/messages_screen.dart';
import 'features/splash/permission_screen.dart';
import 'gateway/gateway_screen.dart';
import 'core/bluetooth/gossip_engine.dart';
import 'core/database/message_model.dart';
import 'core/services/notification_service.dart';
import 'package:audioplayers/audioplayers.dart';

class RescueApp extends StatelessWidget {
  const RescueApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Set system UI overlay style
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: Color(0xFF0f0f23),
        systemNavigationBarIconBrightness: Brightness.light,
      ),
    );

    return MaterialApp(
      title: 'LifeNod',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0f0f23),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFe63946),
          brightness: Brightness.dark,
        ),
        fontFamily: 'Inter',
      ),
      home: const PermissionScreen(),
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

  @override
  void initState() {
    super.initState();
    _initServices();
    GossipEngine.addMessageListener(_onMessageReceived);
  }

  Future<void> _initServices() async {
    await NotificationService().init();
  }

  @override
  void dispose() {
    GossipEngine.removeMessageListener(_onMessageReceived);
    super.dispose();
  }

  void _onMessageReceived(MessageModel message) {
    if (SosController.sentMessageIds.contains(message.id)) return;

    // Show Notification
    NotificationService().showNotification(
      id: message.timestamp,
      title:
          'SOS Alert: ${message.payload.startsWith("AUDIO:") ? "Voice Message" : message.payload}',
      body: 'Priority: ${message.priority}',
    );

    // Vibration & Sound
    NotificationService().vibrate();
    final player = AudioPlayer();
    player.play(AssetSource('sounds/alert.mp3'));
  }

  final screens = const [
    SosScreen(),
    PttScreen(),
    MessagesScreen(),
    HazardScreen(),
    GatewayScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: index,
        children: screens,
      ),
      bottomNavigationBar: LayoutBuilder(
        builder: (context, constraints) {
          final isTablet = constraints.maxWidth > 600;
          final isDesktop = constraints.maxWidth > 900;

          return Container(
            decoration: BoxDecoration(
              color: const Color(0xFF1a1a2e),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 20,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: SafeArea(
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: isDesktop ? 40 : (isTablet ? 24 : 16),
                  vertical: isTablet ? 16 : 12,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildNavItem(0, Icons.warning_rounded, 'SOS',
                        const Color(0xFFe63946), isTablet, isDesktop),
                    _buildNavItem(1, Icons.mic_rounded, 'PTT',
                        const Color(0xFF00b4d8), isTablet, isDesktop),
                    _buildNavItem(2, Icons.inbox_rounded, 'Messages',
                        const Color(0xFF06d6a0), isTablet, isDesktop),
                    _buildNavItem(3, Icons.water_drop_rounded, 'Alerts',
                        const Color(0xFF48cae4), isTablet, isDesktop),
                    _buildNavItem(4, Icons.cloud_upload_rounded, 'Gateway',
                        const Color(0xFF9d4edd), isTablet, isDesktop),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildNavItem(int itemIndex, IconData icon, String label, Color color,
      bool isTablet, bool isDesktop) {
    final isSelected = index == itemIndex;
    final iconSize = isDesktop ? 28.0 : (isTablet ? 26.0 : 24.0);
    final fontSize = isDesktop ? 16.0 : (isTablet ? 15.0 : 14.0);
    final showLabel = isSelected || isTablet;

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        setState(() => index = itemIndex);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(
          horizontal: isSelected ? (isTablet ? 24 : 20) : (isTablet ? 16 : 12),
          vertical: isTablet ? 12 : 10,
        ),
        decoration: BoxDecoration(
          color:
              isSelected ? color.withValues(alpha: 0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(isTablet ? 20 : 16),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected
                  ? color
                  : (isTablet ? Colors.white54 : Colors.white38),
              size: iconSize,
            ),
            if (showLabel) ...[
              SizedBox(width: isTablet ? 10 : 8),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? color : Colors.white54,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  fontSize: fontSize,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
