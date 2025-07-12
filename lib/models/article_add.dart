import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';

class UploadArticlePage extends StatefulWidget {
  const UploadArticlePage({super.key});

  @override
  State<UploadArticlePage> createState() => _UploadArticlePageState();
}

class _UploadArticlePageState extends State<UploadArticlePage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _title = TextEditingController();
  final TextEditingController _subtitle = TextEditingController();
  final TextEditingController _content = TextEditingController();

  PlatformFile? _pickedFile;
  bool _loading = false;

  Future<void> _pickImage() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );

    if (result != null && result.files.single.bytes != null) {
      setState(() {
        _pickedFile = result.files.single;
      });
    }
  }

  Future<String?> _uploadToImgBB(PlatformFile file) async {
    const apiKey = '50fd987bc1cc0919a4213aae0e8319eb';
    final url = Uri.parse('https://api.imgbb.com/1/upload?key=$apiKey');

    final base64Image = base64Encode(file.bytes!);
    final response = await http.post(url, body: {'image': base64Image});

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return data['data']['url'];
    } else {
      return null;
    }
  }

  Future<String?> _getAuthorName() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return null;

    final doc = await FirebaseFirestore.instance
        .collection('user_bio')
        .doc(uid)
        .get();

    return doc.data()?['name'];
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _pickedFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lengkapi semua data dan pilih gambar')),
      );
      return;
    }

    setState(() => _loading = true);

    final imageUrl = await _uploadToImgBB(_pickedFile!);
    final author = await _getAuthorName();

    if (imageUrl == null || author == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Gagal upload gambar atau ambil data user"),
        ),
      );
      setState(() => _loading = false);
      return;
    }

    await FirebaseFirestore.instance.collection('articles').add({
      'title': _title.text.trim(),
      'subtitle': _subtitle.text.trim(),
      'content': _content.text.trim(),
      'image': imageUrl,
      'author': author,
      'date': Timestamp.now(),
    });

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text("Artikel berhasil diunggah")));

    setState(() => _loading = false);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Upload Artikel")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              GestureDetector(
                onTap: _pickImage,
                child: _pickedFile != null
                    ? Image.memory(
                        _pickedFile!.bytes!,
                        height: 200,
                        fit: BoxFit.cover,
                      )
                    : Container(
                        height: 200,
                        color: Colors.grey[300],
                        child: const Center(child: Text("Pilih Gambar")),
                      ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _title,
                decoration: const InputDecoration(labelText: "Judul"),
                validator: (val) => val!.isEmpty ? "Wajib diisi" : null,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _subtitle,
                decoration: const InputDecoration(labelText: "Subjudul"),
                validator: (val) => val!.isEmpty ? "Wajib diisi" : null,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _content,
                maxLines: 10,
                decoration: const InputDecoration(labelText: "Isi Artikel"),
                validator: (val) => val!.isEmpty ? "Wajib diisi" : null,
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _loading ? null : _submit,
                child: _loading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text("Upload Artikel"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
