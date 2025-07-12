import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import '../services/firebase_options.dart';
import '../widgets/custom_navbar.dart'; // import navbar buatanmu
import '../home.dart';
import 'article.dart';
import 'profile.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../widgets/appbar.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Healthease',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const MainScreen(),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;

  final List<Widget> _pages = [
    HomePage(),
    SearchPage(),
    ArticlePage(),
    ProfilePage(),
  ];

  void _onNavTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_selectedIndex],
      bottomNavigationBar: CustomNavbar(
        currentIndex: _selectedIndex,
        onTap: _onNavTapped,
      ),
    );
  }
}

class InfoCard extends StatelessWidget {
  final String imageUrl;
  final String title;
  final String subtitle;
  final String description;
  final Widget bottomRightWidget;

  const InfoCard({
    super.key,
    required this.imageUrl,
    required this.title,
    required this.subtitle,
    required this.description,
    required this.bottomRightWidget,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 3,
      margin: const EdgeInsets.all(8),
      child: Container(
        width: 240,
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                imageUrl,
                width: 64,
                height: 64,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(subtitle, style: const TextStyle(color: Colors.grey)),
                  const SizedBox(height: 2),
                  Text(description, style: const TextStyle(color: Colors.grey)),
                  const SizedBox(height: 6),
                  bottomRightWidget,
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  String searchText = '';

  @override
  Widget build(BuildContext context) {
    final DoctorsRef = FirebaseFirestore.instance.collection('dokter').limit(3);
    final rsRef = FirebaseFirestore.instance.collection('rumah_sakit').limit(3);
    final ArticlesRef = FirebaseFirestore.instance
        .collection('articles')
        .limit(3);
    Future<DocumentSnapshot> _getUserBio() async {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) throw Exception("User tidak login");
      return await FirebaseFirestore.instance
          .collection('user_bio')
          .doc(uid)
          .get();
    }

    return Scaffold(
      appBar: CustomAppBar(getUserBio: _getUserBio),

      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: TextField(
              decoration: const InputDecoration(
                labelText: 'Search Doctors, Hospitals, or Articles',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                ),
              ),
              onChanged: (value) =>
                  setState(() => searchText = value.toLowerCase()),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  _buildSection(
                    title: 'Doctors',
                    stream: DoctorsRef.snapshots(),
                    builder: (data) => _buildCard(
                      image: data['image'],
                      title: 'dr. ${data['nama']}',
                      subtitle: data['spesialisasi'],
                      extra: data['rumah_sakit'],
                      stars: data['rating']?.toDouble() ?? 0,
                    ),
                  ),
                  _buildSection(
                    title: 'Hospitals',
                    stream: rsRef.snapshots(),
                    builder: (data) => _buildCard(
                      image: data['image'],
                      title: data['nama'],
                      subtitle: data['lokasi'],
                      extra: '',
                      stars: data['rating']?.toDouble() ?? 0,
                    ),
                  ),
                  _buildSection(
                    title: 'Articles',
                    stream: ArticlesRef.snapshots(),
                    builder: (data) => buildArticleCard(
                      image: data['image'],
                      title: data['title'],
                      subtitle: data['subtitle'],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required Stream<QuerySnapshot> stream,
    required Widget Function(Map<String, dynamic>) builder,
  }) {
    return StreamBuilder<QuerySnapshot>(
      stream: stream,
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const CircularProgressIndicator();
        final docs = snapshot.data!.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return data.values.any(
            (v) => v.toString().toLowerCase().contains(searchText),
          );
        }).toList();

        if (docs.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            ...docs.map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              return builder(data);
            }),
          ],
        );
      },
    );
  }

  Widget buildArticleCard({
    required String image,
    required String title,
    required String subtitle,
  }) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                image,
                width: 80,
                height: 80,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const Icon(Icons.image, size: 80),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(subtitle, style: const TextStyle(color: Colors.grey)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCard({
    required String image,
    required String title,
    required String subtitle,
    required String extra,
    double? stars,
  }) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                image,
                width: 80,
                height: 80,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const Icon(Icons.image, size: 80),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(subtitle, style: const TextStyle(color: Colors.grey)),
                  if (extra.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        extra,
                        style: const TextStyle(color: Colors.grey),
                      ),
                    ),
                  if (stars != null)
                    Row(
                      children: List.generate(5, (i) {
                        return Icon(
                          i < stars ? Icons.star : Icons.star_border,
                          color: Colors.amber,
                          size: 20,
                        );
                      })..add(Text('  ${stars.toStringAsFixed(1)} Stars')),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
