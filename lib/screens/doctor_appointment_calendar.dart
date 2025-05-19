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
        final date = DateTime(
          timestamp.toDate().year,
          timestamp.toDate().month,
          timestamp.toDate().day,
        );
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
    if (selectedDateOnly.isAfter(nowDateOnly)) return true;
    if (selectedDateOnly.isAtSameMomentAs(nowDateOnly) && now.hour < 17) return true;
    return false;
  }

  Future<List<TimeOfDay>> _getAvailableTimeSlots(DateTime day) async {
    final doctorId = FirebaseAuth.instance.currentUser?.uid;
    if (doctorId == null) return [];

    final dayStart = DateTime(day.year, day.month, day.day, 9);
    final dayEnd = DateTime(day.year, day.month, day.day, 17);

    final snapshot = await FirebaseFirestore.instance
        .collectionGroup('appointments')
        .where('doctorId', isEqualTo: doctorId)
        .where('status', isEqualTo: 'confirmed')
        .where('dateTime', isGreaterThanOrEqualTo: Timestamp.fromDate(dayStart))
        .where('dateTime', isLessThan: Timestamp.fromDate(dayEnd))
        .get();

    final bookedHours = snapshot.docs.map((doc) {
      final date = (doc['dateTime'] as Timestamp).toDate();
      return TimeOfDay(hour: date.hour, minute: 0);
    }).toSet();

    return List.generate(8, (i) => TimeOfDay(hour: 9 + i, minute: 0))
        .where((slot) => !bookedHours.contains(slot))
        .toList();
  }

  Future<void> _showAddAppointmentDialog() async {
    final doctorId = FirebaseAuth.instance.currentUser?.uid;
    if (doctorId == null || _patients.isEmpty) return;

    DocumentSnapshot? selectedPatient = _patients.first;
    DateTime selectedDate = _selectedDay ?? _focusedDay;
    final noteController = TextEditingController();
    TimeOfDay? selectedTime;
    List<TimeOfDay> availableSlots = await _getAvailableTimeSlots(selectedDate);

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
                items: _patients.map((doc) {
                  final name = doc['name'] ?? 'Unnamed';
                  return DropdownMenuItem(
                    value: doc,
                    child: Text(name),
                  );
                }).toList(),
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
                  if (picked != null) {
                    final slots = await _getAvailableTimeSlots(picked);
                    setModalState(() {
                      selectedDate = picked;
                      availableSlots = slots;
                      selectedTime = null;
                    });
                  }
                },
              ),
              DropdownButton<TimeOfDay>(
                hint: const Text("Select Time"),
                value: selectedTime,
                isExpanded: true,
                items: availableSlots.map((slot) {
                  return DropdownMenuItem(
                    value: slot,
                    child: Text(slot.format(context)),
                  );
                }).toList(),
                onChanged: (val) => setModalState(() => selectedTime = val!),
              ),
              TextField(
                controller: noteController,
                decoration: const InputDecoration(labelText: 'Note'),
              ),
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

                final existing = await FirebaseFirestore.instance
                    .collection('users')
                    .doc(patientId)
                    .collection('appointments')
                    .where('doctorId', isEqualTo: doctorId)
                    .where('dateTime', isEqualTo: Timestamp.fromDate(newDateTime))
                    .get();

                if (existing.docs.isEmpty) {
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
                }

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

  @override
  Widget build(BuildContext context) {
    final appointments = _getAppointmentsForDay(_selectedDay ?? _focusedDay);
    return Scaffold(
      appBar: AppBar(title: const Text('Appointments Calendar')),
      floatingActionButton: _canAddAppointmentForSelectedDay()
          ? FloatingActionButton.extended(
              onPressed: _showAddAppointmentDialog,
              icon: const Icon(Icons.add),
              label: const Text('Add Appointment'),
              backgroundColor: Colors.purple,
            )
          : null,
      body: Column(
        children: [
          TableCalendar(
            firstDay: DateTime.utc(2024, 1, 1),
            lastDay: DateTime.utc(2030, 12, 31),
            focusedDay: _focusedDay,
            selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
            onDaySelected: (selectedDay, focusedDay) {
              setState(() {
                _selectedDay = selectedDay;
                _focusedDay = focusedDay;
              });
            },
            eventLoader: _getAppointmentsForDay,
          ),
          Expanded(
            child: ListView.builder(
              itemCount: appointments.length,
              itemBuilder: (context, index) {
                final appt = appointments[index];
                final time = (appt['dateTime'] as Timestamp).toDate();
                return ListTile(
                  title: Text(appt['patientName'] ?? 'Unknown'),
                  subtitle: Text('${TimeOfDay.fromDateTime(time).format(context)} • ${appt['note'] ?? ''}'),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
