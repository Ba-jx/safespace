import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class RealTimeMonitorScreen extends StatefulWidget {
  const RealTimeMonitorScreen({super.key});

  @override
  State<RealTimeMonitorScreen> createState() => _RealTimeMonitorScreenState();
}

class _RealTimeMonitorScreenState extends State<RealTimeMonitorScreen> {
  BluetoothDevice? connectedDevice;
  BluetoothCharacteristic? notifyCharacteristic;
  String heartRate = '--';
  String temperature = '--';
  String oxygenLevel = '--';
  bool isConnecting = false;

  @override
  void initState() {
    super.initState();
    scanAndConnect();
  }

  void scanAndConnect() async {
    setState(() => isConnecting = true);
    FlutterBluePlus.startScan(timeout: const Duration(seconds: 5));

    FlutterBluePlus.scanResults.listen((results) async {
      for (ScanResult r in results) {
        if (r.device.name == "ESP32_HealthMonitor") {
          await FlutterBluePlus.stopScan();
          connectedDevice = r.device;

          await connectedDevice!.connect(autoConnect: false);
          discoverServices();
          break;
        }
      }
    });
  }

  void discoverServices() async {
    if (connectedDevice == null) return;

    List<BluetoothService> services = await connectedDevice!.discoverServices();
    for (BluetoothService service in services) {
      for (BluetoothCharacteristic c in service.characteristics) {
        if (c.properties.notify) {
          notifyCharacteristic = c;
          await c.setNotifyValue(true);
          c.onValueReceived.listen((value) {
            final data = String.fromCharCodes(value);
            parseAndSetData(data);
          });
          setState(() => isConnecting = false);
          return;
        }
      }
    }
  }

  void parseAndSetData(String data) {
    final parts = data.split('|');
    if (parts.length == 3) {
      setState(() {
        heartRate = parts[0].replaceAll('BPM:', '').trim();
        oxygenLevel = parts[1].replaceAll('SpO2:', '').replaceAll('%', '').trim();
        temperature = parts[2].replaceAll('Temp:', '').replaceAll('C', '').trim();
      });
    }
  }

  @override
  void dispose() {
    connectedDevice?.disconnect();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Real-Time Monitor')),
      body: isConnecting
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  _buildMetricRow(
                    icon: Icons.favorite,
                    title: 'Heart Rate',
                    value: '$heartRate BPM',
                    color: Colors.redAccent,
                  ),
                  const SizedBox(height: 16),
                  _buildMetricRow(
                    icon: Icons.thermostat,
                    title: 'Temperature',
                    value: '$temperature °C',
                    color: Colors.orange,
                  ),
                  const SizedBox(height: 16),
                  _buildMetricRow(
                    icon: Icons.bloodtype,
                    title: 'Oxygen Level',
                    value: '$oxygenLevel %',
                    color: Colors.blueAccent,
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildMetricRow({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
  }) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Icon(icon, size: 36, color: color),
        title: RichText(
          text: TextSpan(
            style: const TextStyle(fontSize: 18, color: Colors.black),
            children: [
              TextSpan(
                text: title,
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
              const TextSpan(text: '  '),
              TextSpan(
                text: value,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
