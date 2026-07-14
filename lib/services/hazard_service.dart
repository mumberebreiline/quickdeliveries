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

  /// One-off fetch, used when building a route plan (a stream would be
  /// overkill for something that changes rarely).
  Future<List<RouteHazard>> getActiveHazards() async {
    final snapshot = await _ref.where('isActive', isEqualTo: true).get();
    return snapshot.docs
        .map((doc) => RouteHazard.fromMap(doc.data(), doc.id))
        .toList();
  }

  Future<void> reportHazard(RouteHazard hazard) {
    return _ref.add(hazard.toMap());
  }

  Future<void> deactivateHazard(String hazardId) {
    return _ref.doc(hazardId).update({'isActive': false});
  }
}
