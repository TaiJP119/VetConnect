import 'package:VetApp/features/pet_management/screens/edit_medical_record_page.dart';
import 'package:VetApp/features/user_auth/presentation/pages/add_event_page.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/pet_model.dart';
import '../models/medical_record_model.dart';
import 'add_medical_record_page.dart';
import 'edit_pet_page.dart'; // Make sure this import exists

void openFile(String url) async {
  if (await canLaunchUrl(Uri.parse(url))) {
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  } else {
    throw 'Could not launch $url';
  }
}

class PetProfilePage extends StatefulWidget {
  final PetModel pet;
  const PetProfilePage({super.key, required this.pet});

  @override
  State<PetProfilePage> createState() => _PetProfilePageState();
}

class _PetProfilePageState extends State<PetProfilePage> {
  MedicalRecordType _selectedCategory = MedicalRecordType.medicalHistory;
  late final List<MedicalRecordType> _categories;

  @override
  void initState() {
    super.initState();
    _categories = [
      MedicalRecordType.medicalHistory,
      MedicalRecordType.ectoparasite,
      MedicalRecordType.worm,
      MedicalRecordType.heartworm,
      MedicalRecordType.notes,
      MedicalRecordType.vaccination,
    ];
  }

  Future<void> _deleteMedicalRecord(MedicalRecord record) async {
    final userId = FirebaseAuth.instance.currentUser!.uid;
    final petId = widget.pet.id!;

    try {
      // Delete attached files from Storage
      if (record.fileUrls.isNotEmpty) {
        for (String url in record.fileUrls) {
          final ref = FirebaseStorage.instance.refFromURL(url);
          await ref.delete();
        }
      }

      // Delete calendar event and notifications linked to this record
      final events = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('events')
          .where('recordId', isEqualTo: record.id)
          .get();

      for (var event in events.docs) {
        await cancelNotifications(event.id);
        await event.reference.delete();
      }

      // Delete medical record itself
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('pets')
          .doc(petId)
          .collection('records')
          .doc(record.id)
          .delete();

      print('Medical record and associated events/files deleted.');
    } catch (e) {
      print('Error deleting medical record: $e');
    }
  }

  Widget _categorySelector() {
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _categories.length,
        separatorBuilder: (_, __) => SizedBox(width: 8),
        itemBuilder: (context, index) {
          final type = _categories[index];
          final isSelected = _selectedCategory == type;
          return ChoiceChip(
            label: Text(medicalRecordTypeToString(type)),
            selected: isSelected,
            onSelected: (val) {
              setState(() {
                _selectedCategory = type;
              });
            },
            selectedColor:
                Theme.of(context).colorScheme.primary.withOpacity(0.85),
            backgroundColor: Colors.grey[200],
            labelStyle: TextStyle(
                color: isSelected ? Colors.white : Colors.black,
                fontWeight: FontWeight.w600),
          );
        },
      ),
    );
  }

  Widget _petProfileCard() {
    final pet = widget.pet;
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: const EdgeInsets.only(bottom: 18),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Pet Photo
            CircleAvatar(
              radius: 38,
              backgroundImage:
                  (pet.imageUrl != null && pet.imageUrl!.isNotEmpty)
                      ? NetworkImage(pet.imageUrl!)
                      : null,
              child: (pet.imageUrl == null || pet.imageUrl!.isEmpty)
                  ? Icon(Icons.pets, size: 40, color: Colors.grey[400])
                  : null,
              backgroundColor: Colors.grey[200],
            ),
            const SizedBox(width: 18),
            // Pet Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    pet.name ?? 'Unknown',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  if (pet.breed != null && pet.breed!.isNotEmpty)
                    Text("Breed: ${pet.breed!}",
                        style: TextStyle(fontSize: 16)),
                  if (pet.species != null && pet.species!.isNotEmpty)
                    Text("Species: ${pet.species!}",
                        style: TextStyle(fontSize: 16)),
                  if (pet.birthday != null && pet.birthday!.isNotEmpty)
                    Text("Birthday: ${pet.birthday!}",
                        style: TextStyle(fontSize: 16)),
                  if (pet.gender != null && pet.gender!.isNotEmpty)
                    Row(
                      children: [
                        Icon(
                          pet.gender!.toLowerCase() == 'male'
                              ? Icons.male
                              : Icons.female,
                          color: pet.gender!.toLowerCase() == 'male'
                              ? Colors.blue
                              : Colors.pink,
                          size: 20,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          "Sex: ${pet.gender![0].toUpperCase()}${pet.gender!.substring(1)}",
                          style: TextStyle(fontSize: 16),
                        ),
                      ],
                    ),
                  if (pet.colorMark != null && pet.colorMark!.isNotEmpty)
                    Text("Color/Mark: ${pet.colorMark!}",
                        style: TextStyle(fontSize: 16)),
                  if (pet.microchipNumber != null &&
                      pet.microchipNumber!.isNotEmpty)
                    Text("Microchip No.: ${pet.microchipNumber!}",
                        style: TextStyle(fontSize: 16)),
                  if (pet.natured != null)
                    Row(
                      children: [
                        Icon(
                          pet.natured == 'Yes'
                              ? Icons.check_circle
                              : Icons.cancel,
                          color:
                              pet.natured == 'Yes' ? Colors.green : Colors.red,
                          size: 20,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          "Natured: ${pet.natured!}",
                          style: TextStyle(fontSize: 16),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMedicalRecordsList() {
    final userId = FirebaseAuth.instance.currentUser!.uid;
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('pets')
          .doc(widget.pet.id)
          .collection('records')
          .orderBy('date', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final records = snapshot.data!.docs
            .map((doc) {
              try {
                return MedicalRecord.fromSnapshot(doc);
              } catch (e) {
                print("Error parsing medical record: $e");
                return null;
              }
            })
            .where((e) => e != null)
            .cast<MedicalRecord>()
            .toList();

        // Filter records by selected category
        final filtered =
            records.where((rec) => rec.type == _selectedCategory).toList();

        if (filtered.isEmpty) {
          return Center(child: Text('No records in this category.'));
        }
        return ListView.builder(
          itemCount: filtered.length,
          itemBuilder: (context, index) {
            final record = filtered[index];
            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: ExpansionTile(
                title: Text(
                  medicalRecordTypeToString(record.type),
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(DateFormat('dd-MM-yyyy').format(record.date)),
                children: [
                  ...record.data.entries.map((e) => ListTile(
                        title: Text("${e.key}:"),
                        subtitle: Text("${e.value}"),
                      )),
                  if (record.fileUrls.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8.0),
                      child: Text("Attachments:",
                          style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                    ...record.fileUrls.map((url) {
                      final fileName =
                          Uri.decodeFull(url.split('/').last.split('?').first);
                      return ListTile(
                        leading: Icon(Icons.attach_file),
                        title: Text(fileName),
                        trailing: Icon(Icons.open_in_new),
                        onTap: () => openFile(url),
                      );
                    }).toList(),
                  ],
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      // If you have EditMedicalRecordPage:
                      TextButton.icon(
                        icon: Icon(Icons.edit),
                        label: Text("Edit"),
                        onPressed: () async {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => EditMedicalRecordPage(
                                  petId: widget.pet.id!, record: record),
                            ),
                          );
                        },
                      ),
                      TextButton.icon(
                        icon: Icon(Icons.delete),
                        label: Text("Delete"),
                        onPressed: () async {
                          await _deleteMedicalRecord(record);
                        },
                      ),
                    ],
                  )
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("${widget.pet.name}'s Profile"),
        actions: [
          IconButton(
            icon: Icon(Icons.edit),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => EditPetPage(pet: widget.pet)),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: () async {
              final confirm = await showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text("Delete Pet"),
                  content:
                      const Text("Are you sure you want to delete this pet?"),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text("Cancel")),
                    TextButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text("Delete")),
                  ],
                ),
              );
              if (confirm == true) {
                final userId = FirebaseAuth.instance.currentUser!.uid;
                await FirebaseFirestore.instance
                    .collection("users")
                    .doc(userId)
                    .collection("pets")
                    .doc(widget.pet.id)
                    .delete();
                Navigator.pop(context);
              }
            },
          )
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _petProfileCard(), // Pet details card at the top
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Medical Records",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                ElevatedButton(
                  child: Text("Add Record"),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            AddMedicalRecordPage(petId: widget.pet.id!),
                      ),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 10),
            _categorySelector(),
            const SizedBox(height: 10),
            Expanded(child: _buildMedicalRecordsList()),
          ],
        ),
      ),
    );
  }
}
