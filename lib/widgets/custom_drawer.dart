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
    return Drawer(
      backgroundColor: const Color(0xFFF5F5FF),
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
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFFB9A6E8), Color(0xFF7A6EDB)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Safe Space',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Welcome, $name',
                      style: const TextStyle(color: Colors.white70, fontSize: 16),
                    ),
                  ],
                ),
              ),
              ..._buildDrawerItems(context, isDoctor),
              const Divider(color: Color(0xFFCCC2DC)),
              ListTile(
                leading: const Icon(Icons.logout, color: Color(0xFF7A6EDB)),
                title: const Text(
                  'Logout',
                  style: TextStyle(color: Color(0xFF5A4E8C)),
                ),
                onTap: () => _confirmAndLogout(context),
              ),
            ],
          );
        },
      ),
    );
  }

  List<Widget> _buildDrawerItems(BuildContext context, bool isDoctor) {
    const iconColor = Color(0xFF7A6EDB);
    const textStyle = TextStyle(color: Color(0xFF5A4E8C));

    if (isDoctor) {
      return [
        ListTile(
          leading: const Icon(Icons.dashboard, color: iconColor),
          title: const Text('Dashboard', style: textStyle),
          onTap: () => Navigator.pushNamed(context, '/doctor/dashboard'),
        ),
        ListTile(
          leading: const Icon(Icons.people, color: iconColor),
          title: const Text('View Patients', style: textStyle),
          onTap: () => Navigator.pushNamed(context, '/doctor/patients'),
        ),
        ListTile(
          leading: const Icon(Icons.calendar_today, color: iconColor),
          title: const Text('Appointments', style: textStyle),
          onTap: () => Navigator.pushNamed(context, '/doctor/appointments'),
        ),
        ListTile(
          leading: const Icon(Icons.calendar_month, color: iconColor),
          title: const Text('Calendar', style: textStyle),
          onTap: () => Navigator.pushNamed(context, '/doctor/calendar'),
        ),
        ListTile(
          leading: const Icon(Icons.chat, color: iconColor),
          title: const Text('Chats', style: textStyle),
          onTap: () => Navigator.pushNamed(context, '/doctor/communication'),
        ),
      ];
    } else {
      return [
        ListTile(
          leading: const Icon(Icons.home, color: iconColor),
          title: const Text('Home', style: textStyle),
          onTap: () => Navigator.pushNamed(context, '/home'),
        ),
        ListTile(
          leading: const Icon(Icons.monitor_heart, color: iconColor),
          title: const Text('Real Time Monitor', style: textStyle),
          onTap: () => Navigator.pushNamed(context, '/real-time-monitor'),
        ),
        ListTile(
          leading: const Icon(Icons.mood, color: iconColor),
          title: const Text('Track Symptoms', style: textStyle),
          onTap: () => Navigator.pushNamed(context, '/symptom-tracking'),
        ),
        ListTile(
          leading: const Icon(Icons.chat, color: iconColor),
          title: const Text('Chats', style: textStyle),
          onTap: () => Navigator.pushNamed(context, '/patient/communication'),
        ),
        ListTile(
          leading: const Icon(Icons.schedule, color: iconColor),
          title: const Text('Book Appointments', style: textStyle),
          onTap: () => Navigator.pushNamed(context, '/appointments/book'),
        ),
        ListTile(
          leading: const Icon(Icons.calendar_today, color: iconColor),
          title: const Text('My Appointments', style: textStyle),
          onTap: () => Navigator.pushNamed(context, '/appointments/list'),
        ),
      ];
    }
  }
}
