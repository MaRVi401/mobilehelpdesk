import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

void main() {
  // Pastikan package intl sudah ditambahkan di pubspec.yaml:
  // dependencies:
  //   flutter:
  //     sdk: flutter
  //   http: ^1.2.1
  //   intl: ^0.19.0
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'HELPDESK POLINDRA',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const CariTiketPage(),
    );
  }
}

class CariTiketPage extends StatefulWidget {
  const CariTiketPage({super.key});

  @override
  State<CariTiketPage> createState() => _CariTiketPageState();
}

class _CariTiketPageState extends State<CariTiketPage> {
  final TextEditingController _controller = TextEditingController();
  Map<String, dynamic>? tiketData;
  bool loading = false;
  String? errorMessage;

  // 🔗 Ganti URL ini sesuai endpoint API kamu
  final String baseUrl = "http://10.0.2.2:8000/api/tiket";
  // 🔑 Ganti dengan API Key yang benar dari .env Laravel Anda.
  final String apiKey = "dalit123";

  // URL Base untuk mengambil file gambar/lampiran
  // Ganti ini dengan domain Laravel Anda yang sebenarnya
  final String storageBaseUrl = "http://10.0.2.2:8000/storage/";

  Future<void> fetchTiket(String input) async {
    if (input.trim().isEmpty) {
      setState(() {
        errorMessage = "Mohon masukkan ID atau Nomor Tiket.";
        tiketData = null;
      });
      return;
    }

    setState(() {
      loading = true;
      errorMessage = null;
      tiketData = null;
    });

    try {
      final response = await http.get(
        Uri.parse("$baseUrl/$input"),
        headers: {'Accept': 'application/json', 'API_KEY_MAHASISWA': apiKey},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['data'] != null) {
          setState(() {
            tiketData = data['data'];
          });
        } else {
          setState(() {
            errorMessage = data['message'] ?? "Data tidak ditemukan.";
          });
        }
      } else if (response.statusCode == 404) {
        setState(() {
          errorMessage =
              "Tiket **$input** tidak ditemukan. Coba cek kembali ID/Nomor.";
        });
      } else if (response.statusCode == 401) {
        setState(() {
          errorMessage = "Unauthorized: API Key tidak valid.";
        });
      } else {
        setState(() {
          errorMessage = "Terjadi kesalahan server (${response.statusCode}).";
        });
      }
    } catch (e) {
      print('Fetch Error: $e');
      setState(() {
        errorMessage =
            "Gagal terhubung ke server. Pastikan server aktif dan alamat API benar.";
      });
    } finally {
      setState(() {
        loading = false;
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Helpdesk Polindra',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        ),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        centerTitle: true,
        elevation: 8,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Cari Status Tiket Anda',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: Colors.deepPurple.shade700,
              ),
            ),
            const SizedBox(height: 15),
            TextField(
              controller: _controller,
              keyboardType: TextInputType.text,
              decoration: InputDecoration(
                hintText: 'Masukkan ID atau No Tiket',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.deepPurple),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: Colors.deepPurple,
                    width: 2,
                  ),
                ),
                prefixIcon: const Icon(
                  Icons.confirmation_number,
                  color: Colors.deepPurple,
                ),
                suffixIcon: IconButton(
                  icon: loading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.search, color: Colors.deepPurple),
                  onPressed: loading
                      ? null
                      : () {
                          fetchTiket(_controller.text);
                        },
                ),
                filled: true,
                fillColor: Colors.deepPurple.shade50.withOpacity(0.5),
              ),
              onSubmitted: loading ? null : (value) => fetchTiket(value),
            ),
            const SizedBox(height: 30),
            _buildResultWidget(),
          ],
        ),
      ),
    );
  }

  // 📦 Widget untuk menampilkan hasil (loading, error, atau data)
  Widget _buildResultWidget() {
    if (loading) {
      return _buildLoadingPlaceholder();
    } else if (errorMessage != null) {
      return _buildErrorWidget(errorMessage!);
    } else if (tiketData != null) {
      return _buildTiketDetail(tiketData!);
    } else {
      return Center(
        child: Column(
          children: [
            Icon(Icons.search_rounded, size: 80, color: Colors.grey.shade300),
            const SizedBox(height: 10),
            Text(
              'Silakan masukkan ID atau Nomor Tiket untuk melacak status.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ],
        ),
      );
    }
  }

  // 📝 Widget Detail Tiket
  Widget _buildTiketDetail(Map<String, dynamic> data) {
    final riwayat = (data['riwayat_status'] as List?) ?? [];
    final komentar = (data['komentar'] as List?) ?? [];

    final latestStatus = riwayat.isNotEmpty
        ? riwayat.first['status']
        : 'Menunggu Respon';

    Color statusColor;
    IconData statusIcon;
    switch (latestStatus.toLowerCase()) {
      case 'selesai':
        statusColor = Colors.green.shade700;
        statusIcon = Icons.check_circle;
        break;
      case 'diproses':
      case 'dikerjakan':
        statusColor = Colors.orange.shade700;
        statusIcon = Icons.hourglass_top;
        break;
      case 'ditolak':
        statusColor = Colors.red.shade700;
        statusIcon = Icons.cancel;
        break;
      default:
        statusColor = Colors.blue.shade700;
        statusIcon = Icons.pending_actions;
        break;
    }

    // Asumsi: field 'lampiran' berisi path file relatif
    final String? lampiranPath = data['lampiran'];

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
        side: BorderSide(color: statusColor, width: 1.5),
      ),
      elevation: 8,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Tiket
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(
                    "Tiket #${data['no_tiket'] ?? 'N/A'}",
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: statusColor,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Chip(
                  avatar: Icon(statusIcon, color: Colors.white, size: 18),
                  label: Text(
                    latestStatus.toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  backgroundColor: statusColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ],
            ),
            const Divider(height: 25, thickness: 1.5, color: Colors.black12),

            // Detail Ringkas
            Text(
              data['judul'] ?? 'Informasi Umum',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 10),

            _buildDetailRow(
              'Layanan',
              data['layanan']?['nama'] ?? 'Layanan Umum',
              Icons.category_rounded,
            ),
            _buildDetailRow(
              'Prioritas',
              data['prioritas'] ?? 'Normal',
              Icons.priority_high_rounded,
            ),
            _buildDetailRow(
              'Tanggal Dibuat',
              _formatDate(data['created_at']),
              Icons.calendar_today_rounded,
            ),
            _buildDetailRow(
              'Deskripsi',
              data['deskripsi']?.toString().trim().isNotEmpty == true
                  ? data['deskripsi']
                  : 'Tidak ada deskripsi tambahan.',
              Icons.description_rounded,
              isMultiline: true,
            ),

            const SizedBox(height: 20),

            // Lampiran/Gambar
            if (lampiranPath != null && lampiranPath.isNotEmpty)
              _buildLampiranSection(lampiranPath),

            if (lampiranPath != null && lampiranPath.isNotEmpty)
              const SizedBox(height: 20),

            // Riwayat Status (Timeline)
            if (riwayat.isNotEmpty) _buildRiwayatStatusSection(riwayat),

            const SizedBox(height: 20),

            // Komentar/Diskusi
            if (komentar.isNotEmpty) _buildKomentarSection(komentar),
          ],
        ),
      ),
    );
  }

  // 🖼️ Widget Lampiran
  Widget _buildLampiranSection(String path) {
    // Membangun URL lengkap
    final fullUrl = '$storageBaseUrl$path';

    // Cek ekstensi file sederhana untuk menentukan ikon
    final extension = path.toLowerCase().split('.').last;
    IconData fileIcon;
    if (['jpg', 'jpeg', 'png', 'gif'].contains(extension)) {
      fileIcon = Icons.image_rounded;
    } else if (extension == 'pdf') {
      fileIcon = Icons.picture_as_pdf_rounded;
    } else if (extension == 'doc' || extension == 'docx') {
      fileIcon = Icons.text_snippet_rounded;
    } else {
      fileIcon = Icons.attach_file_rounded;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(fileIcon, color: Colors.deepPurple, size: 24),
            const SizedBox(width: 8),
            const Text(
              "Lampiran",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // Menampilkan gambar jika ekstensi adalah gambar
        if (['jpg', 'jpeg', 'png', 'gif'].contains(extension))
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(
              fullUrl,
              height: 200,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  height: 100,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Text(
                    "Gagal memuat gambar. Cek koneksi atau path URL: $fullUrl",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.red.shade600),
                  ),
                );
              },
            ),
          )
        else
          // Untuk file non-gambar (PDF, DOCX, dll.)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blueGrey.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blueGrey.shade200),
            ),
            child: Row(
              children: [
                Icon(fileIcon, color: Colors.blueGrey.shade700),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    "Lampiran (${extension.toUpperCase()}) tersedia.",
                    style: TextStyle(color: Colors.blueGrey.shade800),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const Icon(Icons.download_rounded, color: Colors.deepPurple),
              ],
            ),
          ),
      ],
    );
  }

  // 🗣️ Widget Komentar
  Widget _buildKomentarSection(List<dynamic> komentar) {
    return ExpansionTile(
      initiallyExpanded: true,
      tilePadding: EdgeInsets.zero,
      leading: Icon(Icons.comment_rounded, color: Colors.deepPurple.shade400),
      title: Text(
        "Diskusi & Komentar (${komentar.length})",
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
      ),
      children: [
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: komentar.length,
          itemBuilder: (context, index) {
            final c = komentar[index];
            // 🚨 Menggunakan 'pengirim' sesuai perbaikan backend Laravel
            final userName = c['pengirim']?['name'] ?? 'Petugas Helpdesk';
            final userRole =
                c['pengirim']?['role'] ??
                'Admin'; // Asumsi role ada di objek pengirim
            final commentTime = _formatDateTime(c['created_at']);
            final commentText = c['komentar'] ?? 'Tidak ada isi komentar.';

            return Padding(
              padding: const EdgeInsets.symmetric(
                vertical: 8.0,
                horizontal: 8.0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: userRole == 'Mahasiswa'
                            ? Colors.blue.shade100
                            : Colors.deepPurple.shade100,
                        radius: 12,
                        child: Icon(
                          Icons.person,
                          size: 16,
                          color: userRole == 'Mahasiswa'
                              ? Colors.blue.shade700
                              : Colors.deepPurple.shade700,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          "$userName (${userRole})",
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      Text(
                        commentTime,
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.only(left: 32.0, top: 4.0),
                    child: Text(
                      commentText,
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                  const Divider(height: 10, thickness: 0.5),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  // 🕰️ Widget Riwayat Status (dibuat seperti timeline)
  Widget _buildRiwayatStatusSection(List<dynamic> riwayat) {
    // Balik urutan agar timeline dimulai dari status tertua (ASC)
    final reversedRiwayat = riwayat.reversed.toList();

    return ExpansionTile(
      initiallyExpanded: true, // Detail Riwayat Status langsung terbuka
      tilePadding: EdgeInsets.zero,
      leading: Icon(Icons.timeline_rounded, color: Colors.deepPurple.shade400),
      title: Text(
        "Riwayat Status (${riwayat.length})",
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
      ),
      children: [
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: reversedRiwayat.length,
          itemBuilder: (context, index) {
            final s = reversedRiwayat[index];
            final isLast = index == reversedRiwayat.length - 1;
            final isFirst = index == 0;
            final userName = s['user']?['name'] ?? 'System';
            final userRole = s['user']?['role'] ?? 'System';

            Color itemColor = isLast
                ? Colors.green.shade600
                : Colors.deepPurple.shade300;
            if (s['status'].toLowerCase() == 'ditolak') {
              itemColor = Colors.red.shade600;
            }

            return IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Timeline Connector
                  Column(
                    children: [
                      Container(
                        width: 2.0,
                        height: 8.0,
                        color: isFirst ? Colors.transparent : itemColor,
                      ),
                      Container(
                        padding: const EdgeInsets.all(3.0),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white,
                          border: Border.all(color: itemColor, width: 2.0),
                        ),
                        child: Icon(
                          isLast ? Icons.star_rounded : Icons.circle,
                          size: 10.0,
                          color: itemColor,
                        ),
                      ),
                      Expanded(
                        child: Container(
                          width: 2.0,
                          color: isLast ? Colors.transparent : itemColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 10),

                  // Status Content
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 15.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            s['status']?.toUpperCase() ??
                                'STATUS TIDAK DIKETAHUI',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: itemColor,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            "Oleh: ${userName} (${userRole})",
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.black87,
                            ),
                          ),
                          Text(
                            _formatDateTime(s['created_at']),
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  // Helper untuk baris detail
  Widget _buildDetailRow(
    String title,
    String? value,
    IconData icon, {
    bool isMultiline = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: Colors.deepPurple.shade300),
          const SizedBox(width: 10),
          Expanded(
            flex: 2,
            child: Text(
              "$title:",
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ),
          Expanded(
            flex: 4,
            child: Text(
              value ?? 'N/A',
              style: const TextStyle(color: Colors.black54),
              maxLines: isMultiline ? null : 3,
              overflow: isMultiline ? TextOverflow.clip : TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  // 🚫 Widget Error
  Widget _buildErrorWidget(String message) {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.red.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.red.shade300),
        ),
        child: Column(
          children: [
            const Icon(
              Icons.warning_amber_rounded,
              size: 60,
              color: Colors.red,
            ),
            const SizedBox(height: 10),
            Text(
              'Pencarian Gagal:',
              style: TextStyle(
                color: Colors.red.shade800,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              message.replaceAll('**', ''),
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.red),
            ),
          ],
        ),
      ),
    );
  }

  // ⏳ Widget Placeholder
  Widget _buildLoadingPlaceholder() {
    return Center(
      child: Column(
        children: [
          CircularProgressIndicator(color: Colors.deepPurple.shade400),
          const SizedBox(height: 15),
          const Text("Mencari data tiket, mohon tunggu..."),
        ],
      ),
    );
  }

  // Helper untuk format tanggal saja
  String _formatDate(String? dateTimeString) {
    if (dateTimeString == null) return 'N/A';
    try {
      final dateTime = DateTime.parse(dateTimeString).toLocal();
      return DateFormat(
        'dd MMMM yyyy',
        'id_ID',
      ).format(dateTime); // Menggunakan locale Indonesia
    } catch (e) {
      return dateTimeString.split(' ')[0];
    }
  }

  // Helper untuk format tanggal dan waktu
  String _formatDateTime(String? dateTimeString) {
    if (dateTimeString == null) return 'N/A';
    try {
      final dateTime = DateTime.parse(dateTimeString).toLocal();
      // Menggunakan locale Indonesia dan format 24 jam
      return DateFormat('dd/MM/yyyy HH:mm', 'id_ID').format(dateTime);
    } catch (e) {
      return dateTimeString;
    }
  }
}
