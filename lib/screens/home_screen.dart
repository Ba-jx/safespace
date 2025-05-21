import 'package:flutter/material.dart';
import '../widgets/custom_drawer.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const CustomDrawer(),
      appBar: AppBar(
        title: const Text('Your Safe Space'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: GridView.count(
          crossAxisCount: 2,
          crossAxisSpacing: 20,
          mainAxisSpacing: 20,
          children: [
            _DashboardTile(
              icon: Icons.monitor_heart,
              label: 'Real-Time Monitor',
              onTap: () => Navigator.pushNamed(context, '/real-time-monitor'),
            ),
            _DashboardTile(
              icon: Icons.mood,
              label: 'Track Symptoms',
              onTap: () => Navigator.pushNamed(context, '/symptom-tracking'),
            ),
            _DashboardTile(
              icon: Icons.chat,
              label: 'Communicate',
              onTap: () => Navigator.pushNamed(context, '/patient/communication'),
            ),
            _DashboardTile(
              icon: Icons.schedule,
              label: 'Booking Appointments',
              onTap: () => Navigator.pushNamed(context, '/appointments/book'),
            ),
            _DashboardTile(
              icon: Icons.calendar_today,
              label: 'My Appointments',
              onTap: () => Navigator.pushNamed(context, '/appointments/list'),
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
