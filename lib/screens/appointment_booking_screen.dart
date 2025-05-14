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
  List<TimeOfDay> availableSlots = [];

  Future<void> _pickDate() async {
    final today = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: today,
      firstDate: today,
      lastDate: today.add(const Duration(days: 30)),
    );
    if (picked != null) {
      setState(() {
        selectedDate = picked;
        selectedTime = null;
        availableSlots = [];
      });
      await _loadAvailableSlots(picked);
    }
  }

  Future<void> _loadAvailableSlots(DateTime day) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    final doctorId = userDoc.data()?['doctorId'];
    if (doctorId == null) return;

    final startOfDay = DateTime(day.year, day.month, day.day, 0, 0);
    final endOfDay = DateTime(day.year, day.month, day.day, 23, 59);

    final snapshot = await FirebaseFirestore.instance
        .collectionGroup('appointments')
        .where('doctorId', isEqualTo: doctorId)
        .where('status', isEqualTo: 'confirmed')
        .where('dateTime', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
        .where('dateTime', isLessThanOrEqualTo: Timestamp.fromDate(endOfDay))
        .get();

    final bookedTimes = snapshot.docs
        .map((doc) => (doc['dateTime'] as Timestamp).toDate())
        .toList();

    final List<TimeOfDay> slots = [];
    for (int hour = 9; hour < 17; hour++) {
      final slotDateTime = DateTime(day.year, day.month, day.day, hour);
      final conflict = bookedTimes.any((booked) =>
          (slotDateTime.difference(booked).inMinutes).abs() < 60);
      if (!conflict) {
        slots.add(TimeOfDay(hour: hour, minute: 0));
      }
    }

    setState(() {
      availableSlots = slots;
    });
  }

  Future<void> _submitAppointment() async {
    if (selectedDate == null || selectedTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select both date and time.')),
      );
      return;
    }

    final dateTime = DateTime(
      selectedDate!.year,
      selectedDate!.month,
      selectedDate!.day,
      selectedTime!.hour,
      selectedTime!.minute,
    );

    if (dateTime.difference(DateTime.now()).inHours < 12) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Appointments must be booked at least 12 hours in advance.')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception("User not logged in");

      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      final doctorId = userDoc.data()?['doctorId'];
      final patientName = userDoc.data()?['name'];

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('appointments')
          .add({
        'dateTime': Timestamp.fromDate(dateTime),
        'note': _noteController.text.trim(),
        'createdAt': Timestamp.now(),
        'doctorId': doctorId,
        'patientName': patientName,
        'status': 'pending',
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Appointment booked successfully')),
      );

      setState(() {
        selectedDate = null;
        selectedTime = null;
        availableSlots = [];
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
            if (availableSlots.isNotEmpty)
              DropdownButton<TimeOfDay>(
                value: selectedTime,
                hint: const Text('Select Available Time'),
                items: availableSlots
                    .map((slot) => DropdownMenuItem(
                          value: slot,
                          child: Text(slot.format(context)),
                        ))
                    .toList(),
                onChanged: (value) {
                  setState(() => selectedTime = value);
                },
              )
            else if (selectedDate != null)
              const Padding(
                padding: EdgeInsets.all(8),
                child: Text('No available time slots for this day.'),
              ),
            const SizedBox(height: 12),
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
