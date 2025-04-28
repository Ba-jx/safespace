import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../widgets/custom_drawer.dart';
import '../providers/user_provider.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final userName = Provider.of<UserProvider>(context).userName;

    return Scaffold(
      appBar: AppBar(title: const Text('Safe Space Home')),
      drawer: const CustomDrawer(),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 24),
            Text(
              'Welcome back, $userName 👋',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Card(
              elevation: 3,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'Quick Access',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    SizedBox(height: 10),
                    Text(
                      '• Log symptoms\n'
                      '• View real-time vitals\n'
                      '• Connect with your doctor',
                      style: TextStyle(height: 1.5),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              icon: const Icon(Icons.favorite),
              label: const Text('Track Symptoms'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              onPressed:
                  () => Navigator.pushNamed(context, '/symptom-tracking'),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              icon: const Icon(Icons.monitor_heart),
              label: const Text('Real-Time Monitor'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              onPressed:
                  () => Navigator.pushNamed(context, '/real-time-monitor'),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              icon: const Icon(Icons.medical_services),
              label: const Text('Doctor Chat'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              onPressed:
                  () => Navigator.pushNamed(context, '/doctor-communication'),
            ),
          ],
        ),
      ),
    );
  }
}
