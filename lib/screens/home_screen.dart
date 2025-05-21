import 'package:flutter/material.dart';
import '../widgets/custom_drawer.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const CustomDrawer(),
      appBar: AppBar(
        title: const Text('Your Safe Space'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _DashboardTile(
                icon: Icons.monitor_heart,
                label: 'Real-Time Monitor',
                onTap: () => Navigator.pushNamed(context, '/real-time-monitor'),
              ),
              const SizedBox(width: 16),
              _DashboardTile(
                icon: Icons.mood,
                label: 'Track Symptoms',
                onTap: () => Navigator.pushNamed(context, '/symptom-tracking'),
              ),
              const SizedBox(width: 16),
              _DashboardTile(
                icon: Icons.chat,
                label: 'Communicate',
                onTap: () => Navigator.pushNamed(context, '/patient/communication'),
              ),
              const SizedBox(width: 16),
              _DashboardTile(
                icon: Icons.schedule,
                label: 'Booking Appointments',
                onTap: () => Navigator.pushNamed(context, '/appointments/book'),
              ),
              const SizedBox(width: 16),
              _DashboardTile(
                icon: Icons.calendar_today,
                label: 'My Appointments',
                onTap: () => Navigator.pushNamed(context, '/appointments/list'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
