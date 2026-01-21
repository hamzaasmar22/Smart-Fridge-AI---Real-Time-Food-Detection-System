import 'package:flutter/material.dart';
import 'mqtt_service.dart';

void main() => runApp(const SmartFridgeApp());

class SmartFridgeApp extends StatelessWidget {
  const SmartFridgeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Smart Fridge',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String temperature = '--°C';
  String humidity = '--%';
  List<String> foodItems = [];
  bool isScanning = false;
  String lastUpdate = 'Never';
  final MQTTService mqtt = MQTTService();

  @override
  void initState() {
    super.initState();
    setupMQTT();
  }

  void setupMQTT() {
    // Temperature
    mqtt.onTemperature = (temp) {
      print('🌡️ Temp: $temp');
      setState(() {
        temperature = temp;
        lastUpdate = _timeNow();
      });
    };
    
    // Humidity
    mqtt.onHumidity = (hum) {
      print('💧 Humidity: $hum');
      setState(() {
        humidity = hum;
      });
    };
    
    // Food - SIMPLE PARSING
    mqtt.onFoodDetected = (data) {
      print('📦 Raw food data: "$data"');
      
      setState(() {
        isScanning = false;
        foodItems.clear();
        
        if (data == "EMPTY" || data.isEmpty) {
          print('📭 Fridge is empty');
          return;
        }
        
        // Split by comma: "apple:0.85,water:0.92"
        List<String> items = data.split(',');
        print('Found ${items.length} items');
        
        for (String item in items) {
          List<String> parts = item.split(':');
          if (parts.length == 2) {
            String name = parts[0];
            double confidence = double.tryParse(parts[1]) ?? 0;
            int percent = (confidence * 100).round();
            
            foodItems.add('${name.toUpperCase()} ($percent%)');
            print('  ✓ $name: $percent%');
          }
        }
        
        lastUpdate = _timeNow();
      });
    };
    
    // Connect
    mqtt.connect();
  }

  String _timeNow() {
    return DateTime.now().toString().substring(11, 19);
  }

  void _measureNow() {
    print('📱 User pressed MEASURE NOW');
    setState(() {
      isScanning = true;
      foodItems.clear();
    });
    
    mqtt.requestMeasurement();
    
    // Timeout after 7 seconds
    Future.delayed(const Duration(seconds: 7), () {
      if (mounted && isScanning) {
        setState(() => isScanning = false);
        print('⚠️ Scan timeout');
      }
    });
  }

  @override
  void dispose() {
    mqtt.disconnect();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Smart Fridge'),
        actions: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(
              'Updated: $lastUpdate',
              style: const TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // MEASURE BUTTON
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              height: 60,
              child: ElevatedButton(
                onPressed: isScanning ? null : _measureNow,
                style: ElevatedButton.styleFrom(
                  backgroundColor: isScanning ? Colors.grey : Colors.blue,
                  foregroundColor: Colors.white,
                ),
                child: isScanning
                    ? const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(color: Colors.white),
                          SizedBox(width: 12),
                          Text('SCANNING...', style: TextStyle(fontSize: 18)),
                        ],
                      )
                    : const Text(
                        'SCAN FRIDGE NOW',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
              ),
            ),
          ),
          
          // ENVIRONMENT
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Column(
                      children: [
                        const Text('TEMPERATURE', style: TextStyle(color: Colors.grey)),
                        const SizedBox(height: 8),
                        Text(temperature, style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    Container(width: 1, height: 50, color: Colors.grey[300]),
                    Column(
                      children: [
                        const Text('HUMIDITY', style: TextStyle(color: Colors.grey)),
                        const SizedBox(height: 8),
                        Text(humidity, style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // FOOD ITEMS HEADER
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'DETECTED ITEMS',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Text(
                  '${foodItems.length} items',
                  style: const TextStyle(color: Colors.grey),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 8),
          
          // FOOD LIST
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Card(
                child: foodItems.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.kitchen,
                              size: 80,
                              color: Colors.grey[300],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              isScanning ? 'Scanning...' : 'Fridge is empty',
                              style: const TextStyle(fontSize: 18, color: Colors.grey),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              isScanning ? 'Please wait' : 'Press SCAN button',
                              style: TextStyle(color: Colors.grey[500]),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(8),
                        itemCount: foodItems.length,
                        itemBuilder: (context, index) {
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: Colors.blue[50],
                              child: Text(
                                '${index + 1}',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                            title: Text(
                              foodItems[index],
                              style: const TextStyle(fontSize: 16),
                            ),
                            trailing: Icon(
                              Icons.check_circle,
                              color: Colors.green[400],
                            ),
                          );
                        },
                      ),
              ),
            ),
          ),
          
          // STATUS BAR
          Container(
            padding: const EdgeInsets.all(8),
            color: Colors.grey[100],
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.wifi,
                  size: 16,
                  color: Colors.green,
                ),
                const SizedBox(width: 8),
                const Text('Connected to Raspberry Pi'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}