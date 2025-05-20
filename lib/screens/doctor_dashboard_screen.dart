import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';

import '../widgets/custom_drawer.dart';

class DoctorDashboardScreen extends StatefulWidget {
  const DoctorDashboardScreen({super.key});

  @override
  State<DoctorDashboardScreen> createState() => _DoctorDashboardScreenState();
}

class _DoctorDashboardScreenState extends State<DoctorDashboardScreen> {
  bool _isMigrating = false;
  int _updatedCount = 0;

  Future<void> hashExistingPasswords() async {
    setState(() {
      _isMigrating = true;
      _updatedCount = 0;
    });

    final usersRef = FirebaseFirestore.instance.collection('users');
    final snapshot = await usersRef.get();

    int updated = 0;

    for (final doc in snapshot.docs) {
      final data = doc.data();
      final userId = doc.id;

      if (data.containsKey('password') && data['password'] is String) {
        final plainPassword = data['password'];
        final hashedPassword = sha256.convert(utf8.encode(plainPassword)).toString();

        await usersRef.doc(userId).update({
          'hashedPassword': hashedPassword,
          'password': FieldValue.delete(),
        });

        updated++;
        print('✅ Updated $userId');
      }
    }

    setState(() {
      _isMigrating = false;
      _updatedCount = updated;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Migration complete. $updated users updated.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const CustomDrawer(),
      appBar: AppBar(
        title: const Text('Doctor Dashboard'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Expanded(
              child: GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: 20,
                mainAxisSpacing: 20,
                children: [
                  _DashboardTile(
                    icon: Icons.people,
                    label: 'View Patients',
                    onTap: () => Navigator.pushNamed(context, '/doctor/patients'),
                  ),
                  _DashboardTile(
                    icon: Icons.person_add,
                    label: 'Create Patient',
                    onTap: () => Navigator.pushNamed(context, '/doctor/create-patient'),
                  ),
                  _DashboardTile(
                    icon: Icons.calendar_today,
                    label: 'Manage Appointments',
                    onTap: () => Navigator.pushNamed(context, '/doctor/appointments'),
                  ),
                  _DashboardTile(
                    icon: Icons.calendar_month,
                    label: 'Calendar',
                    onTap: () => Navigator.pushNamed(context, '/doctor/calendar'),
                  ),
                  _DashboardTile(
                    icon: Icons.chat,
                    label: 'Communicate',
                    onTap: () => Navigator.pushNamed(context, '/doctor/communication'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _isMigrating ? null : hashExistingPasswords,
              icon: const Icon(Icons.security),
              label: _isMigrating
                  ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Run Password Migration'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                foregroundColor: Colors.white,
              ),
            ),
            if (_updatedCount > 0)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(
                  '✅ $_updatedCount users updated.',
                  style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _DashboardTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _DashboardTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF2A2640) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            if (!isDark)
              BoxShadow(
                color: Colors.grey.shade300,
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
          ],
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 40, color: theme.colorScheme.primary),
            const SizedBox(height: 12),
            Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
