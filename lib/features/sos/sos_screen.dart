import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'sos_controller.dart';
import '../../core/bluetooth/nearby_service.dart';
import '../../core/bluetooth/gossip_engine.dart';
import '../../core/database/message_model.dart';
import '../ptt/audio_service.dart';

class SosScreen extends StatefulWidget {
  const SosScreen({super.key});

  @override
  State<SosScreen> createState() => _SosScreenState();
}

class _SosScreenState extends State<SosScreen> with TickerProviderStateMixin {
  bool _isSending = false;
  int _countdown = 0;
  String? _selectedType;
  late AnimationController _pulseController;
  late final NearbyService nearbyService = NearbyService();

  int _peerCount = 0;
  MeshStatus _meshStatus = MeshStatus.inactive;

  void _onConnectionChanged(int peerCount) {
    if (mounted) {
      setState(() {
        _peerCount = peerCount;
        _meshStatus = NearbyService().status;
      });
    }
  }

  void _onMessageReceived(MessageModel message) async {
    if (!mounted) return;

    // Skip popup for messages we sent ourselves
    if (SosController.isSelfSent(message.id)) {
      debugPrint('Skipping popup for self-sent message: ${message.id}');
      return;
    }

    // Play notification beep
    // Audio and Haptic feedback handled globally in HomeScreen

    // Check if this is an audio message
    final bool isAudio = message.payload.startsWith('AUDIO:');

    if (isAudio) {
      // Extract and play audio
      final base64Audio =
          message.payload.substring(6); // Remove "AUDIO:" prefix
      _showAudioMessageDialog(message, base64Audio);
    } else {
      // Show regular SOS dialog
      _showSosDialog(message);
    }
  }

  void _showAudioMessageDialog(MessageModel message, String base64Audio) {
    bool isPlaying = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1a1a2e),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF00b4d8).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.mic_rounded,
                    color: Color(0xFF00b4d8), size: 28),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  '🎤 Voice Message',
                  style: TextStyle(
                    color: Color(0xFF00b4d8),
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Voice message received from mesh network',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.8)),
              ),
              const SizedBox(height: 20),
              // Play button
              GestureDetector(
                onTap: () async {
                  setDialogState(() => isPlaying = !isPlaying);
                  if (isPlaying) {
                    await AudioService().playFromBase64(base64Audio);
                  } else {
                    await AudioService().stopPlayback();
                  }
                },
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: isPlaying
                          ? [const Color(0xFFe63946), const Color(0xFFa4161a)]
                          : [const Color(0xFF00b4d8), const Color(0xFF0077b6)],
                    ),
                  ),
                  child: Icon(
                    isPlaying ? Icons.stop_rounded : Icons.play_arrow_rounded,
                    size: 40,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                isPlaying ? 'Playing...' : 'Tap to play',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
              ),
              const SizedBox(height: 16),
              _buildInfoRow(
                  Icons.access_time, 'Time', _formatTime(message.timestamp)),
              _buildInfoRow(
                Icons.location_on,
                'Location',
                (message.lat != 0 || message.lng != 0)
                    ? '${message.lat.toStringAsFixed(4)}, ${message.lng.toStringAsFixed(4)}'
                    : 'Location unavailable',
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                AudioService().stopPlayback();
                Navigator.of(context).pop();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00b4d8),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('CLOSE', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  void _showSosDialog(MessageModel message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1a1a2e),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color:
                    _getPriorityColor(message.priority).withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                _getPriorityIcon(message.priority),
                color: _getPriorityColor(message.priority),
                size: 28,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                '🚨 ${message.payload} SOS',
                style: TextStyle(
                  color: _getPriorityColor(message.priority),
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Emergency alert received from mesh network',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.8)),
            ),
            const SizedBox(height: 16),
            _buildInfoRow(
                Icons.access_time, 'Time', _formatTime(message.timestamp)),
            _buildInfoRow(
              Icons.location_on,
              'Location',
              (message.lat != 0 || message.lng != 0)
                  ? '${message.lat.toStringAsFixed(4)}, ${message.lng.toStringAsFixed(4)}'
                  : 'Location unavailable',
            ),
            _buildInfoRow(
              Icons.priority_high,
              'Priority',
              message.priority == 1
                  ? 'Critical'
                  : (message.priority == 2 ? 'High' : 'Medium'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child:
                const Text('DISMISS', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            style: ElevatedButton.styleFrom(
              backgroundColor: _getPriorityColor(message.priority),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('ACKNOWLEDGE',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.white54),
          const SizedBox(width: 8),
          Text('$label: ',
              style: const TextStyle(color: Colors.white54, fontSize: 13)),
          Text(value,
              style: const TextStyle(color: Colors.white, fontSize: 13)),
        ],
      ),
    );
  }

  Color _getPriorityColor(int priority) {
    switch (priority) {
      case 1:
        return const Color(0xFFe63946);
      case 2:
        return const Color(0xFFf4a261);
      case 3:
        return const Color(0xFFffd166);
      default:
        return Colors.grey;
    }
  }

  IconData _getPriorityIcon(int priority) {
    switch (priority) {
      case 1:
        return Icons.medical_services_rounded;
      case 2:
        return Icons.water_drop_rounded;
      case 3:
        return Icons.warning_rounded;
      default:
        return Icons.info_rounded;
    }
  }

  String _formatTime(int timestamp) {
    final dt = DateTime.fromMillisecondsSinceEpoch(timestamp);
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    // Listen for connection changes
    NearbyService().addConnectionListener(_onConnectionChanged);
    _peerCount = NearbyService().peerCount;
    _meshStatus = NearbyService().status;

    // Listen for incoming SOS messages
    GossipEngine.addMessageListener(_onMessageReceived);
  }

  @override
  void dispose() {
    GossipEngine.removeMessageListener(_onMessageReceived);
    NearbyService().removeConnectionListener(_onConnectionChanged);
    _pulseController.dispose();
    super.dispose();
  }

  Color _getStatusColor() {
    switch (_meshStatus) {
      case MeshStatus.connected:
        return Colors.green.shade400;
      case MeshStatus.searching:
        return Colors.orange.shade400;
      case MeshStatus.inactive:
        return Colors.red.shade400;
    }
  }

  String _getStatusText() {
    switch (_meshStatus) {
      case MeshStatus.connected:
        return 'Connected to $_peerCount peer${_peerCount != 1 ? 's' : ''}';
      case MeshStatus.searching:
        return 'Searching for peers...';
      case MeshStatus.inactive:
        return 'Mesh Network Inactive';
    }
  }

  Future<void> _triggerSOS(int priority, String label) async {
    HapticFeedback.heavyImpact();
    setState(() {
      _isSending = true;
      _selectedType = label;
      _countdown = 5;
    });

    // Countdown
    for (int i = 5; i > 0; i--) {
      if (!mounted) return;
      setState(() => _countdown = i);
      await Future.delayed(const Duration(seconds: 1));
    }

    if (!mounted) return;

    await SosController.sendSOS(priority: priority, label: label);

    if (!mounted) return;
    setState(() {
      _isSending = false;
      _selectedType = null;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 12),
            Text('$label SOS Broadcasted!'),
          ],
        ),
        backgroundColor: Colors.green.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
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
        child: _isSending ? _buildCountdownView() : _buildMainView(),
      ),
    );
  }

  Widget _buildCountdownView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              return Container(
                width: 200 + (_pulseController.value * 30),
                height: 200 + (_pulseController.value * 30),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.red
                      .withValues(alpha: 0.3 - (_pulseController.value * 0.2)),
                ),
                child: Center(
                  child: Container(
                    width: 150,
                    height: 150,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFFe63946), Color(0xFFa4161a)],
                      ),
                    ),
                    child: Center(
                      child: Text(
                        '$_countdown',
                        style: const TextStyle(
                          fontSize: 72,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 40),
          Text(
            'Sending $_selectedType...',
            style: const TextStyle(
              fontSize: 24,
              color: Colors.white70,
              fontWeight: FontWeight.w300,
            ),
          ),
          const SizedBox(height: 20),
          TextButton(
            onPressed: () {
              setState(() {
                _isSending = false;
                _selectedType = null;
              });
            },
            child: const Text(
              'CANCEL',
              style: TextStyle(
                color: Colors.white54,
                fontSize: 18,
                letterSpacing: 2,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainView() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isTablet = constraints.maxWidth > 600;
        final isSmallPhone = constraints.maxHeight < 700;
        final isLandscape = constraints.maxWidth > constraints.maxHeight;

        final titleSize = isTablet ? 52.0 : (isSmallPhone ? 32.0 : 42.0);
        final subtitleSize = isTablet ? 16.0 : 14.0;

        // Adjust padding based on screen height
        final buttonVerticalPadding =
            isTablet ? 28.0 : (isSmallPhone ? 16.0 : 24.0);
        final buttonHorizontalPadding =
            isTablet ? 28.0 : (isSmallPhone ? 20.0 : 24.0);

        final buttonPadding = EdgeInsets.symmetric(
            vertical: buttonVerticalPadding,
            horizontal: buttonHorizontalPadding);

        return Padding(
          padding: EdgeInsets.symmetric(horizontal: isTablet ? 40 : 24),
          child: OrientationBuilder(
            builder: (context, orientation) {
              if (isLandscape && constraints.maxHeight < 500) {
                // Landscape mode - horizontal layout
                return _buildLandscapeLayout(
                  titleSize: titleSize,
                  subtitleSize: subtitleSize,
                  buttonPadding: buttonPadding,
                  isTablet: isTablet,
                );
              }

              // Portrait mode - vertical layout
              return Column(
                children: [
                  SizedBox(height: isTablet ? 60 : (isSmallPhone ? 20 : 40)),
                  // Header
                  ShaderMask(
                    shaderCallback: (bounds) => const LinearGradient(
                      colors: [Color(0xFFe63946), Color(0xFFff6b6b)],
                    ).createShader(bounds),
                    child: Text(
                      'EMERGENCY',
                      style: TextStyle(
                        fontSize: titleSize,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: isSmallPhone ? 4 : 8,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tap to broadcast distress signal',
                    style: TextStyle(
                      fontSize: subtitleSize,
                      color: Colors.white.withValues(alpha: 0.6),
                      letterSpacing: 1,
                    ),
                  ),
                  SizedBox(height: isTablet ? 80 : (isSmallPhone ? 30 : 60)),

                  // SOS Buttons
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Flexible(
                          child: _buildSOSButton(
                            icon: Icons.medical_services_rounded,
                            label: 'MEDICAL',
                            subtitle: 'Urgent medical assistance',
                            gradient: const [
                              Color(0xFFe63946),
                              Color(0xFFa4161a)
                            ],
                            priority: 1,
                            padding: buttonPadding,
                            isTablet: isTablet,
                            isSmall: isSmallPhone,
                          ),
                        ),
                        SizedBox(
                            height: isTablet ? 24 : (isSmallPhone ? 12 : 20)),
                        Flexible(
                          child: _buildSOSButton(
                            icon: Icons.water_drop_rounded,
                            label: 'FOOD/WATER',
                            subtitle: 'Need supplies',
                            gradient: const [
                              Color(0xFFf4a261),
                              Color(0xFFe76f51)
                            ],
                            priority: 2,
                            padding: buttonPadding,
                            isTablet: isTablet,
                            isSmall: isSmallPhone,
                          ),
                        ),
                        SizedBox(
                            height: isTablet ? 24 : (isSmallPhone ? 12 : 20)),
                        Flexible(
                          child: _buildSOSButton(
                            icon: Icons.warning_rounded,
                            label: 'TRAPPED',
                            subtitle: 'Unable to evacuate',
                            gradient: const [
                              Color(0xFFffd166),
                              Color(0xFFf48c06)
                            ],
                            priority: 3,
                            padding: buttonPadding,
                            isTablet: isTablet,
                            isSmall: isSmallPhone,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Footer - Connection Status
                  Padding(
                    padding: const EdgeInsets.only(bottom: 20),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _getStatusColor(),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _getStatusText(),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white.withValues(alpha: 0.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildLandscapeLayout({
    required double titleSize,
    required double subtitleSize,
    required EdgeInsets buttonPadding,
    required bool isTablet,
  }) {
    return Row(
      children: [
        // Left side - Header
        Expanded(
          flex: 1,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ShaderMask(
                shaderCallback: (bounds) => const LinearGradient(
                  colors: [Color(0xFFe63946), Color(0xFFff6b6b)],
                ).createShader(bounds),
                child: Text(
                  'EMERGENCY',
                  style: TextStyle(
                    fontSize: titleSize * 0.8,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: 6,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Tap to broadcast',
                style: TextStyle(
                  fontSize: subtitleSize,
                  color: Colors.white.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _getStatusColor(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _meshStatus == MeshStatus.connected
                        ? '$_peerCount peer${_peerCount != 1 ? 's' : ''}'
                        : (_meshStatus == MeshStatus.searching
                            ? 'Searching...'
                            : 'Inactive'),
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.white.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        // Right side - Buttons
        Expanded(
          flex: 2,
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildSOSButton(
                  icon: Icons.medical_services_rounded,
                  label: 'MEDICAL',
                  subtitle: 'Urgent medical assistance',
                  gradient: const [Color(0xFFe63946), Color(0xFFa4161a)],
                  priority: 1,
                  padding:
                      const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                  isTablet: isTablet,
                ),
                const SizedBox(height: 12),
                _buildSOSButton(
                  icon: Icons.water_drop_rounded,
                  label: 'FOOD/WATER',
                  subtitle: 'Need supplies',
                  gradient: const [Color(0xFFf4a261), Color(0xFFe76f51)],
                  priority: 2,
                  padding:
                      const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                  isTablet: isTablet,
                ),
                const SizedBox(height: 12),
                _buildSOSButton(
                  icon: Icons.warning_rounded,
                  label: 'TRAPPED',
                  subtitle: 'Unable to evacuate',
                  gradient: const [Color(0xFFffd166), Color(0xFFf48c06)],
                  priority: 3,
                  padding:
                      const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                  isTablet: isTablet,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSOSButton({
    required IconData icon,
    required String label,
    required String subtitle,
    required List<Color> gradient,
    required int priority,
    EdgeInsets padding =
        const EdgeInsets.symmetric(vertical: 24, horizontal: 24),
    bool isTablet = false,
    bool isSmall = false,
  }) {
    final iconSize = isTablet ? 32.0 : (isSmall ? 24.0 : 28.0);
    final labelSize = isTablet ? 22.0 : (isSmall ? 18.0 : 20.0);
    final subtitleSize = isTablet ? 14.0 : (isSmall ? 12.0 : 13.0);
    final borderRadius = isTablet ? 24.0 : 20.0;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _triggerSOS(priority, label),
        borderRadius: BorderRadius.circular(borderRadius),
        child: Container(
          width: double.infinity,
          padding: padding,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(borderRadius),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: gradient,
            ),
            boxShadow: [
              BoxShadow(
                color: gradient[0].withValues(alpha: 0.4),
                blurRadius: isTablet ? 25 : 20,
                offset: Offset(0, isTablet ? 12 : 10),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(isTablet ? 14 : (isSmall ? 10 : 12)),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(isTablet ? 14 : 12),
                ),
                child: Icon(icon, color: Colors.white, size: iconSize),
              ),
              SizedBox(width: isTablet ? 24 : (isSmall ? 16 : 20)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize
                      .min, // Ensure it doesn't expand unnecessarily
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: labelSize,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 1,
                      ),
                    ),
                    SizedBox(height: isTablet ? 6 : 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: subtitleSize,
                        color: Colors.white.withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                color: Colors.white.withValues(alpha: 0.7),
                size: isTablet ? 22 : (isSmall ? 16 : 18),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
