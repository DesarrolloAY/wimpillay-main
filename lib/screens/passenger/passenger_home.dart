import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:wimpillay_main/models/ticket_model.dart';
import 'package:wimpillay_main/services/ticket_service.dart';
import 'package:wimpillay_main/services/ocr_service.dart';
import 'package:wimpillay_main/screens/passenger/ticket_screen.dart';
import 'package:wimpillay_main/screens/auth/auth_service.dart';
import 'package:flutter/services.dart'; // Para clipboard
import 'package:gal/gal.dart'; // Para guardar en galería

class PassengerHome extends StatefulWidget {
  const PassengerHome({super.key});

  @override
  State<PassengerHome> createState() => _PassengerHomeState();
}

class _PassengerHomeState extends State<PassengerHome> {
  int adult = 0;
  int university = 0;
  int school = 0;
  final double adultPrice = 1.0;
  final double universityPrice = 0.5;
  final double schoolPrice = 0.5;
  bool _isProcessing = false;

  double get total =>
      adult * adultPrice + university * universityPrice + school * schoolPrice;

  final TicketService _ticketService = TicketService();
  final OcrService _ocrService = OcrService();
  final ImagePicker _picker = ImagePicker();
  final user = FirebaseAuth.instance.currentUser;
  final AuthService _authService = AuthService();

  @override
  void dispose() {
    _ocrService.dispose();
    super.dispose();
  }

  // --- FUNCIÓN NUEVA: Mostrar errores en Pop-up elegante ---
  void _showErrorDialog(String message) {
    // Limpiamos el mensaje para que no diga "Exception:" al principio
    final cleanMessage = message.replaceAll("Exception:", "").trim();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: const Row(
          children: [
            Icon(Icons.info_outline, color: Colors.orange, size: 28),
            SizedBox(width: 10),
            Text("Atención"),
          ],
        ),
        content: Text(
          cleanMessage,
          style: const TextStyle(fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Entendido",
                style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // --- FUNCIÓN PARA GUARDAR EL QR EN GALERÍA ---
  Future<void> _saveQrToGallery() async {
    try {
      final ByteData bytes = await rootBundle.load('assets/qr_yape.jpg');
      final Uint8List list = bytes.buffer.asUint8List();
      await Gal.putImageBytes(list);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ QR guardado en tu galería'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      // CAMBIO AQUÍ: Usamos el Pop-up en lugar del SnackBar
      _showErrorDialog("No se pudo guardar la imagen: $e");
    }
  }

  // --- 1. MOSTRAR INSTRUCCIONES DE PAGO ---
  void _showPaymentInstructions() {
    if (total <= 0) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Selecciona pasajeros')));
      return;
    }

    const Color brandColor = Color(0xFF7CBF39);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Theme.of(context).cardColor,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          contentPadding: EdgeInsets.zero,
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // CABECERA VERDE
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  color: brandColor,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: const Text(
                  "Yapear a Wimpillay",
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 20),

              // QR
              Container(
                height: 180,
                width: 180,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Image.asset('assets/qr_yape.jpg',
                    fit: BoxFit.cover,
                    errorBuilder: (c, o, s) => const Icon(Icons.qr_code_2,
                        size: 100, color: Colors.black)),
              ),

              // BOTÓN GUARDAR QR
              TextButton.icon(
                onPressed: _saveQrToGallery,
                icon: const Icon(Icons.download, size: 18, color: brandColor),
                label: const Text("Guardar QR en Galería",
                    style: TextStyle(color: brandColor)),
              ),

              const SizedBox(height: 5),

              // BOTÓN COPIAR NÚMERO
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 40),
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text("933 429 201",
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    IconButton(
                      icon: const Icon(Icons.copy, size: 20, color: brandColor),
                      onPressed: () {
                        Clipboard.setData(
                            const ClipboardData(text: "933429201"));
                        ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Número copiado')));
                      },
                    ),
                  ],
                ),
              ),

              const Divider(height: 30),

              // DATOS
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    Text("Destino:", style: TextStyle(color: Colors.grey[400])),
                    const Text("Elvis A. Flores G.",
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 10),
                    Text("Monto a pagar:",
                        style: TextStyle(color: Colors.grey[400])),
                    Text("S/. ${total.toStringAsFixed(2)}",
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 26,
                            color: brandColor)),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // BOTÓN ACCIÓN
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: brandColor,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10))),
                    icon: const Icon(Icons.upload_file, color: Colors.white),
                    label: const Text("YA PAGUÉ, SUBIR VOUCHER",
                        style: TextStyle(
                            color: Colors.white, fontWeight: FontWeight.bold)),
                    onPressed: () {
                      Navigator.pop(context);
                      _scanAndValidateVoucher();
                    },
                  ),
                ),
              ),
              const SizedBox(height: 10),
            ],
          ),
        );
      },
    );
  }

  // --- 2. VALIDACIÓN VOUCHER (OCR) ---
  Future<void> _scanAndValidateVoucher() async {
    final XFile? image =
        await _picker.pickImage(source: ImageSource.gallery, imageQuality: 80);

    if (image == null) return;

    setState(() => _isProcessing = true);

    try {
      final data = await _ocrService.scanPaymentVoucher(image);

      final String scannedAmountStr = data['amount'] ?? "0";
      final String scannedCode = data['code'] ?? "";
      final String receiver = data['receiver'] ?? "";
      final String time = data['time'] ?? "";
      final bool isDateValid = data['isDateValid'] ?? true;

      final double amountDetected = double.tryParse(scannedAmountStr) ?? 0.0;

      List<String> warnings = [];
      bool criticalError = false;

      // Validaciones
      if ((amountDetected - total).abs() > 0.10) {
        warnings.add(
            "⚠️ El monto (S/ $scannedAmountStr) no coincide con el total (S/ ${total.toStringAsFixed(2)}).");
        criticalError = true;
      }
      if (receiver.isEmpty) {
        warnings.add("⚠️ No se detectó el destino 'Elvis A. Flores G.'.");
      }
      if (!isDateValid) {
        warnings.add("⚠️ La fecha del voucher no parece ser de hoy.");
        criticalError = true;
      }
      if (scannedCode.isEmpty) {
        warnings.add("⚠️ No se leyó el N° de Operación claramente.");
      }

      if (!mounted) return;

      // Mostrar Resultados
      bool? confirm = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          title: Text(
              warnings.isEmpty ? "Voucher Válido ✅" : "Revisar Voucher 👀"),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (warnings.isEmpty)
                  const Text("Todos los datos coinciden correctamente.",
                      style: TextStyle(color: Colors.green)),
                ...warnings.map((w) => Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: Text(w, style: const TextStyle(color: Colors.red)),
                    )),
                const Divider(),
                _buildReviewRow("Monto leído:", "S/. $scannedAmountStr"),
                _buildReviewRow(
                    "Destino:", receiver.isEmpty ? "No detectado" : receiver),
                _buildReviewRow("Hora:", time.isEmpty ? "No detectada" : time),
                _buildReviewRow("Operación:", scannedCode),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text("Cancelar"),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: criticalError
                      ? Colors.red
                      : (warnings.isNotEmpty ? Colors.orange : Colors.green)),
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(criticalError ? "OMITIR Y CREAR" : "CONFIRMAR"),
            ),
          ],
        ),
      );

      if (confirm != true) {
        setState(() => _isProcessing = false);
        return;
      }

      // Crear Ticket
      final finalCode = scannedCode.isEmpty ? "NO_DETECTADO" : scannedCode;
      final ticket = await _ticketService.createTicket(
        userId: user!.uid,
        adultCount: adult,
        universityCount: university,
        schoolCount: school,
        totalAmount: total,
        paymentRef: finalCode,
      );

      if (!mounted) return;
      Navigator.push(context,
          MaterialPageRoute(builder: (_) => TicketScreen(ticket: ticket)));

      setState(() {
        adult = 1;
        university = 0;
        school = 0;
      });
    } catch (e) {
      // CAMBIO AQUÍ: Usamos el Pop-up en lugar del SnackBar
      if (mounted) {
        _showErrorDialog(e.toString());
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Widget _buildReviewRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style:
                  const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          Flexible(child: Text(value, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }

  Widget _buildCounterDark({
    required String label,
    required double price,
    required int value,
    required VoidCallback onAdd,
    required VoidCallback onRemove,
  }) {
    final theme = Theme.of(context);
    return Card(
      color: theme.cardColor,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.symmetric(vertical: 10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: theme.textTheme.bodyLarge?.color)),
                Text('S/. ${price.toStringAsFixed(2)}',
                    style: TextStyle(
                        color: theme.textTheme.bodySmall?.color, fontSize: 14)),
              ],
            ),
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline,
                      color: Colors.red, size: 28),
                  onPressed: onRemove,
                ),
                Text(
                  '$value',
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: theme.textTheme.bodyLarge?.color),
                ),
                IconButton(
                  icon: const Icon(Icons.add_circle_outline,
                      color: Colors.green, size: 28),
                  onPressed: onAdd,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _signOut() async {
    await _authService.signOut();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Comprar Ticket'),
        backgroundColor: theme.appBarTheme.backgroundColor,
        elevation: 0,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.confirmation_number),
            tooltip: 'Mis Tickets',
            onPressed: () {
              Navigator.pushNamed(context, '/passenger-tickets');
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Cerrar sesión',
            onPressed: _signOut,
          )
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Bienvenido, ${user?.displayName ?? 'Pasajero'}',
              style: theme.textTheme.headlineSmall
                  ?.copyWith(color: theme.textTheme.bodyLarge?.color),
            ),
            const SizedBox(height: 12),
            Text(
              'Selecciona la cantidad de pasajeros:',
              style: theme.textTheme.titleMedium
                  ?.copyWith(color: theme.textTheme.bodySmall?.color),
            ),
            const SizedBox(height: 12),
            _buildCounterDark(
              label: 'Adultos',
              price: adultPrice,
              value: adult,
              onAdd: () => setState(() => adult++),
              onRemove: () {
                if (adult > 0 || (university + school) > 0) {
                  if (adult > 0) setState(() => adult--);
                }
              },
            ),
            _buildCounterDark(
              label: 'Universitarios',
              price: universityPrice,
              value: university,
              onAdd: () => setState(() => university++),
              onRemove: () {
                if (university > 0) setState(() => university--);
              },
            ),
            _buildCounterDark(
              label: 'Escolares',
              price: schoolPrice,
              value: school,
              onAdd: () => setState(() => school++),
              onRemove: () {
                if (school > 0) setState(() => school--);
              },
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Total a pagar:',
                    style: theme.textTheme.titleLarge
                        ?.copyWith(color: theme.textTheme.bodyLarge?.color),
                  ),
                  Text(
                    'S/. ${total.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: theme.primaryColor,
                    ),
                  ),
                ],
              ),
            ),
            const Spacer(),
            _isProcessing
                ? const Center(child: CircularProgressIndicator())
                : SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.check_circle_outline, size: 26),
                      onPressed: _showPaymentInstructions,
                      style: theme.elevatedButtonTheme.style,
                      label: const Text(
                        'PAGAR CON YAPE',
                        style: TextStyle(fontSize: 18, color: Colors.white),
                      ),
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}
