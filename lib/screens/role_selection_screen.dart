import 'package:flutter/material.dart';

class RoleSelectionScreen extends StatelessWidget {
  const RoleSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFEADCF8),
              Color(0xFFD8BFD8),
              Color(0xFFCFB4E5),
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 36.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo with soft shadow
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.08),
                          blurRadius: 12,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Image.asset(
                      'assets/images/safe_space_logo1.png',
                      height: 100,
                      fit: BoxFit.contain,
                    ),
                  ),
                  const SizedBox(height: 36),

                  // Welcome text with darker shade for readability
                  Text(
                    'Welcome to Safe Space',
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: Colors.deepPurple.shade700,
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
                      backgroundColor: const Color(0xFFE2D4F5),
                      foregroundColor: Colors.black87,
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
                      backgroundColor: const Color(0xFF9C6ADE),
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
      ),
    );
  }
}
