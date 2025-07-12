import 'dart:convert';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class FormUserData extends StatefulWidget {
  final String email;
  final String uid;

  const FormUserData({super.key, required this.email, required this.uid});

  @override
  State<FormUserData> createState() => _FormUserDataState();
}

class _FormUserDataState extends State<FormUserData> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _name = TextEditingController();
  final TextEditingController _address = TextEditingController();
  final TextEditingController _weight = TextEditingController();
  final TextEditingController _height = TextEditingController();

  int _gender = 1;
  DateTime? _birthday;
  PlatformFile? _pickedImage;
  bool _loading = false;

  Future<void> _pickImage() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );

    if (result != null && result.files.single.bytes != null) {
      setState(() => _pickedImage = result.files.single);
    }
  }

  Future<String?> _uploadToImgBB(PlatformFile file) async {
    const apiKey = '50fd987bc1cc0919a4213aae0e8319eb'; // Ganti dengan key kamu
    final uri = Uri.parse('https://api.imgbb.com/1/upload?key=$apiKey');

    final base64Image = base64Encode(file.bytes!);

    final response = await http.post(
      uri,
      body: {'image': base64Image, 'name': file.name},
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['data']['url'];
    } else {
      return null;
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() ||
        _birthday == null ||
        _pickedImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Lengkapi semua data termasuk gambar dan tanggal lahir",
          ),
        ),
      );
      return;
    }

    setState(() => _loading = true);

    try {
      final imageUrl = await _uploadToImgBB(_pickedImage!);
      if (imageUrl == null) {
        throw Exception("Gagal upload gambar ke ImgBB");
      }

      await FirebaseFirestore.instance
          .collection("user_bio")
          .doc(widget.uid)
          .set({
            "name": _name.text.trim(),
            "email": widget.email,
            "address": _address.text.trim(),
            "gender": _gender,
            "birthday": Timestamp.fromDate(_birthday!),
            "weight": double.parse(_weight.text),
            "height": double.parse(_height.text),
            "image": imageUrl,
          });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Data berhasil disimpan")));

      Navigator.pushReplacementNamed(context, "/home");
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Gagal menyimpan data: $e")));
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    Uint8List? imageBytes = _pickedImage?.bytes;

    return Scaffold(
      appBar: AppBar(title: const Text("Isi Data Diri")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              GestureDetector(
                onTap: _pickImage,
                child: CircleAvatar(
                  radius: 60,
                  backgroundImage: imageBytes != null
                      ? MemoryImage(imageBytes)
                      : null,
                  child: imageBytes == null
                      ? const Icon(Icons.add_a_photo, size: 32)
                      : null,
                ),
              ),
              const SizedBox(height: 20),

              TextFormField(
                controller: _name,
                decoration: const InputDecoration(labelText: "Nama"),
                validator: (val) => val!.isEmpty ? "Wajib diisi" : null,
              ),
              const SizedBox(height: 10),

              TextFormField(
                controller: _address,
                decoration: const InputDecoration(labelText: "Alamat"),
                validator: (val) => val!.isEmpty ? "Wajib diisi" : null,
              ),
              const SizedBox(height: 10),

              Row(
                children: [
                  const Text("Jenis Kelamin: "),
                  Radio(
                    value: 1,
                    groupValue: _gender,
                    onChanged: (val) => setState(() => _gender = val!),
                  ),
                  const Text("Laki-laki"),
                  Radio(
                    value: 2,
                    groupValue: _gender,
                    onChanged: (val) => setState(() => _gender = val!),
                  ),
                  const Text("Perempuan"),
                ],
              ),

              ListTile(
                title: Text(
                  _birthday != null
                      ? "Tanggal Lahir: ${_birthday!.day}/${_birthday!.month}/${_birthday!.year}"
                      : "Pilih Tanggal Lahir",
                ),
                trailing: const Icon(Icons.calendar_today),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: DateTime(2000),
                    firstDate: DateTime(1950),
                    lastDate: DateTime.now(),
                  );
                  if (picked != null) {
                    setState(() => _birthday = picked);
                  }
                },
              ),

              TextFormField(
                controller: _weight,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: "Berat Badan (kg)",
                ),
                validator: (val) => val!.isEmpty ? "Wajib diisi" : null,
              ),
              const SizedBox(height: 10),

              TextFormField(
                controller: _height,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: "Tinggi Badan (cm)",
                ),
                validator: (val) => val!.isEmpty ? "Wajib diisi" : null,
              ),
              const SizedBox(height: 20),

              ElevatedButton(
                onPressed: _loading ? null : _submit,
                child: _loading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text("Simpan"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
