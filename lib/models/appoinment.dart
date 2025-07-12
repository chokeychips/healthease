// Tambahkan semua import yang diperlukan
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
// ignore: unused_import
import 'package:firebase_auth/firebase_auth.dart';

class AppointmentPage extends StatefulWidget {
  final Map<String, dynamic> doctorData;
  final String doctorId;
  final String userId;

  const AppointmentPage({
    super.key,
    required this.doctorData,
    required this.doctorId,
    required this.userId,
  });

  @override
  State<AppointmentPage> createState() => _AppointmentPageState();
}

class _AppointmentPageState extends State<AppointmentPage> {
  final _formKey = GlobalKey<FormState>();
  final _manualName = TextEditingController();
  final _manualWeight = TextEditingController();
  final _manualHeight = TextEditingController();
  DateTime? _manualBirthday;
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  String? _selectedPayment;
  String? _virtualAccount;
  List<Map<String, dynamic>> userBios = [];
  Map<String, dynamic>? selectedUserBio;

  final _cardNumber = TextEditingController();
  final _cardHolder = TextEditingController();
  final _cvv = TextEditingController();

  final paymentMethods = [
    {"label": "Debit Card", "value": "debit", "icon": "assets/icons/debit.png"},
    {
      "label": "BRI Virtual Account",
      "value": "bri",
      "icon": "assets/icons/bri.png",
    },
    {"label": "GoPay", "value": "gopay", "icon": "assets/icons/gopay.png"},
    {"label": "OVO", "value": "ovo", "icon": "assets/icons/ovo.png"},
    {"label": "Dana", "value": "dana", "icon": "assets/icons/dana.png"},
    {
      "label": "ShopeePay",
      "value": "shopeepay",
      "icon": "assets/icons/shopeepay.png",
    },
  ];

  bool _isManual = false;
  bool _showReceipt = false;

  @override
  void initState() {
    super.initState();
    debugPrint("User ID received: ${widget.userId}");
    fetchUserBio();
  }

  void fetchUserBio() async {
    final doc = await FirebaseFirestore.instance
        .collection('user_bio')
        .doc(widget.userId)
        .get();

    if (doc.exists) {
      print("✅ Data user_bio ditemukan: ${doc.data()}");
      setState(() => userBios = [doc.data()!]);
    } else {
      print("⚠️ Tidak ada data user_bio dengan ID: ${widget.userId}");
      setState(() => userBios = []);
    }
  }

  Future<void> _submit() async {
    if (_selectedDate == null ||
        _selectedTime == null ||
        _selectedPayment == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please complete all fields")),
      );
      return;
    }

    if (_formKey.currentState!.validate()) {
      final selectedDateTime = DateTime(
        _selectedDate!.year,
        _selectedDate!.month,
        _selectedDate!.day,
        _selectedTime!.hour,
        _selectedTime!.minute,
      );

      final endDateTime = selectedDateTime.add(const Duration(hours: 1));

      // Check schedule conflict
      final conflict = await FirebaseFirestore.instance
          .collection('appointment')
          .where('doctor_id', isEqualTo: widget.doctorId)
          .where('datetime', isEqualTo: Timestamp.fromDate(selectedDateTime))
          .get();

      if (conflict.docs.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("This time slot is already booked.")),
        );
        return;
      }

      final patient = _isManual
          ? {
              "name": _manualName.text,
              "weight": double.parse(_manualWeight.text),
              "height": double.parse(_manualHeight.text),
              "birthday": Timestamp.fromDate(_manualBirthday!),
            }
          : selectedUserBio ?? {};

      // ignore: unused_local_variable
      final paymentMethods = [
        {
          "label": "Debit Card",
          "value": "debit",
          "icon": "assets/icons/debit.png",
        },
        {
          "label": "BRI Virtual Account",
          "value": "bri",
          "icon": "assets/icons/bri.png",
        },
        {"label": "GoPay", "value": "gopay", "icon": "assets/icons/gopay.png"},
        {"label": "OVO", "value": "ovo", "icon": "assets/icons/ovo.png"},
        {"label": "Dana", "value": "dana", "icon": "assets/icons/dana.png"},
        {
          "label": "ShopeePay",
          "value": "shopeepay",
          "icon": "assets/icons/shopeepay.png",
        },
      ];

      final appointment = {
        "doctor_id": widget.doctorId,
        "doctor_name": widget.doctorData["nama"],
        "spesialisasi": widget.doctorData["spesialisasi"],
        "rumah_sakit": widget.doctorData["rumah_sakit"],
        "user_id": widget.userId,
        "patient": patient,
        "datetime": Timestamp.fromDate(selectedDateTime),
        "endtime": Timestamp.fromDate(endDateTime),
        "payment_method": _selectedPayment,
        "payment_status": _selectedPayment == "bri" ? "pending" : "success",
        "created_at": Timestamp.now(),
      };

      if (_selectedPayment == "bri") {
        _virtualAccount = "BRI-${100000 + Random().nextInt(999999)}";
        appointment["virtual_account"] = _virtualAccount;
      }

      await FirebaseFirestore.instance
          .collection("appointment")
          .add(appointment);

      setState(() => _showReceipt = true);
    }
  }

  Widget _buildPaymentOptions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Payment Method",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        ...paymentMethods.map((method) {
          return RadioListTile(
            value: method['value'],
            groupValue: _selectedPayment,
            onChanged: (val) {
              setState(() => _selectedPayment = val.toString());
            },
            title: Row(
              children: [
                Image.asset(method['icon'] ?? '', width: 24),
                const SizedBox(width: 10),
                Text(method['label'] ?? ''),
              ],
            ),
          );
        }),
        if (_selectedPayment == "debit")
          Column(
            children: [
              TextFormField(
                controller: _cardNumber,
                decoration: const InputDecoration(labelText: "Card Number"),
              ),
              TextFormField(
                controller: _cardHolder,
                decoration: const InputDecoration(labelText: "Card Holder"),
              ),
              TextFormField(
                controller: _cvv,
                decoration: const InputDecoration(labelText: "CVV"),
                obscureText: true,
              ),
            ],
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_showReceipt) {
      return FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance
            .collection('appointment')
            .orderBy('created_at', descending: true)
            .limit(1)
            .get()
            .then((snap) => snap.docs.first),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }

          final data = snapshot.data!.data() as Map<String, dynamic>;
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
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // ✅ ANIMASI LOADING + POPUP CHECK MARK
                    const SizedBox(height: 20),
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0.0, end: 1.0),
                      duration: const Duration(seconds: 2),
                      builder: (context, value, child) {
                        if (value < 1.0) {
                          return const CircularProgressIndicator();
                        } else {
                          return const Icon(
                            Icons.check_circle,
                            color: Colors.green,
                            size: 60,
                          );
                        }
                      },
                    ),
                    const SizedBox(height: 20),

                    const Text(
                      "Appointment Receipt",
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 20),

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
                                    tooltip: "Copy VA",
                                    onPressed: () {
                                      Clipboard.setData(
                                        ClipboardData(text: va.toString()),
                                      );
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            "Virtual Account copied to clipboard",
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              ),

                            if (paymentMethod != "bri")
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
                        "Done",
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: const Text("Make Appointment")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              SwitchListTile(
                title: const Text("Enter patient info manually?"),
                value: _isManual,
                onChanged: (val) => setState(() => _isManual = val),
              ),
              if (!_isManual && userBios.isNotEmpty)
                DropdownButtonFormField<Map<String, dynamic>>(
                  decoration: const InputDecoration(
                    labelText: "Select Patient",
                  ),
                  items: userBios
                      .map(
                        (e) =>
                            DropdownMenuItem(value: e, child: Text(e['name'])),
                      )
                      .toList(),
                  onChanged: (val) => setState(() => selectedUserBio = val),
                ),
              if (_isManual)
                Column(
                  children: [
                    TextFormField(
                      controller: _manualName,
                      decoration: const InputDecoration(labelText: "Name"),
                      validator: (val) => val!.isEmpty ? "Required" : null,
                    ),
                    TextFormField(
                      controller: _manualWeight,
                      decoration: const InputDecoration(labelText: "Weight"),
                      keyboardType: TextInputType.number,
                    ),
                    TextFormField(
                      controller: _manualHeight,
                      decoration: const InputDecoration(labelText: "Height"),
                      keyboardType: TextInputType.number,
                    ),
                    ListTile(
                      title: Text(
                        _manualBirthday == null
                            ? "Select Birthday"
                            : DateFormat('yyyy-MM-dd').format(_manualBirthday!),
                      ),
                      trailing: const Icon(Icons.calendar_today),
                      onTap: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: DateTime(2000),
                          firstDate: DateTime(1950),
                          lastDate: DateTime.now(),
                        );
                        if (date != null) {
                          setState(() => _manualBirthday = date);
                        }
                      },
                    ),
                  ],
                ),
              const SizedBox(height: 10),
              ListTile(
                title: Text(
                  _selectedDate == null
                      ? "Select Appointment Date"
                      : DateFormat('yyyy-MM-dd').format(_selectedDate!),
                ),
                trailing: const Icon(Icons.date_range),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    firstDate: DateTime.now(),
                    lastDate: DateTime(2100),
                    initialDate: DateTime.now(),
                  );
                  if (picked != null) {
                    setState(() => _selectedDate = picked);
                  }
                },
              ),
              ListTile(
                title: Text(
                  _selectedTime == null
                      ? "Select Time"
                      : _selectedTime!.format(context),
                ),
                trailing: const Icon(Icons.access_time),
                onTap: () async {
                  final picked = await showTimePicker(
                    context: context,
                    initialTime: TimeOfDay.now(),
                  );
                  if (picked != null) {
                    setState(() => _selectedTime = picked);
                  }
                },
              ),
              const SizedBox(height: 20),
              _buildPaymentOptions(),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF171713),
                ),
                child: const Text(
                  "Confirm Appointment",
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
