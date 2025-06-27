import 'dart:io';

import 'package:VetApp/features/user_auth/presentation/pages/add_event_page.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

import '../models/medical_record_model.dart';

class EditMedicalRecordPage extends StatefulWidget {
  final String petId;
  final MedicalRecord record;

  const EditMedicalRecordPage({
    super.key,
    required this.petId,
    required this.record,
  });

  @override
  State<EditMedicalRecordPage> createState() => _EditMedicalRecordPageState();
}

class _EditMedicalRecordPageState extends State<EditMedicalRecordPage> {
  final _formKey = GlobalKey<FormState>();
  late MedicalRecordType _selectedType;
  late DateTime _selectedDate;
  late Map<String, dynamic> _formData;
  List<String> _existingFiles = [];
  List<String> _filesToRemove = [];
  List<PlatformFile> _newFiles = [];
  List<UploadTask> _uploadTasks = [];

  DateTime? _nextVisitDateTime;

  @override
  void initState() {
    super.initState();
    _selectedType = widget.record.type;
    _selectedDate = widget.record.date;
    _formData = Map<String, dynamic>.from(widget.record.data);
    _existingFiles = List<String>.from(widget.record.fileUrls);

    // Retrieve and convert the nextVisitDate (Timestamp or DateTime) to DateTime
    if (_formData['nextVisitDate'] != null) {
      final val = _formData['nextVisitDate'];
      if (val is Timestamp) {
        _nextVisitDateTime = val.toDate();
      } else if (val is DateTime) {
        _nextVisitDateTime = val;
      } else if (val is String) {
        _nextVisitDateTime = DateTime.tryParse(val);
      }
    }
  }

  // Pick new files to add
  Future<void> _pickFiles() async {
    final result = await FilePicker.platform
        .pickFiles(allowMultiple: true, withData: true);
    if (result != null) {
      setState(() {
        _newFiles = result.files;
      });
    }
  }

  // Pick next visit date + time
  Future<void> _pickNextVisitDateTime() async {
    // Pick date
    final date = await showDatePicker(
      context: context,
      initialDate:
          _nextVisitDateTime ?? DateTime.now().add(const Duration(days: 30)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
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

  // Upload new files to Firebase Storage
  Future<List<String>> _uploadFiles(String recordId) async {
    final userId = FirebaseAuth.instance.currentUser!.uid;
    final storage = FirebaseStorage.instance;
    final urls = <String>[];

    for (final file in _newFiles) {
      final fileName = '${DateTime.now().millisecondsSinceEpoch}_${file.name}';
      final ref = storage.ref().child(
          'users/$userId/pets/${widget.petId}/records/$recordId/$fileName');
      UploadTask task;
      if (file.bytes != null && file.bytes!.isNotEmpty) {
        task = ref.putData(file.bytes!);
      } else if (file.path != null && File(file.path!).existsSync()) {
        task = ref.putFile(File(file.path!));
      } else {
        continue;
      }
      setState(() => _uploadTasks.add(task));
      final snapshot = await task.whenComplete(() {});
      urls.add(await snapshot.ref.getDownloadURL());
    }
    return urls;
  }

  // Remove files from Firebase Storage
  Future<void> _removeFiles() async {
    for (final url in _filesToRemove) {
      try {
        final ref = FirebaseStorage.instance.refFromURL(url);
        await ref.delete();
      } catch (e) {
        print('Error deleting file: $e');
      }
    }
  }

  // Save changes to Firestore
  Future<void> _saveRecord() async {
    if (!_formKey.currentState!.validate()) return;

    _formKey.currentState!.save();
    final userId = FirebaseAuth.instance.currentUser!.uid;
    final docRef = FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('pets')
        .doc(widget.petId)
        .collection('records')
        .doc(widget.record.id);

    // Remove deleted files from Storage
    await _removeFiles();

    // Upload new files and get URLs
    List<String> uploadedUrls = [];
    if (_newFiles.isNotEmpty) {
      uploadedUrls = await _uploadFiles(widget.record.id!);
    }

    // Update file URLs
    final updatedFileUrls = [
      ..._existingFiles.where((url) => !_filesToRemove.contains(url)),
      ...uploadedUrls,
    ];

    // Compute new nextVisitDateTime based on user input or logic
    DateTime? nextVisitDateTime = _nextVisitDateTime;
    if (nextVisitDateTime == null) {
      if (_selectedType == MedicalRecordType.ectoparasite) {
        nextVisitDateTime = _selectedDate.add(const Duration(days: 30));
      } else if (_selectedType == MedicalRecordType.worm) {
        nextVisitDateTime = _selectedDate.add(const Duration(days: 90));
      }
    }

    // Update formData with nextVisitDateTime
    if (nextVisitDateTime != null) {
      _formData['nextVisitDate'] = nextVisitDateTime;
    } else {
      _formData.remove('nextVisitDate');
    }

    // Prepare updated record
    final updatedRecord = {
      'type': _selectedType.toString().split('.').last,
      'date': Timestamp.fromDate(_selectedDate),
      'data': _formData,
      'fileUrls': updatedFileUrls,
    };

    await docRef.update(updatedRecord);

    // Delete all previous calendar events for this record
    final eventsSnapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('events')
        .where('recordId', isEqualTo: widget.record.id)
        .get();

    for (var event in eventsSnapshot.docs) {
      await cancelNotifications(event.id);
      await event.reference.delete();
    }

    // Get pet name for event
    final petSnapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('pets')
        .doc(widget.petId)
        .get();
    final petName = petSnapshot.data()?['name'] ?? 'Unknown Pet';

    // Add new event/notification if nextVisitDateTime exists
    if (nextVisitDateTime != null) {
      final eventData = {
        'title': 'Next Visit - ${medicalRecordTypeToString(_selectedType)}',
        'petName': petName,
        'date': Timestamp.fromDate(nextVisitDateTime),
        'recordId': widget.record.id,
      };

      final newEventRef = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('events')
          .add(eventData);

      await newEventRef.update({'eventId': newEventRef.id});

      await scheduleNotifications(
        newEventRef.id,
        eventData['title'] as String,
        nextVisitDateTime,
      );
    }

    if (!mounted) return;
    Navigator.pop(context);
  }

  // Field widgets by type
  List<Widget> _fieldsByType() {
    switch (_selectedType) {
      case MedicalRecordType.medicalHistory:
        return [
          TextFormField(
            initialValue: _formData['procedureOrMedicine'] ?? '',
            decoration:
                const InputDecoration(labelText: "Procedure or Medicine"),
            onSaved: (v) => _formData['procedureOrMedicine'] = v,
            validator: (v) => v == null || v.isEmpty ? 'Required' : null,
          ),
        ];
      case MedicalRecordType.ectoparasite:
        return [
          TextFormField(
            initialValue: _formData['medicineName'] ?? '',
            decoration: const InputDecoration(labelText: "Medicine Name"),
            onSaved: (v) => _formData['medicineName'] = v,
            validator: (v) => v == null || v.isEmpty ? 'Required' : null,
          ),
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
            initialValue: _formData['medicineName'] ?? '',
            decoration: const InputDecoration(labelText: "Medicine Name"),
            onSaved: (v) => _formData['medicineName'] = v,
            validator: (v) => v == null || v.isEmpty ? 'Required' : null,
          ),
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
            value: _formData['result'],
            decoration: const InputDecoration(labelText: "Result"),
            items: const [
              DropdownMenuItem(value: "POS", child: Text("POS")),
              DropdownMenuItem(value: "NEG", child: Text("NEG")),
            ],
            onChanged: (v) => setState(() => _formData['result'] = v),
            onSaved: (v) => _formData['result'] = v,
            validator: (v) => v == null || v.isEmpty ? 'Required' : null,
          ),
          TextFormField(
            initialValue: _formData['comments'] ?? '',
            decoration: const InputDecoration(labelText: "Comments"),
            onSaved: (v) => _formData['comments'] = v,
          ),
        ];
      case MedicalRecordType.notes:
        return [
          TextFormField(
            initialValue: _formData['comments'] ?? '',
            decoration: const InputDecoration(labelText: "Comments"),
            onSaved: (v) => _formData['comments'] = v,
          ),
        ];
      case MedicalRecordType.vaccination:
        return [
          TextFormField(
            initialValue: _formData['weight']?.toString() ?? '',
            decoration: const InputDecoration(labelText: "Current Weight (kg)"),
            keyboardType: TextInputType.number,
            onSaved: (v) => _formData['weight'] = v,
          ),
          TextFormField(
            initialValue: _formData['dose'] ?? '',
            decoration:
                const InputDecoration(labelText: "Nth Dose (e.g., 1st, 2nd)"),
            onSaved: (v) => _formData['dose'] = v,
          ),
          TextFormField(
            initialValue: _formData['vaccineName'] ?? '',
            decoration: const InputDecoration(labelText: "Vaccine Name"),
            onSaved: (v) => _formData['vaccineName'] = v,
          ),
        ];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Edit Medical Record')),
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
                  if (type != null) {
                    setState(() {
                      _selectedType = type;
                      _formData = {}; // Reset fields on type change
                    });
                  }
                },
              ),
              const SizedBox(height: 12),
              ListTile(
                title: Text(
                    'Date: ${DateFormat('dd-MM-yyyy').format(_selectedDate)}'),
                trailing: Icon(Icons.calendar_today),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _selectedDate,
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                  );
                  if (picked != null) setState(() => _selectedDate = picked);
                },
              ),
              ..._fieldsByType(),
              const SizedBox(height: 16),
              Text(
                'Existing Attachments:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              ..._existingFiles
                  .where((url) => !_filesToRemove.contains(url))
                  .map(
                    (url) => ListTile(
                      title: Text(url.split('/').last),
                      leading: Icon(Icons.attach_file),
                      trailing: IconButton(
                        icon: Icon(Icons.delete, color: Colors.red),
                        onPressed: () {
                          setState(() => _filesToRemove.add(url));
                        },
                      ),
                      onTap: () {}, // preview if you want
                    ),
                  ),
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
