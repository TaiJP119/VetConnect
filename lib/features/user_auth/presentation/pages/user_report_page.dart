import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';

class UserReportPage extends StatefulWidget {
  @override
  _UserReportPageState createState() => _UserReportPageState();
}

class _UserReportPageState extends State<UserReportPage> {
  final TextEditingController _descriptionController = TextEditingController();
  String _selectedIssueType = "General Issue";
  File? _selectedImage;
  final picker = ImagePicker();

  void _submitReport() async {
    final userId = FirebaseAuth.instance.currentUser!.uid;
    final description = _descriptionController.text.trim();
    final user = FirebaseAuth.instance.currentUser!;
    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();
    final username = userDoc.data()?['username'] ?? user.email;
    String? imageUrl;

    if (description.isNotEmpty) {
      // Clear the form after submission
      _descriptionController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Report submitted successfully.")),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please provide a description.")),
      );
    }
    if (_selectedImage != null) {
      final userId = FirebaseAuth.instance.currentUser!.uid;
      final imageRef = FirebaseStorage.instance
          .ref()
          .child("report_images")
          .child(userId)
          .child("${DateTime.now().millisecondsSinceEpoch}.jpg");

      await imageRef.putFile(_selectedImage!);
      imageUrl = await imageRef.getDownloadURL();
    }

    await FirebaseFirestore.instance.collection('userReports').add({
      'userId': userId, // store UID
      'username': username, // store username instead of UID
      'description': description,
      'issueType': _selectedIssueType,
      'status': 'Open',
      'timestamp': FieldValue.serverTimestamp(),
      'imageUrl': imageUrl,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Submit a Report")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Issue Type:"),
            DropdownButton<String>(
              value: _selectedIssueType,
              items: <String>[
                'General Issue',
                'Bug Report',
                'Technical Issue',
                'Other'
              ].map((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(value),
                );
              }).toList(),
              onChanged: (newValue) {
                setState(() {
                  _selectedIssueType = newValue!;
                });
              },
            ),
            const SizedBox(height: 20),
            const Text("Description:"),
            TextField(
              controller: _descriptionController,
              decoration:
                  const InputDecoration(hintText: "Describe the issue..."),
              maxLines: 5,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _submitReport,
              child: const Text("Submit Report"),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () async {
                final picked =
                    await picker.pickImage(source: ImageSource.gallery);
                if (picked != null) {
                  setState(() => _selectedImage = File(picked.path));
                }
              },
              child: Text("Attach Image"),
            ),
            if (_selectedImage != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Image.file(_selectedImage!, height: 100),
              ),
          ],
        ),
      ),
    );
  }
}
