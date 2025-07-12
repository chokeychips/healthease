class Dokter {
  final String id;
  final String nama;
  final String spesialisasi;
  final String rumahSakit;
  final int rating;

  Dokter({
    required this.id,
    required this.nama,
    required this.spesialisasi,
    required this.rumahSakit,
    required this.rating,
  });

  factory Dokter.fromJson(Map<String, dynamic> json) {
    return Dokter(
      id: json['id'],
      nama: json['nama'],
      spesialisasi: json['spesialisasi'],
      rumahSakit: json['rumah_sakit'],
      rating: json['rating'],
    );
  }
}
