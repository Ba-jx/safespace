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
            .collection('users')
            .doc(uid)
            .collection('symptom_logs')
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
            .collection('users')
            .doc(uid)
            .collection('symptom_logs')
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

    final todayStart = DateTime.now();
    final logsRef = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('symptom_logs');

    final snapshot =
        await logsRef
            .where(
              'timestamp',
              isGreaterThanOrEqualTo: Timestamp.fromDate(
                DateTime(todayStart.year, todayStart.month, todayStart.day),
              ),
            )
            .limit(1)
            .get();

    try {
      if (snapshot.docs.isNotEmpty) {
        final docId = snapshot.docs.first.id;
        await logsRef.doc(docId).update({
          'mood': _selectedMood,
          'note': _noteController.text.trim(),
          'timestamp': FieldValue.serverTimestamp(),
          'edited': true,
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('✅ Mood entry updated!')));
      } else {
        await logsRef.add({
          'mood': _selectedMood,
          'note': _noteController.text.trim(),
          'timestamp': FieldValue.serverTimestamp(),
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('🎉 Mood saved successfully!')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error saving mood: $e')));
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
            .collection('users')
            .doc(uid)
            .collection('symptom_logs')
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
              if (_summaryMood != null) ...[
                const Text(
                  'Mood Summary',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(_summaryMood!, style: const TextStyle(fontSize: 48)),
                Text(_summaryLabel),
                const SizedBox(height: 16),
              ],
              SizedBox(
                height: 140,
                child: TableCalendar(
                  firstDay: DateTime.utc(2020, 1, 1),
                  lastDay: DateTime.utc(2030, 12, 31),
                  focusedDay: _focusedDay,
                  calendarFormat: CalendarFormat.week,
                  selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                  onDaySelected: (selected, focused) async {
                    setState(() {
                      _focusedDay = focused;
                      _selectedDay = selected;
                    });
                    await _calculateMoodSummary(selected);
                  },
                  eventLoader: (day) {
                    final key = DateTime(day.year, day.month, day.day);
                    return _events[key] ?? [];
                  },
                  headerStyle: const HeaderStyle(
                    formatButtonVisible: false,
                    titleCentered: true,
                    leftChevronVisible: false,
                    rightChevronVisible: false,
                  ),
                  calendarBuilders: CalendarBuilders(
                    headerTitleBuilder: (context, day) {
                      return Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          IconButton(
                            icon: const Icon(
                              Icons.chevron_left,
                              color: Colors.deepPurple,
                            ),
                            onPressed: () {
                              setState(() {
                                _focusedDay = _focusedDay.subtract(
                                  const Duration(days: 7),
                                );
                              });
                            },
                          ),
                          Text(
                            '${day.month}/${day.year}',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Row(
                            children: [
                              IconButton(
                                icon: const Icon(
                                  Icons.today,
                                  color: Colors.deepPurple,
                                ),
                                tooltip: 'Today',
                                onPressed: () {
                                  setState(() {
                                    _focusedDay = DateTime.now();
                                    _selectedDay = DateTime.now();
                                  });
                                },
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.chevron_right,
                                  color: Colors.deepPurple,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _focusedDay = _focusedDay.add(
                                      const Duration(days: 7),
                                    );
                                  });
                                },
                              ),
                            ],
                          ),
                        ],
                      );
                    },
                    markerBuilder: (context, date, events) {
                      if (events.isNotEmpty) {
                        return Positioned(
                          bottom: 1,
                          child: Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.deepPurple,
                            ),
                          ),
                        );
                      }
                      return const SizedBox.shrink();
                    },
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                "Record Today's Mood",
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
    style: ElevatedButton.styleFrom(
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFFB9A6E8)
          : const Color(0xFF6C4DB0),
      foregroundColor: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(30),
      ),
    ),
    child: const Text(
      'Save Mood',
      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
    ),
  ),
),
const SizedBox(height: 24),
Center(
  child: TextButton(
    onPressed: () {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const MoodHistoryScreen(),
        ),
      );
    },
    style: TextButton.styleFrom(
      foregroundColor: Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFFB9A6E8)
          : const Color(0xFF6C4DB0),
    ),
    child: const Text(
      'View All Mood History',
      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
    ),
  ),
),

            ],
          ),
        ),
      ),
    );
  }
}
