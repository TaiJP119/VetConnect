import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminManagementPage extends StatefulWidget {
  @override
  _AdminManagementPageState createState() => _AdminManagementPageState();
}

class _AdminManagementPageState extends State<AdminManagementPage> {
  final TextEditingController _searchController = TextEditingController();
  String _roleFilter = 'all';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Admin Management"),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: 'Search by username or email',
                border: OutlineInputBorder(),
              ),
            ),
          ),
          Row(
            children: [
              DropdownButton<String>(
                value: _roleFilter,
                items: ['all', 'admin', 'customer', 'vet']
                    .map((role) => DropdownMenuItem(
                          value: role,
                          child: Text(role),
                        ))
                    .toList(),
                onChanged: (value) {
                  setState(() {
                    _roleFilter = value!;
                  });
                },
              ),
            ],
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .where('userRole',
                      isEqualTo: _roleFilter != 'all' ? _roleFilter : null)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const CircularProgressIndicator();
                final users = snapshot.data!.docs;

                return ListView.builder(
                  itemCount: users.length,
                  itemBuilder: (context, index) {
                    final user = users[index].data() as Map<String, dynamic>;

                    return ListTile(
                      title: Text(user['username'] ?? 'Unnamed'),
                      subtitle: Text(user['email'] ?? 'No email'),
                      trailing: user['userRole'] == 'admin'
                          ? Text('Admin')
                          : ElevatedButton(
                              onPressed: () async {
                                await FirebaseFirestore.instance
                                    .collection('users')
                                    .doc(users[index].id)
                                    .update({'userRole': 'admin'});

                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content: Text('User promoted to Admin')),
                                );
                              },
                              child: const Text('Promote to Admin'),
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
