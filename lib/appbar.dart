import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'notification.dart';

class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  final Future<DocumentSnapshot> Function() getUserBio;

  const CustomAppBar({super.key, required this.getUserBio});

  @override
  Size get preferredSize => const Size.fromHeight(70);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      toolbarHeight: 70,
      backgroundColor: const Color(0xFF171713),
      automaticallyImplyLeading: false,
      title: Padding(
        padding: const EdgeInsets.all(15),
        child: FutureBuilder<DocumentSnapshot>(
          future: getUserBio(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const CircularProgressIndicator(color: Colors.white);
            }

            final data = snapshot.data!.data() as Map<String, dynamic>;
            final String name = data['name'] ?? 'Pengguna';
            final String image = data['image'] ?? '';
            final int gender = data['gender'] ?? 1;

            return Row(
              children: [
                CircleAvatar(
                  backgroundImage: image.isNotEmpty
                      ? NetworkImage(image)
                      : const AssetImage("assets/images/user.jpeg")
                            as ImageProvider,
                ),
                const SizedBox(width: 10),
                Text(
                  name,
                  style: const TextStyle(color: Colors.white, fontSize: 18),
                ),
                const SizedBox(width: 5),
                Icon(
                  gender == 1 ? Icons.male : Icons.female,
                  color: Colors.white,
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.notifications, color: Colors.white),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => NotificationPage()),
                    );
                  },
                ),
                const SizedBox(width: 10),
                const Icon(Icons.settings, color: Colors.white),
              ],
            );
          },
        ),
      ),
    );
  }
}
