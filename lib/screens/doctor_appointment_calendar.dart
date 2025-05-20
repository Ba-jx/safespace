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
        .where('status', whereIn: ['confirmed', 'rescheduled'])
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
      floatingActionButton: FloatingActionButton(
        onPressed: () {},
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
                      final ref = appt['ref'] as DocumentReference?;

                      return ListTile(
                        title: Text(name),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${TimeOfDay.fromDateTime(time).format(context)} - $note'),
                            const SizedBox(height: 4),
                            Chip(
                              label: Text(status.toUpperCase()),
                              backgroundColor: {
                                'confirmed': Colors.green[100],
                                'rescheduled': Colors.blue[100],
                              }[status] ?? Colors.grey[300],
                              labelStyle: TextStyle(
                                color: {
                                  'confirmed': Colors.green,
                                  'rescheduled': Colors.blue,
                                }[status] ?? Colors.black,
                                fontWeight: FontWeight.bold,
                              ),
                              visualDensity: VisualDensity.compact,
                            ),
                          ],
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () async {
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text('Confirm Deletion'),
                                content: const Text('Are you sure you want to cancel this appointment?'),
                                actions: [
                                  TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('No')),
                                  ElevatedButton(
                                    onPressed: () => Navigator.pop(context, true),
                                    style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                                    child: const Text('Yes'),
                                  ),
                                ],
                              ),
                            );
                            if (confirm == true && ref != null) {
                              await ref.update({'status': 'cancelled'});
                              await _fetchAppointments();
                            }
                          },
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
