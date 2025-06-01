import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:convert';
import 'package:crypto/crypto.dart';

class DoctorCreatesPatientScreen extends StatefulWidget {
  const DoctorCreatesPatientScreen({super.key});

  @override
  State<DoctorCreatesPatientScreen> createState() => _DoctorCreatesPatientScreenState();
}

class _DoctorCreatesPatientScreenState extends State<DoctorCreatesPatientScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _doctorPasswordController = TextEditingController();

  bool _isLoading = false;

  Future<void> _createPatientAccount() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final currentDoctor = FirebaseAuth.instance.currentUser!;
      final doctorEmail = currentDoctor.email!;
      final doctorPassword = _doctorPasswordController.text.trim();

      final userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      final hashedPassword = sha256
          .convert(utf8.encode(_passwordController.text.trim()))
          .toString();

      await FirebaseFirestore.instance
          .collection('users')
          .doc(userCredential.user!.uid)
          .set({
        'name': _nameController.text.trim(),
        'email': _emailController.text.trim(),
        'role': 'patient',
        'doctorId': currentDoctor.uid,
        'hashedPassword': hashedPassword,
        'generatedPassword': _passwordController.text.trim(),
      });

      await FirebaseAuth.instance.signOut();

      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: doctorEmail,
        password: doctorPassword,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Patient account created successfully')),
      );

      _formKey.currentState!.reset();
      _nameController.clear();
      _emailController.clear();
      _passwordController.clear();
      _doctorPasswordController.clear();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to create account: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Patient Account')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              const Text(
                'Enter Patient Details',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Patient Name',
                  border: OutlineInputBorder(),
                ),
                validator: (value) =>
                    value == null || value.isEmpty ? 'Enter a name' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.emailAddress,
                validator: (value) =>
                    value == null || !value.contains('@') ? 'Enter valid email' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _passwordController,
                decoration: const InputDecoration(
                  labelText: 'Patient Password',
                  border: OutlineInputBorder(),
                ),
                obscureText: true,
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Enter a password';
                  if (value.length < 8) return 'Must be at least 8 characters';
                  if (!RegExp(r'[A-Z]').hasMatch(value)) return 'Include an uppercase letter';
                  if (!RegExp(r'[a-z]').hasMatch(value)) return 'Include a lowercase letter';
                  if (!RegExp(r'\d').hasMatch(value)) return 'Include a number';
                  if (!RegExp(r'[!@#\$&*~%^()\-_=+{}[\]|;:"<>,.?]').hasMatch(value)) {
                    return 'Include a special character';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _doctorPasswordController,
                decoration: const InputDecoration(
                  labelText: 'Your Password (Doctor)',
                  border: OutlineInputBorder(),
                ),
                obscureText: true,
                validator: (value) => value == null || value.length < 6
                    ? 'Enter your password to confirm'
                    : null,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isLoading ? null : _createPatientAccount,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).brightness == Brightness.dark
                      ? const Color(0xFFE1D7FB)
                      : const Color(0xFF7654B9),
                  foregroundColor: Theme.of(context).brightness == Brightness.dark
                      ? Colors.black87
                      : Colors.white,
                  textStyle: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  elevation: 4,
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      )
                    : const Text('Create Account'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
