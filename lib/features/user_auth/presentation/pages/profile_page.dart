import 'package:VetApp/features/user_auth/presentation/pages/user_report_history_page.dart';
import 'package:VetApp/features/user_auth/presentation/pages/user_report_page.dart';
import 'package:VetApp/features/user_auth/presentation/pages/user_report_tab_view.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../global/common/toast.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  User? user;
  Map<String, dynamic>? userData;
  bool isLoading = true;
  bool isEditing = false;

  final _formKey = GlobalKey<FormState>();

  // Editable fields
  late TextEditingController _usernameController;
  late TextEditingController _contactController;
  late TextEditingController _locationController;
  late TextEditingController _contactPrefController;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    user = _auth.currentUser;

    if (user != null) {
      final doc = await _firestore.collection('users').doc(user!.uid).get();
      userData = doc.data();

      _usernameController =
          TextEditingController(text: userData?['username'] ?? '');
      _contactController =
          TextEditingController(text: userData?['contact'] ?? '');
      _locationController =
          TextEditingController(text: userData?['address'] ?? '');

      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _saveProfile() async {
    if (_formKey.currentState!.validate()) {
      final userDoc = _firestore.collection('users').doc(user!.uid);

      final docSnapshot = await userDoc.get();
      final dataToSave = {
        'username': _usernameController.text.trim(),
        'contact': _contactController.text.trim(),
        'address': _locationController.text.trim(),
      };

      if (docSnapshot.exists) {
        await userDoc.update(dataToSave);
      } else {
        await userDoc.set(dataToSave);
      }

      showToast(message: "Profile updated successfully!");

      setState(() {
        isEditing = false;
      });
    }
  }

  void _logout() async {
    await _auth.signOut();
    showToast(message: "Logged out successfully");
    Navigator.pushNamedAndRemoveUntil(context, "/login", (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("User Profile"),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: "Logout",
            onPressed: _logout,
          )
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              Center(
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 50,
                      backgroundImage: userData?['photoUrl'] != null
                          ? NetworkImage(userData!['photoUrl'])
                          : const AssetImage("assets/default_profile.png")
                              as ImageProvider,
                    ),
                    const SizedBox(height: 10),
                    isEditing
                        ? TextFormField(
                            controller: _usernameController,
                            decoration:
                                const InputDecoration(labelText: 'Username'),
                            validator: (value) => value == null || value.isEmpty
                                ? "Enter name"
                                : null,
                          )
                        : Text(
                            _usernameController.text,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ],
                ),
              ),
              const SizedBox(height: 30),

              // Email (readonly)
              ListTile(
                leading: const Icon(Icons.email),
                title: const Text("Email"),
                subtitle: Text(user?.email ?? "Not available"),
              ),

              // Phone
              ListTile(
                leading: const Icon(Icons.phone),
                title: const Text("Contact"),
                subtitle: isEditing
                    ? TextFormField(
                        controller: _contactController,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(
                            hintText: 'Enter contact number'),
                        validator: (value) => value == null || value.isEmpty
                            ? "Enter contact number"
                            : null,
                      )
                    : Text(_contactController.text),
              ),

              // Location
              ListTile(
                leading: const Icon(Icons.location_on),
                title: const Text("Location"),
                subtitle: isEditing
                    ? TextFormField(
                        controller: _locationController,
                        decoration:
                            const InputDecoration(hintText: 'Enter location'),
                        validator: (value) => value == null || value.isEmpty
                            ? "Enter location"
                            : null,
                      )
                    : Text(_locationController.text),
              ),

              const SizedBox(height: 20),

              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      //upserreporttabview
                      builder: (_) => const UserReportTabView(),
                    ),
                  );
                },
                child: const Text("Report Center"),
              ),

              const SizedBox(height: 20),
              // Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (!isEditing)
                    ElevatedButton.icon(
                      onPressed: () {
                        setState(() {
                          isEditing = true;
                        });
                      },
                      icon: const Icon(Icons.edit),
                      label: const Text("Edit Profile"),
                    ),
                  if (isEditing)
                    ElevatedButton.icon(
                      onPressed: _saveProfile,
                      icon: const Icon(Icons.save),
                      label: const Text("Save"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                      ),
                    ),
                  if (isEditing) const SizedBox(width: 10),
                  if (isEditing)
                    ElevatedButton.icon(
                      onPressed: () {
                        setState(() {
                          isEditing = false;
                        });
                      },
                      icon: const Icon(Icons.cancel),
                      label: const Text("Cancel"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey,
                      ),
                    ),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }
}
