import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class VetCalendarPage extends StatefulWidget {
  const VetCalendarPage({super.key});

  @override
  State<VetCalendarPage> createState() => _VetCalendarPageState();
}

class _VetCalendarPageState extends State<VetCalendarPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  DateTime? _selectedDate;
  String? _selectedDay;
  TimeOfDay? _selectedTime;
  List<Map<String, String>> _timeSlots = []; // slot + vetName
  String _vetName = '';

  final List<String> _days = [
    'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'
  ];

  @override
  void initState() {
    super.initState();
    _getVetName();
    _loadSlots();
  }

  Future<void> _getVetName() async {
    final user = _auth.currentUser;
    if (user != null) {
      final doc = await _firestore.collection('users').doc(user.uid).get();
      if (doc.exists && doc.data() != null && doc.data()!['name'] != null) {
        setState(() {
          _vetName = doc.data()!['name'];
        });
      }
    }
  }

  Future<void> _loadSlots() async {
    final user = _auth.currentUser;
    if (user != null) {
      final doc = await _firestore.collection('vets').doc(user.uid).get();
      if (doc.exists && doc.data() != null && doc.data()!['slots'] != null) {
        setState(() {
          _timeSlots = List<Map<String, String>>.from(
            (doc.data()!['slots'] as List)
                .map((slot) => Map<String, String>.from(slot)),
          );
        });
      }
    }
  }

  Future<void> _saveSlot(Map<String, String> slot) async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      _timeSlots.add(slot);
      await _firestore.collection('vets').doc(user.uid).set({
        'slots': _timeSlots,
        'updatedAt': FieldValue.serverTimestamp(),
        'vetName': _vetName,
      }, SetOptions(merge: true));

      // Success message with green background
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Slot added successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      // Error message with red background
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error adding slot: $e'),
          backgroundColor: Colors.red,
        ),
      );
      print("Error adding slot: $e");
    }
  }

  Future<void> _pickDate() async {
    DateTime today = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: today,
      firstDate: today,
      lastDate: DateTime(today.year + 2),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Colors.pink,
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(foregroundColor: Colors.pink),
            ),
          ),
          child: child!,
        );
      },
    );
    if (date != null) {
      setState(() {
        _selectedDate = date;
        _selectedDay = _days[date.weekday - 1];
      });
    }
  }

  Future<void> _pickTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Colors.pink,
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
            timePickerTheme: TimePickerThemeData(
              dialBackgroundColor: Colors.pink.shade50,
              hourMinuteTextColor: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );
    if (time != null) {
      setState(() {
        _selectedTime = time;
      });
    }
  }

  void _addSlot() {
    if (_selectedDate == null || _selectedDay == null || _selectedTime == null) return;

    final slotStr =
        "${DateFormat('yyyy-MM-dd').format(_selectedDate!)} ($_selectedDay) ${_selectedTime!.format(context)}";

    final slotMap = {'slot': slotStr, 'vetName': _vetName};

    if (!_timeSlots.any((s) => s['slot'] == slotStr)) {
      _saveSlot(slotMap);
      setState(() {
        _selectedDate = null;
        _selectedDay = null;
        _selectedTime = null;
      });
    }
  }

  void _removeSlot(Map<String, String> slot) async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      _timeSlots.remove(slot);
      await _firestore.collection('vets').doc(user.uid).set({
        'slots': _timeSlots,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Success message with green background
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Slot removed successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      // Error message with red background
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error removing slot: $e'),
          backgroundColor: Colors.red,
        ),
      );
      print("Error removing slot: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.pink.shade50,
      appBar: AppBar(
        title: const Text(
          'Vet Availability Calendar',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.pink,
        iconTheme: const IconThemeData(
          color: Colors.white,
        ),
        elevation: 2,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.pink,
                foregroundColor: Colors.black,
                minimumSize: const Size.fromHeight(50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: _pickDate,
              child: Text(_selectedDate == null
                  ? "Select Date"
                  : "Date: ${DateFormat('yyyy-MM-dd').format(_selectedDate!)} ($_selectedDay)"),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.pink,
                foregroundColor: Colors.black,
                minimumSize: const Size.fromHeight(50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: _selectedDate == null ? null : _pickTime,
              child: Text(_selectedTime == null
                  ? "Select Time"
                  : "Time: ${_selectedTime!.format(context)}"),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.pink,
                foregroundColor: Colors.black,
                minimumSize: const Size.fromHeight(50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: (_selectedDate != null && _selectedTime != null)
                  ? _addSlot
                  : null,
              child: const Text("Add Slot"),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: _timeSlots.isEmpty
                  ? const Center(
                      child: Text(
                        "No slots added",
                        style: TextStyle(fontSize: 16, color: Colors.black54),
                      ),
                    )
                  : ListView.builder(
                      itemCount: _timeSlots.length,
                      itemBuilder: (context, index) {
                        final slot = _timeSlots[index];
                        return Card(
                          color: Colors.pink.shade100,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          margin: const EdgeInsets.symmetric(vertical: 6),
                          child: ListTile(
                            title: Text(
                              slot['slot']!,
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            subtitle: Text("Vet: ${slot['vetName']}"),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete, color: Colors.black),
                              onPressed: () => _removeSlot(slot),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
