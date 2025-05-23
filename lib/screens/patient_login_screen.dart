import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../providers/user_provider.dart';

class PatientLoginScreen extends StatefulWidget {
  const PatientLoginScreen({super.key});

  @override
  State<PatientLoginScreen> createState() => _PatientLoginScreenState();
}

class _PatientLoginScreenState extends State<PatientLoginScreen> {
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

      if (!doc.exists || doc['role'] != 'patient') {
        await FirebaseAuth.instance.signOut();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Access denied: Only patients may log in here')),
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
          const SnackBar(content: Text('Verification email sent. Please check and click Continue.')),
        );
        return;
      }

      await _onFinalLogin(credential.user!);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Login failed: $e')),
      );
    }
  }

  Future<void> _onFinalLogin(User user) async {
    final uid = user.uid;
    final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();

    final name = doc.data()?['name'] ?? 'User';
    Provider.of<UserProvider>(context, listen: false).setUserName(name);

    final token = await FirebaseMessaging.instance.getToken();
    if (token != null) {
      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'fcmToken': token,
      });
    }

    Navigator.pushReplacementNamed(context, '/home');
  }

  Future<void> _checkVerificationAndContinue() async {
    await _user?.reload();
    final refreshedUser = FirebaseAuth.instance.currentUser;

    if (refreshedUser != null && refreshedUser.emailVerified) {
      await _onFinalLogin(refreshedUser);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Email not verified yet.')),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF1C152D) : const Color(0xFFF5F3F8),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: isDark ? Colors.white : const Color(0xFF5A4E8C)),
          onPressed: () => Navigator.pushReplacementNamed(context, '/role-selection'),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: _mfaStep
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Email Verification Required',
                        style: TextStyle(
                            fontSize: 18,
                            color: isDark ? Colors.white : const Color(0xFF5A4E8C)),
                      ),
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
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.asset(
                            'assets/images/safe_space_logo1.png',
                            height: 300,
                            fit: BoxFit.contain,
                          ),
                        ),
                        const SizedBox(height: 24),
                        TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                          decoration: InputDecoration(
                            prefixIcon: const Icon(Icons.email_outlined, color: Color(0xFFD4C2F2)),
                            hintText: 'Patient Email',
                            hintStyle:
                                TextStyle(color: isDark ? Colors.grey[300] : Colors.black54),
                            border: const OutlineInputBorder(),
                          ),
                          validator: (value) =>
                              value != null && value.contains('@') ? null : 'Invalid email',
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _passwordController,
                          obscureText: true,
                          style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                          decoration: InputDecoration(
                            prefixIcon: const Icon(Icons.lock_outline, color: Color(0xFFD4C2F2)),
                            hintText: 'Password',
                            hintStyle:
                                TextStyle(color: isDark ? Colors.grey[300] : Colors.black54),
                            border: const OutlineInputBorder(),
                          ),
                          validator: (value) =>
                              value != null && value.length >= 6 ? null : 'Password too short',
                        ),
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: _resetPassword,
                            child: const Text(
                              'Forgot Password?',
                              style: TextStyle(color: Color(0xFFB9A6E8)),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        ElevatedButton(
                          onPressed: _login,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF8C6DE8),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: const Text(
                            'Login',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
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
