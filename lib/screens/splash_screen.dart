import 'dart:async';
import 'package:flutter/material.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Color?> _colorAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );

    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(_controller);
    _controller.forward();

    Timer(const Duration(seconds: 4), () {
      Navigator.pushReplacementNamed(context, '/role-selection');
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final isDark = Theme.of(context).brightness == Brightness.dark;

    _colorAnimation = ColorTween(
      begin: isDark ? const Color(0xFF9E8CD8) : const Color(0xFFB9A6E8),
      end: isDark ? const Color(0xFFB9A6E8) : const Color(0xFF7A6EDB),
    ).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF1C152D) : const Color(0xFFF5F5FF),
      body: Center(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: AnimatedBuilder(
            animation: _colorAnimation,
            builder: (context, child) => Text(
              'Safe Space',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: _colorAnimation.value,
                letterSpacing: 1.5,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
