import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';

class ImageUploader extends StatefulWidget {
  final Function(String imageUrl) onUploadComplete;

  const ImageUploader({super.key, required this.onUploadComplete});

  @override
  State<ImageUploader> createState() => _ImageUploaderState();
}

class _ImageUploaderState extends State<ImageUploader> {
  bool _isUploading = false;
  String? _uploadedUrl;

  Future<void> _pickAndUploadImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);

    if (picked == null) return;

    setState(() => _isUploading = true);

    final file = File(picked.path);
    final filename = picked.name;
    final ref = FirebaseStorage.instance.ref().child('images/$filename');

    try {
      await ref.putFile(file);
      final url = await ref.getDownloadURL();
      setState(() {
        _uploadedUrl = url;
        _isUploading = false;
      });
      widget.onUploadComplete(url);
    } catch (e) {
      setState(() => _isUploading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Gagal upload: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (_uploadedUrl != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Image.network(_uploadedUrl!, width: 100),
          ),
        ElevatedButton.icon(
          onPressed: _isUploading ? null : _pickAndUploadImage,
          icon: const Icon(Icons.upload),
          label: Text(_isUploading ? 'Mengunggah...' : 'Upload Gambar'),
        ),
      ],
    );
  }
}
