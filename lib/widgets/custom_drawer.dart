import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../providers/user_provider.dart';

class CustomDrawer extends StatelessWidget {
  const CustomDrawer({super.key});

  Future<Map<String, dynamic>?> _getUserData() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return null;
    final doc = await FirebaseFirestore.instance.collection('users').doc(userId).get();
    return doc.exists ? doc.data() : null;
  }

  Future<void> _confirmAndLogout(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Logout'),
        content: const Text('Are you sure you want to log out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await FirebaseAuth.instance.signOut();
      Provider.of<UserProvider>(context, listen: false).setUserName('');
      Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Drawer(
      backgroundColor: isDark ? const Color(0xFF1A1729) : const Color(0xFFF9F7FC),
      child: FutureBuilder<Map<String, dynamic>?>(
        future: _getUserData(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final userData = snapshot.data!;
          final String name = userData['name'] ?? 'User';
          final String role = userData['role'] ?? '';
          final isDoctor = role == 'doctor';

         return ListView(
            padding: EdgeInsets.zero,
            children: [
              Container(
                height: 140,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF7A5ACD) : const Color(0xFFB39DDB),
                  borderRadius: const BorderRadius.only(
                    bottomRight: Radius.circular(24),
                  ),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('Safe Space', style: TextStyle(color: Colors.white, fontSize: 20)),
                    const SizedBox(height: 8),
                    Text('Welcome, $name',
                        style: const TextStyle(color: Colors.white, fontSize: 16)),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              ..._buildNavigationItems(context, isDoctor),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.logout),
                title: const Text('Logout'),
                onTap: () => _confirmAndLogout(context),
              ),
            ],
          );
        },
      ),
    );
  }

  List<Widget> _buildNavigationItems(BuildContext context, bool isDoctor) {
    if (isDoctor) {
      return [
        _drawerTile(context, Icons.dashboard, 'Dashboard', '/doctor/dashboard'),
        _drawerTile(context, Icons.people, 'View Patients', '/doctor/patients'),
        _drawerTile(context, Icons.calendar_today, 'Appointments', '/doctor/appointments'),
        _drawerTile(context, Icons.calendar_month, 'Calendar', '/doctor/calendar'),
        _drawerTile(context, Icons.chat, 'Chats', '/doctor/communication'),
      ];
    } else {
      return [
        _drawerTile(context, Icons.home, 'Home', '/home'),
        _drawerTile(context, Icons.monitor_heart, 'Real Time Monitor', '/real-time-monitor'),
        _drawerTile(context, Icons.mood, 'Track Symptoms', '/symptom-tracking'),
        _drawerTile(context, Icons.chat, 'Chats', '/patient/communication'),
        _drawerTile(context, Icons.schedule, 'Book Appointments', '/appointments/book'),
        _drawerTile(context, Icons.calendar_today, 'My Appointments', '/appointments/list'),
      ];
    }
  }

  Widget _drawerTile(BuildContext context, IconData icon, String title, String route) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      onTap: () => Navigator.pushNamed(context, route),
    );
  }
}
