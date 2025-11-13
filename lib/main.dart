import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

void main() {
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
        // Tambahkan font global jika ada (opsional)
        // fontFamily: 'Poppins',
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
  final String apiKey = "dalit123"; // sama seperti di .env Laravel

  Future<void> fetchTiket(String input) async {
    // 1. Validasi Input Dasar
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
          // Status 200 tapi 'success' false (misalnya data kosong)
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
          errorMessage = "API Key tidak valid. Hubungi administrator.";
        });
      } else {
        setState(() {
          errorMessage = "Terjadi kesalahan server (${response.statusCode}).";
        });
      }
    } catch (e) {
      // Lebih spesifik untuk emulator (10.0.2.2) dan network issues
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
  Widget build(BuildContext context) {
    return Scaffold(
      // Menggunakan AppBar standar dengan sedikit kustomisasi
      appBar: AppBar(
        title: const Text(
          'Helpdesk Polindra',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        centerTitle: true,
        elevation: 4,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 📍 Area Input
            Text(
              'Cari Status Tiket Anda',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.deepPurple.shade700,
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _controller,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                hintText: 'Masukkan ID atau No Tiket (Contoh: 1234)',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.deepPurple),
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

            // 📊 Area Status dan Hasil
            _buildResultWidget(),
          ],
        ),
      ),
    );
  }

  // 📦 Widget untuk menampilkan hasil (loading, error, atau data)
  Widget _buildResultWidget() {
    if (loading) {
      // Tampilkan indikator loading atau placeholder
      return _buildLoadingPlaceholder();
    } else if (errorMessage != null) {
      // Tampilkan pesan error
      return _buildErrorWidget(errorMessage!);
    } else if (tiketData != null) {
      // Tampilkan detail tiket
      return _buildTiketDetail(tiketData!);
    } else {
      // Tampilan awal
      return Center(
        child: Column(
          children: [
            Icon(Icons.info_outline, size: 60, color: Colors.grey.shade400),
            const SizedBox(height: 10),
            Text(
              'Silakan masukkan ID/Nomor Tiket untuk melihat status.',
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ],
        ),
      );
    }
  }

  // 📝 Widget Detail Tiket
  Widget _buildTiketDetail(Map<String, dynamic> data) {
    // Tentukan warna dan ikon berdasarkan status terakhir (jika ada)
    final riwayat = data['riwayat_status'] as List? ?? [];
    final latestStatus = riwayat.isNotEmpty
        ? riwayat.last['status']
        : 'Menunggu Respon';

    Color statusColor;
    IconData statusIcon;
    switch (latestStatus.toLowerCase()) {
      case 'selesai':
        statusColor = Colors.green;
        statusIcon = Icons.check_circle_outline;
        break;
      case 'diproses':
      case 'dikerjakan':
        statusColor = Colors.orange;
        statusIcon = Icons.hourglass_top;
        break;
      case 'ditolak':
        statusColor = Colors.red;
        statusIcon = Icons.cancel_outlined;
        break;
      default:
        statusColor = Colors.blue;
        statusIcon = Icons.pending_actions;
        break;
    }

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
        side: BorderSide(color: statusColor.withOpacity(0.5), width: 2),
      ),
      elevation: 6,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Tiket
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "TICKET #${data['no_tiket']}",
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: Colors.deepPurple,
                  ),
                ),
                Chip(
                  avatar: Icon(statusIcon, color: Colors.white, size: 18),
                  label: Text(
                    latestStatus.toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  backgroundColor: statusColor,
                ),
              ],
            ),
            const Divider(height: 25, thickness: 1),

            // Detail Ringkas
            _buildDetailRow(
              'Layanan',
              data['layanan']?['nama'] ?? 'N/A',
              Icons.category,
            ),
            _buildDetailRow('Deskripsi', data['deskripsi'], Icons.description),
            _buildDetailRow(
              'Tanggal Dibuat',
              data['created_at']?.split(' ')[0] ?? 'N/A',
              Icons.calendar_today,
            ),

            const SizedBox(height: 15),

            // Riwayat Status (menggunakan ExpansionTile)
            if (riwayat.isNotEmpty)
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: const Text(
                  "Riwayat Status",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                leading: Icon(Icons.history, color: Colors.deepPurple.shade400),
                children: [
                  ...riwayat.reversed
                      .map(
                        (s) => ListTile(
                          dense: true,
                          contentPadding: const EdgeInsets.only(left: 10),
                          leading: const Icon(
                            Icons.arrow_right,
                            size: 18,
                            color: Colors.grey,
                          ),
                          title: Text(
                            "${s['status']} oleh ${s['user']?['name'] ?? 'System'}",
                            style: const TextStyle(fontSize: 14),
                          ),
                          subtitle: Text(
                            _formatDateTime(s['created_at']),
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ],
              ),
          ],
        ),
      ),
    );
  }

  // 🚫 Widget Error
  Widget _buildErrorWidget(String message) {
    return Center(
      child: Column(
        children: [
          const Icon(Icons.error_outline, size: 60, color: Colors.red),
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
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.red),
          ),
        ],
      ),
    );
  }

  // ⏳ Widget Placeholder (Simulasi Shimmer/Loading)
  Widget _buildLoadingPlaceholder() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildShimmerItem(width: 150),
        const SizedBox(height: 10),
        _buildShimmerItem(width: double.infinity, height: 16),
        _buildShimmerItem(width: 250, height: 16),
        const SizedBox(height: 20),
        _buildShimmerItem(width: 120),
        const SizedBox(height: 8),
        _buildShimmerItem(width: double.infinity, height: 12),
        _buildShimmerItem(width: double.infinity, height: 12),
      ],
    );
  }

  // Helper untuk Shimmer
  Widget _buildShimmerItem({
    double width = double.infinity,
    double height = 12.0,
  }) {
    return Container(
      width: width,
      height: height,
      margin: const EdgeInsets.only(bottom: 8.0),
      decoration: BoxDecoration(
        color: Colors.grey.shade300,
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }

  // Helper untuk baris detail
  Widget _buildDetailRow(String title, String? value, IconData icon) {
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
            ),
          ),
        ],
      ),
    );
  }

  // Helper untuk format tanggal
  String _formatDateTime(String? dateTimeString) {
    if (dateTimeString == null) return 'N/A';
    try {
      final dateTime = DateTime.parse(dateTimeString).toLocal();
      return "${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute}";
    } catch (e) {
      return dateTimeString;
    }
  }
}
