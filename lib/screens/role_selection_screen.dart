import 'package:flutter/material.dart';

class RoleSelectionScreen extends StatelessWidget {
  const RoleSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? Colors.black : const Color(0xFFF5F5FF),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 36.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Enlarged logo
                ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: 360,
                    maxHeight: 360,
                  ),
                  child: Image.asset(
                    'assets/images/safe_space_logo1.png',
                    height: 300,
                    fit: BoxFit.contain,
                  ),
                ),
                const SizedBox(height: 16),

                // Welcome text
                Text(
                  'Welcome to Safe Space',
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: isDark ? Colors.white : const Color(0xFF5A4E8C),
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 36),

                // Patient login button
                ElevatedButton.icon(
                  onPressed: () => Navigator.pushNamed(context, '/login'),
                  icon: const Icon(Icons.person),
                  label: const Text('Patient Login'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isDark ? const Color(0xFF5A4E8C) : const Color(0xFFDDD6F7),
                    foregroundColor: isDark ? Colors.white : const Color(0xFF333366),
                    minimumSize: const Size.fromHeight(48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 1,
                  ),
                ),
                const SizedBox(height: 20),

                // Doctor login button
                ElevatedButton.icon(
                  onPressed: () => Navigator.pushNamed(context, '/doctor/login'),
                  icon: const Icon(Icons.medical_services),
                  label: const Text('Doctor Login'),
                  style: ElevatedButton.styleFrom(
                  backgroundColor: isDark ? const Color(0xFF5A4E8C) : const Color(0xFFDDD6F7),
                    foregroundColor: isDark ? Colors.white : const Color(0xFF333366),
                    minimumSize: const Size.fromHeight(48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 2,
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
