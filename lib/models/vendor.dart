import 'location.dart';

/// The vendor running the stall. One vendor for now — modelled properly
/// so multi-vendor support later doesn't need a rewrite.
class Vendor {
  final String id;
  final String name;
  final String phone;
  final Location? currentLocation;
  final bool isOnline;

  const Vendor({
    required this.id,
    required this.name,
    required this.phone,
    this.currentLocation,
    this.isOnline = false,
  });

  factory Vendor.fromMap(Map<String, dynamic> map, String id) {
    return Vendor(
      id: id,
      name: map['name'] as String? ?? '',
      phone: map['phone'] as String? ?? '',
      currentLocation: map['currentLocation'] != null
          ? Location.fromMap(map['currentLocation'] as Map<String, dynamic>)
          : null,
      isOnline: map['isOnline'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'phone': phone,
      'currentLocation': currentLocation?.toMap(),
      'isOnline': isOnline,
    };
  }
}
