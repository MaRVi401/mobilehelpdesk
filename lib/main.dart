import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';

// === THEME COLORS ===
const Color hlOrange = Color(0xFFFF9D00); 
const Color hlBg = Color(0xFF1C1C1C);     
const Color hlPanel = Color(0xFF2B2B2B);  
const Color hlGreen = Color(0xFF62B236);  
const Color hlRed = Color(0xFFD92424);    

// === CONFIG ===
// Ganti IP ini sesuai perangkat:
// Emulator Android: 10.0.2.2
// Real Device / iOS: Gunakan IP Laptop (misal: 192.168.1.x)
const String apiBaseUrl = "http://10.0.2.2:8000/api"; 
const String storageBaseUrl = "http://10.0.2.2:8000/storage/";
const String apiKey = "dalit123";

void main() async{
  WidgetsFlutterBinding.ensureInitialized();
  await SharedPreferences.getInstance();
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
      home: const AuthCheck(),
    );
  }
}

// === 1. AUTH CHECKER ===
class AuthCheck extends StatefulWidget {
  const AuthCheck({super.key});
  @override
  State<AuthCheck> createState() => _AuthCheckState();
}

class _AuthCheckState extends State<AuthCheck> {
  @override
  void initState() { super.initState(); _checkLogin(); }

  Future<void> _checkLogin() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    if (mounted) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => 
        token != null ? const MainScreen() : const LoginPage()
      ));
    }
  }
  @override
  Widget build(BuildContext context) => const Scaffold(body: Center(child: CircularProgressIndicator(color: hlOrange)));
}

// === 2. LOGIN PAGE ===
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _isLoading = false;
  bool _isObscure = true; 
  final GoogleSignIn _googleSignIn = GoogleSignIn(scopes: ['email']);

  Future<void> _login(bool isGoogle) async {
    setState(() => _isLoading = true);
    try {
      String endpoint = isGoogle ? '/auth/google-mobile' : '/auth/login';
      Map<String, dynamic> body = {};

      if (isGoogle) {
        final gUser = await _googleSignIn.signIn();
        if (gUser == null) { setState(() => _isLoading = false); return; }
        
        // Validasi Domain jika diperlukan
        // if (!gUser.email.endsWith('@student.polindra.ac.id')) { ... }

        body = {
          'email': gUser.email,
          'google_id': gUser.id,
          'name': gUser.displayName ?? 'AGENT',
          'avatar': gUser.photoUrl ?? ''
        };
      } else {
        if (_emailCtrl.text.isEmpty || _passCtrl.text.isEmpty) {
          _alert("INPUT ERROR", "Please enter email and password");
          setState(() => _isLoading = false);
          return;
        }
        body = {'email': _emailCtrl.text, 'password': _passCtrl.text};
      }

      final res = await http.post(
        Uri.parse("$apiBaseUrl$endpoint"),
        headers: {'Accept': 'application/json'},
        body: body,
      );

      log("Login Response: ${res.body}"); // Debugging

      final data = jsonDecode(res.body);
      if (res.statusCode == 200 && data['success'] == true) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('auth_token', data['token']);
        if(data['data'] != null && data['data']['name'] != null) {
           await prefs.setString('user_name', data['data']['name']);
        }
        if(mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const MainScreen()));
      } else {
        if(isGoogle) await _googleSignIn.signOut();
        if(mounted) _alert("LOGIN FAILED", data['message'] ?? "Unauthorized access");
      }
    } catch (e) {
      log("Login Error: $e");
      if(mounted) _alert("SYSTEM ERROR", "Connection failed. Check your internet or server URL.");
    } finally {
      if(mounted) setState(() => _isLoading = false);
    }
  }

  void _alert(String title, String msg) {
    showDialog(context: context, builder: (ctx) => AlertDialog(
      backgroundColor: hlPanel,
      shape: RoundedRectangleBorder(side: const BorderSide(color: hlRed), borderRadius: BorderRadius.circular(4)),
      title: Text(title, style: GoogleFonts.orbitron(color: hlRed, fontWeight: FontWeight.bold)),
      content: Text(msg, style: GoogleFonts.shareTechMono(color: Colors.white)),
      actions: [TextButton(onPressed: ()=>Navigator.pop(ctx), child: const Text("CLOSE", style: TextStyle(color: hlOrange)))]
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.security_outlined, size: 80, color: hlOrange),
                const SizedBox(height: 20),
                Text("HELPDESK ACCESS", style: GoogleFonts.orbitron(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 2)),
                const SizedBox(height: 40),
                TextField(
                  controller: _emailCtrl, 
                  style: GoogleFonts.shareTechMono(color: hlOrange), 
                  decoration: const InputDecoration(labelText: "EMAIL", prefixIcon: Icon(Icons.person, color: hlOrange))
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _passCtrl, 
                  obscureText: _isObscure, 
                  style: GoogleFonts.shareTechMono(color: hlOrange), 
                  decoration: InputDecoration(
                    labelText: "PASSWORD", 
                    prefixIcon: const Icon(Icons.lock, color: hlOrange),
                    suffixIcon: IconButton(
                      icon: Icon(_isObscure ? Icons.visibility_off : Icons.visibility, color: hlOrange),
                      onPressed: () => setState(() => _isObscure = !_isObscure),
                    )
                  )
                ),
                const SizedBox(height: 24),
                if (_isLoading) 
                  const CircularProgressIndicator(color: hlOrange) 
                else Column(
                  children: [
                    SizedBox(width: double.infinity, child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: hlOrange, foregroundColor: Colors.black, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4))),
                      onPressed: () => _login(false),
                      child: Text("LOGIN", style: GoogleFonts.orbitron(fontWeight: FontWeight.bold)),
                    )),
                    const SizedBox(height: 16),
                    SizedBox(width: double.infinity, child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.white54), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4))),
                      onPressed: () => _login(true),
                      icon: const Icon(Icons.g_mobiledata, color: Colors.white),
                      label: Text("GOOGLE LOGIN", style: GoogleFonts.shareTechMono(color: Colors.white)),
                    )),
                  ],
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// === 3. MAIN SCREEN ===
class MainScreen extends StatefulWidget {
  const MainScreen({super.key});
  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _index = 0;
  final List<Widget> _pages = [
    const MyTicketListPage(),
    const SearchTicketPage(),
  ];

  void _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    await GoogleSignIn().signOut();
    if(mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginPage()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("POLINDRA HELPDESK", style: GoogleFonts.orbitron(letterSpacing: 2, color: hlOrange, fontSize: 18)),
        backgroundColor: Colors.black,
        centerTitle: true,
        bottom: PreferredSize(preferredSize: const Size.fromHeight(2), child: Container(color: hlOrange, height: 2)),
        actions: [IconButton(onPressed: _logout, icon: const Icon(Icons.logout, color: hlRed))],
      ),
      body: _pages[_index],
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: const Color(0xFF111111),
        selectedItemColor: hlOrange,
        unselectedItemColor: Colors.grey,
        currentIndex: _index,
        onTap: (i) => setState(() => _index = i),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.list_alt), label: "My Tickets"),
          BottomNavigationBarItem(icon: Icon(Icons.search), label: "Search"),
        ],
      ),
    );
  }
}

// === 4. LIST TIKET SAYA (FIXED) ===
class MyTicketListPage extends StatefulWidget {
  const MyTicketListPage({super.key});
  @override
  State<MyTicketListPage> createState() => _MyTicketListPageState();
}

class _MyTicketListPageState extends State<MyTicketListPage> {
  List<dynamic> tickets = [];
  bool loading = true;
  String? error;

  @override
  void initState() { super.initState(); _loadTickets(); }

  Future<void> _loadTickets() async {
    if(!mounted) return;
    setState(() { loading = true; error = null; });
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      
      final res = await http.get(
        Uri.parse("$apiBaseUrl/tiket/my-tickets"),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
          'API_KEY_MAHASISWA': apiKey
        }
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['success'] == true) {
          // SAFE PARSING: Ensure data['data'] is treated as list even if empty
          setState(() {
            if (data['data'] is List) {
              tickets = data['data'];
            } else {
              tickets = []; // Fallback if data is not list
            }
          });
        } else {
          setState(() => error = data['message']);
        }
      } else {
        setState(() => error = "Server Error: ${res.statusCode}");
      }
    } catch (e) {
      log("Fetch Error: $e");
      setState(() => error = "Connection failed");
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  // Helper untuk memformat tanggal dengan aman
  String _safeDate(dynamic dateString) {
    if (dateString == null) return '-';
    try {
      return DateFormat('dd MMM yy HH:mm').format(DateTime.parse(dateString.toString()));
    } catch (e) {
      return '-';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator(color: hlOrange));
    if (error != null) return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Text(error!, style: GoogleFonts.shareTechMono(color: hlRed)),
      const SizedBox(height: 10),
      ElevatedButton(onPressed: _loadTickets, style: ElevatedButton.styleFrom(backgroundColor: hlOrange), child: const Text("RETRY", style: TextStyle(color: Colors.black)))
    ]));
    if (tickets.isEmpty) return Center(child: Text("NO DATA FOUND", style: GoogleFonts.orbitron(color: Colors.grey)));

    return RefreshIndicator(
      color: hlOrange,
      backgroundColor: hlPanel,
      onRefresh: _loadTickets,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: tickets.length,
        separatorBuilder: (_,__) => const SizedBox(height: 12),
        itemBuilder: (ctx, i) {
          final t = tickets[i];
          final riwayat = (t['riwayat_status'] as List?) ?? [];
          
          String currentStatus = t['status'] ?? 'PENDING';
          if (riwayat.isNotEmpty) {
            currentStatus = riwayat[0]['status'] ?? 'PENDING';
          }
          
          // Logic Unit dengan Null Safety Ekstra
          String unitName = 'UNIT N/A';
          if (t['unit'] != null && t['unit']['nama_unit'] != null) {
            unitName = t['unit']['nama_unit'];
          } else if (t['layanan'] != null && t['layanan']['unit'] != null && t['layanan']['unit']['nama_unit'] != null) {
            unitName = t['layanan']['unit']['nama_unit'];
          }

          return InkWell(
            onTap: () {
               Navigator.push(context, MaterialPageRoute(builder: (_) => TicketDetailPage(ticketId: "${t['no_tiket']}")));
            },
            child: _HevCard(
              title: "${t['no_tiket'] ?? 'ID_ERROR'}",
              borderColor: _getStatusColor(currentStatus),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                       // Menggunakan Expanded agar text panjang tidak error
                       Expanded(
                         child: Text(
                           t['layanan']?['nama'] ?? 'UNKNOWN SERVICE', 
                           style: GoogleFonts.shareTechMono(color: Colors.white, fontWeight: FontWeight.bold), 
                           maxLines: 1, 
                           overflow: TextOverflow.ellipsis
                         )
                       ),
                       const SizedBox(width: 8),
                       _StatusBadge(status: currentStatus.replaceAll('_', ' ').toUpperCase()), 
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(unitName, style: GoogleFonts.shareTechMono(color: Colors.grey, fontSize: 12)),
                  const SizedBox(height: 4),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      _safeDate(t['created_at']),
                      style: GoogleFonts.shareTechMono(fontSize: 10, color: hlOrange),
                    ),
                  )
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Color _getStatusColor(String s) {
    s = s.toLowerCase();
    if(s.contains('selesai')) return hlGreen;
    if(s.contains('tolak') || s.contains('masalah')) return hlRed;
    return hlOrange;
  }
}

// === 5. SEARCH PAGE ===
class SearchTicketPage extends StatefulWidget {
  const SearchTicketPage({super.key});
  @override
  State<SearchTicketPage> createState() => _SearchTicketPageState();
}

class _SearchTicketPageState extends State<SearchTicketPage> {
  final _ctrl = TextEditingController();
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          color: const Color(0xFF111111),
          padding: const EdgeInsets.all(20),
          child: Row(children: [
            Expanded(child: TextField(controller: _ctrl, style: GoogleFonts.shareTechMono(color: hlOrange, fontSize: 18), decoration: const InputDecoration(labelText: "TICKET ID", prefixIcon: Icon(Icons.qr_code, color: hlOrange)))),
            const SizedBox(width: 12),
            InkWell(
              onTap: () {
                if(_ctrl.text.isNotEmpty) {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => TicketDetailPage(ticketId: _ctrl.text)));
                }
              },
              child: Container(
                height: 56, width: 60,
                decoration: BoxDecoration(color: hlOrange.withOpacity(0.1), border: Border.all(color: hlOrange), borderRadius: BorderRadius.circular(4)),
                child: const Icon(Icons.search, color: hlOrange, size: 30),
              ),
            )
          ]),
        ),
        Expanded(child: Center(child: Opacity(opacity: 0.3, child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.radar, size: 100, color: hlOrange),
          const SizedBox(height: 20),
          Text("SYSTEM READY", style: GoogleFonts.orbitron(color: hlOrange))
        ])))),
      ],
    );
  }
}

// === 6. TICKET DETAIL (FIXED) ===
class TicketDetailPage extends StatefulWidget {
  final String ticketId;
  const TicketDetailPage({super.key, required this.ticketId});
  @override
  State<TicketDetailPage> createState() => _TicketDetailPageState();
}

class _TicketDetailPageState extends State<TicketDetailPage> {
  Map<String, dynamic>? tiketData;
  String? deadlineTimer;
  bool loading = true;
  String? error;
  final _commentController = TextEditingController();
  bool sending = false;

  @override
  void initState() { super.initState(); _fetch(); }

  Future<void> _fetch() async {
    setState(() { loading = true; error = null; });
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      
      final url = Uri.parse("$apiBaseUrl/tiket/${Uri.encodeComponent(widget.ticketId)}");
      final res = await http.get(url, headers: {
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
        'API_KEY_MAHASISWA': apiKey
      });

      if (res.statusCode == 200) {
        final d = jsonDecode(res.body);
        if (d['success'] == true) {
          setState(() { tiketData = d['data']; deadlineTimer = d['deadline_timer']; });
        } else {
          setState(() => error = d['message']);
        }
      } else {
        setState(() => error = "Error ${res.statusCode}: Not Found");
      }
    } catch (e) {
      setState(() => error = "Network Error");
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _postComment() async {
    if (_commentController.text.trim().isEmpty) return;
    setState(() => sending = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      // Safety check
      if (tiketData == null || tiketData!['id'] == null) return;

      final url = Uri.parse("$apiBaseUrl/tiket/${tiketData!['id']}/komentar");
      final res = await http.post(url, headers: {
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
        'API_KEY_MAHASISWA': apiKey
      }, body: {'komentar': _commentController.text});

      if (res.statusCode == 200) {
        _commentController.clear();
        _fetch(); // Refresh data
      } else {
        log("Comment Error: ${res.body}");
      }
    } catch(e) { log("Err: $e"); }
    finally { if (mounted) setState(() => sending = false); }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("TICKET: ${widget.ticketId}", style: GoogleFonts.orbitron(color: hlOrange)),
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: hlOrange),
      ),
      body: loading ? const Center(child: CircularProgressIndicator(color: hlOrange)) :
            error != null ? Center(child: Text(error!, style: GoogleFonts.shareTechMono(color: hlRed))) :
            SingleChildScrollView(padding: const EdgeInsets.all(16), child: _buildContent(tiketData!)),
    );
  }

  Widget _buildContent(Map<String, dynamic> data) {
    final pemohon = data['pemohon'] ?? {};
    final mahasiswa = data['mahasiswa'] ?? pemohon['mahasiswa'] ?? {};
    final prodi = mahasiswa['program_studi'] ?? {};
    final jurusan = prodi['jurusan'] ?? {};
    final layananNama = data['layanan']?['nama'] ?? 'UNKNOWN';
    
    // FIX Unit Logic yang Robust
    String unit = 'N/A';
    if (data['unit'] != null && data['unit']['nama_unit'] != null) {
      unit = data['unit']['nama_unit'];
    } else if (data['layanan'] != null && data['layanan']['unit'] != null) {
      unit = data['layanan']['unit']['nama_unit'] ?? 'N/A';
    }
              
    final detailLayanan = data['detail'];
    final riwayat = (data['riwayat_status'] as List?) ?? [];
    
    String status = data['status'] ?? 'PENDING';
    if (riwayat.isNotEmpty) status = riwayat[0]['status'] ?? status;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _HevCard(title: "STATUS", child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Expanded(child: Text("#${data['no_tiket'] ?? '-'}", style: GoogleFonts.orbitron(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white))),
          _StatusBadge(status: status.replaceAll('_', ' ').toUpperCase()), 
        ])),
        const SizedBox(height: 16),

        if (status == 'Diselesaikan_oleh_PIC' && deadlineTimer != null)
           _HevCard(title: "AUTO CLOSE TIMER", borderColor: hlRed, child: Column(children: [
             Text("Ticket will close automatically in:", style: GoogleFonts.shareTechMono(color: hlRed)),
             const SizedBox(height: 8),
             CountdownTimer(deadlineStr: deadlineTimer!),
           ])),
        if (status == 'Diselesaikan_oleh_PIC' && deadlineTimer != null) const SizedBox(height: 16),

        _HevCard(title: "USER INFO", child: Column(children: [
          _InfoRow("NAMA", pemohon['name'] ?? mahasiswa['nama'] ?? 'N/A'),
          _InfoRow("NIM", mahasiswa['nim'] ?? 'N/A'),
          _InfoRow("JURUSAN", jurusan['nama_jurusan'] ?? 'N/A'),
          _InfoRow("PRODI", prodi['nama_prodi'] ?? 'N/A'),
        ])),
        const SizedBox(height: 16),

        _HevCard(title: "DETAILS", child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _InfoRow("SERVICE", layananNama),
          _InfoRow("UNIT", unit),
          const Divider(color: Colors.white24, height: 24),
          Text("DESCRIPTION:", style: GoogleFonts.shareTechMono(color: hlOrange, fontSize: 12)),
          const SizedBox(height: 4),
          Text(data['deskripsi'] ?? '-', style: GoogleFonts.shareTechMono(fontSize: 16)),
          if (data['lampiran'] != null) _AttachmentBtn(path: data['lampiran']),
        ])),
        const SizedBox(height: 16),

        if (detailLayanan != null) _HevCard(title: "SPECIFIC DATA", borderColor: hlGreen, child: _buildDynamicSpecificData(layananNama, detailLayanan)),
        if (detailLayanan != null) const SizedBox(height: 16),

        _HevCard(title: "HISTORY", child: Column(children: riwayat.map((l) => Padding(padding: const EdgeInsets.only(bottom: 12), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(_formatDate(l['created_at'], timeOnly: true), style: GoogleFonts.shareTechMono(color: hlOrange)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text((l['status'] ?? '-').toString().replaceAll('_', ' ').toUpperCase(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            Text("By: ${l['user']?['name'] ?? 'SYSTEM'}", style: const TextStyle(color: Colors.grey, fontSize: 12)),
          ]))
        ]))).toList())),
        const SizedBox(height: 16),

        _HevCard(title: "COMMENTS", child: Column(children: [
          Row(children: [
            Expanded(child: TextField(controller: _commentController, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(hintText: "Type a message..."))),
            const SizedBox(width: 8),
            IconButton(onPressed: sending ? null : _postComment, icon: const Icon(Icons.send, color: hlOrange), style: IconButton.styleFrom(backgroundColor: Colors.black, side: const BorderSide(color: hlOrange)))
          ]),
          const SizedBox(height: 16),
          if ((data['komentar'] as List? ?? []).isEmpty) const Text("No comments yet.", style: TextStyle(color: Colors.grey)),
          ...(data['komentar'] as List? ?? []).map((c) {
             final isMe = c['pengirim']?['role'] == 'mahasiswa';
             return Container(margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: isMe ? hlOrange.withOpacity(0.1) : hlGreen.withOpacity(0.1), border: Border(left: BorderSide(color: isMe ? hlOrange : hlGreen, width: 3))), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
               Text(c['pengirim']?['name'] ?? 'UNKNOWN', style: TextStyle(fontWeight: FontWeight.bold, color: isMe ? hlOrange : hlGreen)),
               const SizedBox(height: 4),
               Text(c['komentar'] ?? '', style: const TextStyle(color: Colors.white)),
             ]));
          })
        ])),
      ],
    );
  }

  Widget _buildDynamicSpecificData(String namaLayanan, Map<String, dynamic> detail) {
    List<Widget> widgets = [];
    String lower = namaLayanan.toLowerCase();
    
    // Custom display untuk layanan Publikasi (contoh kasus)
    if (lower.contains('publikasi')) {
      if(detail['judul'] != null) widgets.add(_InfoRow("Topik", detail['judul']));
      if(detail['kategori'] != null) widgets.add(_InfoRow("Kategori", detail['kategori']));
      if(detail['konten'] != null) widgets.add(Text("CONTENT: ${detail['konten']}", style: GoogleFonts.shareTechMono(fontSize: 14)));
      if (detail['gambar'] != null) {
         String imgUrl = detail['gambar'].startsWith('http') ? detail['gambar'] : "$storageBaseUrl${detail['gambar']}";
         widgets.add(const SizedBox(height: 16));
         widgets.add(Container(height: 150, width: double.infinity, decoration: BoxDecoration(border: Border.all(color: hlGreen)), child: Image.network(imgUrl, fit: BoxFit.cover, errorBuilder: (ctx,e,s)=>const Center(child: Icon(Icons.broken_image, color: hlRed)))));
      }
    } else {
      // Default dynamic display
      detail.forEach((k, v) { 
        if (v is String && !['id','tiket_id','created_at','updated_at'].contains(k)) {
          widgets.add(_InfoRow(k.toUpperCase().replaceAll('_', ' '), v)); 
        }
      });
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: widgets);
  }

  String _formatDate(dynamic d, {bool timeOnly = false}) {
    if (d == null) return '-';
    try { final dt = DateTime.parse(d.toString()); return timeOnly ? DateFormat('HH:mm').format(dt) : DateFormat('dd/MM/yy HH:mm').format(dt); } catch (e) { return '-'; }
  }
}

// === WIDGET HELPERS ===
class _HevCard extends StatelessWidget {
  final String title; final Widget child; final Color borderColor;
  const _HevCard({required this.title, required this.child, this.borderColor = hlOrange});
  @override
  Widget build(BuildContext context) => Container(width: double.infinity, decoration: BoxDecoration(color: const Color(0xFF222222), border: Border.all(color: borderColor, width: 1.5), borderRadius: BorderRadius.circular(4)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Container(width: double.infinity, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4), color: borderColor.withOpacity(0.2), child: Text(title, style: GoogleFonts.orbitron(fontSize: 12, fontWeight: FontWeight.bold, color: borderColor, letterSpacing: 1.5))), Padding(padding: const EdgeInsets.all(16), child: child)]));
}
class _InfoRow extends StatelessWidget {
  final String label; final String? value;
  const _InfoRow(this.label, this.value);
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.only(bottom: 8), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [SizedBox(width: 110, child: Text(label, style: GoogleFonts.shareTechMono(color: Colors.grey))), Expanded(child: Text(value ?? '-', style: GoogleFonts.shareTechMono(color: Colors.white, fontWeight: FontWeight.bold)))]));
}
class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});
  @override
  Widget build(BuildContext context) {
    Color c = Colors.grey;
    String upper = status.toUpperCase();
    if (upper.contains('SELESAI')) c = hlGreen;
    if (upper.contains('TOLAK') || upper.contains('MASALAH')) c = hlRed;
    if (upper.contains('PROSES') || upper.contains('TANGANI')) c = hlOrange;
    return Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(border: Border.all(color: c), borderRadius: BorderRadius.circular(4)), child: Text(upper, style: TextStyle(color: c, fontWeight: FontWeight.bold, fontSize: 10)));
  }
}
class _AttachmentBtn extends StatelessWidget {
  final String path;
  const _AttachmentBtn({required this.path});
  @override
  Widget build(BuildContext context) => GestureDetector(onTap: () { log("Open: $storageBaseUrl$path"); }, child: Container(margin: const EdgeInsets.only(top: 8), padding: const EdgeInsets.all(8), decoration: BoxDecoration(border: Border.all(color: hlOrange), borderRadius: BorderRadius.circular(4)), child: Row(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.folder_open, color: hlOrange, size: 16), const SizedBox(width: 8), Text("OPEN FILE", style: GoogleFonts.shareTechMono(color: hlOrange))])));
}
class CountdownTimer extends StatefulWidget {
  final String deadlineStr;
  const CountdownTimer({super.key, required this.deadlineStr});
  @override
  State<CountdownTimer> createState() => _CountdownTimerState();
}
class _CountdownTimerState extends State<CountdownTimer> {
  late Timer _t; Duration _d = Duration.zero;
  @override
  void initState() { super.initState(); _startTimer(); }
  void _startTimer() {
    try {
      final end = DateTime.parse(widget.deadlineStr);
      _t = Timer.periodic(const Duration(seconds: 1), (_) {
        if(mounted) setState(() => _d = end.difference(DateTime.now()));
      });
    } catch(e) { _d = Duration.zero; }
  }
  @override
  void dispose() { if(mounted) _t.cancel(); super.dispose(); }
  @override
  Widget build(BuildContext context) => Text(_d.isNegative ? "00:00:00" : "${_d.inHours}:${_d.inMinutes % 60}:${_d.inSeconds % 60}", style: GoogleFonts.orbitron(fontSize: 32, color: hlRed, fontWeight: FontWeight.bold));
}