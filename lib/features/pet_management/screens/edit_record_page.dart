import 'dart:io';

import 'package:VetApp/features/pet_management/models/health_record_model.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class EditRecordPage extends StatefulWidget {
  final String petId;
  final HealthRecord record;

  const EditRecordPage({super.key, required this.petId, required this.record});

  @override
  State<EditRecordPage> createState() => _EditRecordPageState();
}

class _EditRecordPageState extends State<EditRecordPage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _noteController;
  DateTime? _selectedDate;
  List<PlatformFile> _newFiles = [];

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.record.title);
    _noteController = TextEditingController(text: widget.record.note ?? '');
    _selectedDate = DateTime.tryParse(widget.record.date ?? '');
  }

  Future<void> _pickFiles() async {
    final result = await FilePicker.platform.pickFiles(allowMultiple: true);
    if (result != null) {
      setState(() {
        _newFiles = result.files;
      });
    }
  }

  Future<List<String>> _uploadFiles(String recordId) async {
    final userId = FirebaseAuth.instance.currentUser!.uid;
    final storage = FirebaseStorage.instance;
    final urls = <String>[];

    for (final file in _newFiles) {
      final ref = storage.ref().child(
          'users/$userId/pets/${widget.petId}/records/$recordId/${file.name}');
      final uploadTask = ref.putFile(File(file.path!));
      final snapshot = await uploadTask;
      final url = await snapshot.ref.getDownloadURL();
      urls.add(url);
    }
    return urls;
  }

  Future<void> _saveRecord() async {
    if (_formKey.currentState!.validate()) {
      final userId = FirebaseAuth.instance.currentUser!.uid;
      final docRef = FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('pets')
          .doc(widget.petId)
          .collection('records')
          .doc(widget.record.id);

      List<String> fileUrls = widget.record.fileUrls;

      if (_newFiles.isNotEmpty) {
        // Optionally delete old files
        for (String oldUrl in fileUrls) {
          try {
            final ref = FirebaseStorage.instance.refFromURL(oldUrl);
            await ref.delete();
          } catch (e) {
            print('Error deleting old file: $e');
          }
        }

        // Upload new files
        fileUrls = await _uploadFiles(widget.record.id!);
      }

      final updatedRecord = {
        'title': _titleController.text.trim(),
        'date': _selectedDate!.toIso8601String(),
        'note': _noteController.text.trim(),
        'fileUrls': fileUrls,
      };

      await docRef.update(updatedRecord);
      Navigator.pop(context);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Edit Record'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _titleController,
                decoration: InputDecoration(labelText: 'Title'),
                validator: (val) =>
                    val == null || val.isEmpty ? 'Enter title' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _noteController,
                decoration: InputDecoration(labelText: 'Note'),
                maxLines: 3,
              ),
              const SizedBox(height: 12),
              ListTile(
                title: Text(
                  _selectedDate != null
                      ? 'Date: ${_selectedDate!.toLocal().toString().split(' ')[0]}'
                      : 'Select Date',
                ),
                trailing: Icon(Icons.calendar_today),
                onTap: () async {
                  final pickedDate = await showDatePicker(
                    context: context,
                    initialDate: _selectedDate ?? DateTime.now(),
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                  );
                  if (pickedDate != null) {
                    setState(() {
                      _selectedDate = pickedDate;
                    });
                  }
                },
              ),
              const SizedBox(height: 12),
              Text(
                'Existing Attachments:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              ...widget.record.fileUrls.map((url) => ListTile(
                    title: Text(url.split('/').last),
                    trailing: Icon(Icons.file_present),
                    onTap: () async {
                      // Optional: preview file externally
                    },
                  )),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: _pickFiles,
                icon: Icon(Icons.attach_file),
                label: Text('Pick New Files'),
              ),
              const SizedBox(height: 12),
              if (_newFiles.isNotEmpty) ...[
                Text(
                  'New Files:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                ..._newFiles.map((f) => ListTile(
                      title: Text(f.name),
                      leading: Icon(Icons.insert_drive_file),
                    )),
              ],
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _saveRecord,
                child: Text('Save Changes'),
              )
            ],
          ),
        ),
      ),
    );
  }
}
