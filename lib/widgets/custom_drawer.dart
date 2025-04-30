
import 'package:flutter/material.dart';

class CustomDrawer extends StatelessWidget {
  const CustomDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          const DrawerHeader(
            decoration: BoxDecoration(color: Colors.deepPurple),
            child: Text('Safe Space', style: TextStyle(color: Colors.white, fontSize: 24)),
          ),
          ListTile(
            leading: const Icon(Icons.home),
            title: const Text('Home'),
            onTap: () => Navigator.pushNamed(context, '/home'),
          ),
          ListTile(
            leading: const Icon(Icons.mood),
            title: const Text('Symptom Tracking'),
            onTap: () => Navigator.pushNamed(context, '/symptom-tracking'),
          ),
          ListTile(
            leading: const Icon(Icons.monitor_heart),
            title: const Text('Real-Time Monitor'),
            onTap: () => Navigator.pushNamed(context, '/real-time-monitor'),
          ),
          ListTile(
            leading: const Icon(Icons.chat),
            title: const Text('Doctor Communication'),
            onTap: () => Navigator.pushNamed(context, '/doctor-communication'),
          ),
          ListTile(
            leading: const Icon(Icons.settings),
            title: const Text('Settings'),
            onTap: () => Navigator.pushNamed(context, '/settings'),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.add_circle_outline),
            title: const Text('Book Appointment'),
            onTap: () => Navigator.pushNamed(context, '/appointments/book'),
          ),
          ListTile(
            leading: const Icon(Icons.calendar_month),
            title: const Text('My Appointments'),
            onTap: () => Navigator.pushNamed(context, '/appointments/list'),
          ),
        ],
      ),
    );
  }
}
