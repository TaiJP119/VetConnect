import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class EditBannerPage extends StatefulWidget {
  final String docId;
  final Map<String, dynamic> data;
  const EditBannerPage({required this.docId, required this.data, Key? key})
      : super(key: key);

  @override
  State<EditBannerPage> createState() => _EditBannerPageState();
}

class _EditBannerPageState extends State<EditBannerPage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _bannerCtrl;
  late TextEditingController _messageCtrl;
  late TextEditingController _urlCtrl;

  File? _selectedImage;
  String? _existingImageUrl;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _bannerCtrl = TextEditingController(text: widget.data['banner'] ?? "");
    _messageCtrl = TextEditingController(text: widget.data['message'] ?? "");
    _urlCtrl = TextEditingController(text: widget.data['url'] ?? "");
    _existingImageUrl = widget.data['imageUrl'] as String?;
  }

  @override
  void dispose() {
    _bannerCtrl.dispose();
    _messageCtrl.dispose();
    _urlCtrl.dispose();
    super.dispose();
  }

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

  Future<void> _updateAnnouncement() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    String? imageUrl = _existingImageUrl;
    if (_selectedImage != null) {
      imageUrl = await _uploadImage(_selectedImage!);
    }

    await FirebaseFirestore.instance
        .collection('announcements')
        .doc(widget.docId)
        .update({
      'banner': _bannerCtrl.text.trim(),
      'message': _messageCtrl.text.trim(),
      'url': _urlCtrl.text.trim(),
      'imageUrl': imageUrl ?? '',
    });

    setState(() => _isSaving = false);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    Widget imageWidget;
    if (_selectedImage != null) {
      imageWidget = Image.file(_selectedImage!, height: 180, fit: BoxFit.cover);
    } else if (_existingImageUrl != null && _existingImageUrl!.isNotEmpty) {
      imageWidget =
          Image.network(_existingImageUrl!, height: 180, fit: BoxFit.cover);
    } else {
      imageWidget = Container(
        height: 180,
        color: Colors.grey[200],
        child: Icon(Icons.add_photo_alternate, size: 60),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text('Edit Banner')),
      body: Padding(
        padding: const EdgeInsets.all(18.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              GestureDetector(
                onTap: _pickImage,
                child: imageWidget,
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
                onPressed: _isSaving ? null : _updateAnnouncement,
                child: _isSaving
                    ? CircularProgressIndicator()
                    : Text('Update Announcement'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
