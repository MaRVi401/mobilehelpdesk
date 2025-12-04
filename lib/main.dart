import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';

const Color hlOrange = Color(0xFFFF9D00); 
const Color hlBg = Color(0xFF1C1C1C);     
const Color hlPanel = Color(0xFF2B2B2B);  
const Color hlGreen = Color(0xFF62B236);  
const Color hlRed = Color(0xFFD92424);    

// KONFIGURASI SERVER (Ganti dengan IP Laptop Anda)
const String apiBaseUrl = "http://10.0.2.2:8000/api"; 
const String storageBaseUrl = "http://10.0.2.2:8000/storage/";
const String apiKey = "dalit123";

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Helpdesk Polindra',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: hlBg,
        colorScheme: const ColorScheme.dark(
          primary: hlOrange,
          secondary: hlGreen,
          surface: hlPanel,
          error: hlRed,
        ),
        textTheme: TextTheme(
          displayLarge: GoogleFonts.orbitron(fontWeight: FontWeight.bold, color: hlOrange),
          bodyLarge: GoogleFonts.shareTechMono(fontSize: 16, color: Colors.white),
          bodyMedium: GoogleFonts.shareTechMono(fontSize: 14, color: Colors.white70),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.black,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          border: OutlineInputBorder(borderSide: const BorderSide(color: hlOrange), borderRadius: BorderRadius.circular(4)),
          enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: hlOrange.withOpacity(0.5)), borderRadius: BorderRadius.circular(4)),
          focusedBorder: OutlineInputBorder(borderSide: const BorderSide(color: hlOrange, width: 2), borderRadius: BorderRadius.circular(4)),
          labelStyle: const TextStyle(color: hlOrange),
          hintStyle: TextStyle(color: hlOrange.withOpacity(0.5)),
        ),
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
  final TextEditingController _commentController = TextEditingController();
  
  Map<String, dynamic>? tiketData;
  String? deadlineTimer;
  bool loading = false;
  bool sendingComment = false;
  String? errorMessage;

  // --- FUNGSI API ---

  Future<void> fetchTiket(String input) async {
    if (input.trim().isEmpty) return _setError("INPUT SUBJECT ID");

    setState(() { loading = true; errorMessage = null; tiketData = null; });

    try {
      final url = Uri.parse("$apiBaseUrl/tiket/${Uri.encodeComponent(input.trim())}");
      log("Connecting to: $url");

      final response = await http.get(url, headers: {'Accept': 'application/json', 'API_KEY_MAHASISWA': apiKey});

      log("Response Body: ${response.body}"); // Cek Log untuk memastikan data 'detail' ada

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['data'] != null) {
          setState(() {
            tiketData = data['data'];
            deadlineTimer = data['deadline_timer'];
          });
        } else {
          _setError(data['message'] ?? "SUBJECT NOT FOUND");
        }
      } else {
        _setError("CONNECTION ERROR (${response.statusCode})");
      }
    } catch (e) {
      _setError("NETWORK FAILURE: $e");
    } finally {
      setState(() { loading = false; });
    }
  }

  Future<void> postComment() async {
    if (_commentController.text.trim().isEmpty) return;
    setState(() { sendingComment = true; });

    try {
      final id = tiketData!['id'];
      final url = Uri.parse("$apiBaseUrl/tiket/$id/komentar");
      
      final response = await http.post(
        url,
        headers: {'Accept': 'application/json', 'API_KEY_MAHASISWA': apiKey},
        body: {'komentar': _commentController.text}
      );

      if (response.statusCode == 200) {
        _commentController.clear();
        fetchTiket(tiketData!['no_tiket']); // Refresh data
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Transmission Failed"), backgroundColor: hlRed));
      }
    } catch (e) {
      log("Error: $e");
    } finally {
      setState(() { sendingComment = false; });
    }
  }

  void _setError(String msg) {
    setState(() { errorMessage = msg; });
  }

  // --- TAMPILAN UTAMA ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("HELPDESK // POLINDRA", style: GoogleFonts.orbitron(letterSpacing: 2, color: hlOrange, fontSize: 20)),
        backgroundColor: Colors.black,
        bottom: PreferredSize(preferredSize: const Size.fromHeight(2), child: Container(color: hlOrange, height: 2)),
        centerTitle: true,
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: _buildContent(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      color: const Color(0xFF111111),
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              style: GoogleFonts.shareTechMono(color: hlOrange, fontSize: 18),
              decoration: const InputDecoration(
                labelText: "ENTER TICKET ID",
                prefixIcon: Icon(Icons.qr_code_scanner, color: hlOrange),
              ),
              onSubmitted: (val) => fetchTiket(val),
            ),
          ),
          const SizedBox(width: 12),
          InkWell(
            onTap: () => fetchTiket(_controller.text),
            child: Container(
              height: 56, width: 60,
              decoration: BoxDecoration(
                color: hlOrange.withOpacity(0.1),
                border: Border.all(color: hlOrange),
                borderRadius: BorderRadius.circular(4),
              ),
              child: loading 
                ? const Center(child: CircularProgressIndicator(color: hlOrange))
                : const Icon(Icons.search, color: hlOrange, size: 30),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (errorMessage != null) {
      return Center(
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(border: Border.all(color: hlRed), color: hlRed.withOpacity(0.1)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.warning, color: hlRed, size: 50),
              const SizedBox(height: 16),
              Text("WARNING: $errorMessage", style: GoogleFonts.shareTechMono(color: hlRed, fontSize: 18), textAlign: TextAlign.center),
            ],
          ),
        ),
      );
    }

    if (tiketData == null) {
      return Center(
        child: Opacity(
          opacity: 0.3,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.science_outlined, size: 100, color: hlOrange),
              const SizedBox(height: 20),
              Text("AWAITING DATA INPUT...", style: GoogleFonts.orbitron(color: hlOrange, fontSize: 16)),
            ],
          ),
        ),
      );
    }

    return _buildTicketDetails(tiketData!);
  }

  Widget _buildTicketDetails(Map<String, dynamic> data) {
    // DATA UTAMA
    final pemohon = data['pemohon'] ?? {};
    final mahasiswa = data['mahasiswa'] ?? pemohon['mahasiswa'] ?? {};
    final prodi = mahasiswa['program_studi'] ?? {};
    final jurusan = prodi['jurusan'] ?? {};
    final layananNama = data['layanan']?['nama'] ?? 'UNKNOWN';
    final unit = data['layanan']?['unit'] ?? data['unit'] ?? {}; // Unit dari relasi layanan
    final detailLayanan = data['detail']; // INI PENTING (Data Spesifik)

    // STATUS
    final riwayat = (data['riwayat_status'] as List?) ?? [];
    String status = data['status'] ?? 'PENDING';
    if (riwayat.isNotEmpty) status = riwayat[0]['status'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. HEADER STATUS
        _HevCard(
          title: "SYSTEM STATUS",
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("#${data['no_tiket']}", style: GoogleFonts.orbitron(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
              _StatusBadge(status: status),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // 2. TIMER (JIKA ADA)
        if (status == 'Diselesaikan_oleh_PIC' && deadlineTimer != null)
           _HevCard(
             title: "CRITICAL TIMER",
             borderColor: hlRed,
             child: Column(
               children: [
                 Text("AUTO-CLOSE SEQUENCE INITIATED", style: GoogleFonts.shareTechMono(color: hlRed)),
                 const SizedBox(height: 8),
                 CountdownTimer(deadlineStr: deadlineTimer!),
               ],
             ),
           ),
        if (status == 'Diselesaikan_oleh_PIC' && deadlineTimer != null) const SizedBox(height: 16),

        // 3. INFO PEMOHON
        _HevCard(
          title: "PERSONNEL DATA",
          child: Column(
            children: [
              _InfoRow("NAMA", pemohon['name'] ?? mahasiswa['nama'] ?? 'N/A'),
              _InfoRow("ID (NIM)", mahasiswa['nim'] ?? 'N/A'),
              _InfoRow("JURUSAN", jurusan['nama_jurusan'] ?? 'N/A'),
              _InfoRow("PRODI", prodi['program_studi'] ?? 'N/A'),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // 4. DETAIL TIKET UMUM
        _HevCard(
          title: "REQUEST PARAMETERS",
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _InfoRow("LAYANAN", layananNama),
              _InfoRow("UNIT", unit['nama_unit'] ?? 'N/A'), // Unit muncul disini
              const Divider(color: Colors.white24, height: 24),
              Text("DESKRIPSI:", style: GoogleFonts.shareTechMono(color: hlOrange, fontSize: 12)),
              const SizedBox(height: 4),
              Text(data['deskripsi'] ?? '-', style: GoogleFonts.shareTechMono(fontSize: 16)),
              
              // Lampiran Umum
              if (data['lampiran'] != null)
                _AttachmentBtn(path: data['lampiran']),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // 5. DATA SPESIFIK LAYANAN (YANG DI-HIGHLIGHT MERAH)
        // Logika ini hanya jalan jika Backend mengirim 'detail'
        if (detailLayanan != null)
          _HevCard(
            title: "ENCRYPTED DATA BLOCK",
            borderColor: hlGreen,
            child: _buildDynamicSpecificData(layananNama, detailLayanan),
          )
        else 
          // Debugging jika data detail null
          Container(
            padding: const EdgeInsets.all(10), 
            decoration: BoxDecoration(border: Border.all(color: Colors.grey)),
            child: const Text("NO SPECIFIC DATA RECEIVED FROM SERVER", style: TextStyle(color: Colors.grey)),
          ),

        const SizedBox(height: 16),

        // 6. RIWAYAT (TIMELINE)
        _HevCard(
          title: "EVENT LOG",
          child: _buildTimeline(riwayat),
        ),
        const SizedBox(height: 16),

        // 7. KOMENTAR
        _HevCard(
          title: "COMM CHANNEL",
          child: _buildComments(data['komentar']),
        ),
        const SizedBox(height: 40),
      ],
    );
  }

  // === LOGIKA TAMPILAN DATA SPESIFIK (PERSIS BLADE) ===
  Widget _buildDynamicSpecificData(String namaLayanan, Map<String, dynamic> detail) {
    List<Widget> widgets = [];
    String lower = namaLayanan.toLowerCase();

    // 1. Surat Keterangan Aktif
    if (lower.contains('surat keterangan aktif')) {
      widgets.add(_InfoRow("Keperluan", detail['keperluan']));
      widgets.add(_InfoRow("Thn Ajaran", detail['tahun_ajaran']));
      widgets.add(_InfoRow("Semester", detail['semester']));
      if (detail['keperluan_lainnya'] != null) {
        widgets.add(_InfoRow("Lainnya", detail['keperluan_lainnya']));
      }
    } 
    // 2. Reset Akun
    else if (lower.contains('reset akun')) {
      widgets.add(_InfoRow("Aplikasi", detail['aplikasi']));
      widgets.add(_InfoRow("Masalah", detail['deskripsi']));
    }
    // 3. Ubah Data Mahasiswa
    else if (lower.contains('ubah data')) {
      widgets.add(_InfoRow("Nama Baru", detail['data_nama_lengkap']));
      widgets.add(_InfoRow("Tmp Lahir", detail['data_tmp_lahir']));
      widgets.add(_InfoRow("Tgl Lahir", detail['data_tgl_lhr']));
    }
    // 4. Request Publikasi (GAMBAR ADA DISINI)
    else if (lower.contains('publikasi')) {
      widgets.add(_InfoRow("Topik", detail['judul']));
      widgets.add(_InfoRow("Kategori", detail['kategori']));
      widgets.add(const SizedBox(height: 8));
      widgets.add(Text("CONTENT:", style: GoogleFonts.shareTechMono(color: hlOrange, fontSize: 12)));
      widgets.add(Text(detail['konten'] ?? '-', style: GoogleFonts.shareTechMono(fontSize: 14)));
      
      // === LOGIKA GAMBAR ===
      if (detail['gambar'] != null) {
        // Pastikan URL lengkap
        String imgUrl = detail['gambar'].startsWith('http') 
            ? detail['gambar'] 
            : "$storageBaseUrl${detail['gambar']}";
            
        widgets.add(const SizedBox(height: 16));
        widgets.add(Container(
          width: double.infinity,
          decoration: BoxDecoration(border: Border.all(color: hlGreen)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
               Container(
                 color: hlGreen.withOpacity(0.2),
                 width: double.infinity,
                 padding: const EdgeInsets.all(4),
                 child: Text("VISUAL DATA ATTACHMENT", style: GoogleFonts.shareTechMono(color: hlGreen, fontSize: 10)),
               ),
               Image.network(
                 imgUrl,
                 fit: BoxFit.contain,
                 errorBuilder: (ctx, err, stack) {
                   log("Gagal load gambar: $imgUrl ($err)");
                   return Container(
                     padding: const EdgeInsets.all(20),
                     alignment: Alignment.center,
                     child: Text("IMAGE LOAD ERROR\n$imgUrl", textAlign: TextAlign.center, style: const TextStyle(color: hlRed)),
                   );
                 },
                 loadingBuilder: (ctx, child, progress) {
                   if (progress == null) return child;
                   return const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator(color: hlGreen)));
                 },
               ),
            ],
          ),
        ));
      }
    } 
    // Fallback Default
    else {
      detail.forEach((k, v) {
        if (v is String && !['id','tiket_id','created_at','updated_at'].contains(k)) {
          widgets.add(_InfoRow(k.toUpperCase(), v));
        }
      });
    }
    
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: widgets);
  }

  Widget _buildTimeline(List<dynamic> logs) {
    return Column(
      children: logs.map((log) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_formatDate(log['created_at'], timeOnly: true), style: GoogleFonts.shareTechMono(color: hlOrange)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(log['status'].toString().replaceAll('_', ' ').toUpperCase(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    Text("User: ${log['user']?['name'] ?? 'SYSTEM'}", style: const TextStyle(color: Colors.grey, fontSize: 12)),
                  ],
                ),
              )
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildComments(List<dynamic>? comments) {
    return Column(
      children: [
        Row(children: [
          Expanded(child: TextField(controller: _commentController, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(hintText: "TRANSMIT MESSAGE..."))),
          const SizedBox(width: 8),
          IconButton(onPressed: sendingComment ? null : postComment, icon: const Icon(Icons.send, color: hlOrange), style: IconButton.styleFrom(backgroundColor: Colors.black, side: const BorderSide(color: hlOrange)))
        ]),
        const SizedBox(height: 16),
        if (comments == null || comments.isEmpty) const Text("NO TRANSMISSIONS RECORDED", style: TextStyle(color: Colors.grey)),
        if (comments != null) ...comments.map((c) {
           final isMe = c['pengirim']?['role'] == 'mahasiswa';
           return Container(
             margin: const EdgeInsets.only(bottom: 8),
             padding: const EdgeInsets.all(8),
             decoration: BoxDecoration(
               color: isMe ? hlOrange.withOpacity(0.1) : hlGreen.withOpacity(0.1),
               border: Border(left: BorderSide(color: isMe ? hlOrange : hlGreen, width: 3)),
             ),
             child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
               Text(c['pengirim']?['name'] ?? 'UNKNOWN', style: TextStyle(fontWeight: FontWeight.bold, color: isMe ? hlOrange : hlGreen)),
               const SizedBox(height: 4),
               Text(c['komentar'] ?? '', style: const TextStyle(color: Colors.white)),
             ]),
           );
        })
      ],
    );
  }

  String _formatDate(String? d, {bool timeOnly = false}) {
    if (d == null) return '-';
    try {
      final dt = DateTime.parse(d);
      if (timeOnly) return DateFormat('HH:mm').format(dt);
      return DateFormat('dd/MM/yyyy HH:mm').format(dt);
    } catch (e) { return d; }
  }
}

// === WIDGET HELPERS ===

class _HevCard extends StatelessWidget {
  final String title;
  final Widget child;
  final Color borderColor;
  const _HevCard({required this.title, required this.child, this.borderColor = hlOrange});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF222222),
        border: Border.all(color: borderColor, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            color: borderColor.withOpacity(0.2),
            child: Text(title, style: GoogleFonts.orbitron(fontSize: 12, fontWeight: FontWeight.bold, color: borderColor, letterSpacing: 1.5)),
          ),
          Padding(padding: const EdgeInsets.all(16), child: child),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String? value;
  const _InfoRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 110, child: Text(label, style: GoogleFonts.shareTechMono(color: Colors.grey))),
          Expanded(child: Text(value ?? '-', style: GoogleFonts.shareTechMono(color: Colors.white, fontWeight: FontWeight.bold))),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    Color c = Colors.grey;
    if (status.contains('Selesai')) c = hlGreen;
    if (status.contains('Tolak') || status.contains('Masalah')) c = hlRed;
    if (status.contains('Proses') || status.contains('Tangani')) c = hlOrange;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(border: Border.all(color: c)),
      child: Text(status.replaceAll('_', ' ').toUpperCase(), style: TextStyle(color: c, fontWeight: FontWeight.bold, fontSize: 10)),
    );
  }
}

class _AttachmentBtn extends StatelessWidget {
  final String path;
  const _AttachmentBtn({required this.path});

  @override
  Widget build(BuildContext context) {
    String fullUrl = path.startsWith('http') ? path : "$storageBaseUrl$path";
    return GestureDetector(
      onTap: () { log("Open: $fullUrl"); },
      child: Container(
        margin: const EdgeInsets.only(top: 8),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(border: Border.all(color: hlOrange)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.folder_open, color: hlOrange, size: 16),
          const SizedBox(width: 8),
          Text("ACCESS ATTACHMENT", style: GoogleFonts.shareTechMono(color: hlOrange)),
        ]),
      ),
    );
  }
}

class CountdownTimer extends StatefulWidget {
  final String deadlineStr;
  const CountdownTimer({super.key, required this.deadlineStr});
  @override
  State<CountdownTimer> createState() => _CountdownTimerState();
}

class _CountdownTimerState extends State<CountdownTimer> {
  late Timer _t;
  Duration _d = Duration.zero;
  @override
  void initState() { super.initState(); _t = Timer.periodic(const Duration(seconds: 1), (_) => _tick()); }
  void _tick() { 
    if(mounted) setState(() => _d = DateTime.parse(widget.deadlineStr).difference(DateTime.now())); 
  }
  @override
  void dispose() { _t.cancel(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    return Text("${_d.inHours}:${_d.inMinutes % 60}:${_d.inSeconds % 60}", style: GoogleFonts.orbitron(fontSize: 32, color: hlRed, fontWeight: FontWeight.bold));
  }
}