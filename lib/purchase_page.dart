import 'dart:convert';
import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:qr_flutter/qr_flutter.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';

const String baseUrl = "http://suikaxmaxxxmangyannxbrock.cloudnesia.my.id:3323";

class PurchasePage extends StatefulWidget {
  const PurchasePage({super.key});

  @override
  State<PurchasePage> createState() => _PurchasePageState();
}

class _PurchasePageState extends State<PurchasePage>
    with TickerProviderStateMixin {

  Map roles = {};
  bool loading = true;

  final username = TextEditingController();
  final password = TextEditingController();

  String selectedRole = "";
  String selectedDays = "30";

  String? qr;
  String? trxId;

  bool paid = false;
  bool expired = false;

  int timeLeft = 360;

  Timer? checkTimer;
  Timer? countdownTimer;

  late AnimationController successAnim;

  @override
  void initState() {
    super.initState();
    fetchRoles();

    successAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
  }

  Future fetchRoles() async {

    final res = await http.get(Uri.parse("$baseUrl/roles"));
    final data = jsonDecode(res.body);

    setState(() {
      roles = {for (var r in data["data"]) r["name"]: r};
      loading = false;
    });
  }

  Future createTransaction() async {

    if(username.text.isEmpty || password.text.isEmpty || selectedRole.isEmpty){
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text("Lengkapi semua data"))
  );
  return;
}

    final res = await http.post(
      Uri.parse("$baseUrl/createTransaction"),
      body: {
        "user_id": username.text,
        "password": password.text,
        "role": selectedRole,
        "days": selectedDays
      },
    );

    final data = jsonDecode(res.body);

    if(data["status"] == true){

      setState(() {
        qr = data["qr"];
        trxId = data["id"].toString();
      });

      startCountdown();
      startChecking();
    }
  }

  void startCountdown(){

    countdownTimer = Timer.periodic(const Duration(seconds:1),(t){

      if(timeLeft <= 0){

        t.cancel();

        setState(() {
          expired = true;
        });

      }else{

        setState(() {
          timeLeft--;
        });

      }
    });
  }

  void startChecking(){

    checkTimer = Timer.periodic(const Duration(seconds:5),(t) async {

      final res = await http.post(
        Uri.parse("$baseUrl/checkTransaction"),
        body: {"id": trxId},
      );

      final data = jsonDecode(res.body);

      if(data["paid"] == true){

        t.cancel();
        countdownTimer?.cancel();

        setState(() {
          paid = true;
        });

        successAnim.forward();
      }
    });
  }

  String formatTime(){

    int m = timeLeft ~/ 60;
    int s = timeLeft % 60;

    return "$m:${s.toString().padLeft(2,'0')}";
  }

  Future downloadReceipt() async {

    final pdf = pw.Document();

    final now = DateFormat("yyyy-MM-dd HH:mm").format(DateTime.now());

    pdf.addPage(
      pw.Page(
        build:(context){

          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [

              pw.Text(
                "SADISTIC RECEIPT",
                style: pw.TextStyle(
                  fontSize:24,
                  fontWeight: pw.FontWeight.bold
                )
              ),

              pw.SizedBox(height:20),

              row("Transaction ID",trxId ?? ""),
              row("Username",username.text),
              row("Password",password.text),
              row("Role",selectedRole),
              row("Duration","$selectedDays Days"),
              row("Date",now),

              pw.SizedBox(height:20),

              pw.Text(
                "Payment Success",
                style: pw.TextStyle(color: PdfColors.green)
              )
            ],
          );
        }
      )
    );

    final bytes = await pdf.save();

    await Printing.sharePdf(
      bytes: bytes,
      filename: "receipt_$trxId.pdf"
    );
  }

  pw.Widget row(String t,String v){

    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical:5),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children:[
          pw.Text(t),
          pw.Text(v)
        ]
      )
    );
  }

  Widget glassCard(Widget child){

    return ClipRRect(
      borderRadius: BorderRadius.circular(25),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX:20,sigmaY:20),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(25),
            border: Border.all(color: Colors.white.withOpacity(0.15)),
            gradient: LinearGradient(
              colors:[
                Colors.white.withOpacity(0.1),
                Colors.white.withOpacity(0.02)
              ]
            )
          ),
          child: child,
        ),
      ),
    );
  }

  Widget roleCard(String role, Map data){

    final price = (data["days"] ?? {})[selectedDays] ?? "0";
    final selected = selectedRole == role;

    return GestureDetector(
      onTap: (){
        setState(() {
          selectedRole = role;
        });
      },

      child: AnimatedContainer(
        duration: const Duration(milliseconds:300),
        margin: const EdgeInsets.only(bottom:15),
        decoration: BoxDecoration(
          gradient: selected
              ? const LinearGradient(
                  colors:[Color(0xff7F00FF),Color(0xff00C6FF)])
              : null,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: selected ? Colors.transparent : Colors.white24),
        ),

        child: glassCard(

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [

              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  Text(
                    role.toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold
                    ),
                  ),

                  Text(
                    "Profit: ${data["keuntungan"]}",
                    style: const TextStyle(color: Colors.white70),
                  )
                ],
              ),

              Text(
                "Rp $price",
                style: const TextStyle(
                  color: Colors.greenAccent,
                  fontWeight: FontWeight.bold
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget qrSection(){

    if(qr == null) return const SizedBox();

    if(expired){

      return const Text(
        "Waktu pembayaran habis",
        style: TextStyle(color: Colors.red,fontSize:18),
      );
    }

    if(paid){

      return Column(
        children: [

          ScaleTransition(
            scale: successAnim,
            child: const Icon(
              Icons.check_circle,
              size:120,
              color: Colors.green,
            ),
          ),

          const SizedBox(height:20),

          const Text(
            "PEMBAYARAN BERHASIL",
            style: TextStyle(
              color: Colors.white,
              fontSize:22,
              fontWeight: FontWeight.bold
            ),
          ),

          const SizedBox(height:20),

          ElevatedButton(
            onPressed: downloadReceipt,
            child: const Text("Download Struk"),
          )
        ],
      );
    }

    return Column(
      children: [

        const Text(
          "SCAN QRIS",
          style: TextStyle(color: Colors.white,fontSize:22),
        ),

        const SizedBox(height:20),

        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(30)
          ),
          child: QrImageView(
            data: qr!,
            size: 220,
          ),
        ),

        const SizedBox(height:15),

        Text(
          "Harap transfer dalam ${formatTime()}",
          style: const TextStyle(color: Colors.white70),
        )
      ],
    );
  }

@override
Widget build(BuildContext context) {
  return Scaffold(
    body: Stack(
      children: [
        // Background image
        Positioned.fill(
          child: Image.asset(
            "assets/images/vecto.jpg",
            fit: BoxFit.cover,
          ),
        ),

        // Dark blur overlay
        BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(color: Colors.black.withOpacity(0.6)),
        ),

        SafeArea(
          child: loading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      const SizedBox(height: 20),

                      const Text(
                        "VECTO X CRASH",
                        style: TextStyle(
                          fontSize: 28,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2,
                        ),
                      ),

                      const SizedBox(height: 30),

                      // Username
                      glassCard(
                        TextField(
                          controller: username,
                          style: const TextStyle(color: Colors.white, fontSize: 18),
                          decoration: InputDecoration(
                            hintText: "Username",
                            hintStyle: const TextStyle(color: Colors.white70, fontSize: 16),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Colors.white24),
                            ),
                            filled: true,
                            fillColor: Colors.white.withOpacity(0.05),
                            contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Password
                      glassCard(
                        TextField(
                          controller: password,
                          style: const TextStyle(color: Colors.white, fontSize: 18),
                          obscureText: true,
                          decoration: InputDecoration(
                            hintText: "Password",
                            hintStyle: const TextStyle(color: Colors.white70, fontSize: 16),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Colors.white24),
                            ),
                            filled: true,
                            fillColor: Colors.white.withOpacity(0.05),
                            contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Dropdown Durasi
                      glassCard(
                        DropdownButtonFormField<String>(
                          value: selectedDays,
                          dropdownColor: Colors.black,
                          decoration: InputDecoration(
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Colors.white24),
                            ),
                            filled: true,
                            fillColor: Colors.white.withOpacity(0.05),
                            contentPadding: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
                          ),
                          items: const [
                            DropdownMenuItem(value: "30", child: Text("30 Hari", style: TextStyle(color: Colors.white))),
                            DropdownMenuItem(value: "999", child: Text("999 Hari", style: TextStyle(color: Colors.white))),
                          ],
                          onChanged: (v) {
                            setState(() => selectedDays = v!);
                          },
                        ),
                      ),

                      const SizedBox(height: 25),

                      // Role Selection Cards
                      ...roles.keys.map((r) => roleCard(r, roles[r])),

                      const SizedBox(height: 25),

                      // Buy Button
                      GestureDetector(
                        onTap: createTransaction,
                        child: Container(
                          height: 60,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xff7F00FF), Color(0xff00C6FF)],
                            ),
                            borderRadius: BorderRadius.circular(40),
                          ),
                          alignment: Alignment.center,
                          child: const Text(
                            "BELI SEKARANG",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              letterSpacing: 2,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 40),

                      // QR Section
                      qrSection(),

                      const SizedBox(height: 40),
                    ],
                  ),
                ),
        ),
      ],
    ),
  );
}
}