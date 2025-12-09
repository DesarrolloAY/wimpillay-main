// lib/models/ticket_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class TicketModel {
  final String? id;
  final String userId;
  // --- NUEVO CAMPO ---
  final String? paymentRef; // Para guardar el N° de Operación de Yape/Plin
  // -------------------
  final int adultCount;
  final int universityCount;
  final int schoolCount;
  final double totalAmount;
  final Timestamp purchaseDate;
  final String qrCode;
  final bool isUsed;
  final Timestamp? usedAt;

  TicketModel({
    this.id,
    required this.userId,
    this.paymentRef, // <--- Añadir al constructor
    required this.adultCount,
    required this.universityCount,
    required this.schoolCount,
    required this.totalAmount,
    required this.purchaseDate,
    required this.qrCode,
    this.isUsed = false,
    this.usedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'paymentRef': paymentRef, // <--- Añadir al Mapa
      'adultCount': adultCount,
      'universityCount': universityCount,
      'schoolCount': schoolCount,
      'totalAmount': totalAmount,
      'purchaseDate': purchaseDate,
      'qrCode': qrCode,
      'isUsed': isUsed,
      'usedAt': usedAt,
    };
  }

  factory TicketModel.fromMap(Map<String, dynamic> map, String documentId) {
    return TicketModel(
      id: documentId,
      userId: map['userId'] ?? '',
      paymentRef: map['paymentRef'], // <--- Leer del Mapa (puede ser null)
      adultCount: map['adultCount'] ?? 0,
      universityCount: map['universityCount'] ?? 0,
      schoolCount: map['schoolCount'] ?? 0,
      totalAmount: (map['totalAmount'] ?? 0).toDouble(),
      purchaseDate: map['purchaseDate'] ?? Timestamp.now(),
      qrCode: map['qrCode'] ?? '',
      isUsed: map['isUsed'] ?? false,
      usedAt: map['usedAt'],
    );
  }
}
