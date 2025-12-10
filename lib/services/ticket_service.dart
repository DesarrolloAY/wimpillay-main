import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:wimpillay_main/models/ticket_model.dart';
import 'package:wimpillay_main/services/firebase_service.dart';

// Enum para saber el resultado de la validación
enum TicketValidationStatus { valid, alreadyUsed, notFound, error }

// Clase auxiliar para devolver el resultado y el ticket (si existe)
class ValidationResult {
  final TicketValidationStatus status;
  final TicketModel? ticket;
  final String message;

  ValidationResult({required this.status, this.ticket, required this.message});
}

class TicketService {
  final FirebaseService _firebaseService = FirebaseService();
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Tu método existente para CREAR tickets
  Future<TicketModel> createTicket({
    required String userId,
    required int adultCount,
    required int universityCount,
    required int schoolCount,
    required double totalAmount,
    String? paymentRef, // <--- NUEVO PARÁMETRO OPCIONAL
  }) async {
    // --- NUEVA VALIDACIÓN ANTI-FRAUDE ---
    // Si tenemos un número de operación (y no es "NO_DETECTADO"), verificamos duplicados
    if (paymentRef != null &&
        paymentRef != "NO_DETECTADO" &&
        paymentRef.isNotEmpty) {
      final querySnapshot = await _db
          .collection('tickets')
          .where('paymentRef',
              isEqualTo: paymentRef) // Buscamos tickets con el mismo código
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        // ¡ENCONTRAMOS UN DUPLICADO!
        // Lanzamos un error para detener todo el proceso.
        throw Exception(
            "Este voucher (Operación $paymentRef) ya fue utilizado anteriormente.");
      }
    }
    // ------------------------------------

    final ticket = TicketModel(
      userId: userId,
      paymentRef: paymentRef, // <--- Pasamos el dato al modelo
      adultCount: adultCount,
      universityCount: universityCount,
      schoolCount: schoolCount,
      totalAmount: totalAmount,
      purchaseDate: Timestamp.now(),
      qrCode: '',
      isUsed: false,
      usedAt: null,
    );
    return await _firebaseService.saveTicket(ticket);
  }

  // Obtener tickets del usuario en tiempo real
  Stream<List<TicketModel>> getUserTickets(String userId) {
    return _db
        .collection('tickets')
        .where('userId', isEqualTo: userId)
        // Nota: Ordenar en Firestore requiere crear un índice compuesto.
        // Para evitar complicaciones ahora, ordenaremos en la app (Dart).
        .snapshots()
        .map((snapshot) {
      final tickets = snapshot.docs
          .map((doc) => TicketModel.fromMap(doc.data(), doc.id))
          .toList();

      // Ordenamos aquí: Los más recientes primero
      tickets.sort((a, b) => b.purchaseDate.compareTo(a.purchaseDate));
      return tickets;
    });
  }

  // --- NUEVA LÓGICA DE VALIDACIÓN ---
  Future<ValidationResult> validateTicket(String qrCodeData) async {
    try {
      // 1. Validar formato básico del QR
      // Se espera: "TKT:{ticketId}::USER:{userId}"
      if (!qrCodeData.startsWith("TKT:")) {
        return ValidationResult(
            status: TicketValidationStatus.error,
            message: "Formato de QR inválido o no pertenece a Wimpillay");
      }

      // 2. Extraer el ID del ticket
      // Ejemplo: de "TKT:QtRvn...::USER:jkl..." sacamos "QtRvn..."
      final parts = qrCodeData.split("::");
      if (parts.isEmpty) {
        return ValidationResult(
            status: TicketValidationStatus.error,
            message: "Código QR corrupto");
      }

      final ticketIdPart = parts[0]; // "TKT:QtRvn..."
      final ticketId = ticketIdPart.split(":")[1]; // "QtRvn..."

      // 3. Referencia al documento en Firestore
      final docRef = _db.collection('tickets').doc(ticketId);

      // 4. Usamos una transacción para asegurar integridad
      // Esto evita que dos choferes escaneen el mismo ticket al mismo milisegundo
      return await _db.runTransaction((transaction) async {
        final snapshot = await transaction.get(docRef);

        if (!snapshot.exists) {
          return ValidationResult(
              status: TicketValidationStatus.notFound,
              message: "Ticket no encontrado en el sistema");
        }

        // Convertimos la data a nuestro modelo
        final ticket = TicketModel.fromMap(snapshot.data()!, snapshot.id);

        // CASO A: SI YA FUE USADO
        if (ticket.isUsed) {
          return ValidationResult(
            status: TicketValidationStatus.alreadyUsed,
            ticket: ticket,
            message: "¡ALERTA! Este ticket ya fue utilizado.",
          );
        }

        // CASO B: SI ES VÁLIDO Y NUEVO -> LO MARCAMOS COMO USADO
        transaction.update(docRef, {
          'isUsed': true,
          'usedAt': FieldValue
              .serverTimestamp(), // Guardamos la hora exacta del escaneo
        });

        // Devolvemos el resultado de éxito
        return ValidationResult(
          status: TicketValidationStatus.valid,
          ticket: ticket,
          message: "Ticket válido. Pase autorizado.",
        );
      });
    } catch (e) {
      // Cualquier otro error técnico (sin internet, permisos, etc.)
      return ValidationResult(
          status: TicketValidationStatus.error,
          message: "Error técnico validando ticket: $e");
    }
  }
}
