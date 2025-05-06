import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class CustomDrawer extends StatelessWidget {
  const CustomDrawer({super.key});

  Future<String?> _getUserRole() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return null;
    final doc = await FirebaseFirestore.instance.collection('users').doc(userId).get();
    return doc['role'];
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: FutureBuilder<String?>(
        future: _getUserRole(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final role = snapshot.data;
          final isDoctor = role == 'doctor';

          return ListView(
            padding: EdgeInsets.zero,
            children: [
              const DrawerHeader(
                decoration: BoxDecoration(color: Colors.purple),
                child: Text('SafeSpace', style: TextStyle(color: Colors.white, fontSize: 24)),
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
                  title: const Text('Communicate'),
                  onTap: () => Navigator.pushNamed(context, '/doctor/communication'),
                ),
              ] else ...[
                ListTile(
                  leading: const Icon(Icons.home),
                  title: const Text('Home'),
                  onTap: () => Navigator.pushNamed(context, '/home'),
                ),
                  ListTile(
                  leading: const Icon(Icons.mood),
                  title: const Text('Track Symptoms'),
                  onTap: () => Navigator.pushNamed(context, '/symptom-tracking'),
                ),
                  ListTile(
                  leading: const Icon(Icons.monitor_heart),
                  title: const Text('Real Time Monitor'),
                  onTap: () => Navigator.pushNamed(context, '/real-time-monitor'),
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
                ListTile(
                  leading: const Icon(Icons.chat),
                  title: const Text('Communicate'),
                  onTap: () => Navigator.pushNamed(context, '/patient/communication'),
                ),
              ],
              const Divider(),
              ListTile(
                leading: const Icon(Icons.logout),
                title: const Text('Logout'),
                onTap: () => FirebaseAuth.instance.signOut(),
              ),
            ],
          );
        },
      ),
    );
  }
}
