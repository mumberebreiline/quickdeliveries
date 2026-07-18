import 'package:cloud_firestore/cloud_firestore.dart';

class Accompaniment {
  final String id;
  final String name;
  final double extraPrice;

  Accompaniment({
    required this.id,
    required this.name,
    required this.extraPrice,
  });

  factory Accompaniment.fromFirestore(
      DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return Accompaniment(
      id: doc.id,
      name: data['name'],
      extraPrice: (data['price'] ?? 0).toDouble(),
    );
  }
}