
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

  @override
  void initState() {
    super.initState();
    _fetchConfirmedAppointments();
  }

  Future<void> _fetchConfirmedAppointments() async {
  final doctorId = FirebaseAuth.instance.currentUser?.uid;
  if (doctorId == null) {
    print('❌ Doctor ID is null');
    return;
  }

  print('🔍 Fetching appointments for doctorId: $doctorId');

  try {
    final snapshot = await FirebaseFirestore.instance
        .collectionGroup('appointments')
        .where('doctorId', isEqualTo: doctorId)
        .where('status', isEqualTo: 'confirmed')
        .get();

    final Map<DateTime, List<Map<String, dynamic>>> grouped = {};

    print('📦 Fetched ${snapshot.docs.length} confirmed appointments');

    for (var doc in snapshot.docs) {
      final data = doc.data();
      final timestamp = data['dateTime'];

      print('➡️ Document: ${doc.id}, Data: $data');

      if (timestamp is Timestamp) {
        final date = DateTime(
            timestamp.toDate().year, timestamp.toDate().month, timestamp.toDate().day);
        grouped[date] = grouped[date] ?? [];
        grouped[date]!.add({...data, 'docId': doc.id, 'ref': doc.reference});
      } else {
        print('⚠️ Skipping doc ${doc.id}, invalid dateTime: $timestamp');
      }
    }

    if (!mounted) return;
    setState(() {
      _appointmentsByDate = grouped;
    });
  } catch (e) {
    print('❌ Error loading appointments: $e');
  }
}    }

    if (!mounted) return;
    setState(() {
      _appointmentsByDate = grouped;
    });
  }

  List<Map<String, dynamic>> _getAppointmentsForDay(DateTime day) {
    final date = DateTime(day.year, day.month, day.day);
    return _appointmentsByDate[date] ?? [];
  }

  void _showAppointmentDialog({DateTime? defaultDate, Map<String, dynamic>? existing}) async {
    final doctorId = FirebaseAuth.instance.currentUser!.uid;

    final noteController = TextEditingController(text: existing?['note'] ?? '');
    String? patientId = existing?['patientId'];
    String? patientName = existing?['patientName'];

    TimeOfDay selectedTime = existing != null
        ? TimeOfDay.fromDateTime((existing['dateTime'] as Timestamp).toDate())
        : const TimeOfDay(hour: 9, minute: 0);

    final patientsSnapshot = await FirebaseFirestore.instance
        .collection('users')
        .where('role', isEqualTo: 'patient')
        .where('doctorId', isEqualTo: doctorId)
        .get();

    if (!mounted) return;

    final patients = patientsSnapshot.docs.map((doc) {
      final data = doc.data();
      return {
        'id': doc.id,
        'name': data['name'] ?? 'Unknown',
        'email': data['email'],
        'age': data['age'],
      };
    }).toList();

    Map<String, dynamic>? patientProfile;
    if (patientId != null) {
      patientProfile = patients.firstWhere((p) => p['id'] == patientId, orElse: () => {});
    }

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          title: Text(existing != null ? 'Edit Appointment' : 'Create Appointment'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if ((patientProfile ?? {}).isNotEmpty) ...[
                  const Text('Patient Info', style: TextStyle(fontWeight: FontWeight.bold)),
                  Text('Name: ${patientProfile?['name'] ?? 'N/A'}'),
                  Text('Email: ${patientProfile?['email'] ?? 'N/A'}'),
                  if (patientProfile?['age'] != null) Text('Age: ${patientProfile?['age']}'),
                  const Divider(),
                ],
                DropdownButtonFormField<String>(
                  value: patientId,
                  decoration: const InputDecoration(labelText: 'Select Patient'),
                  items: patients.map((patient) {
                    return DropdownMenuItem<String>(
                      value: patient['id'],
                      child: Text(patient['name']),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setModalState(() {
                      patientId = value;
                      patientProfile = patients.firstWhere((p) => p['id'] == value);
                      patientName = patientProfile?['name'];
                    });
                  },
                ),
                TextField(
                  controller: noteController,
                  decoration: const InputDecoration(labelText: 'Note'),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Text('Time:'),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () async {
                        final picked = await showTimePicker(context: context, initialTime: selectedTime);
                        if (picked != null) {
                          setModalState(() {
                            selectedTime = picked;
                          });
                        }
                      },
                      child: Text(selectedTime.format(context)),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            if (existing != null)
              TextButton(
                onPressed: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Delete Appointment'),
                      content: const Text('Are you sure you want to delete this appointment?'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                        TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
                      ],
                    ),
                  );
                  if (confirm == true) {
                    await (existing['ref'] as DocumentReference).delete();
                    if (!mounted) return;
                    Navigator.pop(context);
                    await _fetchConfirmedAppointments();
                  }
                },
                child: const Text('Delete', style: TextStyle(color: Colors.red)),
              ),
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                if (patientId == null || patientName == null) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please select a patient')),
                  );
                  return;
                }

                final selectedDate = defaultDate ?? _selectedDay ?? DateTime.now();
                final dateTime = DateTime(
                  selectedDate.year,
                  selectedDate.month,
                  selectedDate.day,
                  selectedTime.hour,
                  selectedTime.minute,
                );

                final data = {
                  'patientName': patientName,
                  'patientId': patientId,
                  'note': noteController.text.trim(),
                  'dateTime': Timestamp.fromDate(dateTime),
                  'status': 'confirmed',
                  'doctorId': doctorId,
                };

                if (existing != null) {
                  await (existing['ref'] as DocumentReference).update(data);
                } else {
                  await FirebaseFirestore.instance
                      .collection('users')
                      .doc(patientId!)
                      .collection('appointments')
                      .add(data);
                }

                if (!mounted) return;
                Navigator.pop(context);
                await _fetchConfirmedAppointments();
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
      appBar: AppBar(title: const Text('Doctor Appointment Calendar')),
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
            calendarStyle: const CalendarStyle(
              markerDecoration: BoxDecoration(color: Colors.purple, shape: BoxShape.circle),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView(
              children: appointments.map((appt) {
                final patientName = appt['patientName'] ?? 'Unknown';
                final note = appt['note'] ?? '';
                final time = (appt['dateTime'] as Timestamp).toDate();

                return ListTile(
                  title: Text(patientName),
                  subtitle: Text('${TimeOfDay.fromDateTime(time).format(context)} - $note'),
                  leading: const Icon(Icons.event_available),
                  onTap: () => _showAppointmentDialog(existing: appt),
                );
              }).toList(),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAppointmentDialog(defaultDate: _selectedDay ?? _focusedDay),
        child: const Icon(Icons.add),
        backgroundColor: Colors.purple,
      ),
    );
  }
}
