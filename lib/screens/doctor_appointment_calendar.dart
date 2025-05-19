// DoctorAppointmentCalendar - Final Complete Version

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:table_calendar/table_calendar.dart';

class DoctorAppointmentCalendar extends StatefulWidget {
  const DoctorAppointmentCalendar({super.key});

  @override
  State<DoctorAppointmentCalendar> createState() => _DoctorAppointmentCalendarState();
}

class _DoctorAppointmentCalendarState extends State<DoctorAppointmentCalendar> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  Map<DateTime, List<Map<String, dynamic>>> _appointmentsByDate = {};
  List<DocumentSnapshot> _patients = [];

  @override
  void initState() {
    super.initState();
    _fetchAppointments();
    _fetchPatients();
  }

  Future<void> _fetchPatients() async {
    final doctorId = FirebaseAuth.instance.currentUser?.uid;
    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .where('role', isEqualTo: 'patient')
        .where('doctorId', isEqualTo: doctorId)
        .get();
    setState(() {
      _patients = snapshot.docs;
    });
  }

  Future<void> _fetchAppointments() async {
    final doctorId = FirebaseAuth.instance.currentUser?.uid;
    if (doctorId == null) return;

    final snapshot = await FirebaseFirestore.instance
        .collectionGroup('appointments')
        .where('doctorId', isEqualTo: doctorId)
        .where('status', whereIn: ['confirmed', 'pending', 'rescheduled'])
        .get();

    final Map<DateTime, List<Map<String, dynamic>>> grouped = {};
    for (var doc in snapshot.docs) {
      final data = doc.data();
      final timestamp = data['dateTime'];
      if (timestamp is Timestamp) {
        final date = DateTime(timestamp.toDate().year, timestamp.toDate().month, timestamp.toDate().day);
        grouped[date] = grouped[date] ?? [];
        grouped[date]!.add({...data, 'docId': doc.id, 'ref': doc.reference});
      }
    }

    if (!mounted) return;
    setState(() {
      _appointmentsByDate = grouped;
    });
  }

  List<Map<String, dynamic>> _getAppointmentsForDay(DateTime day) {
    final date = DateTime(day.year, day.month, day.day);
    return _appointmentsByDate[date] ?? [];
  }

  bool _isDateFullyBooked(DateTime date) {
    final day = DateTime(date.year, date.month, date.day);
    return (_appointmentsByDate[day]?.length ?? 0) >= 8;
  }

  bool _canAddAppointmentForSelectedDay() {
    final now = DateTime.now();
    final selected = _selectedDay ?? _focusedDay;
    final selectedDateOnly = DateTime(selected.year, selected.month, selected.day);
    final nowDateOnly = DateTime(now.year, now.month, now.day);
    return selectedDateOnly.isAfter(nowDateOnly) || (selectedDateOnly.isAtSameMomentAs(nowDateOnly) && now.hour < 17);
  }

  Future<void> _showAddAppointmentDialog() async {
    final doctorId = FirebaseAuth.instance.currentUser?.uid;
    if (doctorId == null || _patients.isEmpty) return;

    DocumentSnapshot? selectedPatient = _patients.first;
    DateTime selectedDate = _selectedDay ?? _focusedDay;
    final noteController = TextEditingController();

    final existingTimes = _getAppointmentsForDay(selectedDate)
        .where((appt) => appt['status'] == 'confirmed')
        .map((appt) => (appt['dateTime'] as Timestamp).toDate().hour)
        .toSet();

    final availableSlots = List.generate(8, (i) => 9 + i).where((h) => !existingTimes.contains(h)).toList();
    TimeOfDay? selectedTime = availableSlots.isNotEmpty ? TimeOfDay(hour: availableSlots.first, minute: 0) : null;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          title: const Text('Add Appointment'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButton<DocumentSnapshot>(
                value: selectedPatient,
                isExpanded: true,
                onChanged: (val) => setModalState(() => selectedPatient = val),
                items: _patients.map((doc) => DropdownMenuItem(value: doc, child: Text(doc['name']))).toList(),
              ),
              ListTile(
                title: const Text('Date'),
                subtitle: Text('${selectedDate.toLocal()}'.split(' ')[0]),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: selectedDate,
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (picked != null) setModalState(() => selectedDate = picked);
                },
              ),
              if (availableSlots.isNotEmpty)
                DropdownButton<TimeOfDay>(
                  value: selectedTime,
                  isExpanded: true,
                  items: availableSlots.map((h) => DropdownMenuItem(
                    value: TimeOfDay(hour: h, minute: 0),
                    child: Text(TimeOfDay(hour: h, minute: 0).format(context)),
                  )).toList(),
                  onChanged: (val) => setModalState(() => selectedTime = val),
                )
              else const Text('No available slots for this day'),
              TextField(controller: noteController, decoration: const InputDecoration(labelText: 'Note')),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: selectedTime == null ? null : () async {
                final newDateTime = DateTime(
                  selectedDate.year,
                  selectedDate.month,
                  selectedDate.day,
                  selectedTime!.hour,
                  selectedTime!.minute,
                );
                final patientId = selectedPatient!.id;

                await FirebaseFirestore.instance
                    .collection('users')
                    .doc(patientId)
                    .collection('appointments')
                    .add({
                  'doctorId': doctorId,
                  'patientId': patientId,
                  'patientName': selectedPatient['name'],
                  'status': 'confirmed',
                  'note': noteController.text.trim(),
                  'dateTime': Timestamp.fromDate(newDateTime),
                });

                if (!mounted) return;
                Navigator.pop(context);
                await _fetchAppointments();
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
