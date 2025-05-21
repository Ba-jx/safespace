import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

class DoctorLoginScreen extends StatefulWidget {
  const DoctorLoginScreen({super.key});

  @override
  State<DoctorLoginScreen> createState() => _DoctorLoginScreenState();
}

class _DoctorLoginScreenState extends State<DoctorLoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  bool _mfaStep = false;
  User? _user;

  Future<void> _login() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (!_formKey.currentState!.validate()) return;

    try {
      final credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final uid = credential.user?.uid;
      final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();

      if (!doc.exists || doc['role'] != 'doctor') {
        await FirebaseAuth.instance.signOut();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Access denied: Only doctors may log in here')),
        );
        return;
      }

      if (!credential.user!.emailVerified) {
        await credential.user!.sendEmailVerification();
        _user = credential.user;
        setState(() {
          _mfaStep = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Verification email sent. Please verify and press Continue.')),
        );
        return;
      }

      await _onFinalLogin(credential.user!);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Login failed: ${e.toString()}')),
      );
    }
  }

  Future<void> _onFinalLogin(User user) async {
    final uid = user.uid;

    final fcmToken = await FirebaseMessaging.instance.getToken();
    if (fcmToken != null) {
      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'fcmToken': fcmToken,
      });
    }

    Navigator.pushReplacementNamed(context, '/doctor/dashboard');
  }

  Future<void> _checkVerificationAndContinue() async {
    await _user?.reload();
    final refreshedUser = FirebaseAuth.instance.currentUser;

    if (refreshedUser != null && refreshedUser.emailVerified) {
      await _onFinalLogin(refreshedUser);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Email not verified yet. Please check your inbox.')),
      );
    }
  }

  Future<void> _resetPassword() async {
    final email = _emailController.text.trim();

    if (email.isEmpty || !email.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid email.')),
      );
      return;
    }

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password reset email sent.')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5FF),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: _mfaStep
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Email Verification Required', style: TextStyle(fontSize: 18)),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _checkVerificationAndContinue,
                        child: const Text('Continue'),
                      ),
                    ],
                  )
                : Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: 16),
                        const Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Login',
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        Image.asset('assets/images/doctor_login_illustration.jpg', height: 180),
                        const SizedBox(height: 32),
                        TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: const InputDecoration(
                            prefixIcon: Icon(Icons.email_outlined),
                            hintText: 'Email',
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) =>
                              value != null && value.contains('@') ? null : 'Enter a valid email',
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _passwordController,
                          obscureText: true,
                          decoration: const InputDecoration(
                            prefixIcon: Icon(Icons.lock_outline),
                            hintText: 'Password',
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) =>
                              value != null && value.length >= 6 ? null : 'Password too short',
                        ),
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: _resetPassword,
                            child: const Text('Forgot Password?'),
                          ),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _login,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFD8BFD8),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: const Icon(Icons.arrow_forward),
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
