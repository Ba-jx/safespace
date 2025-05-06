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
                decoration: const BoxDecoration(color: Colors.purple),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('SafeSpace', style: TextStyle(color: Colors.white, fontSize: 20)),
                    const SizedBox(height: 8),
                    Text('Welcome, $name',
                        style: const TextStyle(color: Colors.white, fontSize: 16)),
                  ],
                ),
              ),
              if (isDoctor) ...[
                ListTile(
                  leading: const Icon(Icons.dashboard),
                  title: const Text('Dashboard'),
                  onTap: () => Navigator.pushNamed(context, '/doctor/dashboard'),
                ),
                ListTile(
                  leading: const Icon(Icons.people),
                  title: const Text('View Patients'),
                  onTap: () => Navigator.pushNamed(context, '/doctor/patients'),
                ),
                ListTile(
                  leading: const Icon(Icons.calendar_today),
                  title: const Text('Appointments'),
                  onTap: () => Navigator.pushNamed(context, '/doctor/appointments'),
                ),
                ListTile(
                  leading: const Icon(Icons.chat),
                  title: const Text('Chats'),
                  onTap: () => Navigator.pushNamed(context, '/doctor/communication'),
                ),
              ] else ...[
                ListTile(
                  leading: const Icon(Icons.home),
                  title: const Text('Home'),
                  onTap: () => Navigator.pushNamed(context, '/home'),
                ),
                ListTile(
                  leading: const Icon(Icons.monitor_heart),
                  title: const Text('Real Time Monitor'),
                  onTap: () => Navigator.pushNamed(context, '/real-time-monitor'),
                ),
                ListTile(
                  leading: const Icon(Icons.mood),
                  title: const Text('Track Symptoms'),
                  onTap: () => Navigator.pushNamed(context, '/symptom-tracking'),
                ),
                ListTile(
                  leading: const Icon(Icons.chat),
                  title: const Text('Chats'),
                  onTap: () => Navigator.pushNamed(context, '/patient/communication'),
                ),
                ListTile(
                  leading: const Icon(Icons.schedule),
                  title: const Text('Book Appointments'),
                  onTap: () => Navigator.pushNamed(context, '/appointments/book'),
                ),
                ListTile(
                  leading: const Icon(Icons.calendar_today),
                  title: const Text('My Appointments'),
                  onTap: () => Navigator.pushNamed(context, '/appointments/list'),
                ),
              ],
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
}
