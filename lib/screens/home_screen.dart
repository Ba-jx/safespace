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
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Welcome, $userName!',
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Your Safe Space dashboard',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 32),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              childAspectRatio: 1,
              children: [
                _buildFeatureCard(
                  context,
                  icon: Icons.monitor_heart,
                  label: 'Real-Time Monitor',
                  route: '/real-time-monitor',
                ),
                _buildFeatureCard(
                  context,
                  icon: Icons.mood,
                  label: 'Symptom Tracking',
                  route: '/symptom-tracking',
                ),
                _buildFeatureCard(
                  context,
                  icon: Icons.chat,
                  label: 'Contact Doctor',
                  route: '/doctor-communication',
                ),
                _buildFeatureCard(
                  context,
                  icon: Icons.add_circle_outline,
                  label: 'Book Appointment',
                  route: '/appointments/book',
                ),
                _buildFeatureCard(
                  context,
                  icon: Icons.calendar_today,
                  label: 'View Appointments',
                  route: '/appointments/list',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureCard(BuildContext context,
      {required IconData icon, required String label, required String route}) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 4,
      child: InkWell(
        onTap: () => Navigator.pushNamed(context, route),
        borderRadius: BorderRadius.circular(16),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 40, color: Colors.deepPurple),
              const SizedBox(height: 12),
              Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 16)),
            ],
          ),
        ),
      ),
    );
  }
}
