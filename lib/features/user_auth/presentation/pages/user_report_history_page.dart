import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UserReportHistoryPage extends StatefulWidget {
  const UserReportHistoryPage({super.key});

  @override
  State<UserReportHistoryPage> createState() => _UserReportHistoryPageState();
}

class _UserReportHistoryPageState extends State<UserReportHistoryPage> {
  String _filterStatus = 'All';
  String? _userId;

  // Fetch the userId from FirebaseAuth instead of username
  Future<void> _loadUserId() async {
    final user = FirebaseAuth.instance.currentUser!;
    setState(() {
      _userId = user.uid; // Store userId from FirebaseAuth
    });
  }

  @override
  void initState() {
    super.initState();
    _loadUserId(); // Load userId when the page initializes
  }

  @override
  Widget build(BuildContext context) {
    if (_userId == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final query = FirebaseFirestore.instance
        .collection('userReports')
        .where('userId',
            isEqualTo: _userId!) // Query using userId, not username
        .orderBy('timestamp', descending: true);

    return Scaffold(
      appBar: AppBar(title: const Text("My Report History")),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: DropdownButtonFormField<String>(
                decoration:
                    const InputDecoration(labelText: "Filter by Status"),
                value: _filterStatus,
                items: ['All', 'Open', 'In Progress', 'Resolved', 'Ignored']
                    .map((status) =>
                        DropdownMenuItem(value: status, child: Text(status)))
                    .toList(),
                onChanged: (value) {
                  setState(() {
                    _filterStatus = value!;
                  });
                },
              ),
            ),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: query.snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  var reports = snapshot.data!.docs.where((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    return _filterStatus == 'All' ||
                        data['status'] == _filterStatus;
                  }).toList();

                  if (reports.isEmpty) {
                    return const Center(child: Text("No reports found."));
                  }

                  return ListView.builder(
                    itemCount: reports.length,
                    itemBuilder: (context, index) {
                      final data =
                          reports[index].data() as Map<String, dynamic>;

                      return Card(
                        margin: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        child: ListTile(
                          title: Text(data['issueType']),
                          subtitle: Text(
                            "Status: ${data['status']} • ${data['timestamp']?.toDate().toString().split('.')[0] ?? ''}",
                          ),
                          trailing: data['imageUrl'] != null
                              ? Image.network(data['imageUrl'],
                                  width: 60, height: 60, fit: BoxFit.cover)
                              : null,
                          onTap: () {
                            showDialog(
                              context: context,
                              builder: (_) => AlertDialog(
                                title: const Text("Report Details"),
                                content: SingleChildScrollView(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text("Type: ${data['issueType']}"),
                                      const SizedBox(height: 8),
                                      Text(
                                          "Description:\n${data['description']}"),
                                      if (data['adminReply'] != null)
                                        Padding(
                                          padding:
                                              const EdgeInsets.only(top: 8.0),
                                          child: Text(
                                              "Admin Reply:\n${data['adminReply']}"),
                                        ),
                                      if (data['imageUrl'] != null)
                                        Padding(
                                          padding:
                                              const EdgeInsets.only(top: 12.0),
                                          child:
                                              Image.network(data['imageUrl']),
                                        ),
                                    ],
                                  ),
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    child: const Text("Close"),
                                  ),
                                ],
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
      ),
    );
  }
}
