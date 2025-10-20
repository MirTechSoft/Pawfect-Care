import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class HealthTrackingScreen extends StatefulWidget {
  const HealthTrackingScreen({super.key});

  @override
  State<HealthTrackingScreen> createState() => _HealthTrackingScreenState();
}

class _HealthTrackingScreenState extends State<HealthTrackingScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _filterType = "All";

  @override
  Widget build(BuildContext context) {
    final currentVetId = FirebaseAuth.instance.currentUser?.uid ?? "";

    return Scaffold(
      backgroundColor: Colors.pink.shade50,
      appBar: AppBar(
        title: const Text("Health Record",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.pink,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: "Search (Pet / Owner / Date)",
                      prefixIcon: const Icon(Icons.search, color: Colors.pink),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: DropdownButton<String>(
                    value: _filterType,
                    underline: const SizedBox(),
                    items: ["All", "Pet", "Owner", "Date"]
                        .map((f) => DropdownMenuItem(
                              value: f,
                              child: Text(f,
                                  style: const TextStyle(color: Colors.black)),
                            ))
                        .toList(),
                    onChanged: (val) {
                      setState(() {
                        _filterType = val!;
                      });
                    },
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('appointments')
                  .where('vetId', isEqualTo: currentVetId)
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                      child: CircularProgressIndicator(color: Colors.pink));
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text("No Appointments"));
                }

                final searchQuery =
                    _searchController.text.toLowerCase().trim();

                final docs = snapshot.data!.docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final petName = (data['petName'] ?? '').toString().toLowerCase();
                  final ownerName =
                      (data['ownerName'] ?? '').toString().toLowerCase();
                  final date = (data['date'] ?? '').toString().toLowerCase();

                  return petName.contains(searchQuery) ||
                      ownerName.contains(searchQuery) ||
                      date.contains(searchQuery);
                }).toList();

                if (docs.isEmpty) {
                  return const Center(child: Text("No Appointments Found"));
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final data = docs[index].data() as Map<String, dynamic>;
                    final id = data['id'] ?? '';
                    final petName = data['petName'] ?? '';
                    final ownerName = data['ownerName'] ?? '';
                    final vetName = data['vetName'] ?? '';
                    final petImageUrl = data['petImageUrl'] ??
                        "https://cdn-icons-png.flaticon.com/512/616/616408.png";
                    final date = data['date'] ?? '';
                    final time = data['time'] ?? '';
                    final statusValue = (data['status'] ?? 'pending').toString();

                    return Card(
                      color: Colors.pink.shade50,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundImage: NetworkImage(petImageUrl),
                          radius: 25,
                        ),
                        title: Text(
                          "$petName (#$id)",
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, color: Colors.black),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("Owner: $ownerName"),
                            Text("Vet: $vetName"),
                            Text("Date: $date $time"),
                            Text("Status: ${statusValue.toUpperCase()}"),
                          ],
                        ),
                        trailing: PopupMenuButton<String>(
                          icon: const Icon(Icons.more_vert, color: Colors.black),
                          onSelected: (val) async {
                            if (val == "edit") {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => HealthRecordEditPage(
                                      appointmentData: data, appointmentId: id),
                                ),
                              );
                            } else if (val == "delete") {
                              final recordQuery = await FirebaseFirestore.instance
                                  .collection('health_records')
                                  .where('appointmentId', isEqualTo: id)
                                  .get();

                              for (var doc in recordQuery.docs) {
                                await FirebaseFirestore.instance
                                    .collection('health_records')
                                    .doc(doc.id)
                                    .delete();
                              }

                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text("Health record deleted"),
                                    duration: Duration(seconds: 1),
                                  ),
                                );
                              }
                            }
                          },
                          itemBuilder: (context) => const [
                            PopupMenuItem(value: "edit", child: Text("Edit")),
                            PopupMenuItem(value: "delete", child: Text("Delete")),
                          ],
                        ),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  HealthRecordDetailPage(appointmentData: data),
                            ),
                          );
                        },
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
class HealthRecordEditPage extends StatefulWidget {
  final Map<String, dynamic> appointmentData;
  final String appointmentId;

  const HealthRecordEditPage(
      {super.key, required this.appointmentData, required this.appointmentId});

  @override
  State<HealthRecordEditPage> createState() => _HealthRecordEditPageState();
}

class _HealthRecordEditPageState extends State<HealthRecordEditPage> {
  late TextEditingController vaccineController;
  late TextEditingController prescriptionController;
  late TextEditingController diagnosisController;

  @override
  void initState() {
    super.initState();
    vaccineController =
        TextEditingController(text: widget.appointmentData['vaccine'] ?? '');
    prescriptionController =
        TextEditingController(text: widget.appointmentData['prescription'] ?? '');
    diagnosisController =
        TextEditingController(text: widget.appointmentData['diagnosis'] ?? '');
  }
  Future<void> _saveHealthRecord() async {
  final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? "";
  await FirebaseFirestore.instance.collection('health_records').add({
    'appointmentId': widget.appointmentId,
    'petName': widget.appointmentData['petName'] ?? '',
    'ownerName': widget.appointmentData['ownerName'] ?? '',
    'ownerId': widget.appointmentData['ownerId'] ?? '', // <-- add ownerId
    'vetName': widget.appointmentData['vetName'] ?? '',
    'vetId': currentUserId, // <-- add vetId
    'date': widget.appointmentData['date'] ?? '',
    'time': widget.appointmentData['time'] ?? '',
    'vaccine': vaccineController.text,
    'prescription': prescriptionController.text,
    'diagnosis': diagnosisController.text,
    'createdAt': FieldValue.serverTimestamp(),
  });

  if (mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Health record saved")),
    );
  }

  Navigator.pop(context);
}


  @override
  Widget build(BuildContext context) {
    final pet = widget.appointmentData;
    return Scaffold(
      appBar: AppBar(
        title: const Text("Edit Health Record"),
        backgroundColor: Colors.pink,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text("Pet: ${pet['petName'] ?? ''}", style: const TextStyle(fontSize: 18)),
          Text("Owner: ${pet['ownerName'] ?? ''}", style: const TextStyle(fontSize: 18)),
          Text("Vet: ${pet['vetName'] ?? ''}", style: const TextStyle(fontSize: 18)),
          const SizedBox(height: 16),
          TextField(
            controller: vaccineController,
            decoration: const InputDecoration(labelText: "Vaccine"),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: prescriptionController,
            decoration: const InputDecoration(labelText: "Prescription"),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: diagnosisController,
            decoration: const InputDecoration(labelText: "Diagnosis/Notes"),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _saveHealthRecord,
            style: ElevatedButton.styleFrom(backgroundColor: Colors.pink),
            child: const Text("Save Health Record"),
          ),
        ],
      ),
    );
  }
}
class HealthRecordDetailPage extends StatelessWidget {
  final Map<String, dynamic> appointmentData;
  const HealthRecordDetailPage({super.key, required this.appointmentData});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Health Record Details"),
        backgroundColor: Colors.pink,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text("Pet: ${appointmentData['petName'] ?? ''}", style: const TextStyle(fontSize: 18)),
          Text("Owner: ${appointmentData['ownerName'] ?? ''}", style: const TextStyle(fontSize: 18)),
          Text("Vet: ${appointmentData['vetName'] ?? ''}", style: const TextStyle(fontSize: 18)),
          Text("Date: ${appointmentData['date'] ?? ''}", style: const TextStyle(fontSize: 16)),
          Text("Time: ${appointmentData['time'] ?? ''}", style: const TextStyle(fontSize: 16)),
          const SizedBox(height: 16),
          Text("Vaccine: ${appointmentData['vaccine'] ?? ''}", style: const TextStyle(fontSize: 16)),
          Text("Prescription: ${appointmentData['prescription'] ?? ''}", style: const TextStyle(fontSize: 16)),
          Text("Diagnosis/Notes: ${appointmentData['diagnosis'] ?? ''}", style: const TextStyle(fontSize: 16)),
        ],
      ),
    );
  }
}
