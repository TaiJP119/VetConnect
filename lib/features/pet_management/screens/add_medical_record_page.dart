import 'dart:io';
import 'package:VetApp/features/user_auth/presentation/pages/add_event_page.dart';
import 'package:VetApp/services/notification_service.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

import '../models/medical_record_model.dart';

class AddMedicalRecordPage extends StatefulWidget {
  final String petId;
  const AddMedicalRecordPage({super.key, required this.petId});

  @override
  State<AddMedicalRecordPage> createState() => _AddMedicalRecordPageState();
}

class _AddMedicalRecordPageState extends State<AddMedicalRecordPage> {
  final _formKey = GlobalKey<FormState>();
  MedicalRecordType _selectedType = MedicalRecordType.medicalHistory;
  DateTime _selectedDate = DateTime.now();
  DateTime? _nextVisitDateTime;
  Map<String, dynamic> _formData = {};
  List<PlatformFile> _selectedFiles = [];
  List<UploadTask> _uploadTasks = [];

  // Pick Date
  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  // Pick next visit date + time
  Future<void> _pickNextVisitDateTime() async {
    // Pick date
    final date = await showDatePicker(
      context: context,
      initialDate: _nextVisitDateTime ?? DateTime.now().add(Duration(days: 30)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(Duration(days: 365)),
    );
    if (date == null) return;
    // Pick time
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_nextVisitDateTime ?? DateTime.now()),
    );
    if (time == null) return;
    setState(() {
      _nextVisitDateTime = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
  }

  // Pick files
  Future<void> _pickFiles() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      withData: true,
    );
    if (result != null) {
      setState(() => _selectedFiles = result.files);
    }
  }

  // Upload files
  Future<List<String>> _uploadFiles() async {
    List<String> urls = [];
    final userId = FirebaseAuth.instance.currentUser!.uid;
    for (var file in _selectedFiles) {
      final fileName = '${DateTime.now().millisecondsSinceEpoch}_${file.name}';
      final ref = FirebaseStorage.instance
          .ref()
          .child('users/$userId/pets/${widget.petId}/records/$fileName');
      UploadTask task;
      if (file.bytes != null && file.bytes!.isNotEmpty) {
        task = ref.putData(file.bytes!);
      } else if (file.path != null && File(file.path!).existsSync()) {
        task = ref.putFile(File(file.path!));
      } else {
        continue;
      }
      setState(() => _uploadTasks.add(task));
      await task.whenComplete(() {});
      urls.add(await ref.getDownloadURL());
    }
    return urls;
  }

  // Save record
  Future<void> _saveRecord() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();
    try {
      List<String> fileUrls = [];
      if (_selectedFiles.isNotEmpty) fileUrls = await _uploadFiles();

      final userId = FirebaseAuth.instance.currentUser!.uid;

      // Determine nextVisitDate
      DateTime? nextVisitDateTime;
      if (_nextVisitDateTime != null) {
        nextVisitDateTime = _nextVisitDateTime;
      } else if (_selectedType == MedicalRecordType.ectoparasite) {
        nextVisitDateTime = _selectedDate.add(const Duration(days: 30));
      } else if (_selectedType == MedicalRecordType.worm) {
        nextVisitDateTime = _selectedDate.add(const Duration(days: 90));
      } else if (_selectedType == MedicalRecordType.vaccination) {
        nextVisitDateTime = _selectedDate.add(const Duration(days: 360));
      }

      if (nextVisitDateTime != null) {
        _formData['nextVisitDate'] = nextVisitDateTime;
      }

      final record = MedicalRecord(
        type: _selectedType,
        date: _selectedDate,
        data: _formData,
        fileUrls: fileUrls,
      );

      // Get pet name for calendar event
      final petSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('pets')
          .doc(widget.petId)
          .get();
      final petName = petSnapshot.data()?['name'] ?? 'Unknown Pet';

      final docRef = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('pets')
          .doc(widget.petId)
          .collection('records')
          .add(record.toJson());

      // Calendar event creation
      if (nextVisitDateTime != null) {
        Map<String, dynamic> eventData = {
          'title': 'Next Visit - ${medicalRecordTypeToString(_selectedType)}',
          'petName': petName,
          'date': Timestamp.fromDate(nextVisitDateTime),
          'recordId': docRef.id,
        };

        final eventRef = await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .collection('events')
            .add(eventData);

        // Set eventId for notification management
        await eventRef.update({'eventId': eventRef.id});
        await NotificationService.scheduleMultiStageNotifications(
          eventId: eventRef.id,
          title: eventData['title'] as String,
          dateTime: nextVisitDateTime,
        );
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Record saved successfully ✅")),
      );
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to save record: $e")),
      );
    }
  }

  // Fields UI for each type
  List<Widget> _fieldsByType() {
    switch (_selectedType) {
      case MedicalRecordType.medicalHistory:
        return [
          TextFormField(
            decoration:
                const InputDecoration(labelText: "Procedure or Medicine"),
            onSaved: (v) => _formData['procedureOrMedicine'] = v,
            validator: (v) => v == null || v.isEmpty ? 'Required' : null,
          ),
        ];
      case MedicalRecordType.ectoparasite:
        return [
          TextFormField(
            decoration: const InputDecoration(labelText: "Medicine Name"),
            onSaved: (v) => _formData['medicineName'] = v,
            validator: (v) => v == null || v.isEmpty ? 'Required' : null,
          ),
          // UI to pick nextVisitDateTime:
          ListTile(
            title: Text(_nextVisitDateTime != null
                ? "Next Visit: ${DateFormat('dd-MM-yyyy HH:mm').format(_nextVisitDateTime!)}"
                : "Pick Next Visit Date & Time (optional)"),
            leading: Icon(Icons.calendar_today),
            onTap: _pickNextVisitDateTime,
          ),
        ];
      case MedicalRecordType.worm:
        return [
          TextFormField(
            decoration: const InputDecoration(labelText: "Medicine Name"),
            onSaved: (v) => _formData['medicineName'] = v,
            validator: (v) => v == null || v.isEmpty ? 'Required' : null,
          ),
          // UI to pick nextVisitDateTime:
          ListTile(
            title: Text(_nextVisitDateTime != null
                ? "Next Visit: ${DateFormat('dd-MM-yyyy HH:mm').format(_nextVisitDateTime!)}"
                : "Pick Next Visit Date & Time (optional)"),
            leading: Icon(Icons.calendar_today),
            onTap: _pickNextVisitDateTime,
          ),
        ];
      case MedicalRecordType.heartworm:
        return [
          DropdownButtonFormField<String>(
            decoration: const InputDecoration(labelText: "Result"),
            items: const [
              DropdownMenuItem(value: "POS", child: Text("POS")),
              DropdownMenuItem(value: "NEG", child: Text("NEG")),
            ],
            onChanged: (v) => _formData['result'] = v,
            onSaved: (v) => _formData['result'] = v,
            validator: (v) => v == null || v.isEmpty ? 'Required' : null,
          ),
          TextFormField(
            decoration: const InputDecoration(labelText: "Comments"),
            onSaved: (v) => _formData['comments'] = v,
          ),
        ];
      case MedicalRecordType.notes:
        return [
          TextFormField(
            decoration: const InputDecoration(labelText: "Comments"),
            onSaved: (v) => _formData['comments'] = v,
          ),
        ];
      case MedicalRecordType.vaccination:
        return [
          TextFormField(
            decoration: const InputDecoration(labelText: "Current Weight (kg)"),
            keyboardType: TextInputType.number,
            onSaved: (v) => _formData['weight'] = v,
          ),
          TextFormField(
            decoration:
                const InputDecoration(labelText: "Nth Dose (e.g., 1st, 2nd)"),
            onSaved: (v) => _formData['dose'] = v,
          ),
          TextFormField(
            decoration: const InputDecoration(labelText: "Vaccine Name"),
            onSaved: (v) => _formData['vaccineName'] = v,
          ),
          // UI to pick nextVisitDateTime:
          ListTile(
            title: Text(_nextVisitDateTime != null
                ? "Next Visit: ${DateFormat('dd-MM-yyyy HH:mm').format(_nextVisitDateTime!)}"
                : "Pick Next Visit Date & Time (optional)"),
            leading: Icon(Icons.calendar_today),
            onTap: _pickNextVisitDateTime,
          ),
        ];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Medical Record')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              DropdownButtonFormField<MedicalRecordType>(
                value: _selectedType,
                decoration: const InputDecoration(labelText: "Record Type"),
                items: MedicalRecordType.values
                    .map((type) => DropdownMenuItem(
                          value: type,
                          child: Text(medicalRecordTypeToString(type)),
                        ))
                    .toList(),
                onChanged: (type) {
                  setState(() {
                    _selectedType = type!;
                    _formData = {};
                  });
                },
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Text(
                        'Date: ${DateFormat('dd-MM-yyyy').format(_selectedDate)}'),
                  ),
                  TextButton(
                      onPressed: _pickDate, child: const Text("Pick Date")),
                ],
              ),
              ..._fieldsByType(),
              const SizedBox(height: 16),
              Row(
                children: [
                  ElevatedButton(
                      onPressed: _pickFiles,
                      child: const Text("Pick Attachments 📎")),
                  const SizedBox(width: 8),
                  Text('${_selectedFiles.length} file(s) selected'),
                ],
              ),
              const SizedBox(height: 16),
              if (_uploadTasks.isNotEmpty)
                ..._uploadTasks.map((task) => StreamBuilder<TaskSnapshot>(
                      stream: task.snapshotEvents,
                      builder: (context, snapshot) {
                        if (snapshot.hasData) {
                          final progress = snapshot.data!.bytesTransferred /
                              snapshot.data!.totalBytes;
                          final percent = (progress * 100).toStringAsFixed(0);
                          return Text('Uploading... $percent%');
                        } else {
                          return const SizedBox();
                        }
                      },
                    )),
              const SizedBox(height: 24),
              ElevatedButton(
                  onPressed: _saveRecord, child: const Text('Save Record')),
            ],
          ),
        ),
      ),
    );
  }
}
