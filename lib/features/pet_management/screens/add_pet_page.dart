import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/pet_model.dart';
import 'package:intl/intl.dart';

class AddPetPage extends StatefulWidget {
  const AddPetPage({super.key});

  @override
  State<AddPetPage> createState() => _AddPetPageState();
}

class _AddPetPageState extends State<AddPetPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _breedCtrl = TextEditingController();
  final TextEditingController _birthdayCtrl = TextEditingController();
  final TextEditingController _addressCtrl = TextEditingController();
  final TextEditingController _colorMarkCtrl = TextEditingController();
  final TextEditingController _contactNumberCtrl = TextEditingController();
  final TextEditingController _microchipNumberCtrl = TextEditingController();
  bool useDefaultAddress = true; // Default setting

  String _selectedSpecies = 'Dog';
  String _selectedGender = 'Male';

  File? _selectedImage;
  String? _imageUrl;
  String? _naturedCtrl;
  Future<void> _loadUserProfile() async {
    final userId = FirebaseAuth.instance.currentUser!.uid;
    final userDoc =
        await FirebaseFirestore.instance.collection('users').doc(userId).get();
    final userData = userDoc.data();

    if (userData != null) {
      setState(() {
        _addressCtrl.text = userData['address'] ?? '';
        _contactNumberCtrl.text = userData['contact'] ?? '';
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _naturedCtrl = 'Yes'; // existing initialization
    _loadUserProfile(); // Load address & contact number
  }

  Future<void> _pickImage() async {
    final pickedFile =
        await ImagePicker().pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      setState(() {
        _selectedImage = File(pickedFile.path);
      });
    }
  }

  Future<String> _uploadImage(File imageFile) async {
    final userId = FirebaseAuth.instance.currentUser!.uid;
    final fileName = DateTime.now().millisecondsSinceEpoch.toString();
    final ref =
        FirebaseStorage.instance.ref().child('pets/$userId/$fileName.jpg');

    await ref.putFile(imageFile);
    return await ref.getDownloadURL();
  }

  void _savePet() async {
    if (_formKey.currentState!.validate()) {
      if (_selectedImage != null) {
        _imageUrl = await _uploadImage(_selectedImage!);
      }

      final pet = PetModel(
        name: _nameCtrl.text,
        breed: _breedCtrl.text,
        birthday: _birthdayCtrl.text,
        species: _selectedSpecies,
        gender: _selectedGender,
        natured: _naturedCtrl!,
        imageUrl: _imageUrl ?? "",
        address: _addressCtrl.text,
        colorMark: _colorMarkCtrl.text,
        contactNumber: _contactNumberCtrl.text,
        microchipNumber: _microchipNumberCtrl.text.isEmpty
            ? null
            : _microchipNumberCtrl.text,
      );

      final userId = FirebaseAuth.instance.currentUser!.uid;
      final petsRef = FirebaseFirestore.instance
          .collection("users")
          .doc(userId)
          .collection("pets");

      await petsRef.add(pet.toJson());

      Navigator.pop(context); // Return to home
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Add Pet")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(children: [
            GestureDetector(
              onTap: _pickImage,
              child: CircleAvatar(
                radius: 50,
                backgroundImage: _selectedImage != null
                    ? FileImage(_selectedImage!)
                    : const AssetImage('assets/images/default_pet.png')
                        as ImageProvider,
                child: _selectedImage == null
                    ? const Icon(Icons.camera_alt,
                        size: 30, color: Colors.white70)
                    : null,
              ),
            ),
            const SizedBox(height: 10),
            const Text("Tap to choose image", textAlign: TextAlign.center),
            const SizedBox(height: 20),
            TextFormField(
              controller: _nameCtrl,
              decoration: const InputDecoration(labelText: "Pet Name"),
              validator: (val) => val!.isEmpty ? "Enter name" : null,
            ),
            DropdownButtonFormField<String>(
              value: _selectedSpecies,
              items: ['Dog', 'Cat', 'Other']
                  .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                  .toList(),
              onChanged: (val) => setState(() => _selectedSpecies = val!),
              decoration: const InputDecoration(labelText: "Species"),
            ),
            TextFormField(
              controller: _breedCtrl,
              decoration: const InputDecoration(labelText: "Breed"),
            ),
            DropdownButtonFormField<String>(
              value: _selectedGender,
              items: ['Male', 'Female']
                  .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                  .toList(),
              onChanged: (val) => setState(() => _selectedGender = val!),
              decoration: const InputDecoration(labelText: "Gender"),
            ),
            TextFormField(
              controller: _birthdayCtrl,
              decoration: const InputDecoration(
                labelText: "Birthday",
                suffixIcon: Icon(Icons.calendar_today),
              ),
              readOnly: true,
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: DateTime(2020),
                  firstDate: DateTime(2000),
                  lastDate: DateTime.now(),
                );
                if (picked != null) {
                  _birthdayCtrl.text = DateFormat('yyyy-MM-dd').format(picked);
                }
              },
            ),
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(labelText: "Natured"),
              value: _naturedCtrl,
              items: ['Yes', 'No'].map((value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(value),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _naturedCtrl = value;
                });
              },
              validator: (value) => value == null ? "Select if natured" : null,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _savePet,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color.fromRGBO(255, 238, 47, 1),
              ),
              child: const Text("Save Pet"),
            ),
            const SizedBox(height: 20),
            SwitchListTile(
              title: const Text('Use Default Address'),
              value: useDefaultAddress,
              onChanged: (val) {
                setState(() => useDefaultAddress = val);
                if (val)
                  _loadUserProfile();
                else
                  _addressCtrl.clear();
              },
            ),
            if (!useDefaultAddress)
              TextFormField(
                controller: _addressCtrl,
                decoration: const InputDecoration(labelText: "Address"),
                validator: (val) => val!.isEmpty ? "Enter address" : null,
              ),
            TextFormField(
              controller: _colorMarkCtrl,
              decoration: const InputDecoration(labelText: "Color/Markings"),
              validator: (val) =>
                  val!.isEmpty ? "Enter markings or colors" : null,
            ),
            TextFormField(
              controller: _contactNumberCtrl,
              decoration: const InputDecoration(labelText: "Contact Number"),
              validator: (val) => val!.isEmpty ? "Enter contact number" : null,
            ),
            TextFormField(
              controller: _microchipNumberCtrl,
              decoration: const InputDecoration(
                  labelText: "Microchip Number (Optional)"),
            ),
          ]),
        ),
      ),
    );
  }
}
