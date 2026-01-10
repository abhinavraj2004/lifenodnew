class MessageModel {
  final String id;
  final String payload;
  final int priority;
  final String status;
  final double lat;
  final double lng;
  final int timestamp;

  MessageModel({
    required this.id,
    required this.payload,
    required this.priority,
    required this.status,
    required this.lat,
    required this.lng,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'payload': payload,
    'priority': priority,
    'status': status,
    'lat': lat,
    'lng': lng,
    'timestamp': timestamp,
  };
}
