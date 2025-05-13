import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AppointmentBookingScreen extends StatefulWidget {
  const AppointmentBookingScreen({super.key});

  @override
  State<AppointmentBookingScreen> createState() => _AppointmentBookingScreenState();
}

class _AppointmentBookingScreenState extends State<AppointmentBookingScreen> {
  DateTime? selectedDate;
  TimeOfDay? selectedTime;
  final TextEditingController _noteController = TextEditingController();
  bool _isSubmitting = false;

  Future<void> _pickDate() async {
    final today = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: today,
      firstDate: today,
      lastDate: today.add(const Duration(days: 30)),
    );
    if (picked != null) {
      setState(() => selectedDate = picked);
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (picked != null) {
      setState(() => selectedTime = picked);
    }
  }

  Future<void> _submitAppointment() async {
    if (selectedDate == null || selectedTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select both date and time.')),
      );
      return;
    }

    final DateTime dateTime = DateTime(
      selectedDate!.year,
      selectedDate!.month,
      selectedDate!.day,
      selectedTime!.hour,
      selectedTime!.minute,
    );

    // 🔒 Block appointments scheduled less than 24 hours from now
    if (dateTime.difference(DateTime.now()).inHours < 24) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Appointments must be booked at least 24 hours in advance.')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception("User not logged in");

      final startWindow = dateTime.subtract(const Duration(hours: 2));
      final endWindow = dateTime.add(const Duration(hours: 2));

      final docRef = FirebaseFirestore.instance.collection('users').doc(user.uid);
      final userDoc = await docRef.get();
      final assignedDoctorId = userDoc.data()?['doctorId'];
      final patientName = userDoc.data()?['name'];

      final conflictQuery = await FirebaseFirestore.instance
          .collectionGroup('appointments')
          .where('doctorId', isEqualTo: assignedDoctorId)
          .where('dateTime', isGreaterThanOrEqualTo: Timestamp.fromDate(startWindow))
          .where('dateTime', isLessThanOrEqualTo: Timestamp.fromDate(endWindow))
          .get();

      if (conflictQuery.docs.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('The selected time conflicts with an existing appointment.')),
        );
        return;
      }

      await docRef.collection('appointments').add({
        'dateTime': Timestamp.fromDate(dateTime),
        'note': _noteController.text.trim(),
        'createdAt': Timestamp.now(),
        'doctorId': assignedDoctorId,
        'patientName': patientName,
        'status': 'pending',
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Appointment booked successfully')),
      );

      setState(() {
        selectedDate = null;
        selectedTime = null;
        _noteController.clear();
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error booking appointment: $e')),
      );
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final formattedDate = selectedDate != null
        ? DateFormat('yyyy-MM-dd').format(selectedDate!)
        : 'Select Date';
    final formattedTime = selectedTime != null
        ? selectedTime!.format(context)
        : 'Select Time';

    return Scaffold(
      appBar: AppBar(title: const Text('Book Appointment')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            ListTile(
              title: const Text('Date'),
              subtitle: Text(formattedDate),
              trailing: const Icon(Icons.calendar_today),
              onTap: _pickDate,
            ),
            ListTile(
              title: const Text('Time'),
              subtitle: Text(formattedTime),
              trailing: const Icon(Icons.access_time),
              onTap: _pickTime,
            ),
            TextField(
              controller: _noteController,
              decoration: const InputDecoration(
                labelText: 'Additional Notes',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _isSubmitting ? null : _submitAppointment,
              child: _isSubmitting
                  ? const CircularProgressIndicator()
                  : const Text('Book Appointment'),
            ),
          ],
        ),
      ),
    );
  }
}
