import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class AddBannerPage extends StatefulWidget {
  @override
  State<AddBannerPage> createState() => _AddBannerPageState();
}

class _AddBannerPageState extends State<AddBannerPage> {
  final _formKey = GlobalKey<FormState>();
  final _bannerCtrl = TextEditingController();
  final _messageCtrl = TextEditingController();
  final _urlCtrl = TextEditingController();
  File? _selectedImage;
  bool _isSaving = false;

  Future<void> _pickImage() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() {
        _selectedImage = File(picked.path);
      });
    }
  }

  Future<String?> _uploadImage(File image) async {
    final fileName = 'banner_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final ref = FirebaseStorage.instance.ref('banner_images/$fileName');
    await ref.putFile(image);
    return await ref.getDownloadURL();
  }

  Future<void> _saveAnnouncement() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    String? imageUrl;
    if (_selectedImage != null) {
      imageUrl = await _uploadImage(_selectedImage!);
    }

    await FirebaseFirestore.instance.collection('announcements').add({
      'banner': _bannerCtrl.text.trim(),
      'message': _messageCtrl.text.trim(),
      'url': _urlCtrl.text.trim(),
      'imageUrl': imageUrl ?? '',
      'createdAt': FieldValue.serverTimestamp(),
    });

    setState(() => _isSaving = false);
    Navigator.pop(context);
  }

  @override
  void dispose() {
    _bannerCtrl.dispose();
    _messageCtrl.dispose();
    _urlCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Add Banner')),
      body: Padding(
        padding: const EdgeInsets.all(18.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              GestureDetector(
                onTap: _pickImage,
                child: _selectedImage == null
                    ? Container(
                        height: 180,
                        color: Colors.grey[200],
                        child: Icon(Icons.add_photo_alternate, size: 60),
                      )
                    : Image.file(_selectedImage!,
                        height: 180, fit: BoxFit.cover),
              ),
              SizedBox(height: 16),
              TextFormField(
                controller: _bannerCtrl,
                decoration: InputDecoration(labelText: 'Banner Title'),
                validator: (v) =>
                    v == null || v.isEmpty ? 'Enter banner title' : null,
              ),
              SizedBox(height: 16),
              TextFormField(
                controller: _messageCtrl,
                decoration: InputDecoration(labelText: 'Banner Message'),
                minLines: 2,
                maxLines: 4,
                validator: (v) =>
                    v == null || v.isEmpty ? 'Enter banner message' : null,
              ),
              SizedBox(height: 16),
              TextFormField(
                controller: _urlCtrl,
                decoration:
                    InputDecoration(labelText: 'Optional URL (clickable link)'),
              ),
              SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isSaving ? null : _saveAnnouncement,
                child: _isSaving
                    ? CircularProgressIndicator()
                    : Text('Save Announcement'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
