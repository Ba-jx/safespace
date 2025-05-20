
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
        .where('status', whereIn: ['confirmed'])
        .get();

    final Map<DateTime, List<Map<String, dynamic>>> grouped = {};
    for (var doc in snapshot.docs) {
      final data = doc.data();
      final timestamp = data['dateTime'];
      if (timestamp is Timestamp) {
        final date = DateTime(timestamp.toDate().year, timestamp.toDate().month, timestamp.toDate().day);
        grouped[date] = grouped[date] ?? [];
        grouped[date]!.add({...data, 'ref': doc.reference});
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

  void _showAppointmentDialog({Map<String, dynamic>? existing}) async {
    final doctorId = FirebaseAuth.instance.currentUser!.uid;
    final noteController = TextEditingController(text: existing?['note'] ?? '');
    String? selectedPatientId = existing?['patientId'];
    String? selectedPatientName = existing?['patientName'];
    DateTime selectedDate = existing != null
        ? (existing['dateTime'] as Timestamp).toDate()
        : (_selectedDay ?? _focusedDay);

    TimeOfDay? selectedTime;
    List<TimeOfDay> availableSlots = [];

    Future<void> _computeAvailableSlots(DateTime date) async {
      final allAppointments = _getAppointmentsForDay(date).map((appt) {
        return (appt['dateTime'] as Timestamp).toDate();
      }).toList();

      availableSlots = [];
      for (int hour = 9; hour < 17; hour++) {
        final slot = DateTime(date.year, date.month, date.day, hour);
        final hasConflict = allAppointments.any((appt) =>
            (slot.difference(appt).inMinutes).abs() < 60 &&
            (existing == null || (existing['dateTime'] as Timestamp).toDate() != appt));
        if (!hasConflict) {
          availableSlots.add(TimeOfDay(hour: hour, minute: 0));
        }
      }
    }

    await _computeAvailableSlots(selectedDate);
    if (existing != null) {
      selectedTime = TimeOfDay.fromDateTime((existing['dateTime'] as Timestamp).toDate());
    }

    final patientsSnapshot = await FirebaseFirestore.instance
        .collection('users')
        .where('role', isEqualTo: 'patient')
        .where('doctorId', isEqualTo: doctorId)
        .get();

    if (!mounted) return;

    final patients = patientsSnapshot.docs.map((doc) {
      final data = doc.data();
      return {'id': doc.id, 'name': data['name'] ?? 'Unknown'};
    }).toList();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          title: Text(existing != null ? 'Edit Appointment' : 'Create Appointment'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                existing == null
                    ? DropdownButtonFormField<String>(
                        value: selectedPatientId,
                        decoration: const InputDecoration(labelText: 'Select Patient'),
                        items: patients.map((patient) {
                          return DropdownMenuItem<String>(
                            value: patient['id'],
                            child: Text(patient['name']),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setModalState(() {
                            selectedPatientId = value;
                            selectedPatientName = patients.firstWhere((p) => p['id'] == value)['name'];
                          });
                        },
                      )
                    : Align(
                        alignment: Alignment.centerLeft,
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 12.0),
                          child: Row(
                            children: [
                              const Text('Patient:', style: TextStyle(fontWeight: FontWeight.bold)),
                              const SizedBox(width: 8),
                              Text(selectedPatientName ?? 'Unknown'),
                            ],
                          ),
                        ),
                      ),
                TextField(
                  controller: noteController,
                  decoration: const InputDecoration(labelText: 'Note'),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Text('Date:'),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: selectedDate,
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(const Duration(days: 365)),
                          selectableDayPredicate: (date) {
                          final now = DateTime.now();
                          final isPast = date.year < now.year ||
                              (date.year == now.year && date.month < now.month) ||
                              (date.year == now.year && date.month == now.month && date.day < now.day);
                          return !isPast && !_isDateFullyBooked(date);
                        },
                        );
                        if (picked != null) {
                          setModalState(() async {
                            selectedDate = picked;
                            selectedTime = null;
                            await _computeAvailableSlots(selectedDate);
                          });
                        }
                      },
                      child: Text('${selectedDate.year}-${selectedDate.month}-${selectedDate.day}'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
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
                    setModalState(() {
                      selectedTime = value;
                    });
                  },
                ),
              ],
            ),
          ),
          actions: [
            if (existing != null)
              TextButton(
                onPressed: () async {
                  await (existing['ref'] as DocumentReference).update({'status': 'cancelled'});
                  if (!mounted) return;
                  Navigator.pop(context);
                  await _fetchAppointments();
                },
                child: const Text('Delete', style: TextStyle(color: Colors.red)),
              ),
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                if ((selectedPatientId == null || selectedPatientName == null) && existing == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please select a patient')),
                  );
                  return;
                }
                if (selectedTime == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please select a time slot')),
                  );
                  return;
                }

                final dateTime = DateTime(
                  selectedDate.year,
                  selectedDate.month,
                  selectedDate.day,
                  selectedTime!.hour,
                  selectedTime!.minute,
                );

                final now = DateTime.now();
                if (dateTime.isBefore(now)) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Cannot book appointments in the past.')),
                  );
                  return;
                }

                if (dateTime.difference(DateTime.now()).inMinutes < 60) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Appointments must be scheduled at least 1 hour in advance.')),
                  );
                  return;
                }

                final data = {
                  'patientId': selectedPatientId,
                  'patientName': selectedPatientName,
                  'note': noteController.text.trim(),
                  'dateTime': Timestamp.fromDate(dateTime),
                  'doctorId': doctorId,
                  'status': 'confirmed',
                };

                if (existing != null) {
                  await (existing['ref'] as DocumentReference).update(data);
                } else {
                  await FirebaseFirestore.instance
                      .collection('users')
                      .doc(selectedPatientId!)
                      .collection('appointments')
                      .add(data);
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
      appBar: AppBar(
        title: const Text('Doctor Appointment Calendar'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12.0),
            child: ElevatedButton.icon(
              onPressed: () {
                setState(() {
                  _focusedDay = DateTime.now();
                  _selectedDay = DateTime.now();
                });
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.purple, foregroundColor: Colors.white),
              icon: const Icon(Icons.calendar_today, size: 18),
              label: const Text('Current Week'),
            ),
          ),
        ],
      ),
      floatingActionButton: (_selectedDay ?? _focusedDay).isBefore(DateTime.now())
          ? null
          : FloatingActionButton(
        onPressed: _showAppointmentDialog,
        backgroundColor: Colors.purple,
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          TableCalendar(
            firstDay: DateTime.utc(2024, 1, 1),
            lastDay: DateTime.utc(2030, 12, 31),
            focusedDay: _focusedDay,
            selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
            onDaySelected: (selectedDay, focusedDay) async {
              if (_isDateFullyBooked(selectedDay)) return;
              setState(() {
                _selectedDay = selectedDay;
                _focusedDay = focusedDay;
              });
              await _fetchAppointments();
            },
            enabledDayPredicate: (day) => !_isDateFullyBooked(day),
            eventLoader: _getAppointmentsForDay,
            availableCalendarFormats: const {CalendarFormat.month: 'Month'},
            headerStyle: const HeaderStyle(formatButtonVisible: false),
            calendarBuilders: CalendarBuilders(
              markerBuilder: (context, date, events) {
                final statuses = events.map((e) => (e as Map<String, dynamic>)['status'] ?? '').toSet();
                return Positioned(
                  bottom: 1,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: statuses.map((status) {
                      Color color;
                      switch (status) {
                        case 'confirmed': color = Colors.green; break;
                        case 'rescheduled': color = Colors.blue; break;
                        default: color = Colors.grey;
                      }
                      return Container(
                        margin: const EdgeInsets.symmetric(horizontal: 1.5),
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                      );
                    }).toList(),
                  ),
                );
              },
            ),
            calendarStyle: const CalendarStyle(markerDecoration: BoxDecoration(shape: BoxShape.circle)),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: appointments.isEmpty
                ? const Center(child: Text('No appointments on this day.'))
                : ListView(
                    children: appointments.map((appt) {
                      final name = appt['patientName'] ?? 'Unknown';
                      final note = appt['note'] ?? '';
                      final time = (appt['dateTime'] as Timestamp).toDate();
                      final status = appt['status'] ?? 'unknown';

                      return ListTile(
                        title: Text(name),
                        subtitle: Text(
                          '${TimeOfDay.fromDateTime(time).format(context)} - $note  •  ${status.toUpperCase()}',
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                        onTap: () => _showAppointmentDialog(existing: appt),
                      );
                    }).toList(),
                  ),
          ),
        ],
      ),
    );
  }
}
