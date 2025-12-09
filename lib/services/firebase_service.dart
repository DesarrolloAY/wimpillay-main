import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:wimpillay_main/models/ticket_model.dart';

class FirebaseService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Guardamos el ticket y actualizamos su ID
  Future<TicketModel> saveTicket(TicketModel ticket) async {
    try {
      // 1. Añade el documento a la colección 'tickets'
      // Guardamos la referencia (docRef) una sola vez
      DocumentReference docRef =
          await _db.collection('tickets').add(ticket.toMap());

      // 2. Obtenemos el ID generado una sola vez
      String ticketId = docRef.id;

      // --- AQUÍ HABÍA CÓDIGO DUPLICADO QUE ELIMINÉ ---

      // 3. Creamos la data del QR (¡ACTUALIZADO CON REF!)
      // Si paymentRef es null, ponemos "NA"
      String qrData =
          'TKT:${ticketId}::USER:${ticket.userId}::REF:${ticket.paymentRef ?? "NA"}';

      // 4. Actualizamos el documento con su propio ID y el QR generado
      await docRef.update({
        'id': ticketId,
        'qrCode': qrData,
      });

      // 5. Devolvemos el modelo completo
      return TicketModel(
        id: ticketId,
        userId: ticket.userId,
        adultCount: ticket.adultCount,
        universityCount: ticket.universityCount,
        schoolCount: ticket.schoolCount,
        totalAmount: ticket.totalAmount,
        purchaseDate: ticket.purchaseDate,
        qrCode: qrData, // Solo una vez
        isUsed: ticket.isUsed,
        usedAt: ticket.usedAt,
        paymentRef: ticket.paymentRef, // Aseguramos devolver la referencia
      );
    } catch (e) {
      print('Error en saveTicket: $e');
      rethrow;
    }
  }

  Future<List<TicketModel>> getTickets() async {
    final snapshot = await _db.collection('tickets').get();
    return snapshot.docs
        .map((doc) => TicketModel.fromMap(doc.data(), doc.id))
        .toList();
  }
}
