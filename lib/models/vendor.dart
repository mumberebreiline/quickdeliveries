import 'location.dart';

/// The food vendor running the stall. In v1 there's likely just one vendor
/// (her), but modelling it properly now means the app can support more
/// vendors later without a rewrite.
class Vendor {
  final String id;
  final String name;
  final String phone;
  final String? email;
  final Location? currentLocation;
  final bool isOnline;
  final double rating;

  const Vendor({
    required this.id,
    required this.name,
    required this.phone,
    this.email,
    this.currentLocation,
    this.isOnline = false,
    this.rating = 5.0,
  });

  factory Vendor.fromMap(Map<String, dynamic> map, String id) {
    return Vendor(
      id: id,
      name: map['name'] as String,
      phone: map['phone'] as String,
      email: map['email'] as String?,
      currentLocation: map['currentLocation'] != null
          ? Location.fromMap(map['currentLocation'] as Map<String, dynamic>)
          : null,
      isOnline: map['isOnline'] as bool? ?? false,
      rating: (map['rating'] as num?)?.toDouble() ?? 5.0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'phone': phone,
      'email': email,
      'currentLocation': currentLocation?.toMap(),
      'isOnline': isOnline,
      'rating': rating,
    };
  }
}
