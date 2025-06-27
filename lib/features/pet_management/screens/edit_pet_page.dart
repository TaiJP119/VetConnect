import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/pet_model.dart';

class EditPetPage extends StatefulWidget {
  final PetModel pet;
  const EditPetPage({super.key, required this.pet});

  @override
  State<EditPetPage> createState() => _EditPetPageState();
}

class _EditPetPageState extends State<EditPetPage> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameCtrl;
  late TextEditingController _speciesCtrl;
  late TextEditingController _breedCtrl;
  late TextEditingController _genderCtrl;
  late TextEditingController _birthdayCtrl;
  String? _naturedCtrl;
  late TextEditingController _addressCtrl;
  late TextEditingController _colorMarkCtrl;
  late TextEditingController _contactNumberCtrl;
  late TextEditingController _microchipNumberCtrl;
  bool useDefaultAddress = false;
  Future<void> _loadUserProfile() async {
    final userId = FirebaseAuth.instance.currentUser!.uid;
    final userDoc =
        await FirebaseFirestore.instance.collection('users').doc(userId).get();
    final userData = userDoc.data();

    if (userData != null && useDefaultAddress) {
      setState(() {
        _addressCtrl.text = userData['address'] ?? '';
        _contactNumberCtrl.text = userData['contact'] ?? '';
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.pet.name);
    _speciesCtrl = TextEditingController(text: widget.pet.species);
    _breedCtrl = TextEditingController(text: widget.pet.breed);
    _genderCtrl = TextEditingController(text: widget.pet.gender);
    _birthdayCtrl = TextEditingController(text: widget.pet.birthday);
    _naturedCtrl = widget.pet.natured;
    _addressCtrl = TextEditingController(text: widget.pet.address);
    _colorMarkCtrl = TextEditingController(text: widget.pet.colorMark);
    _contactNumberCtrl = TextEditingController(text: widget.pet.contactNumber);
    _microchipNumberCtrl =
        TextEditingController(text: widget.pet.microchipNumber);
    useDefaultAddress =
        widget.pet.address == null || widget.pet.address!.isEmpty;
    if (useDefaultAddress) _loadUserProfile();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _speciesCtrl.dispose();
    _breedCtrl.dispose();
    _genderCtrl.dispose();
    _birthdayCtrl.dispose();

    super.dispose();
  }

  void _updatePet() async {
    if (_formKey.currentState!.validate()) {
      final userId = FirebaseAuth.instance.currentUser!.uid;

      final updatedPet = {
        "name": _nameCtrl.text,
        "species": _speciesCtrl.text,
        "breed": _breedCtrl.text,
        "gender": _genderCtrl.text,
        "birthday": _birthdayCtrl.text,
        "natured": _naturedCtrl,
        "address": _addressCtrl.text,
        "colorMark": _colorMarkCtrl.text,
        "contactNumber": _contactNumberCtrl.text,
        "microchipNumber": _microchipNumberCtrl.text.isEmpty
            ? null
            : _microchipNumberCtrl.text,
      };

      await FirebaseFirestore.instance
          .collection("users")
          .doc(userId)
          .collection("pets")
          .doc(widget.pet.id)
          .update(updatedPet);

      Navigator.pop(context); // Back to PetProfilePage
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Edit Pet Info")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(labelText: "Name"),
                validator: (val) => val!.isEmpty ? "Enter name" : null,
              ),
              TextFormField(
                controller: _speciesCtrl,
                decoration: const InputDecoration(labelText: "Species"),
                validator: (val) => val!.isEmpty ? "Enter species" : null,
              ),
              TextFormField(
                controller: _breedCtrl,
                decoration: const InputDecoration(labelText: "Breed"),
                validator: (val) => val!.isEmpty ? "Enter breed" : null,
              ),
              TextFormField(
                controller: _genderCtrl,
                decoration: const InputDecoration(labelText: "Gender"),
                validator: (val) => val!.isEmpty ? "Enter gender" : null,
              ),
              TextFormField(
                controller: _birthdayCtrl,
                decoration: const InputDecoration(
                  labelText: "Birthday",
                  suffixIcon: Icon(Icons.calendar_today),
                ),
                readOnly: true,
                onTap: () async {
                  final pickedDate = await showDatePicker(
                    context: context,
                    initialDate:
                        DateTime.tryParse(_birthdayCtrl.text) ?? DateTime.now(),
                    firstDate: DateTime(2000),
                    lastDate: DateTime.now(),
                  );
                  if (pickedDate != null) {
                    _birthdayCtrl.text =
                        pickedDate.toIso8601String().split('T').first;
                  }
                },
              ),
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(
                  labelText: "Natured",
                ),
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
                validator: (value) =>
                    value == null ? "Select if natured" : null,
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _updatePet,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color.fromRGBO(255, 238, 47, 1),
                ),
                child: const Text("Update Pet"),
              ),
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
                validator: (val) =>
                    val!.isEmpty ? "Enter contact number" : null,
              ),
              TextFormField(
                controller: _microchipNumberCtrl,
                decoration: const InputDecoration(
                    labelText: "Microchip Number (Optional)"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
