import 'package:flutter_test/flutter_test.dart';
import 'package:rescue_mesh/core/database/message_model.dart';

void main() {
  group('MessageModel Tests', () {
    test('toMap and fromMap should be consistent', () {
      final model = MessageModel(
        id: '123',
        payload: 'test_payload',
        priority: 1,
        status: 'local',
        lat: 10.0,
        lng: 20.0,
        timestamp: 1000,
      );

      final map = model.toMap();

      expect(map['id'], '123');
      expect(map['payload'], 'test_payload');
      expect(map['priority'], 1);
      expect(map['status'], 'local');
      expect(map['lat'], 10.0);
      expect(map['lng'], 20.0);
      expect(map['timestamp'], 1000);
    });
  });
}
