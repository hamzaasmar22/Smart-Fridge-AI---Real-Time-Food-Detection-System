
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

class MQTTService {
  MqttServerClient? client;
  Function(String)? onTemperature;
  Function(String)? onHumidity;
  Function(String)? onFoodDetected;
  
  // ip
  final String piIP = '10.194.208.76';
  
  Future<void> connect() async {
    print('📡 Connecting to Pi at: $piIP');
    
    client = MqttServerClient(piIP, 'flutter_fridge_${DateTime.now().millisecondsSinceEpoch}');
    client!.port = 1883;
    client!.keepAlivePeriod = 60;
    client!.logging(on: false);
    
    final connMessage = MqttConnectMessage()
        .withClientIdentifier('flutter_presentation')
        .startClean();
    
    client!.connectionMessage = connMessage;
    
    try {
      await client!.connect();
      print('✅ CONNECTED to Pi at $piIP');
      
      // Subscribe to topics
      client!.subscribe('fridge/temperature', MqttQos.atMostOnce);
      client!.subscribe('fridge/humidity', MqttQos.atMostOnce);
      client!.subscribe('fridge/food', MqttQos.atMostOnce);
      
      // Listen for messages
      client!.updates!.listen((List<MqttReceivedMessage<MqttMessage>> messages) {
        for (var message in messages) {
          final payload = message.payload as MqttPublishMessage;
          final data = MqttPublishPayload.bytesToStringAsString(payload.payload.message);
          final topic = message.topic;
          
          print('📦 [$topic] → $data');
          
          if (topic == 'fridge/temperature') {
            onTemperature?.call('$data°C');
          } else if (topic == 'fridge/humidity') {
            onHumidity?.call('$data%');
          } else if (topic == 'fridge/food') {
            onFoodDetected?.call(data);
          }
        }
      });
      
    } catch (e) {
      print('❌ CONNECTION FAILED: $e');
      print('🔧 Troubleshooting:');
      print('   1. Is phone hotspot ON? (Hamza\'s A06)');
      print('   2. Is Pi connected to hotspot?');
      print('   3. Check Pi IP: $piIP');
    }
  }
  
  void requestMeasurement() {
    if (client == null) {
      print('⚠️ Not connected to Pi');
      return;
    }
    
    final builder = MqttClientPayloadBuilder();
    builder.addString('measure');
    client!.publishMessage('fridge/request', MqttQos.atMostOnce, builder.payload!);
    print('📱 Sent MEASURE request to Pi');
  }
  
  void disconnect() {
    client?.disconnect();
  }
}