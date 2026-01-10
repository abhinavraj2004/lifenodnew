import 'package:flutter/material.dart';
import '../../core/database/app_database.dart';
import '../../core/database/message_model.dart';
import '../../core/bluetooth/gossip_engine.dart';
import '../ptt/audio_service.dart';

class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key});

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  List<MessageModel> _messages = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadMessages();

    // Listen for new messages
    GossipEngine.addMessageListener(_onNewMessage);
  }

  @override
  void dispose() {
    GossipEngine.removeMessageListener(_onNewMessage);
    super.dispose();
  }

  void _onNewMessage(MessageModel message) {
    if (mounted) {
      setState(() {
        // Add to top of list if not already present
        if (!_messages.any((m) => m.id == message.id)) {
          _messages.insert(0, message);
        }
      });
    }
  }

  Future<void> _loadMessages() async {
    try {
      // Clean up old messages first (older than 1 hour)
      await AppDatabase.cleanupOldMessages();

      final db = await AppDatabase.database;
      final results = await db.query(
        'messages',
        orderBy: 'timestamp DESC',
      );

      if (mounted) {
        setState(() {
          _messages = results
              .map((row) => MessageModel(
                    id: row['id'] as String,
                    payload: row['payload'] as String,
                    priority: row['priority'] as int,
                    status: row['status'] as String,
                    lat: row['lat'] as double,
                    lng: row['lng'] as double,
                    timestamp: row['timestamp'] as int,
                  ))
              .toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading messages: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// Check if message contains audio data
  bool _isAudioMessage(MessageModel message) {
    return message.payload.startsWith('AUDIO:');
  }

  /// Get display title for message
  String _getMessageTitle(MessageModel message) {
    if (_isAudioMessage(message)) {
      return 'Voice Message';
    }
    return '${message.payload} SOS';
  }

  String _formatTime(int timestamp) {
    final dt = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final now = DateTime.now();
    final diff = now.difference(dt);

    if (diff.inMinutes < 1) {
      return 'Just now';
    } else if (diff.inHours < 1) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inDays < 1) {
      return '${diff.inHours}h ago';
    } else {
      return '${dt.day}/${dt.month} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
    }
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00b4d8).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.inbox_rounded,
                      color: Color(0xFF00b4d8),
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Messages',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          '${_messages.length} alerts received',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.white.withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      setState(() => _isLoading = true);
                      _loadMessages();
                    },
                    icon: Icon(
                      Icons.refresh_rounded,
                      color: Colors.white.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ),

            // Messages List
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFF00b4d8),
                      ),
                    )
                  : _messages.isEmpty
                      ? _buildEmptyState()
                      : RefreshIndicator(
                          onRefresh: _loadMessages,
                          color: const Color(0xFF00b4d8),
                          child: ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: _messages.length,
                            itemBuilder: (context, index) {
                              return _buildMessageCard(_messages[index]);
                            },
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.inbox_outlined,
            size: 80,
            color: Colors.white.withValues(alpha: 0.2),
          ),
          const SizedBox(height: 16),
          Text(
            'No messages yet',
            style: TextStyle(
              fontSize: 18,
              color: Colors.white.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'SOS alerts from the mesh network\nwill appear here',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withValues(alpha: 0.3),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageCard(MessageModel message) {
    final isVoice = _isAudioMessage(message);
    final color =
        isVoice ? const Color(0xFF00b4d8) : _getPriorityColor(message.priority);

    return Dismissible(
      key: Key(message.id),
      direction: DismissDirection.endToStart,
      onDismissed: (direction) async {
        setState(() {
          _messages.removeWhere((m) => m.id == message.id);
        });
        // Delete and Tombstone
        await AppDatabase.deleteMessage(message.id);
        await AppDatabase.addTombstone(message.id);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Message deleted')),
          );
        }
      },
      background: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.red.shade900,
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete_outline, color: Colors.white, size: 30),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF1a1a2e),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: color.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _showMessageDetails(message),
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  // Icon
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      isVoice
                          ? Icons.mic_rounded
                          : _getPriorityIcon(message.priority),
                      color: color,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),

                  // Content
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                                child: Text(
                              _getMessageTitle(message),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                              overflow: TextOverflow.ellipsis,
                            )),
                            const SizedBox(width: 8),
                            Text(
                              _formatTime(message.timestamp),
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.white.withValues(alpha: 0.5),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.location_on_outlined,
                              size: 14,
                              color: Colors.white.withValues(alpha: 0.4),
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                (message.lat != 0 || message.lng != 0)
                                    ? '${message.lat.toStringAsFixed(4)}, ${message.lng.toStringAsFixed(4)}'
                                    : 'Location unavailable',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.white.withValues(alpha: 0.4),
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: message.status == 'local'
                                    ? Colors.blue.withValues(alpha: 0.2)
                                    : Colors.green.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                message.status == 'local' ? 'Sent' : 'Received',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: message.status == 'local'
                                      ? Colors.blue
                                      : Colors.green,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showMessageDetails(MessageModel message) {
    final isVoice = _isAudioMessage(message);
    final color =
        isVoice ? const Color(0xFF00b4d8) : _getPriorityColor(message.priority);

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1a1a2e),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        bool isPlaying = false;

        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          isVoice
                              ? Icons.mic_rounded
                              : _getPriorityIcon(message.priority),
                          color: color,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _getMessageTitle(message),
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            Text(
                              isVoice
                                  ? 'Audio message'
                                  : (message.priority == 1
                                      ? 'Critical Priority'
                                      : (message.priority == 2
                                          ? 'High Priority'
                                          : 'Medium Priority')),
                              style: TextStyle(color: color),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  // Audio play button for voice messages
                  if (isVoice) ...[
                    const SizedBox(height: 24),
                    Center(
                      child: GestureDetector(
                        onTap: () async {
                          setSheetState(() => isPlaying = !isPlaying);
                          if (isPlaying) {
                            final base64Audio = message.payload.substring(6);
                            await AudioService().playFromBase64(base64Audio);
                            // Auto-stop updating UI when playback finishes is tricky without stream
                            // For now we rely on user manually toggling or it just stopping
                            // But better UX would be to listen to player state.
                            // Ignored for MVP speed.
                          } else {
                            await AudioService().stopPlayback();
                          }
                        },
                        child: Container(
                          width: 70,
                          height: 70,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: isPlaying
                                  ? [
                                      const Color(0xFFe63946),
                                      const Color(0xFFa4161a)
                                    ]
                                  : [
                                      const Color(0xFF00b4d8),
                                      const Color(0xFF0077b6)
                                    ],
                            ),
                          ),
                          child: Icon(
                            isPlaying
                                ? Icons.stop_rounded
                                : Icons.play_arrow_rounded,
                            size: 36,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Center(
                      child: Text(
                        isPlaying ? 'Playing...' : 'Tap to play',
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.5),
                            fontSize: 12),
                      ),
                    ),
                  ],

                  const SizedBox(height: 20),
                  _buildDetailRow(
                      Icons.access_time,
                      'Time',
                      DateTime.fromMillisecondsSinceEpoch(message.timestamp)
                          .toString()
                          .substring(0, 19)),
                  _buildDetailRow(
                      Icons.location_on,
                      'Location',
                      (message.lat != 0 || message.lng != 0)
                          ? '${message.lat.toStringAsFixed(6)}, ${message.lng.toStringAsFixed(6)}'
                          : 'Location unavailable'),
                  _buildDetailRow(
                      Icons.swap_horiz,
                      'Status',
                      message.status == 'local'
                          ? 'Sent by you'
                          : 'Received from mesh'),
                  _buildDetailRow(
                      Icons.tag, 'Message ID', message.id.substring(0, 8)),
                  const SizedBox(height: 16),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.white54),
          const SizedBox(width: 12),
          Text(
            '$label:',
            style: const TextStyle(color: Colors.white54),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: Colors.white),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
