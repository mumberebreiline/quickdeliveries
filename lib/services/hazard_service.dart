import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/route_hazard.dart';

class HazardService {
  final CollectionReference<Map<String, dynamic>> _ref = FirebaseFirestore
      .instance
      .collection('route_hazards');

  Stream<List<RouteHazard>> streamActiveHazards() {
    return _ref
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => RouteHazard.fromMap(doc.data(), doc.id))
              .toList(),
        );
  }

  Future<List<RouteHazard>> getActiveHazards() async {
    final snapshot = await _ref.where('isActive', isEqualTo: true).get();
    return snapshot.docs
        .map((doc) => RouteHazard.fromMap(doc.data(), doc.id))
        .toList();
  }

  Future<void> reportHazard(RouteHazard hazard) => _ref.add(hazard.toMap());

  Future<void> deactivateHazard(String hazardId) =>
      _ref.doc(hazardId).update({'isActive': false});
}
