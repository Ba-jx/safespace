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

  String? doctorId;
  Map<DateTime, int> _appointmentCounts = {};

  @override
  void initState() {
    super.initState();
    _fetchDoctorAndAppointments();
  }

  Future<void> _fetchDoctorAndAppointments() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    doctorId = userDoc.data()?['doctorId'];

    if (doctorId == null) return;

    final snapshot = await FirebaseFirestore.instance
        .collectionGroup('appointments')
        .where('doctorId', isEqualTo: doctorId)
        .where('status', isEqualTo: 'confirmed')
        .get();

    final Map<DateTime, int> counts = {};
    for (var doc in snapshot.docs) {
      final timestamp = doc['dateTime'];
      if (timestamp is Timestamp) {
        final dt = timestamp.toDate();
        final date = DateTime(dt.year, dt.month, dt.day);
        counts[date] = (counts[date] ?? 0) + 1;
      }
    }

    setState(() {
      _appointmentCounts = counts;
    });
  }

  bool _isDateFullyBooked(DateTime date) {
    final day = DateTime(date.year, date.month, date.day);
    return (_appointmentCounts[day] ?? 0) >= 8;
  }

  Future<void> _pickDate() async {
    final today = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: today,
      firstDate: today,
      lastDate: today.add(const Duration(days: 30)),
      selectableDayPredicate: (day) => !_isDateFullyBooked(day),
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

      final docRef = FirebaseFirestore.instance.collection('users').doc(user.uid);
      final userDoc = await docRef.get();
      final patientName = userDoc.data()?['name'];

      final startWindow = dateTime.subtract(const Duration(hours: 1));
      final endWindow = dateTime.add(const Duration(hours: 1));

      final conflictQuery = await FirebaseFirestore.instance
          .collectionGroup('appointments')
          .where('doctorId', isEqualTo: doctorId)
          .where('dateTime', isGreaterThanOrEqualTo: Timestamp.fromDate(startWindow))
          .where('dateTime', isLessThanOrEqualTo: Timestamp.fromDate(endWindow))
          .get();

      if (conflictQuery.docs.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('The selected time conflicts with an existing appointment. Try another time.')),
        );
        return;
      }

      await docRef.collection('appointments').add({
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
        _noteController.clear();
      });

      await _fetchDoctorAndAppointments(); // Refresh after booking
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
