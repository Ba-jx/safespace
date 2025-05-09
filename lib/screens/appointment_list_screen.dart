import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';

class PatientAppointmentCalendar extends StatefulWidget {
  const PatientAppointmentCalendar({super.key});

  @override
  State<PatientAppointmentCalendar> createState() =>
      _PatientAppointmentCalendarState();
}

class _PatientAppointmentCalendarState
    extends State<PatientAppointmentCalendar> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  Map<DateTime, List<Map<String, dynamic>>> _appointmentsByDate = {};

  @override
  void initState() {
    super.initState();
    _fetchAllAppointments();
  }

  Future<void> _fetchAllAppointments() async {
    final patientId = FirebaseAuth.instance.currentUser?.uid;
    if (patientId == null) return;

    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(patientId)
        .collection('appointments')
        .orderBy('dateTime')
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
        grouped[date]!.add({...data, 'docId': doc.id});
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

  Future<void> _editNote(String docId, String currentNote) async {
    final patientId = FirebaseAuth.instance.currentUser?.uid;
    final controller = TextEditingController(text: currentNote);
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Note'),
        content: TextField(controller: controller),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(context, controller.text), child: const Text('Save')),
        ],
      ),
    );

    if (result != null && patientId != null) {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(patientId)
          .collection('appointments')
          .doc(docId)
          .update({'note': result});
      await _fetchAllAppointments();
    }
  }

  Future<void> _deleteAppointment(String docId) async {
    final patientId = FirebaseAuth.instance.currentUser?.uid;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Delete'),
        content: const Text('Are you sure you want to delete this appointment?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );

    if (confirm == true && patientId != null) {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(patientId)
          .collection('appointments')
          .doc(docId)
          .delete();
      await _fetchAllAppointments();
    }
  }

  @override
  Widget build(BuildContext context) {
    final appointments = _getAppointmentsForDay(_selectedDay ?? _focusedDay);

    return Scaffold(
      appBar: AppBar(title: const Text('My Appointments')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0, top: 8),
            child: Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    _focusedDay = DateTime.now();
                    _selectedDay = DateTime.now();
                  });
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purple,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(40),
                  ),
                  elevation: 4,
                ),
                icon: const Icon(Icons.calendar_today, size: 18),
                label: const Text(
                  'Current Week',
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
              ),
            ),
          ),
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
            calendarBuilders: CalendarBuilders(
              markerBuilder: (context, date, events) {
                if (events.isNotEmpty) {
                  return Positioned(
                    bottom: 1,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: events.map((event) {
                        return Container(
                          margin: const EdgeInsets.symmetric(horizontal: 1.5),
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: Colors.purple,
                            shape: BoxShape.circle,
                          ),
                        );
                      }).toList(),
                    ),
                  );
                }
                return null;
              },
            ),
            calendarStyle: const CalendarStyle(
              markerDecoration: BoxDecoration(
                color: Colors.purple,
                shape: BoxShape.circle,
              ),
            ),
            availableCalendarFormats: const {
              CalendarFormat.month: 'Month',
            },
            headerStyle: const HeaderStyle(
              formatButtonVisible: false,
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: appointments.isEmpty
                ? const Center(child: Text('No appointments on this day.'))
                : ListView(
                    children: appointments.map((appt) {
                      final note = appt['note'] ?? '';
                      final status = appt['status'] ?? '';
                      final time = (appt['dateTime'] as Timestamp).toDate();
                      final docId = appt['docId'];

                      return ListTile(
                        title: Text(
                          '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')} - $note',
                        ),
                        subtitle: Text('Status: $status'),
                        leading: const Icon(Icons.calendar_today),
                        trailing: PopupMenuButton<String>(
                          onSelected: (value) {
                            if (value == 'edit') {
                              _editNote(docId, note);
                            } else if (value == 'delete') {
                              _deleteAppointment(docId);
                            }
                          },
                          itemBuilder: (context) => [
                            const PopupMenuItem(
                              value: 'edit',
                              child: Text('Edit'),
                            ),
                            const PopupMenuItem(
                              value: 'delete',
                              child: Text('Delete'),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
          ),
        ],
      ),
    );
  }
}
