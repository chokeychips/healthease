import 'dart:convert';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'services/firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const AdminApp());
}

class AdminApp extends StatelessWidget {
  const AdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: AdminDashboard(),
    );
  }
}

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  int selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: selectedIndex,
            onDestinationSelected: (int index) {
              setState(() => selectedIndex = index);
            },
            labelType: NavigationRailLabelType.all,
            destinations: const [
              NavigationRailDestination(
                icon: Icon(Icons.local_hospital),
                label: Text('Data Dokter'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.local_pharmacy),
                label: Text('Rumah Sakit'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.people),
                label: Text('Pasien'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.event_note),
                label: Text('Appointment'),
              ),
            ],
          ),
          const VerticalDivider(thickness: 1, width: 1),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: IndexedStack(
                index: selectedIndex,
                children: const [
                  DataDokterPage(),
                  RumahSakitPage(),
                  DataPasienPage(),
                  AppointmentListPage(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class DataDokterPage extends StatelessWidget {
  const DataDokterPage({super.key});

  @override
  Widget build(BuildContext context) {
    final dokterRef = FirebaseFirestore.instance.collection('dokter');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Data Dokter',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: dokterRef.snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) return const Text('Error loading data');
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final docs = snapshot.data!.docs;
              return DataTable(
                columns: const [
                  DataColumn(label: Text('Gambar')),
                  DataColumn(label: Text('Nama')),
                  DataColumn(label: Text('Spesialisasi')),
                  DataColumn(label: Text('Rumah Sakit')),
                  DataColumn(label: Text('Rating')),
                  DataColumn(label: Text('Aksi')),
                ],
                rows: docs.map((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  return DataRow(
                    cells: [
                      DataCell(
                        data['image'] != null && data['image'] != ''
                            ? Image.network(
                                data['image'],
                                width: 50,
                                height: 100,
                                fit: BoxFit.cover,
                              )
                            : const Icon(Icons.image_not_supported),
                      ),
                      DataCell(Text(data['nama'] ?? '-')),
                      DataCell(Text(data['spesialisasi'] ?? '-')),
                      DataCell(Text(data['rumah_sakit'] ?? '-')),
                      DataCell(Text('${data['rating'] ?? 0}')),
                      DataCell(
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit, color: Colors.blue),
                              onPressed: () {
                                showDialog(
                                  context: context,
                                  builder: (context) => EditDoctorDialog(
                                    docId: doc.id,
                                    initialData: data,
                                  ),
                                );
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () async {
                                await dokterRef.doc(doc.id).delete();
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                }).toList(),
              );
            },
          ),
        ),
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: () => showDialog(
            context: context,
            builder: (context) => const AddDoctorDialog(),
          ),
          child: const Text('Tambah Dokter'),
        ),
      ],
    );
  }
}

class AddDoctorDialog extends StatefulWidget {
  const AddDoctorDialog({super.key});

  @override
  State<AddDoctorDialog> createState() => _AddDoctorDialogState();
}

class _AddDoctorDialogState extends State<AddDoctorDialog> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController nama = TextEditingController();
  final TextEditingController spesialisasi = TextEditingController();
  final TextEditingController rating = TextEditingController();
  Uint8List? _pickedImage;
  PlatformFile? _pickedFile;
  List<String> rumahSakitList = [];
  String? selectedRumahSakit;

  @override
  void initState() {
    super.initState();
    fetchRumahSakitList();
  }

  void fetchRumahSakitList() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('rumah_sakit')
        .get();
    setState(() {
      rumahSakitList = snapshot.docs
          .map((doc) => doc['nama'].toString())
          .toList();
    });
  }

  Future<void> pickImage() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );

    if (result != null && result.files.single.bytes != null) {
      setState(() {
        _pickedImage = result.files.single.bytes;
        _pickedFile = result.files.single;
      });
    }
  }

  Future<String?> uploadToImgBB(PlatformFile file) async {
    const apiKey = '50fd987bc1cc0919a4213aae0e8319eb';
    final base64Image = base64Encode(file.bytes!);
    final url = Uri.parse('https://api.imgbb.com/1/upload?key=$apiKey');

    final response = await http.post(url, body: {'image': base64Image});
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['data']['url'];
    }
    return null;
  }

  final List<String> spesialisasiList = [
    "Veterinarian",
    "Psychologist",
    "Dentist",
    "Pediatrician",
    "Gynecologist",
    "Aesthetic Doctor",
  ];

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Tambah Dokter'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nama,
                decoration: const InputDecoration(labelText: 'Nama'),
                validator: (value) => value!.isEmpty ? 'Wajib diisi' : null,
              ),
              DropdownButtonFormField<String>(
                value: spesialisasi.text.isNotEmpty ? spesialisasi.text : null,
                decoration: const InputDecoration(labelText: 'Spesialisasi'),
                items: spesialisasiList
                    .map(
                      (spesialis) => DropdownMenuItem(
                        value: spesialis,
                        child: Text(spesialis),
                      ),
                    )
                    .toList(),
                onChanged: (value) =>
                    setState(() => spesialisasi.text = value ?? ''),
                validator: (value) =>
                    value == null || value.isEmpty ? 'Wajib dipilih' : null,
              ),

              DropdownButtonFormField<String>(
                value: selectedRumahSakit,
                items: rumahSakitList
                    .map(
                      (nama) =>
                          DropdownMenuItem(value: nama, child: Text(nama)),
                    )
                    .toList(),
                onChanged: (value) =>
                    setState(() => selectedRumahSakit = value),
                decoration: const InputDecoration(labelText: 'Rumah Sakit'),
              ),
              TextFormField(
                controller: rating,
                decoration: const InputDecoration(labelText: 'Rating'),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: pickImage,
                icon: const Icon(Icons.image),
                label: const Text("Pilih Gambar"),
              ),
              if (_pickedImage != null)
                Image.memory(
                  _pickedImage!,
                  width: 100,
                  height: 100,
                  fit: BoxFit.cover,
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Batal'),
        ),
        ElevatedButton(
          onPressed: () async {
            if (_formKey.currentState!.validate() && _pickedFile != null) {
              final imageUrl = await uploadToImgBB(_pickedFile!);
              if (imageUrl == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Gagal upload gambar")),
                );
                return;
              }
              await FirebaseFirestore.instance.collection('dokter').add({
                'nama': nama.text,
                'spesialisasi': spesialisasi.text,
                'rumah_sakit': selectedRumahSakit ?? '',
                'rating': int.tryParse(rating.text) ?? 0,
                'image': imageUrl,
              });
              Navigator.pop(context);
            }
          },
          child: const Text('Simpan'),
        ),
      ],
    );
  }
}

class EditDoctorDialog extends StatefulWidget {
  final String docId;
  final Map<String, dynamic> initialData;

  const EditDoctorDialog({
    super.key,
    required this.docId,
    required this.initialData,
  });

  @override
  State<EditDoctorDialog> createState() => _EditDoctorDialogState();
}

class _EditDoctorDialogState extends State<EditDoctorDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController nama;
  late TextEditingController spesialisasi;
  late TextEditingController rating;
  late TextEditingController image;
  String? selectedRumahSakit;
  List<String> rumahSakitList = [];
  PlatformFile? selectedImageFile;

  @override
  void initState() {
    super.initState();
    nama = TextEditingController(text: widget.initialData['nama']);
    spesialisasi = TextEditingController(
      text: widget.initialData['spesialisasi'],
    );
    rating = TextEditingController(
      text: widget.initialData['rating'].toString(),
    );
    image = TextEditingController(text: widget.initialData['image'] ?? '');
    selectedRumahSakit = widget.initialData['rumah_sakit'];
    fetchRumahSakitList();
  }

  void fetchRumahSakitList() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('rumah_sakit')
        .get();
    setState(() {
      rumahSakitList = snapshot.docs
          .map((doc) => doc['nama']?.toString() ?? '')
          .where((nama) => nama.isNotEmpty)
          .toList();
    });
  }

  Future<void> pickImage() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );
    if (result != null && result.files.single.bytes != null) {
      setState(() {
        selectedImageFile = result.files.single;
      });
    }
  }

  Future<String?> uploadToImgBB(PlatformFile file) async {
    const apiKey = '50fd987bc1cc0919a4213aae0e8319eb';
    final uri = Uri.parse('https://api.imgbb.com/1/upload?key=$apiKey');
    final base64Image = base64Encode(file.bytes!);
    final response = await http.post(
      uri,
      body: {'image': base64Image, 'name': file.name},
    );

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      return json['data']['url'];
    } else {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit Dokter'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nama,
                decoration: const InputDecoration(labelText: 'Nama'),
                validator: (value) => value!.isEmpty ? 'Wajib diisi' : null,
              ),
              TextFormField(
                controller: spesialisasi,
                decoration: const InputDecoration(labelText: 'Spesialisasi'),
                validator: (value) => value!.isEmpty ? 'Wajib diisi' : null,
              ),
              DropdownButtonFormField<String>(
                value: selectedRumahSakit,
                decoration: const InputDecoration(labelText: 'Rumah Sakit'),
                items: rumahSakitList
                    .map((rs) => DropdownMenuItem(value: rs, child: Text(rs)))
                    .toList(),
                onChanged: (value) =>
                    setState(() => selectedRumahSakit = value),
              ),
              TextFormField(
                controller: rating,
                decoration: const InputDecoration(labelText: 'Rating'),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: pickImage,
                icon: const Icon(Icons.image),
                label: const Text("Pilih Gambar Baru"),
              ),
              if (selectedImageFile != null)
                Image.memory(
                  selectedImageFile!.bytes!,
                  width: 100,
                  height: 100,
                  fit: BoxFit.cover,
                )
              else if (image.text.isNotEmpty)
                Image.network(
                  image.text,
                  width: 100,
                  height: 100,
                  fit: BoxFit.cover,
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Batal'),
        ),
        ElevatedButton(
          onPressed: () async {
            if (_formKey.currentState!.validate()) {
              String finalImageUrl = image.text;

              // Jika user pilih gambar baru, upload ke imgbb
              if (selectedImageFile != null) {
                final uploadedUrl = await uploadToImgBB(selectedImageFile!);
                if (uploadedUrl == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Gagal mengupload gambar')),
                  );
                  return;
                }
                finalImageUrl = uploadedUrl;
              }

              await FirebaseFirestore.instance
                  .collection('dokter')
                  .doc(widget.docId)
                  .update({
                    'nama': nama.text,
                    'spesialisasi': spesialisasi.text,
                    'rumah_sakit': selectedRumahSakit,
                    'rating': int.tryParse(rating.text) ?? 0,
                    'image': finalImageUrl,
                  });

              Navigator.pop(context);
            }
          },
          child: const Text('Update'),
        ),
      ],
    );
  }
}

class RumahSakitPage extends StatelessWidget {
  const RumahSakitPage({super.key});

  @override
  Widget build(BuildContext context) {
    final rsRef = FirebaseFirestore.instance.collection('rumah_sakit');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Data Rumah Sakit',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: rsRef.snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) return const Text('Error loading data');
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final docs = snapshot.data!.docs;
              return DataTable(
                columns: const [
                  DataColumn(label: Text('Gambar')),
                  DataColumn(label: Text('Rumah Sakit')),
                  DataColumn(label: Text('Lokasi')),
                  DataColumn(label: Text('Rating')),
                  DataColumn(label: Text('Aksi')),
                ],
                rows: docs.map((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  return DataRow(
                    cells: [
                      DataCell(
                        data['image'] != null && data['image'] != ''
                            ? Image.network(
                                data['image'],
                                width: 100,
                                height: 100,
                                fit: BoxFit.cover,
                              )
                            : const Icon(Icons.image_not_supported),
                      ),
                      DataCell(Text(data['nama'] ?? '-')),
                      DataCell(Text(data['lokasi'] ?? '-')),
                      DataCell(Text('${data['rating'] ?? 0}')),
                      DataCell(
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit, color: Colors.blue),
                              onPressed: () {
                                showDialog(
                                  context: context,
                                  builder: (context) => EditHospitalDialog(
                                    docId: doc.id,
                                    initialData: data,
                                  ),
                                );
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () async {
                                await rsRef.doc(doc.id).delete();
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                }).toList(),
              );
            },
          ),
        ),
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: () {
            showDialog(
              context: context,
              builder: (context) => const AddRumahSakitDialog(),
            );
          },
          child: const Text('Tambah Rumah Sakit'),
        ),
      ],
    );
  }
}

class AddRumahSakitDialog extends StatefulWidget {
  const AddRumahSakitDialog({super.key});

  @override
  State<AddRumahSakitDialog> createState() => _AddRumahSakitDialogState();
}

class _AddRumahSakitDialogState extends State<AddRumahSakitDialog> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController nama = TextEditingController();
  final TextEditingController lokasi = TextEditingController();
  final TextEditingController rating = TextEditingController();
  PlatformFile? selectedImage;

  Future<void> pickImage() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );
    if (result != null && result.files.single.bytes != null) {
      setState(() => selectedImage = result.files.single);
    }
  }

  Future<String?> uploadToImgBB(PlatformFile file) async {
    const apiKey = '50fd987bc1cc0919a4213aae0e8319eb'; // Ganti dengan key kamu
    final uri = Uri.parse('https://api.imgbb.com/1/upload?key=$apiKey');
    final base64Image = base64Encode(file.bytes!);
    final response = await http.post(
      uri,
      body: {'image': base64Image, 'name': file.name},
    );

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      return json['data']['url'];
    } else {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Tambah Rumah Sakit'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nama,
                decoration: const InputDecoration(
                  labelText: 'Nama Rumah Sakit',
                ),
                validator: (value) => value!.isEmpty ? 'Wajib diisi' : null,
              ),
              TextFormField(
                controller: lokasi,
                decoration: const InputDecoration(labelText: 'Lokasi'),
              ),
              TextFormField(
                controller: rating,
                decoration: const InputDecoration(labelText: 'Rating'),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: pickImage,
                icon: const Icon(Icons.image),
                label: const Text("Pilih Gambar"),
              ),
              if (selectedImage != null)
                Image.memory(
                  selectedImage!.bytes!,
                  width: 100,
                  height: 100,
                  fit: BoxFit.cover,
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Batal'),
        ),
        ElevatedButton(
          onPressed: () async {
            if (_formKey.currentState!.validate()) {
              String imageUrl = '';
              if (selectedImage != null) {
                final url = await uploadToImgBB(selectedImage!);
                if (url == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Gagal upload gambar")),
                  );
                  return;
                }
                imageUrl = url;
              }

              await FirebaseFirestore.instance.collection('rumah_sakit').add({
                'nama': nama.text,
                'lokasi': lokasi.text,
                'rating': int.tryParse(rating.text) ?? 0,
                'image': imageUrl,
              });
              Navigator.pop(context);
            }
          },
          child: const Text('Simpan'),
        ),
      ],
    );
  }
}

class EditHospitalDialog extends StatefulWidget {
  final String docId;
  final Map<String, dynamic> initialData;

  const EditHospitalDialog({
    super.key,
    required this.docId,
    required this.initialData,
  });

  @override
  State<EditHospitalDialog> createState() => _EditHospitalDialogState();
}

class _EditHospitalDialogState extends State<EditHospitalDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController nama;
  late TextEditingController lokasi;
  late TextEditingController rating;
  late TextEditingController imageUrl;
  PlatformFile? selectedImage;

  @override
  void initState() {
    super.initState();
    nama = TextEditingController(text: widget.initialData['nama']);
    lokasi = TextEditingController(text: widget.initialData['lokasi']);
    rating = TextEditingController(
      text: widget.initialData['rating'].toString(),
    );
    imageUrl = TextEditingController(text: widget.initialData['image'] ?? '');
  }

  Future<void> pickImage() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );
    if (result != null && result.files.single.bytes != null) {
      setState(() => selectedImage = result.files.single);
    }
  }

  Future<String?> uploadToImgBB(PlatformFile file) async {
    const apiKey = '50fd987bc1cc0919a4213aae0e8319eb'; // Ganti dengan key kamu
    final uri = Uri.parse('https://api.imgbb.com/1/upload?key=$apiKey');
    final base64Image = base64Encode(file.bytes!);
    final response = await http.post(
      uri,
      body: {'image': base64Image, 'name': file.name},
    );

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      return json['data']['url'];
    } else {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit Rumah Sakit'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nama,
                decoration: const InputDecoration(
                  labelText: 'Nama Rumah Sakit',
                ),
                validator: (value) => value!.isEmpty ? 'Wajib diisi' : null,
              ),
              TextFormField(
                controller: lokasi,
                decoration: const InputDecoration(labelText: 'Lokasi'),
              ),
              TextFormField(
                controller: rating,
                decoration: const InputDecoration(labelText: 'Rating'),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: pickImage,
                icon: const Icon(Icons.image),
                label: const Text("Pilih Gambar Baru"),
              ),
              if (selectedImage != null)
                Image.memory(
                  selectedImage!.bytes!,
                  width: 100,
                  height: 100,
                  fit: BoxFit.cover,
                )
              else if (imageUrl.text.isNotEmpty)
                Image.network(
                  imageUrl.text,
                  width: 100,
                  height: 100,
                  fit: BoxFit.cover,
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Batal'),
        ),
        ElevatedButton(
          onPressed: () async {
            if (_formKey.currentState!.validate()) {
              String finalImageUrl = imageUrl.text;
              if (selectedImage != null) {
                final uploaded = await uploadToImgBB(selectedImage!);
                if (uploaded == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Gagal upload gambar")),
                  );
                  return;
                }
                finalImageUrl = uploaded;
              }

              await FirebaseFirestore.instance
                  .collection('rumah_sakit')
                  .doc(widget.docId)
                  .update({
                    'nama': nama.text,
                    'lokasi': lokasi.text,
                    'rating': int.tryParse(rating.text) ?? 0,
                    'image': finalImageUrl,
                  });

              Navigator.pop(context);
            }
          },
          child: const Text('Update'),
        ),
      ],
    );
  }
}

class DataPasienPage extends StatelessWidget {
  const DataPasienPage({super.key});

  @override
  Widget build(BuildContext context) {
    final pasienRef = FirebaseFirestore.instance.collection('user_bio');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Data Pasien',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: pasienRef.snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) return const Text('Error loading data');
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final docs = snapshot.data!.docs;
              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columns: const [
                    DataColumn(label: Text('Foto')),
                    DataColumn(label: Text('Nama')),
                    DataColumn(label: Text('Email')),
                    DataColumn(label: Text('Alamat')),
                    DataColumn(label: Text('Tanggal Lahir')),
                    DataColumn(label: Text('Gender')),
                    DataColumn(label: Text('Berat (kg)')),
                    DataColumn(label: Text('Tinggi (cm)')),
                  ],
                  rows: docs.map((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    final Timestamp birthday = data['birthday'];
                    final formattedDate =
                        "${birthday.toDate().day}/${birthday.toDate().month}/${birthday.toDate().year}";
                    final gender = data['gender'] == 1
                        ? 'Laki-laki'
                        : 'Perempuan';

                    return DataRow(
                      cells: [
                        DataCell(
                          data['image'] != null && data['image'] != ''
                              ? CircleAvatar(
                                  backgroundImage: NetworkImage(data['image']),
                                  radius: 30,
                                )
                              : const Icon(Icons.person),
                        ),
                        DataCell(Text(data['name'] ?? '-')),
                        DataCell(Text(data['email'] ?? '-')),
                        DataCell(Text(data['address'] ?? '-')),
                        DataCell(Text(formattedDate)),
                        DataCell(Text(gender)),
                        DataCell(Text('${data['weight'] ?? '-'}')),
                        DataCell(Text('${data['height'] ?? '-'}')),
                      ],
                    );
                  }).toList(),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class AppointmentListPage extends StatelessWidget {
  const AppointmentListPage({super.key});

  @override
  Widget build(BuildContext context) {
    final appointmentRef = FirebaseFirestore.instance.collection('appointment');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Data Appointment',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: appointmentRef
                .orderBy('created_at', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) return const Text('Error loading data');
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final docs = snapshot.data!.docs;
              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columns: const [
                    DataColumn(label: Text('Dokter')),
                    DataColumn(label: Text('Pasien')),
                    DataColumn(label: Text('Tanggal')),
                    DataColumn(label: Text('Jam')),
                    DataColumn(label: Text('Metode Bayar')),
                    DataColumn(label: Text('Status')),
                    DataColumn(label: Text('Aksi')),
                  ],
                  rows: docs.map((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    final patient = data['patient'] ?? {};
                    final datetime = (data['datetime'] as Timestamp).toDate();
                    final endtime = (data['endtime'] as Timestamp).toDate();
                    return DataRow(
                      cells: [
                        DataCell(Text(data['doctor_name'] ?? '-')),
                        DataCell(Text(patient['name'] ?? '-')),
                        DataCell(
                          Text(
                            "${datetime.day}/${datetime.month}/${datetime.year}",
                          ),
                        ),
                        DataCell(
                          Text(
                            "${datetime.hour.toString().padLeft(2, '0')}:${datetime.minute.toString().padLeft(2, '0')} - "
                            "${endtime.hour.toString().padLeft(2, '0')}:${endtime.minute.toString().padLeft(2, '0')}",
                          ),
                        ),
                        DataCell(
                          Text(
                            data['payment_method']?.toString().toUpperCase() ??
                                '-',
                          ),
                        ),
                        DataCell(Text(data['payment_status'] ?? '-')),
                        DataCell(
                          Row(
                            children: [
                              IconButton(
                                icon: const Icon(
                                  Icons.delete,
                                  color: Colors.red,
                                ),
                                onPressed: () async {
                                  await appointmentRef.doc(doc.id).delete();
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
