import 'package:flutter/material.dart';

class RoleSelectionScreen extends StatelessWidget {
  const RoleSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF1A1729) : const Color(0xFFF9F7FC),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 36.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset(
                  'assets/images/safe_space_logo1.png',
                  height: 430, 
                  width: 430,
                  fit: BoxFit.contain,
                ),
                const SizedBox(height: 15),
                Text(
                  'Welcome to Safe Space',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF5A4E8C),
                  ),
                ),
                const SizedBox(height: 30),
                ElevatedButton.icon(
                  onPressed: () => Navigator.pushNamed(context, '/login'),
                  icon: const Icon(Icons.person_outline),
                  label: const Text('Patient Login'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6C4DB0),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () => Navigator.pushNamed(context, '/doctor/login'),
                  icon: const Icon(Icons.medical_services_outlined),
                  label: const Text('Doctor Login'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6C4DB0),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
