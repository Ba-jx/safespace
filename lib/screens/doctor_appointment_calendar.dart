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
    if (doctorId == null) return;

    try {
      final snapshot = await FirebaseFirestore.instance
          .collectionGroup('appointments')
          .where('doctorId', isEqualTo: doctorId)
          .where('status', isEqualTo: 'confirmed')
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
    } catch (e) {
      print('❌ Error fetching appointments: $e');
    }
  }

  List<Map<String, dynamic>> _getAppointmentsForDay(DateTime day) {
    final date = DateTime(day.year, day.month, day.day);
    return _appointmentsByDate[date] ?? [];
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
              markerDecoration: BoxDecoration(color: Colors.purple, shape: BoxShape.circle),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: appointments.isEmpty
                ? const Center(child: Text('No appointments on this day.'))
                : ListView(
                    children: appointments.map((appt) {
                      final patientName = appt['patientName'] ?? 'Unknown';
                      final note = appt['note'] ?? '';
                      final time = (appt['dateTime'] as Timestamp).toDate();

                      return ListTile(
                        title: Text(patientName),
                        subtitle: Text('${TimeOfDay.fromDateTime(time).format(context)} - $note'),
                        leading: const Icon(Icons.event_available),
                      );
                    }).toList(),
                  ),
          ),
        ],
      ),
    );
  }
}
