import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart'; // <--- NUEVO
import 'package:wimpillay_main/models/ticket_model.dart';
import 'package:wimpillay_main/services/ticket_service.dart';
import 'package:wimpillay_main/services/ocr_service.dart'; // <--- NUEVO
import 'package:wimpillay_main/screens/passenger/ticket_screen.dart';
import 'package:wimpillay_main/screens/auth/auth_service.dart';

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

  // --- NUEVOS SERVICIOS ---
  final OcrService _ocrService = OcrService();
  final ImagePicker _picker = ImagePicker();
  // ------------------------

  // IMPORTANTE: No olvides cerrar el OCR cuando salgas de la pantalla
  @override
  void dispose() {
    _ocrService.dispose();
    super.dispose();
  }

  final user = FirebaseAuth.instance.currentUser;
  final AuthService _authService = AuthService();

  // NUEVA FUNCIÓN PRINCIPAL DEL BOTÓN DE PAGO
  Future<void> _confirmPaymentWithScreenshot() async {
    // 1. Validaciones básicas
    if (total <= 0) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Selecciona pasajeros')));
      return;
    }
    if (user == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Error de usuario')));
      return;
    }

    try {
      // 2. Abrir Galería para seleccionar la captura
      final XFile? image = await _picker.pickImage(
          source: ImageSource.gallery,
          imageQuality: 85 // Comprimir un poco para que sea rápido
          );

      if (image == null) return; // El usuario canceló la selección

      // 3. Mostrar "Procesando..."
      setState(() => _isProcessing = true);

      // 4. Llamar a nuestro servicio de OCR
      final scannedData = await _ocrService.scanPaymentVoucher(image);

      final String scannedAmountStr = scannedData['amount'] ?? "0";
      final String scannedCode = scannedData['code'] ?? "";
      final double amountDetected = double.tryParse(scannedAmountStr) ?? 0.0;

      // 5. Validación Anti-Fraude (Básica)
      // Verificamos si el monto en la foto coincide con el total a pagar
      // Usamos una pequeña tolerancia de 0.01 por errores de redondeo en doubles
      bool isAmountCorrect = (amountDetected - total).abs() < 0.01;

      if (!mounted) return;

      // 6. Mostrar diálogo de confirmación al usuario con los datos leídos
      bool? confirm = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          title: Row(
            children: [
              Icon(
                  isAmountCorrect
                      ? Icons.check_circle
                      : Icons.warning_amber_rounded,
                  color: isAmountCorrect ? Colors.green : Colors.orange),
              const SizedBox(width: 10),
              const Text("Confirmar Datos"),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Total a pagar: S/. ${total.toStringAsFixed(2)}",
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 15),
              const Text("Datos leídos de la imagen:",
                  style: TextStyle(color: Colors.grey)),
              const Divider(),
              // Mostramos el monto leído. Si no coincide, lo ponemos en rojo.
              Text("Monto: S/. $scannedAmountStr",
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isAmountCorrect ? Colors.black : Colors.red)),

              if (!isAmountCorrect)
                const Text("⚠️ El monto de la imagen no coincide.",
                    style: TextStyle(color: Colors.red, fontSize: 12)),

              const SizedBox(height: 10),
              // Mostramos el código leído. Si está vacío, avisamos.
              Text(
                  "N° Operación: ${scannedCode.isEmpty ? 'No detectado' : scannedCode}",
                  style: const TextStyle(fontSize: 16)),

              if (scannedCode.isEmpty)
                const Text("⚠️ No se pudo leer el código claramente.",
                    style: TextStyle(color: Colors.orange, fontSize: 12)),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false), // Cancelar
              child: const Text("Cancelar"),
            ),
            ElevatedButton(
              // Si el monto no coincide, el botón es naranja como advertencia
              style: ElevatedButton.styleFrom(
                  backgroundColor: isAmountCorrect
                      ? Theme.of(context).primaryColor
                      : Colors.orange),
              onPressed: () => Navigator.pop(ctx, true), // Confirmar
              child: const Text("CONFIRMAR Y CREAR TICKET"),
            ),
          ],
        ),
      );

      // Si el usuario canceló el diálogo o dio click fuera
      if (confirm != true) {
        setState(() => _isProcessing = false);
        return;
      }

      // 7. Todo OK -> Crear Ticket en Firebase
      // Si no se leyó el código, enviamos "NO_DETECTADO" para que quede registro
      final finalCodeToSave =
          scannedCode.isEmpty ? "NO_DETECTADO" : scannedCode;

      final ticket = await _ticketService.createTicket(
        userId: user!.uid,
        adultCount: adult,
        universityCount: university,
        schoolCount: school,
        totalAmount: total,
        paymentRef: finalCodeToSave, // <--- ¡Aquí guardamos el dato del OCR!
      );

      if (!mounted) return;

      // 8. Navegar a la pantalla del ticket
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => TicketScreen(ticket: ticket)),
      );

      // Reseteamos contadores
      setState(() {
        adult = 1; // O 0, como prefieras
        university = 0;
        school = 0;
      });
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error procesando imagen: $e')));
    } finally {
      // Siempre quitamos el "Procesando..." al final
      if (mounted) setState(() => _isProcessing = false);
    }
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
          // --- NUEVO BOTÓN: MIS TICKETS ---
          IconButton(
            icon: const Icon(Icons.confirmation_number), // Ícono de ticket
            tooltip: 'Mis Tickets',
            onPressed: () {
              // Navegamos a la ruta que crearemos en el siguiente paso
              Navigator.pushNamed(context, '/passenger-tickets');
            },
          ),
          // --- FIN NUEVO BOTÓN ---

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
                      onPressed: _confirmPaymentWithScreenshot,
                      style: theme.elevatedButtonTheme.style,
                      label: const Text(
                        'CONFIRMAR PAGO',
                        style: TextStyle(fontSize: 18, color: Colors.white),
                      ),
                    ),
                  ),
          ],
        ),
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
}
