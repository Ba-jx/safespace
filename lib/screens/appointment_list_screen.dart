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

class _PatientAppointmentCalendarState extends State<PatientAppointmentCalendar> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  Map<DateTime, List<Map<String, dynamic>>> _appointmentsByDate = {};

  @override
  void initState() {
    super.initState();
    _fetchAppointments();
  }

  Future<void> _fetchAppointments() async {
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
  if (data['status'] == 'cancelled') continue;

  final timestamp = data['dateTime'];
  if (timestamp is Timestamp) {
    final date = DateTime(timestamp.toDate().year, timestamp.toDate().month, timestamp.toDate().day);
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

  Future<List<TimeOfDay>> _getAvailableTimeSlots(DateTime date, String patientId) async {
    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(patientId)
        .collection('appointments')
        .where('dateTime',
            isGreaterThanOrEqualTo: Timestamp.fromDate(
                DateTime(date.year, date.month, date.day, 0, 0)))
        .where('dateTime',
            isLessThan: Timestamp.fromDate(
                DateTime(date.year, date.month, date.day + 1, 0, 0)))
        .get();

    final bookedHours = snapshot.docs.map((doc) {
      final dt = (doc['dateTime'] as Timestamp).toDate();
      return TimeOfDay(hour: dt.hour, minute: dt.minute);
    }).toSet();

    final slots = <TimeOfDay>[];
    for (int hour = 9; hour < 17; hour++) {
      final slot = TimeOfDay(hour: hour, minute: 0);
      if (!bookedHours.contains(slot)) {
        slots.add(slot);
      }
    }
    return slots;
  }

  void _showEditDialog(Map<String, dynamic> appt) async {
    final patientId = FirebaseAuth.instance.currentUser!.uid;
    DateTime initialDate = (appt['dateTime'] as Timestamp).toDate();
    DateTime selectedDate = initialDate;
    TimeOfDay selectedTime = TimeOfDay.fromDateTime(initialDate);
    List<TimeOfDay> availableSlots = await _getAvailableTimeSlots(selectedDate, patientId);

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          title: const Text('Edit Appointment'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: const Text('Date'),
                subtitle: Text('${selectedDate.toLocal()}'.split(' ')[0]),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: selectedDate,
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 60)),
                  );
                  if (picked != null) {
                    selectedDate = picked;
                    availableSlots = await _getAvailableTimeSlots(selectedDate, patientId);
                    setModalState(() {});
                  }
                },
              ),
              DropdownButton<TimeOfDay>(
                value: availableSlots.contains(selectedTime) ? selectedTime : null,
                hint: const Text('Select Time Slot'),
                isExpanded: true,
                items: availableSlots.map((slot) {
                  return DropdownMenuItem(
                    value: slot,
                    child: Text(slot.format(context)),
                  );
                }).toList(),
                onChanged: (val) => setModalState(() => selectedTime = val!),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                final newDateTime = DateTime(
                  selectedDate.year,
                  selectedDate.month,
                  selectedDate.day,
                  selectedTime.hour,
                  selectedTime.minute,
                );
                final hoursDiff = newDateTime.difference(DateTime.now()).inHours;
                if (hoursDiff < 12) {
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Too Late'),
                      content: const Text('Appointments must be rescheduled at least 12 hours in advance.'),
                      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))],
                    ),
                  );
                  return;
                }

                final docId = appt['docId'];
                await FirebaseFirestore.instance
                    .collection('users')
                    .doc(patientId)
                    .collection('appointments')
                    .doc(docId)
                    .update({
                  'dateTime': Timestamp.fromDate(newDateTime),
                  'status': 'rescheduled',
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

  Future<void> _deleteAppointment(String docId) async {
    final patientId = FirebaseAuth.instance.currentUser?.uid;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Appointment'),
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
      await _fetchAppointments();
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
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(40)),
                  elevation: 4,
                ),
                icon: const Icon(Icons.calendar_today, size: 18),
                label: const Text('Today', style: TextStyle(fontWeight: FontWeight.w500)),
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
            availableCalendarFormats: const {CalendarFormat.month: 'Month'},
            headerStyle: const HeaderStyle(formatButtonVisible: false),
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
                        trailing: (status == 'confirmed' || status == 'cancelled' || status == 'completed')
                            ? const Tooltip(
                                message: 'Cannot edit confirmed, cancelled, or completed appointments',
                                child: Icon(Icons.lock, color: Colors.grey),
                              )
                            : PopupMenuButton<String>(
                                onSelected: (value) {
                                  if (value == 'edit') {
                                    _showEditDialog(appt);
                                  } else if (value == 'delete') {
                                    _deleteAppointment(docId);
                                  }
                                },
                                itemBuilder: (context) => [
                                  const PopupMenuItem(value: 'edit', child: Text('Edit')),
                                  const PopupMenuItem(value: 'delete', child: Text('Delete')),
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
