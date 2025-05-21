import 'package:flutter/material.dart';

class RoleSelectionScreen extends StatelessWidget {
  const RoleSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5FF), // Soft pastel background
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

                // Welcome text with matching purple
                Text(
                  'Welcome to Safe Space',
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: const Color(0xFF5A4E8C), // Harmonized with background
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
                    backgroundColor: const Color(0xFFDDD6F7), // Light lavender
                    foregroundColor: const Color(0xFF333366), // Deep soft text
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
                    backgroundColor: const Color(0xFF7A6EDB), // Medium purple
                    foregroundColor: Colors.white,
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
