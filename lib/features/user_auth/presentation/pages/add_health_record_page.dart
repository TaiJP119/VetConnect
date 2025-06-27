import 'dart:io';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AddRecordPage extends StatefulWidget {
  final String petId;
  const AddRecordPage({super.key, required this.petId});

  @override
  State<AddRecordPage> createState() => _AddRecordPageState();
}

class _AddRecordPageState extends State<AddRecordPage> {
  final _formKey = GlobalKey<FormState>();
  String title = '';
  String note = '';
  DateTime selectedDateTime = DateTime.now();
  List<PlatformFile> _selectedFiles = [];
  List<UploadTask> _uploadTasks = [];

  // Pick Date + Time
  Future<void> _pickDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: selectedDateTime,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );

    if (date != null) {
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(selectedDateTime),
      );

      if (time != null) {
        setState(() {
          selectedDateTime = DateTime(
            date.year,
            date.month,
            date.day,
            time.hour,
            time.minute,
          );
        });
      }
    }
  }

  // Pick multiple files
  Future<void> _pickFiles() async {
    final result = await FilePicker.platform.pickFiles(allowMultiple: true);
    if (result != null) {
      setState(() {
        _selectedFiles = result.files;
      });
    }
  }

  // Upload multiple files
  Future<List<String>> _uploadFiles() async {
    List<String> downloadUrls = [];
    final userId = FirebaseAuth.instance.currentUser!.uid;

    for (var file in _selectedFiles) {
      final ref = FirebaseStorage.instance
          .ref()
          .child('users/$userId/pets/${widget.petId}/records/${DateTime.now().millisecondsSinceEpoch}_${file.name}');
      final uploadTask = ref.putData(file.bytes!);

      setState(() {
        _uploadTasks.add(uploadTask);
      });

      final snapshot = await uploadTask.whenComplete(() {});
      final url = await snapshot.ref.getDownloadURL();
      downloadUrls.add(url);
    }
    return downloadUrls;
  }

  // Save record
  Future<void> saveRecord() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();

    List<String> fileUrls = [];

    if (_selectedFiles.isNotEmpty) {
      fileUrls = await _uploadFiles();
    }

    final userId = FirebaseAuth.instance.currentUser!.uid;

    await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('pets')
        .doc(widget.petId)
        .collection('records')
        .add({
      'title': title,
      'note': note,
      'date': selectedDateTime,
      'fileUrls': fileUrls, // <-- multiple urls stored
    });

    Navigator.pop(context);
  }

  // Preview Widget
  Widget _buildFilePreview(PlatformFile file) {
    if (file.extension == 'jpg' || file.extension == 'png' || file.extension == 'jpeg') {
      return Image.memory(file.bytes!, width: 80, height: 80, fit: BoxFit.cover);
    } else if (file.extension == 'pdf') {
      return Icon(Icons.picture_as_pdf, size: 50, color: Colors.red);
    } else {
      return Icon(Icons.insert_drive_file, size: 50, color: Colors.grey);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Health Record')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // Title
              TextFormField(
                decoration: const InputDecoration(labelText: 'Title'),
                onSaved: (value) => title = value ?? '',
                validator: (value) => value!.isEmpty ? 'Please enter title' : null,
              ),
              const SizedBox(height: 8),

              // Note
              TextFormField(
                decoration: const InputDecoration(labelText: 'Note'),
                onSaved: (value) => note = value ?? '',
              ),
              const SizedBox(height: 8),

              // Pick Date + Time
              Row(
                children: [
                  Text('Selected: ${selectedDateTime.toString().substring(0, 16)}'),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _pickDateTime,
                    child: const Text('Pick Date/Time 📅'),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Pick Files
              Row(
                children: [
                  ElevatedButton(
                    onPressed: _pickFiles,
                    child: const Text('Pick Attachments 📎'),
                  ),
                  const SizedBox(width: 8),
                  Text('${_selectedFiles.length} file(s) selected'),
                ],
              ),

              const SizedBox(height: 16),

              // Show file previews
              if (_selectedFiles.isNotEmpty)
                SizedBox(
                  height: 100,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _selectedFiles.length,
                    separatorBuilder: (context, index) => const SizedBox(width: 10),
                    itemBuilder: (context, index) {
                      return _buildFilePreview(_selectedFiles[index]);
                    },
                  ),
                ),

              const SizedBox(height: 16),

              // Upload Progress
              if (_uploadTasks.isNotEmpty)
                Column(
                  children: _uploadTasks.map((task) {
                    return StreamBuilder<TaskSnapshot>(
                      stream: task.snapshotEvents,
                      builder: (context, snapshot) {
                        if (snapshot.hasData) {
                          final progress = snapshot.data!.bytesTransferred / snapshot.data!.totalBytes;
                          final percentage = (progress * 100).toStringAsFixed(0);

                          return Text('Uploading... $percentage%');
                        } else {
                          return const SizedBox();
                        }
                      },
                    );
                  }).toList(),
                ),

              const Spacer(),

              // Save Button
              ElevatedButton(
                onPressed: saveRecord,
                child: const Text('Save Record ✅'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
