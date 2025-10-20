import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:pet_app/views/vet/appointments_view.dart';
import 'package:shimmer/shimmer.dart';
import 'package:intl/intl.dart';

class AppointmentPage extends StatefulWidget {
  const AppointmentPage({super.key});

  @override
  State<AppointmentPage> createState() => _AppointmentPageState();
}

class _AppointmentPageState extends State<AppointmentPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  bool _loadingPets = true;
  bool _loadingVets = true;
  bool _saving = false;

  List<Map<String, dynamic>> _userPets = [];
  List<Map<String, dynamic>> _vets = [];

  Map<String, dynamic>? _selectedPet;
  Map<String, dynamic>? _selectedVet;
  DateTime? _selectedDate;
  String? _selectedTime;
  String _ownerName = '';
  final TextEditingController _illnessController = TextEditingController();

  List<String> _availableDates = [];
  List<String> _availableTimes = [];

  @override
  void initState() {
    super.initState();
    _fetchOwnerName();
    _fetchPets();
    _fetchVets();
  }

  Future<void> _fetchOwnerName() async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        final doc = await _firestore.collection('users').doc(user.uid).get();
        final name = doc.data()?['name']?.toString() ?? 'Owner';
        setState(() => _ownerName = name);
        print("Owner name: $_ownerName");
      }
    } catch (e, st) {
      print("Error fetching owner name: $e\n$st");
    }
  }
 Future<void> _fetchPets() async {
    try {
      setState(() => _loadingPets = true);
      final user = _auth.currentUser;
      if (user != null) {
        final snapshot = await _firestore
            .collection('pets')
            .where('ownerId', isEqualTo: user.uid)
            .get();
        _userPets = snapshot.docs.map((d) {
          final data = Map<String, dynamic>.from(d.data());
          data['id'] = d.id;
          data['photo'] = data['photo'] ?? ''; 
          return data;
        }).toList();
        print("Pets loaded: ${_userPets.length}");
      }
    } catch (e, st) {
      print("Error fetching pets: $e\n$st");
    } finally {
      setState(() => _loadingPets = false);
    }
  }


  Future<void> _fetchVets() async {
    try {
      setState(() => _loadingVets = true);
      final snapshot = await _firestore.collection('vets').get();
      _vets = snapshot.docs.map((d) {
        final data = Map<String, dynamic>.from(d.data());
        data['id'] = d.id;
        data['vetName'] = data['vetName']?.toString() ?? 'Unknown';
        print("Vet found: ${data['vetName']} (id=${d.id})");
        return data;
      }).toList();
      print("Total vets fetched: ${_vets.length}");
    } catch (e, st) {
      print("Error fetching vets: $e\n$st");
    } finally {
      setState(() => _loadingVets = false);
    }
  }
  Future<void> _pickDate() async {
    if (_selectedVet == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a vet first')));
      return;
    }
    try {
      final vetId = _selectedVet!['id'];
      final snapshot = await _firestore.collection('vets').doc(vetId).get();
      if (!snapshot.exists) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Vet data not found')));
        return;
      }

      final dynamic rawSlots = snapshot.data()?['slots'];
      if (rawSlots == null) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('No availability found for this vet')));
        return;
      }

      final List<String> slots = (rawSlots as List).map<String>((s) {
        if (s is Map<String, dynamic>) return s['slot']?.toString() ?? '';
        if (s is String) return s;
        return '';
      }).where((s) => s.isNotEmpty).toList();

      if (slots.isEmpty) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('No slots available for this vet')));
        return;
      }

      final List<String> dates = slots.map((s) => s.split(" ")[0]).toSet().toList();

      if (dates.isEmpty) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('No available dates for this vet')));
        return;
      }

      final parsedDates = dates.map((d) {
        try {
          return DateFormat('yyyy-MM-dd').parse(d);
        } catch (_) {
          return DateTime.now();
        }
      }).toList()
        ..sort((a, b) => a.compareTo(b));

      DateTime initialDate = parsedDates.firstWhere(
        (dt) => dates.contains(DateFormat('yyyy-MM-dd').format(dt)),
        orElse: () => parsedDates.first,
      );

      setState(() {
        _availableDates = dates;
      });

      final picked = await showDatePicker(
        context: context,
        initialDate: initialDate,
        firstDate: parsedDates.first,
        lastDate: parsedDates.last,
        selectableDayPredicate: (day) {
          final dayStr = DateFormat('yyyy-MM-dd').format(day);
          return _availableDates.contains(dayStr);
        },
      );

      if (picked != null) {
        final pickedStr = DateFormat('yyyy-MM-dd').format(picked);
        final List<String> times = slots
            .where((slot) => slot.startsWith(pickedStr))
            .map((slot) {
              final parts = slot.split(" ");
              if (parts.length >= 4) return "${parts[2]} ${parts[3]}";
              return parts.length >= 3 ? parts.sublist(2).join(" ") : slot;
            })
            .toList();

        setState(() {
          _selectedDate = picked;
          _selectedTime = null;
          _availableTimes = times;
        });
      }
    } catch (e, st) {
      print("Error in _pickDate: $e\n$st");
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error loading dates: $e')));
    }
  }

  
  Future<void> _pickTime() async {
    if (_availableTimes.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('No times available for selected date')));
      return;
    }

    final time = await showModalBottomSheet<String>(
      context: context,
      builder: (_) {
        return ListView(
          children: _availableTimes
              .map((t) => ListTile(
                    title: Text(t),
                    onTap: () => Navigator.pop(context, t),
                  ))
              .toList(),
        );
      },
    );

    if (time != null) {
      setState(() => _selectedTime = time);
    }
  }

  Future<void> _saveAppointment() async {
    if (_selectedPet == null ||
        _selectedVet == null ||
        _selectedDate == null ||
        _selectedTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select pet, vet, date and time')),
      );
      return;
    }

    try {
      setState(() => _saving = true);
      final user = _auth.currentUser;
      final appointmentsRef = _firestore.collection('appointments');

      int newIdNum = 1;
      try {
        final q = await appointmentsRef.orderBy('idNum', descending: true).limit(1).get();
        if (q.docs.isNotEmpty) {
          final val = q.docs.first.data()['idNum'];
          if (val is int) {
            newIdNum = val + 1;
          } else if (val is String) {
            newIdNum = (int.tryParse(val) ?? 0) + 1;
          }
        } else {
          final q2 = await appointmentsRef.orderBy('createdAt', descending: true).limit(1).get();
          if (q2.docs.isNotEmpty) {
            final lastIdStr = q2.docs.first.data()['id']?.toString();
            if (lastIdStr != null) {
              final parsed = int.tryParse(lastIdStr) ??
                  int.tryParse(lastIdStr.replaceAll(RegExp(r'^0+'), '')) ??
                  0;
              if (parsed > 0) newIdNum = parsed + 1;
            }
          }
        }
      } catch (e) {
        print("Warn: couldn't determine last appointment idNum: $e");
      }

      final formattedId = newIdNum.toString().padLeft(2, '0');

      final apptData = {
        'id': formattedId,
        'idNum': newIdNum,
        'petId': _selectedPet!['id'] ?? '',
        'petName': _selectedPet!['name'] ?? '',
        'age': _selectedPet!['age']?.toString() ?? '',
        'species': _selectedPet!['species'] ?? '',
        'breed': _selectedPet!['breed'] ?? '',
        'gender': _selectedPet!['gender'] ?? '',
        'petImageUrl': _selectedPet!['photo'] ?? '',
        'ownerId': user?.uid ?? '',
        'ownerName': _ownerName,
        'vetId': _selectedVet!['id'] ?? '',
        'vetName': _selectedVet!['vetName'] ?? 'Unknown',
        'date': DateFormat('yyyy-MM-dd').format(_selectedDate!),
        'time': _selectedTime ?? '',
        'illness': _illnessController.text,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      };

      await appointmentsRef.doc(formattedId).set(apptData);

      print(" Appointment saved: $apptData");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Appointment #$formattedId saved (Pending)')),
      );

      setState(() {
        _selectedPet = null;
        _selectedVet = null;
        _selectedDate = null;
        _selectedTime = null;
        _availableTimes.clear();
        _illnessController.clear();
      });

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const AppointmentScreen()),
        );
      }
    } catch (e, st) {
      print(" Error saving appointment: $e\n$st");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving appointment: $e')),
      );
    } finally {
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Add Appointment"),
        backgroundColor: Colors.pink,
        foregroundColor: Colors.white, 
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          child: ListView(
            children: [
              if (_selectedPet != null && (_selectedPet!['photo'] ?? '').toString().isNotEmpty)
                Center(
                  child: CircleAvatar(
                    radius: 60,
                    backgroundImage: NetworkImage(_selectedPet!['photo']),
                  ),
                )
              else
                Center(
                  child: CircleAvatar(
                    radius: 60,
                    backgroundColor: Colors.grey[200],
                    child: Icon(Icons.pets, size: 44, color: Colors.grey[600]),
                  ),
                ),
              const SizedBox(height: 16),
              Text('Owner: $_ownerName',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 16),
              _loadingPets
                  ? Shimmer.fromColors(
                      baseColor: Colors.grey[300]!,
                      highlightColor: Colors.grey[100]!,
                      child: Container(height: 56, color: Colors.white),
                    )
                  : DropdownButtonFormField<Map<String, dynamic>>(
                      decoration: const InputDecoration(
                        labelText: 'Select Pet',
                        border: OutlineInputBorder(),
                      ),
                      initialValue: _selectedPet,
                      items: _userPets
                          .map((pet) => DropdownMenuItem(
                                value: pet,
                                child: Text(pet['name'] ?? 'Unknown'),
                              ))
                          .toList(),
                      onChanged: (val) {
                        setState(() => _selectedPet = val);
                      },
                    ),
              const SizedBox(height: 12),
              if (_selectedPet != null)
                Card(
                  elevation: 1,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Name: ${_selectedPet!['name'] ?? ''}"),
                        const SizedBox(height: 4),
                        Text("Age: ${_selectedPet!['age'] ?? ''}"),
                        const SizedBox(height: 4),
                        Text("Species: ${_selectedPet!['species'] ?? ''}"),
                        const SizedBox(height: 4),
                        Text("Breed: ${_selectedPet!['breed'] ?? ''}"),
                        const SizedBox(height: 4),
                        Text("Gender: ${_selectedPet!['gender'] ?? ''}"),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 12),
              _loadingVets
                  ? Shimmer.fromColors(
                      baseColor: Colors.grey[300]!,
                      highlightColor: Colors.grey[100]!,
                      child: Container(height: 56, color: Colors.white),
                    )
                  : DropdownButtonFormField<Map<String, dynamic>>(
                      decoration: const InputDecoration(
                        labelText: 'Select Vet',
                        border: OutlineInputBorder(),
                      ),
                      initialValue: _selectedVet,
                      items: _vets
                          .map((vet) => DropdownMenuItem(
                                value: vet,
                                child: Text(vet['vetName'] ?? 'Unknown'),
                              ))
                          .toList(),
                      onChanged: (val) {
                        setState(() {
                          _selectedVet = val;
                          _selectedDate = null;
                          _selectedTime = null;
                          _availableTimes.clear();
                        });
                      },
                    ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: _selectedVet == null ? null : _pickDate,
                icon: const Icon(Icons.calendar_today),
                label: Text(_selectedDate == null
                    ? "Select Appointment Date"
                    : "Date: ${DateFormat('yyyy-MM-dd').format(_selectedDate!)}"),
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: (_availableTimes.isNotEmpty && _selectedDate != null) ? _pickTime : null,
                icon: const Icon(Icons.access_time),
                label: Text(_selectedTime == null ? "Select Time" : "Time: $_selectedTime"),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _illnessController,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Pet Illness / Notes',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 20),
              _saving
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton(
                      onPressed: _saveAppointment,
                      style: ElevatedButton.styleFrom(padding: const EdgeInsets.all(14)),
                      child: const Text("Save Appointment"),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}
