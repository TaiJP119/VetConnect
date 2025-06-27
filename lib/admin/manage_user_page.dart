import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class ManageUsersPage extends StatefulWidget {
  @override
  State<ManageUsersPage> createState() => _ManageUsersPageState();
}

class _ManageUsersPageState extends State<ManageUsersPage> {
  String _selectedRole = "all"; // Start with "all" as the default
  String _searchQuery = "";

  @override
  Widget build(BuildContext context) {
    Query usersRef = FirebaseFirestore.instance.collection('users');

    // Modify the role-based filtering logic
    if (_selectedRole != "all") {
      usersRef = usersRef.where('userRole', isEqualTo: _selectedRole);
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('User Management'),
        actions: [
          IconButton(
            icon: Icon(Icons.logout),
            onPressed: () {
              // your logout logic here
              Navigator.pushNamedAndRemoveUntil(
                  context, "/login", (_) => false);
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16),
            child: Row(
              children: [
                Text("Role: "),
                DropdownButton<String>(
                  value: _selectedRole,
                  items: [
                    DropdownMenuItem(value: "all", child: Text('All Users')),
                    DropdownMenuItem(
                        value: "customer", child: Text('Customer')),
                    DropdownMenuItem(value: "vet", child: Text('Vet')),
                    DropdownMenuItem(value: "admin", child: Text('Admin')),
                  ],
                  onChanged: (v) => setState(() => _selectedRole = v!),
                ),
                SizedBox(width: 24),
                Expanded(
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: "Search username/email",
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    onChanged: (v) => setState(() => _searchQuery = v),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: usersRef.snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData)
                  return Center(child: CircularProgressIndicator());
                final docs = snapshot.data!.docs;

                // Filter by search query
                final filtered = docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final username = data['username'] ?? '';
                  final email = data['email'] ?? '';
                  return username
                          .toString()
                          .toLowerCase()
                          .contains(_searchQuery.toLowerCase()) ||
                      email
                          .toString()
                          .toLowerCase()
                          .contains(_searchQuery.toLowerCase());
                }).toList();

                if (filtered.isEmpty)
                  return Center(child: Text('No users found for this filter.'));

                return ListView.builder(
                  itemCount: filtered.length,
                  itemBuilder: (context, i) {
                    final doc = filtered[i];
                    final user = doc.data() as Map<String, dynamic>;
                    user['uid'] = doc.id; // Inject document ID as UID

                    return Card(
                      margin: EdgeInsets.symmetric(vertical: 6, horizontal: 14),
                      child: ListTile(
                        title: Text(user['username'] ?? 'Unnamed'),
                        subtitle: Text(user['email'] ?? 'No email'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: Icon(Icons.edit, color: Colors.amber),
                              onPressed: () {
                                // Pass the user object with the uid to edit the role
                                _editUserRole(context, user);
                              },
                            ),
                            IconButton(
                              icon: Icon(Icons.delete, color: Colors.red),
                              onPressed: () async {
                                await _deleteUserAccount(user['uid']);
                              },
                            ),
                          ],
                        ),
                        onTap: () => _showUserDetails(context, user),
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

  // Show user details in a dialog, including email, pets, etc.
  // Show user details in a dialog, including email, pets, etc.
  void _showUserDetails(BuildContext context, Map<String, dynamic> user) async {
    List<String> petNames = [];

    try {
      final petsSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user['uid'])
          .collection('pets')
          .get();

      petNames = petsSnapshot.docs
          .map((doc) => doc.data()['name'] ?? 'Unnamed Pet')
          .cast<String>()
          .toList();
    } catch (e) {
      petNames = ['Error loading pets'];
    }

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(user['username'] ?? 'User Details'),
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Email: ${user['email'] ?? '-'}'),
            Text('Contact: ${user['contact'] ?? '-'}'),
            Text('Address: ${user['address'] ?? '-'}'),
            Text('Username: ${user['username'] ?? '-'}'),
            Text('Role: ${user['userRole'] ?? 'customer'}'),
            SizedBox(height: 8),
            Text('Pets Added:'),
            ...petNames.map((name) => Text('- $name')).toList(),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context), child: Text('Close'))
        ],
      ),
    );
  }

  // Function to handle user role edit
  void _editUserRole(BuildContext context, Map<String, dynamic> user) {
    final TextEditingController _roleController =
        TextEditingController(text: user['userRole']);

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text('Edit User Role'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButton<String>(
                value: _roleController.text,
                items: [
                  DropdownMenuItem(value: 'customer', child: Text('Customer')),
                  DropdownMenuItem(value: 'vet', child: Text('Vet')),
                  DropdownMenuItem(value: 'admin', child: Text('Admin')),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _roleController.text = value;
                    });
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () async {
                final newRole = _roleController.text.trim().toLowerCase();
                if (newRole != 'admin' &&
                    newRole != 'customer' &&
                    newRole != 'vet') {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Invalid role")),
                  );
                  return;
                }

                try {
                  print("UID: ${user['uid']}");
                  print("New role: $newRole");

                  final userDocRef = FirebaseFirestore.instance
                      .collection('users')
                      .doc(user['uid']);
                  final userDoc = await userDocRef.get();

                  if (userDoc.exists) {
                    print("User found. Current data: ${userDoc.data()}");
                    await userDocRef.update({'userRole': newRole});
                    print("Update successful");
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text("User role updated successfully")),
                    );
                    Navigator.pop(context);
                  } else {
                    print("User not found in Firestore");
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text("User not found")),
                    );
                  }
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Error updating user role: $e")),
                  );
                }
              },
              child: Text('Save'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel'),
            ),
          ],
        ),
      ),
    );
  }

  // Function to delete user account
  Future<void> _deleteUserAccount(String userId) async {
    final confirm = await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Delete User'),
        content: Text('Are you sure you want to delete this user account?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text('Delete')),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .delete();
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("User account deleted.")));
      } catch (e) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Error deleting user.")));
      }
    }
  }
}
