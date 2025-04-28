import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:table_calendar/table_calendar.dart';
import 'mood_history_screen.dart'; // Your mood history page

class SymptomTrackingScreen extends StatefulWidget {
  const SymptomTrackingScreen({super.key});

  @override
  State<SymptomTrackingScreen> createState() => _SymptomTrackingScreenState();
}

class _SymptomTrackingScreenState extends State<SymptomTrackingScreen> {
  final TextEditingController _noteController = TextEditingController();
  String _selectedMood = '🙂';
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  Map<DateTime, List<Map<String, dynamic>>> _events = {};
  String? _summaryMood;
  String _summaryLabel = 'No mood logged';

  @override
  void initState() {
    super.initState();
    _loadEvents();
    _selectedDay = _focusedDay;
  }

  Future<void> _loadEvents() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final snapshot =
        await FirebaseFirestore.instance
            .collection('symptom_logs')
            .where('uid', isEqualTo: uid)
            .get();

    final Map<DateTime, List<Map<String, dynamic>>> newEvents = {};

    for (var doc in snapshot.docs) {
      final data = doc.data();
      final timestamp = (data['timestamp'] as Timestamp?)?.toDate();
      if (timestamp != null) {
        final day = DateTime(timestamp.year, timestamp.month, timestamp.day);
        newEvents.putIfAbsent(day, () => []).add(data);
      }
    }

    setState(() {
      _events = newEvents;
    });
  }

  Future<void> _saveMood() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    await FirebaseFirestore.instance.collection('symptom_logs').add({
      'uid': uid,
      'mood': _selectedMood,
      'note': _noteController.text.trim(),
      'timestamp': FieldValue.serverTimestamp(),
    });

    _noteController.clear();
    await _loadEvents();
    await _calculateMoodSummary(_selectedDay!);
  }

  Future<void> _calculateMoodSummary(DateTime day) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final snapshot =
        await FirebaseFirestore.instance
            .collection('symptom_logs')
            .where('uid', isEqualTo: uid)
            .get();

    final moodsToday =
        snapshot.docs
            .where((doc) {
              final timestamp = (doc['timestamp'] as Timestamp?)?.toDate();
              return timestamp != null &&
                  timestamp.year == day.year &&
                  timestamp.month == day.month &&
                  timestamp.day == day.day;
            })
            .map((doc) => doc['mood'] as String)
            .toList();

    if (moodsToday.isEmpty) {
      setState(() {
        _summaryMood = null;
        _summaryLabel = 'No mood logged';
      });
      return;
    }

    final moodCounts = <String, int>{};
    for (var mood in moodsToday) {
      moodCounts[mood] = (moodCounts[mood] ?? 0) + 1;
    }

    final mostCommonMood =
        moodCounts.entries.reduce((a, b) => a.value > b.value ? a : b).key;

    setState(() {
      _summaryMood = mostCommonMood;
      _summaryLabel = _getMoodLabel(mostCommonMood);
    });
  }

  String _getMoodLabel(String mood) {
    switch (mood) {
      case '😄':
        return 'Happy';
      case '🙂':
        return 'Positive';
      case '😐':
        return 'Neutral';
      case '😟':
        return 'Worried';
      case '😢':
        return 'Sad';
      default:
        return 'Unknown';
    }
  }

  Color _getMoodColor(String mood) {
    switch (mood) {
      case '😄':
      case '🙂':
        return Colors.green;
      case '😟':
      case '😢':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  bool isSameDay(DateTime? day1, DateTime? day2) {
    if (day1 == null || day2 == null) return false;
    return day1.year == day2.year &&
        day1.month == day2.month &&
        day1.day == day2.day;
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      appBar: AppBar(title: const Text('Symptom Tracking')),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_summaryMood != null)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const Text(
                      'Mood Summary',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(_summaryMood!, style: const TextStyle(fontSize: 48)),
                    Text(_summaryLabel, style: const TextStyle(fontSize: 16)),
                    const SizedBox(height: 24),
                  ],
                ),
              TableCalendar(
                firstDay: DateTime.utc(2020, 1, 1),
                lastDay: DateTime.utc(2030, 12, 31),
                focusedDay: _focusedDay,
                selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                eventLoader: (day) => _events[day] ?? [],
                onDaySelected: (selectedDay, focusedDay) async {
                  setState(() {
                    _selectedDay = selectedDay;
                    _focusedDay = focusedDay;
                  });
                  await _calculateMoodSummary(selectedDay);
                },
                rowHeight: 38,
                calendarBuilders: CalendarBuilders(
                  markerBuilder: (context, day, events) {
                    if (events.isEmpty) return null;
                    return ListView.builder(
                      shrinkWrap: true,
                      scrollDirection: Axis.horizontal,
                      itemCount: events.length,
                      itemBuilder: (context, index) {
                        final mood =
                            (events[index] as Map<String, dynamic>)['mood'];
                        return Container(
                          width: 6,
                          height: 6,
                          margin: const EdgeInsets.symmetric(horizontal: 0.5),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _getMoodColor(mood),
                          ),
                        );
                      },
                    );
                  },
                ),
                calendarStyle: CalendarStyle(
                  todayDecoration: BoxDecoration(
                    color: Colors.purpleAccent,
                    shape: BoxShape.circle,
                  ),
                  selectedDecoration: BoxDecoration(
                    color: Colors.deepPurple,
                    shape: BoxShape.circle,
                  ),
                  markerSize: 4.0,
                  markersMaxCount: 3,
                  cellMargin: const EdgeInsets.all(2),
                  outsideDaysVisible: false,
                ),
                daysOfWeekStyle: const DaysOfWeekStyle(
                  weekdayStyle: TextStyle(fontSize: 12),
                  weekendStyle: TextStyle(fontSize: 12),
                ),
                headerStyle: const HeaderStyle(
                  formatButtonVisible: false,
                  titleCentered: true,
                  titleTextStyle: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Record Today\'s Mood',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children:
                    ['😄', '🙂', '😐', '😟', '😢'].map((mood) {
                      return IconButton(
                        icon: Text(mood, style: const TextStyle(fontSize: 32)),
                        onPressed: () => setState(() => _selectedMood = mood),
                      );
                    }).toList(),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _noteController,
                decoration: const InputDecoration(
                  labelText: 'Notes (optional)',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 16),
              Center(
                child: ElevatedButton(
                  onPressed: _saveMood,
                  child: const Text('Save Mood'),
                ),
              ),
              const Divider(height: 32),
              Center(
                child: TextButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const MoodHistoryScreen(),
                      ),
                    );
                  },
                  child: const Text('View All Mood History'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
