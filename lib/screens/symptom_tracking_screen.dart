import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:table_calendar/table_calendar.dart';

import 'mood_history_screen.dart';

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
    _selectedDay = _focusedDay;
    _loadEvents();
    _prefillTodayMood();
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

  Future<void> _prefillTodayMood() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final today = DateTime.now();
    final todayStart = DateTime(today.year, today.month, today.day);

    final snapshot =
        await FirebaseFirestore.instance
            .collection('symptom_logs')
            .where('uid', isEqualTo: uid)
            .where(
              'timestamp',
              isGreaterThanOrEqualTo: Timestamp.fromDate(todayStart),
            )
            .limit(1)
            .get();

    if (snapshot.docs.isNotEmpty) {
      final data = snapshot.docs.first.data();
      setState(() {
        _selectedMood = data['mood'] ?? '🙂';
        _noteController.text = data['note'] ?? '';
      });
    }
  }

  Future<void> _saveMood() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);

    final snapshot =
        await FirebaseFirestore.instance
            .collection('symptom_logs')
            .where('uid', isEqualTo: uid)
            .where(
              'timestamp',
              isGreaterThanOrEqualTo: Timestamp.fromDate(todayStart),
            )
            .limit(1)
            .get();

    if (snapshot.docs.isNotEmpty) {
      // Update existing entry
      final docId = snapshot.docs.first.id;
      await FirebaseFirestore.instance
          .collection('symptom_logs')
          .doc(docId)
          .update({
            'mood': _selectedMood,
            'note': _noteController.text.trim(),
            'timestamp': FieldValue.serverTimestamp(),
          });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Mood entry updated!'),
          backgroundColor: Colors.blueAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      // Add new entry — creates the collection if needed
      await FirebaseFirestore.instance.collection('symptom_logs').add({
        'uid': uid,
        'mood': _selectedMood,
        'note': _noteController.text.trim(),
        'timestamp': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🎉 Mood saved successfully!'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }

    _noteController.clear();

    setState(() {
      _focusedDay = DateTime.now();
      _selectedDay = DateTime.now();
    });

    await _loadEvents();
    await _calculateMoodSummary(_selectedDay!);
    await _prefillTodayMood();
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

  bool isSameDay(DateTime? d1, DateTime? d2) =>
      d1?.year == d2?.year && d1?.month == d2?.month && d1?.day == d2?.day;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Symptom Tracking')),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_summaryMood != null)
                Column(
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
                    Text(_summaryLabel),
                    const SizedBox(height: 16),
                  ],
                ),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  ElevatedButton.icon(
                    onPressed: () {
                      setState(() {
                        _focusedDay = DateTime.now();
                        _selectedDay = DateTime.now();
                      });
                    },
                    icon: const Icon(Icons.today),
                    label: const Text('Today'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepPurple,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TableCalendar(
                firstDay: DateTime.utc(2022, 1, 1),
                lastDay: DateTime.utc(2030, 12, 31),
                focusedDay: _focusedDay,
                calendarFormat: CalendarFormat.week,
                availableCalendarFormats: const {CalendarFormat.week: 'Week'},
                selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                eventLoader: (day) {
                  final d = DateTime(day.year, day.month, day.day);
                  return _events[d] ?? [];
                },
                onDaySelected: (selected, focused) async {
                  setState(() {
                    _focusedDay = focused;
                    _selectedDay = selected;
                  });
                  await _calculateMoodSummary(selected);
                },
                onPageChanged: (focused) => _focusedDay = focused,
                calendarBuilders: CalendarBuilders(
                  defaultBuilder: (context, day, _) {
                    final d = DateTime(day.year, day.month, day.day);
                    final events = _events[d] ?? [];
                    return Center(
                      child: Text(
                        events.isNotEmpty ? events.first['mood'] : '${day.day}',
                        style: const TextStyle(fontSize: 16),
                      ),
                    );
                  },
                ),
                calendarStyle: const CalendarStyle(
                  todayDecoration: BoxDecoration(
                    color: Colors.purpleAccent,
                    shape: BoxShape.circle,
                  ),
                  selectedDecoration: BoxDecoration(
                    color: Colors.deepPurple,
                    shape: BoxShape.circle,
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
                      final selected = _selectedMood == mood;
                      return GestureDetector(
                        onTap: () => setState(() => _selectedMood = mood),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: selected ? Colors.deepPurple.shade100 : null,
                            border: Border.all(
                              color: selected ? Colors.deepPurple : Colors.grey,
                              width: selected ? 2 : 1,
                            ),
                          ),
                          child: Text(
                            mood,
                            style: const TextStyle(fontSize: 32),
                          ),
                        ),
                      );
                    }).toList(),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _noteController,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Notes (optional)',
                  border: OutlineInputBorder(),
                ),
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
                  onPressed:
                      () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const MoodHistoryScreen(),
                        ),
                      ),
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
