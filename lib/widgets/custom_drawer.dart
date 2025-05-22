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
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
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
    final backgroundColor = isDark ? const Color(0xFF1A1729) : Colors.white;
    final headerColor = isDark ? const Color(0xFF6C4DB0) : Colors.purple;
    final textColor = isDark ? Colors.white : Colors.black87;

    return Drawer(
      backgroundColor: backgroundColor,
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
              DrawerHeader(
                decoration: BoxDecoration(color: headerColor),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Safe Space', style: TextStyle(color: textColor, fontSize: 20)),
                    const SizedBox(height: 8),
                    Text('Welcome, $name',
                        style: TextStyle(color: textColor, fontSize: 16)),
                  ],
                ),
              ),
              if (isDoctor) ...[
                _drawerItem(context, Icons.dashboard, 'Dashboard', '/doctor/dashboard', textColor),
                _drawerItem(context, Icons.people, 'View Patients', '/doctor/patients', textColor),
                _drawerItem(context, Icons.calendar_today, 'Appointments', '/doctor/appointments', textColor),
                _drawerItem(context, Icons.calendar_month, 'Calendar', '/doctor/calendar', textColor),
                _drawerItem(context, Icons.chat, 'Chats', '/doctor/communication', textColor),
              ] else ...[
                _drawerItem(context, Icons.home, 'Home', '/home', textColor),
                _drawerItem(context, Icons.monitor_heart, 'Real Time Monitor', '/real-time-monitor', textColor),
                _drawerItem(context, Icons.mood, 'Track Symptoms', '/symptom-tracking', textColor),
                _drawerItem(context, Icons.chat, 'Chats', '/patient/communication', textColor),
                _drawerItem(context, Icons.schedule, 'Book Appointments', '/appointments/book', textColor),
                _drawerItem(context, Icons.calendar_today, 'My Appointments', '/appointments/list', textColor),
              ],
              const Divider(),
              _drawerItem(context, Icons.logout, 'Logout', '', textColor, onTapOverride: () => _confirmAndLogout(context)),
            ],
          );
        },
      ),
    );
  }

  Widget _drawerItem(BuildContext context, IconData icon, String label, String route, Color color, {VoidCallback? onTapOverride}) {
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(label, style: TextStyle(color: color)),
      onTap: onTapOverride ?? () => Navigator.pushNamed(context, route),
    );
  }
}
