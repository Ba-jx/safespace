import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:table_calendar/table_calendar.dart';

class DoctorAppointmentCalendar extends StatefulWidget {
  const DoctorAppointmentCalendar({super.key});

  @override
  State<DoctorAppointmentCalendar> createState() =>
      _DoctorAppointmentCalendarState();
}

class _DoctorAppointmentCalendarState
    extends State<DoctorAppointmentCalendar> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  Map<DateTime, List<Map<String, dynamic>>> _appointmentsByDate = {};
  List<Map<String, dynamic>> _patients = [];

  @override
  void initState() {
    super.initState();
    _fetchAppointments();
    _fetchPatients();
  }

  Future<void> _fetchPatients() async {
    final doctorId = FirebaseAuth.instance.currentUser?.uid;
    if (doctorId == null) return;

    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .where('doctorId', isEqualTo: doctorId)
        .where('role', isEqualTo: 'patient')
        .get();

    setState(() {
      _patients = snapshot.docs
          .map((doc) => {'id': doc.id, ...doc.data()})
          .toList();
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

  void _showAddDialog() async {
    String? selectedPatientId;
    String? selectedPatientName;
    TimeOfDay selectedTime = TimeOfDay.now();
    final noteController = TextEditingController();
    DateTime selectedDate = _selectedDay ?? DateTime.now();

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          title: const Text('Add Appointment'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                hint: const Text('Select Patient'),
                value: selectedPatientId,
                items: _patients.map((patient) {
                  return DropdownMenuItem<String>(
                    value: patient['id'],
                    child: Text(patient['name']),
                  );
                }).toList(),
                onChanged: (value) {
                  setModalState(() {
                    selectedPatientId = value;
                    selectedPatientName = _patients
                        .firstWhere((p) => p['id'] == value)['name'];
                  });
                },
              ),
              TextField(
                controller: noteController,
                decoration: const InputDecoration(labelText: 'Note'),
              ),
              const SizedBox(height: 12),
              ListTile(
                title: const Text('Time'),
                subtitle: Text(selectedTime.format(context)),
                onTap: () async {
                  final picked = await showTimePicker(
                    context: context,
                    initialTime: selectedTime,
                  );
                  if (picked != null) {
                    setModalState(() => selectedTime = picked);
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (selectedPatientId == null) return;
                final doctorId = FirebaseAuth.instance.currentUser?.uid;
                if (doctorId == null) return;

                final appointmentTime = DateTime(
                  selectedDate.year,
                  selectedDate.month,
                  selectedDate.day,
                  selectedTime.hour,
                  selectedTime.minute,
                );

                final conflicting = await FirebaseFirestore.instance
                    .collection('users')
                    .doc(selectedPatientId)
                    .collection('appointments')
                    .where('dateTime', isGreaterThanOrEqualTo: Timestamp.fromDate(
                        appointmentTime.subtract(const Duration(minutes: 59))))
                    .where('dateTime', isLessThanOrEqualTo: Timestamp.fromDate(
                        appointmentTime.add(const Duration(minutes: 59))))
                    .get();

                if (conflicting.docs.isNotEmpty) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('This patient already has an appointment around that time.'),
                    backgroundColor: Colors.red,
                  ));
                  return;
                }

                await FirebaseFirestore.instance
                    .collection('users')
                    .doc(selectedPatientId)
                    .collection('appointments')
                    .add({
                  'note': noteController.text.trim(),
                  'dateTime': Timestamp.fromDate(appointmentTime),
                  'doctorId': doctorId,
                  'patientName': selectedPatientName,
                  'status': 'pending',
                });

                if (!mounted) return;
                Navigator.pop(context);
                await _fetchAppointments();
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditDialog(Map<String, dynamic> appt) async {
    final noteController = TextEditingController(text: appt['note'] ?? '');
    final dateTime = (appt['dateTime'] as Timestamp).toDate();
    TimeOfDay selectedTime = TimeOfDay.fromDateTime(dateTime);
    DateTime selectedDate = dateTime;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          title: const Text('Edit Appointment'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: noteController,
                decoration: const InputDecoration(labelText: 'Note'),
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
                    setModalState(() => selectedDate = picked);
                  }
                },
              ),
              ListTile(
                title: const Text('Time'),
                subtitle: Text(selectedTime.format(context)),
                onTap: () async {
                  final picked = await showTimePicker(
                    context: context,
                    initialTime: selectedTime,
                  );
                  if (picked != null) {
                    setModalState(() => selectedTime = picked);
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final updatedDateTime = DateTime(
                  selectedDate.year,
                  selectedDate.month,
                  selectedDate.day,
                  selectedTime.hour,
                  selectedTime.minute,
                );

                await (appt['ref'] as DocumentReference).update({
                  'note': noteController.text.trim(),
                  'dateTime': Timestamp.fromDate(updatedDateTime),
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

  @override
  Widget build(BuildContext context) {
    final appointments = _getAppointmentsForDay(_selectedDay ?? _focusedDay);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Appointment Calendar'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _patients.isEmpty ? null : _showAddDialog,
          )
        ],
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
                final statuses = events
                    .map((e) => (e as Map<String, dynamic>)['status'] ?? '')
                    .where((s) => s.isNotEmpty)
                    .toSet();
                return Positioned(
                  bottom: 1,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: statuses.map((status) {
                      Color color;
                      switch (status) {
                        case 'confirmed':
                          color = Colors.green;
                          break;
                        case 'pending':
                          color = Colors.orange;
                          break;
                        case 'rescheduled':
                          color = Colors.blue;
                          break;
                        default:
                          color = Colors.grey;
                      }
                      return Container(
                        margin: const EdgeInsets.symmetric(horizontal: 1.5),
                        width: 6,
                        height: 6,
                        decoration:
                            BoxDecoration(color: color, shape: BoxShape.circle),
                      );
                    }).toList(),
                  ),
                );
              },
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
                      final status = appt['status'] ?? 'unknown';

                      return ListTile(
                        title: Text(patientName),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${TimeOfDay.fromDateTime(time).format(context)} - $note'),
                            const SizedBox(height: 4),
                            Chip(
                              label: Text(status.toUpperCase()),
                              backgroundColor: {
                                'confirmed': Colors.green[100],
                                'pending': Colors.orange[100],
                                'rescheduled': Colors.blue[100],
                              }[status] ?? Colors.grey[300],
                              labelStyle: TextStyle(
                                color: {
                                  'confirmed': Colors.green,
                                  'pending': Colors.orange,
                                  'rescheduled': Colors.blue,
                                }[status] ?? Colors.black,
                                fontWeight: FontWeight.bold,
                              ),
                              visualDensity: VisualDensity.compact,
                            ),
                          ],
                        ),
                        leading: const Icon(Icons.event_available),
                        onTap: () => _showEditDialog(appt),
                      );
                    }).toList(),
                  ),
          ),
        ],
      ),
    );
  }
}
