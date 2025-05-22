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
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Logout')),
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
    final bgColor = isDark ? const Color(0xFF1A1729) : const Color(0xFFF3EFFB);
    final textColor = isDark ? Colors.white : const Color(0xFF4A3D74);
    final iconColor = isDark ? Colors.white : const Color(0xFF6C4DB0);

    return Drawer(
      backgroundColor: bgColor,
      child: FutureBuilder<Map<String, dynamic>?>(
        future: _getUserData(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final userData = snapshot.data!;
          final name = userData['name'] ?? 'User';
          final role = userData['role'] ?? '';
          final isDoctor = role == 'doctor';

          return ListView(
            padding: EdgeInsets.zero,
            children: [
              Container(
                height: 120,
                color: const Color(0xFF7A6EDB),
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0),
                alignment: Alignment.bottomLeft,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Safe Space', style: TextStyle(color: Colors.white, fontSize: 20)),
                    const SizedBox(height: 4),
                    Text('Welcome, $name', style: const TextStyle(color: Colors.white70, fontSize: 14)),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              ..._buildDrawerItems(context, isDoctor, textColor, iconColor),
              const Divider(),
              ListTile(
                leading: Icon(Icons.logout, color: iconColor),
                title: Text('Logout', style: TextStyle(color: textColor)),
                onTap: () => _confirmAndLogout(context),
              ),
            ],
          );
        },
      ),
    );
  }

  List<Widget> _buildDrawerItems(BuildContext context, bool isDoctor, Color textColor, Color iconColor) {
    if (isDoctor) {
      return [
        _drawerItem(Icons.dashboard, 'Dashboard', '/doctor/dashboard', textColor, iconColor, context),
        _drawerItem(Icons.people, 'View Patients', '/doctor/patients', textColor, iconColor, context),
        _drawerItem(Icons.calendar_today, 'Appointments', '/doctor/appointments', textColor, iconColor, context),
        _drawerItem(Icons.calendar_month, 'Calendar', '/doctor/calendar', textColor, iconColor, context),
        _drawerItem(Icons.chat, 'Chats', '/doctor/communication', textColor, iconColor, context),
      ];
    } else {
      return [
        _drawerItem(Icons.home, 'Home', '/home', textColor, iconColor, context),
        _drawerItem(Icons.monitor_heart, 'Real Time Monitor', '/real-time-monitor', textColor, iconColor, context),
        _drawerItem(Icons.mood, 'Track Symptoms', '/symptom-tracking', textColor, iconColor, context),
        _drawerItem(Icons.chat, 'Chats', '/patient/communication', textColor, iconColor, context),
        _drawerItem(Icons.schedule, 'Book Appointments', '/appointments/book', textColor, iconColor, context),
        _drawerItem(Icons.calendar_today, 'My Appointments', '/appointments/list', textColor, iconColor, context),
      ];
    }
  }

  Widget _drawerItem(IconData icon, String title, String route, Color textColor, Color iconColor, BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: iconColor),
      title: Text(title, style: TextStyle(color: textColor)),
      onTap: () => Navigator.pushNamed(context, route),
    );
  }
}
