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
            decoration: BoxDecoration(color: Color(0xFFD8BFD8)),
            child: Text(
              'Safe Space',
              style: TextStyle(color: Colors.white, fontSize: 24),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.home),
            title: const Text('Home'),
            onTap: () => Navigator.pushReplacementNamed(context, '/home'),
          ),
          ListTile(
            leading: const Icon(Icons.favorite),
            title: const Text('Symptom Tracking'),
            onTap:
                () => Navigator.pushReplacementNamed(
                  context,
                  '/symptom-tracking',
                ),
          ),
          ListTile(
            leading: const Icon(Icons.monitor_heart),
            title: const Text('Real-Time Monitor'),
            onTap:
                () => Navigator.pushReplacementNamed(
                  context,
                  '/real-time-monitor',
                ),
          ),
          ListTile(
            leading: const Icon(Icons.medical_services),
            title: const Text('Doctor Communication'),
            onTap:
                () => Navigator.pushReplacementNamed(
                  context,
                  '/doctor-communication',
                ),
          ),
          ListTile(
            leading: const Icon(Icons.settings),
            title: const Text('Settings'),
            onTap: () => Navigator.pushReplacementNamed(context, '/settings'),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Logout'),
            onTap: () => Navigator.pushReplacementNamed(context, '/login'),
          ),
        ],
      ),
    );
  }
}
