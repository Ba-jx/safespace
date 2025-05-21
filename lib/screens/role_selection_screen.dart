import 'package:flutter/material.dart';

class RoleSelectionScreen extends StatelessWidget {
  const RoleSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFEEDCFF), Color(0xFFD8BFD8)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 36.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // 🧠 App Logo
                  Image.asset(
                    'assets/images/safe_space_logo1.png',
                    height: 140,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(height: 32),
                  // 📣 Welcome Title
                  Text(
                    'Welcome to Safe Space',
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: isDark ? Colors.purple[200] : Colors.purple[800],
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 40),
                  // 👤 Patient Login
                  ElevatedButton.icon(
                    onPressed: () => Navigator.pushNamed(context, '/login'),
                    icon: const Icon(Icons.person),
                    label: const Text('Patient Login'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.purple[200],
                      foregroundColor: Colors.black,
                      minimumSize: const Size.fromHeight(48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  // 🩺 Doctor Login
                  ElevatedButton.icon(
                    onPressed: () => Navigator.pushNamed(context, '/doctor/login'),
                    icon: const Icon(Icons.medical_services_outlined),
                    label: const Text('Doctor Login'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.purple[400],
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(48),
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
      ),
    );
  }
}
