import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CustomDrawer extends StatelessWidget {
  const CustomDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: Column(
        children: [
          UserAccountsDrawerHeader(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFFB497BD), Color(0xFFD8BFD8)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            accountName: const Text("Safe Space User"),
            accountEmail: Text(FirebaseAuth.instance.currentUser?.email ?? ''),
            currentAccountPicture: const CircleAvatar(
              backgroundColor: Colors.white,
              child: Icon(Icons.person, color: Colors.deepPurple),
            ),
          ),
          Expanded(
            child: ListView(
              children: [
                _drawerItem(
                  context,
                  icon: Icons.home,
                  text: 'Home',
                  route: '/home',
                ),
                _drawerItem(
                  context,
                  icon: Icons.mood,
                  text: 'Symptom Tracking',
                  route: '/symptom-tracking',
                ),
                _drawerItem(
                  context,
                  icon: Icons.monitor_heart,
                  text: 'Real-Time Monitor',
                  route: '/real-time-monitor',
                ),
                _drawerItem(
                  context,
                  icon: Icons.chat,
                  text: 'Doctor Communication',
                  route: '/doctor-communication',
                ),
                _drawerItem(
                  context,
                  icon: Icons.settings,
                  text: 'Settings',
                  route: '/settings',
                ),
                const Divider(),
                _drawerItem(
                  context,
                  icon: Icons.add_circle_outline,
                  text: 'Book Appointment',
                  route: '/appointments/book',
                ),
                _drawerItem(
                  context,
                  icon: Icons.calendar_month,
                  text: 'My Appointments',
                  route: '/appointments/list',
                ),
              ],
            ),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.redAccent),
            title: const Text('Logout', style: TextStyle(color: Colors.redAccent)),
            onTap: () async {
              await FirebaseAuth.instance.signOut();
              Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
            },
          ),
        ],
      ),
    );
  }

  Widget _drawerItem(BuildContext context,
      {required IconData icon, required String text, required String route}) {
    return ListTile(
      leading: Icon(icon, color: Colors.deepPurple),
      title: Text(text),
      onTap: () {
        Navigator.pushNamed(context, route);
      },
    );
  }
}
