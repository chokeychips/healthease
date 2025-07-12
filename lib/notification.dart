import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

class NotificationPage extends StatelessWidget {
  const NotificationPage({super.key});

  Future<String?> _getCurrentUserEmail() async {
    final user = FirebaseAuth.instance.currentUser;
    return user?.email;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String?>(
      future: _getCurrentUserEmail(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final userEmail = snapshot.data!;
        final appointmentRef = FirebaseFirestore.instance
            .collection("appointment")
            .where("patient.email", isEqualTo: userEmail);

        return Scaffold(
          appBar: AppBar(title: const Text("Notifications")),
          body: StreamBuilder<QuerySnapshot>(
            stream: appointmentRef.snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) return const Text("Error loading data");
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final docs = snapshot.data!.docs;
              if (docs.isEmpty) {
                return const Center(
                  child: Text("No appointment notifications"),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  final data = docs[index].data() as Map<String, dynamic>;

                  final doctorName = data['doctor_name'] ?? '-';
                  final spec = data['spesialisasi'] ?? '';
                  final time = (data['datetime'] as Timestamp).toDate();
                  // ignore: unused_local_variable
                  final method = data['payment_method'] ?? '';

                  return Card(
                    elevation: 4,
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    child: ListTile(
                      title: Text("Dr. $doctorName - $spec"),
                      subtitle: Text(
                        "Date: ${time.day}/${time.month}/${time.year} - "
                        "${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}",
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ReceiptPage(data: data),
                          ),
                        );
                      },
                    ),
                  );
                },
              );
            },
          ),
        );
      },
    );
  }
}

class ReceiptPage extends StatelessWidget {
  final Map<String, dynamic> data;

  const ReceiptPage({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final patient = data['patient'] ?? {};
    final datetime = (data['datetime'] as Timestamp).toDate();
    final endtime = (data['endtime'] as Timestamp).toDate();
    final paymentMethod = data['payment_method'];
    final va = data['virtual_account'];

    return Scaffold(
      appBar: AppBar(title: const Text("Payment Receipt")),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Icon(Icons.check_circle, color: Colors.green, size: 60),
              const SizedBox(height: 16),
              const Text(
                "Appointment Receipt",
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "👨‍⚕️ Doctor: ${data['doctor_name']} (${data['spesialisasi']})",
                      ),
                      Text("🏥 Hospital: ${data['rumah_sakit']}"),
                      const SizedBox(height: 12),
                      Text("🧍 Patient: ${patient['name'] ?? '-'}"),
                      Text(
                        "🎂 Birthday: ${patient['birthday'] != null ? DateFormat('yyyy-MM-dd').format((patient['birthday'] as Timestamp).toDate()) : '-'}",
                      ),
                      Text("📏 Height: ${patient['height'] ?? '-'} cm"),
                      Text("⚖️ Weight: ${patient['weight'] ?? '-'} kg"),
                      const SizedBox(height: 12),
                      Text(
                        "📅 Date: ${DateFormat('yyyy-MM-dd').format(datetime)}",
                      ),
                      Text(
                        "⏰ Time: ${DateFormat('HH:mm').format(datetime)} - ${DateFormat('HH:mm').format(endtime)}",
                      ),
                      const SizedBox(height: 12),
                      Text(
                        "💳 Payment Method: ${paymentMethod.toString().toUpperCase()}",
                      ),
                      if (paymentMethod == "bri")
                        Row(
                          children: [
                            const Text("🏦 Virtual Account: "),
                            Expanded(
                              child: SelectableText(
                                va.toString(),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.copy, size: 20),
                              onPressed: () {
                                Clipboard.setData(
                                  ClipboardData(text: va.toString()),
                                );
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text("Virtual Account copied"),
                                  ),
                                );
                              },
                            ),
                          ],
                        )
                      else
                        const Text("✅ Payment Successful"),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF171713),
                ),
                child: const Text(
                  "Back",
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
