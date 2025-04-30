import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/user_provider.dart';
import '../widgets/custom_drawer.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final userName = Provider.of<UserProvider>(context).userName;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Home'),
      ),
      drawer: const CustomDrawer(),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Hello, $userName!',
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'What would you like to do today?',
              style: TextStyle(fontSize: 18),
            ),
            const SizedBox(height: 24),
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                ElevatedButton.icon(
                  icon: const Icon(Icons.monitor_heart),
                  label: const Text('Real-Time Monitor'),
                  onPressed: () => Navigator.pushNamed(context, '/real-time-monitor'),
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.mood),
                  label: const Text('Symptom Tracking'),
                  onPressed: () => Navigator.pushNamed(context, '/symptom-tracking'),
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.chat),
                  label: const Text('Contact Doctor'),
                  onPressed: () => Navigator.pushNamed(context, '/doctor-communication'),
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.add_circle_outline),
                  label: const Text('Book Appointment'),
                  onPressed: () => Navigator.pushNamed(context, '/appointments/book'),
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.calendar_today),
                  label: const Text('View Appointments'),
                  onPressed: () => Navigator.pushNamed(context, '/appointments/list'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
