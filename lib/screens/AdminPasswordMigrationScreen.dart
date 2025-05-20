import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';

class AdminPasswordMigrationScreen extends StatefulWidget {
  const AdminPasswordMigrationScreen({super.key});

  @override
  State<AdminPasswordMigrationScreen> createState() => _AdminPasswordMigrationScreenState();
}

class _AdminPasswordMigrationScreenState extends State<AdminPasswordMigrationScreen> {
  bool _isMigrating = false;
  int _updatedCount = 0;

  Future<void> hashExistingPasswords() async {
    setState(() {
      _isMigrating = true;
      _updatedCount = 0;
    });

    final usersRef = FirebaseFirestore.instance.collection('users');
    final snapshot = await usersRef.get();

    int updated = 0;

    for (final doc in snapshot.docs) {
      final data = doc.data();
      final userId = doc.id;

      if (data.containsKey('password') && data['password'] is String) {
        final plainPassword = data['password'];
        final hashedPassword = sha256.convert(utf8.encode(plainPassword)).toString();

        await usersRef.doc(userId).update({
          'hashedPassword': hashedPassword,
          'password': FieldValue.delete(),
        });

        updated++;
        print('✅ Updated $userId');
      }
    }

    setState(() {
      _isMigrating = false;
      _updatedCount = updated;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Migration complete. $updated users updated.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Admin Password Migration')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'This will hash all plaintext passwords in Firestore and remove the original field.',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _isMigrating ? null : hashExistingPasswords,
              child: _isMigrating
                  ? const CircularProgressIndicator()
                  : const Text('Run Migration'),
            ),
            const SizedBox(height: 16),
            if (_updatedCount > 0)
              Text(
                '✅ $_updatedCount accounts updated.',
                style: const TextStyle(fontSize: 16, color: Colors.green),
              ),
          ],
        ),
      ),
    );
  }
}
