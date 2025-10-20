import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class Appointment {
  final String id;
  final String petName;
  final String vetName;
  final String petImage;
  final String date;
  final String time;
  String status;

  Appointment({
    required this.id,
    required this.petName,
    required this.vetName,
    required this.petImage,
    required this.date,
    required this.time,
    this.status = "pending",
  });
}

class AppointmentScreen extends StatefulWidget {
  const AppointmentScreen({super.key});

  @override
  State<AppointmentScreen> createState() => _AppointmentScreenState();
}

class _AppointmentScreenState extends State<AppointmentScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String _filterType = "All";

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this, initialIndex: 0);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.pink.shade50,
      appBar: AppBar(
        title: const Text(
          "Appointments",
          style: TextStyle(
              color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.pink,
        iconTheme: const IconThemeData(color: Colors.white),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(100),
          child: Column(
            children: [
              // Fixed Search + Filter
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: "Search (Pet / Vet / Date)",
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
                        items: ["All", "Pet", "Vet", "Date"]
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
              // Tabs
              TabBar(
                controller: _tabController,
                indicatorColor: Colors.white,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white70,
                tabs: const [
                  Tab(text: "Pending"),
                  Tab(text: "Approved"),
                  Tab(text: "Completed"),
                  Tab(text: "Cancelled"),
                ],
              ),
            ],
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          AppointmentList(status: "pending"),
          AppointmentList(status: "approved"),
          AppointmentList(status: "completed"),
          AppointmentList(status: "cancelled"),
        ],
      ),
    );
  }
}

class AppointmentList extends StatelessWidget {
  final String status;
  const AppointmentList({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final searchQuery = (context
            .findAncestorStateOfType<_AppointmentScreenState>()
            ?._searchController
            .text
            .toLowerCase() ??
        "");

    final currentVetId = FirebaseAuth.instance.currentUser?.uid ?? "";

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('appointments')
          .where('vetId', isEqualTo: currentVetId)
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: Colors.pink),
          );
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text("No Appointments"));
        }

        final docs = snapshot.data!.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final apptStatus = (data['status'] ?? 'pending').toString().toLowerCase();

          final statusMatches = status == "all" || apptStatus == status;

          final petName = (data['petName'] ?? '').toString().toLowerCase();
          final vetName = (data['vetName'] ?? '').toString().toLowerCase();
          final date = (data['date'] ?? '').toString().toLowerCase();

          final searchMatches = petName.contains(searchQuery) ||
              vetName.contains(searchQuery) ||
              date.contains(searchQuery);

          return statusMatches && searchMatches;
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
                    Text("Vet: $vetName"),
                    Text("Date: $date $time"),
                    Text("Status: ${statusValue.toUpperCase()}"),
                  ],
                ),
                trailing: PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, color: Colors.black),
                  onSelected: (val) async {
                    bool confirm = true;
                    if (val == "cancel") {
                      confirm = await showDialog(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text("Cancel Appointment"),
                          content: const Text(
                              "Are you sure you want to cancel this appointment?"),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: const Text("No"),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, true),
                              child: const Text("Yes"),
                            ),
                          ],
                        ),
                      );
                    }

                    if (confirm != true) return;

                    if (val == "cancel") {
                      await FirebaseFirestore.instance
                          .collection('appointments')
                          .doc(id)
                          .update({'status': 'cancelled'});
                    } else if (val == "approved") {
                      await FirebaseFirestore.instance
                          .collection('appointments')
                          .doc(id)
                          .update({'status': 'approved'});
                    } else if (val == "completed") {
                      await FirebaseFirestore.instance
                          .collection('appointments')
                          .doc(id)
                          .update({'status': 'completed'});
                    }
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(value: "approved", child: Text("Approve")),
                    PopupMenuItem(value: "completed", child: Text("Complete")),
                    PopupMenuItem(value: "cancel", child: Text("Cancel")),
                  ],
                ),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AppointmentDetailPageFirestore(
                          appointmentId: id, data: data),
                    ),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }
}
class AppointmentDetailPageFirestore extends StatefulWidget {
  final String appointmentId;
  final Map<String, dynamic> data;
  final bool isEdit;

  const AppointmentDetailPageFirestore({
    super.key,
    required this.appointmentId,
    required this.data,
    this.isEdit = false,
  });

  @override
  State<AppointmentDetailPageFirestore> createState() =>
      _AppointmentDetailPageFirestoreState();
}

class _AppointmentDetailPageFirestoreState
    extends State<AppointmentDetailPageFirestore> {
  late TextEditingController illnessController;
  String status = "pending";
  DateTime? selectedDate;

  @override
  void initState() {
    super.initState();
    illnessController = TextEditingController(text: widget.data['illness'] ?? '');
    status = widget.data['status'] ?? 'pending';
    final dateStr = widget.data['date'] ?? '';
    selectedDate = dateStr.isNotEmpty ? DateTime.parse(dateStr) : DateTime.now();
  }

  Future<void> _saveChanges() async {
    await FirebaseFirestore.instance
        .collection('appointments')
        .doc(widget.appointmentId)
        .update({
      'illness': illnessController.text,
    });
    Navigator.pop(context);
  }

  Future<void> _confirmAction(String action) async {
    final result = await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("${action[0].toUpperCase()}${action.substring(1)} Appointment"),
        content: Text("Are you sure you want to $action this appointment?"),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text("No")),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text("Yes")),
        ],
      ),
    );

    if (result == true) {
      if (action == "delete") {
        await FirebaseFirestore.instance
            .collection('appointments')
            .doc(widget.appointmentId)
            .delete();
      } else if (action == "cancel") {
        await FirebaseFirestore.instance
            .collection('appointments')
            .doc(widget.appointmentId)
            .update({'status': 'cancelled'});
      }
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pet = widget.data;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEdit ? "Edit Appointment" : "Appointment Details",
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.pink,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          if (widget.isEdit)
            IconButton(
                onPressed: () => _confirmAction("delete"),
                icon: const Icon(Icons.delete, color: Colors.white)),
          if (widget.isEdit)
            IconButton(
                onPressed: () => _confirmAction("cancel"),
                icon: const Icon(Icons.cancel, color: Colors.white)),
        ],
      ),
      body: ListView(
        children: [
          Container(
            height: 180,
            decoration: BoxDecoration(
              image: DecorationImage(
                image: NetworkImage(pet['petImageUrl'] ?? ''),
                fit: BoxFit.cover,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Pet Name: ${pet['petName'] ?? ''}",
                    style: const TextStyle(fontSize: 16)),
                Text("Owner Name: ${pet['ownerName'] ?? ''}",
                    style: const TextStyle(fontSize: 16)),
                Text("Vet Name: ${pet['vetName'] ?? ''}",
                    style: const TextStyle(fontSize: 16)),
                Text(
                    "Appointment: ${pet['date'] ?? ''} at ${pet['time'] ?? ''}",
                    style: const TextStyle(fontSize: 16)),
                Text("Status: ${status.toUpperCase()}",
                    style: const TextStyle(fontSize: 16)),
                const SizedBox(height: 12),
                TextFormField(
                  controller: illnessController,
                  decoration: const InputDecoration(labelText: "Illness"),
                  enabled: widget.isEdit,
                ),
                const SizedBox(height: 16),
                const Text("Pet Details:",
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.pink)),
                const SizedBox(height: 8),
                Text("Age: ${pet['age'] ?? ''}"),
                Text("Breed: ${pet['breed'] ?? ''}"),
                Text("Species: ${pet['species'] ?? ''}"),
                Text("Gender: ${pet['gender'] ?? ''}"),
              ],
            ),
          ),
          if (widget.isEdit)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.pink),
                onPressed: _saveChanges,
                child: const Text("Save Changes"),
              ),
            ),
        ],
      ),
    );
  }
}
