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
    actions: [
      Padding(
        padding: const EdgeInsets.only(right: 16),
        child: Image.asset(
          'assets/safe_space_logo1.png', // Make sure the image exists here
          height: 40,
          width: 40,
        ),
      ),
    ],
  ),
),

      body: Padding(
        padding: const EdgeInsets.all(20),
        child: GridView.count(
          crossAxisCount: 2,
          crossAxisSpacing: 20,
          mainAxisSpacing: 20,
          childAspectRatio: 0.9, // 👈 Slightly taller tiles
          children: const [
            _DashboardTile(
              icon: Icons.people,
              label: 'View Patients',
              route: '/doctor/patients',
            ),
            _DashboardTile(
              icon: Icons.person_add,
              label: 'Create Patient',
              route: '/doctor/create-patient',
            ),
            _DashboardTile(
              icon: Icons.calendar_today,
              label: 'Manage Appointments',
              route: '/doctor/appointments',
            ),
            _DashboardTile(
              icon: Icons.calendar_month,
              label: 'Calendar',
              route: '/doctor/calendar',
            ),
            _DashboardTile(
              icon: Icons.chat,
              label: 'Communicate',
              route: '/doctor/communication',
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
  final String route;

  const _DashboardTile({
    required this.icon,
    required this.label,
    required this.route,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, route),
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
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
