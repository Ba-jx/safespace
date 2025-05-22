import 'package:flutter/material.dart';
import '../widgets/custom_drawer.dart';

class DoctorDashboardScreen extends StatelessWidget {
  const DoctorDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const CustomDrawer(),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(80),
        child: AppBar(
          title: const Text(
            'Doctor Dashboard',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
          centerTitle: true,
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
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
        padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 50, color: theme.colorScheme.primary),
            const SizedBox(height: 16),
            Text(
              label,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                fontSize: 14, // 👈 Reduced for better fit
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
