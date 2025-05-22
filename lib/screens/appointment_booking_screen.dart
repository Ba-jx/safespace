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
  Map<DateTime, List<DateTime>> _doctorAppointments = {};
  List<TimeOfDay> availableSlots = [];

  @override
  void initState() {
    super.initState();
    _fetchDoctorAppointments();
  }

  Future<void> _fetchDoctorAppointments() async {
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

    final Map<DateTime, List<DateTime>> grouped = {};
    for (var doc in snapshot.docs) {
      final ts = doc['dateTime'];
      if (ts is Timestamp) {
        final dt = ts.toDate();
        final date = DateTime(dt.year, dt.month, dt.day);
        grouped[date] = grouped[date] ?? [];
        grouped[date]!.add(dt);
      }
    }

    setState(() {
      _doctorAppointments = grouped;
    });
  }

  bool _isDateFullyBooked(DateTime date) {
    final day = DateTime(date.year, date.month, date.day);
    return (_doctorAppointments[day]?.length ?? 0) >= 8;
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 30)),
      selectableDayPredicate: (day) => !_isDateFullyBooked(day),
    );

    if (picked != null) {
      setState(() {
        selectedDate = picked;
        selectedTime = null;
        _computeAvailableSlots(picked);
      });
    }
  }

  void _computeAvailableSlots(DateTime day) {
    final now = DateTime.now();
    final booked = _doctorAppointments[DateTime(day.year, day.month, day.day)] ?? [];
    availableSlots = [];

    for (int hour = 9; hour < 17; hour++) {
      final slot = DateTime(day.year, day.month, day.day, hour);

      if (day.year == now.year && day.month == now.month && day.day == now.day) {
        if (slot.isBefore(now.add(const Duration(minutes: 1)))) continue;
      }

      final hasConflict = booked.any((appt) => (slot.difference(appt).inMinutes).abs() < 60);
      if (!hasConflict) {
        availableSlots.add(TimeOfDay(hour: hour, minute: 0));
      }
    }
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

      final docRef = FirebaseFirestore.instance.collection('users').doc(user.uid);
      final userDoc = await docRef.get();
      final patientName = userDoc.data()?['name'];

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

      await _fetchDoctorAppointments();
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

    final isDark = Theme.of(context).brightness == Brightness.dark;

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
            DropdownButtonFormField<TimeOfDay>(
              value: selectedTime,
              decoration: const InputDecoration(labelText: 'Available Time Slots'),
              items: availableSlots.map((slot) {
                return DropdownMenuItem(
                  value: slot,
                  child: Text(slot.format(context)),
                );
              }).toList(),
              onChanged: (value) {
                setState(() => selectedTime = value);
              },
            ),
            const SizedBox(height: 16),
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
              style: ElevatedButton.styleFrom(
                backgroundColor: isDark
                    ? const Color(0xFFD6C8FA)
                    : const Color(0xFF7A6EDB),
                foregroundColor: isDark ? Colors.black : Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
              child: _isSubmitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text(
                      'Book Appointment',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
